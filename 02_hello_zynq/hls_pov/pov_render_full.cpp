/* pov_render_full.cpp - 路线 B1 可综合 HLS top. 见 pov_render_full.h.
 *
 * 综合产物: 1 个 AXI-Lite slave (control) + 3 个 m_axi master:
 *   gmem_pts (读 points + LUT), gmem_vox (读+写 voxel grid), gmem_out (写 compact 切片).
 *
 * 三阶段顺序 (共享 voxel_grid DDR, 不能跨阶段 dataflow):
 *   Phase 0 CLEAR  : 顺序 burst 写 0 到 128^3 voxel_grid (8 MB). 写带宽瓶颈, 一次性.
 *   Phase 1 SCATTER: 读 n_points point_t, 随机写 voxel_grid (last-write). no burst.
 *   Phase 2 GATHER : == pov_proj. LUT->BRAM, 逐角度 gather (随机读 grid) -> pack -> burst 写 ring.
 *
 * 资源/II 预期 (估, 不跑 csynth):
 *   - BRAM: lut_d/lut_wy 各 16384x16b = 1 BRAM18*?  ~ 16 BRAM18; slot_local 2048x32b ~ 4 BRAM18.
 *           总 ~20 BRAM18, 远小于 7020 的 280. 彩色网格 8MB 留 DDR 不进 BRAM.
 *   - DSP: q15_round 的 d*cs / d*sn 各 1 乘 (16x16), gather 内层 UNROLL x8 -> ~16 DSP.
 *   - Phase 0 CLEAR: 8MB / 4B = 2.10M cell, widen 64 -> 每拍 2 cell, II=1 -> ~1.05M cyc @150M ≈ 7.0 ms.
 *   - Phase 1 SCATTER: n_points ~30K, 每点 1 随机读+写? 不读, 只写, II≈1 但随机写无 burst
 *           m_axi 写延迟主导, 实测会高于估算 (见 memory feedback_hls_cycle_estimate_optimistic).
 *           30K * ~数十拍 ≈ 几百 us ~ 1 ms 量级.
 *   - Phase 2 GATHER: 与 pov_proj 同. 每片 2048 word * II=8 = 16384 拍, 720 片 ≈ 11.8M 拍 ≈ 79 ms (理论),
 *           随机 DDR 读实测远超 -> 4-IP 并行 + 离线批算 (非显示热路径).
 *   单 IP B1 全程 (清+散射+gather) 主要被 Phase 2 主导, 与 A 路径热路径一致 (Phase 0/1 一次性 < 10 ms).
 */
#include "pov_render_full.h"
#include "cos_sin_q15.h"

/* round(prod / 32768), 对称舍入 (round-half-away-from-zero). 与 host 参考 / pov_proj 一致. */
static inline int q15_round(int prod) {
#pragma HLS INLINE
    if (prod >= 0) return (prod + (1 << 14)) >> 15;
    else           return -(((-prod) + (1 << 14)) >> 15);
}

static inline int clamp127(int v) {
#pragma HLS INLINE
    if (v < 0)   return 0;
    if (v > 127) return 127;
    return v;
}

/* clip(v, 0, 127) 用于散射坐标 (== main.c clip127). */
static inline int clip127(int v) {
#pragma HLS INLINE
    if (v < 0)   return 0;
    if (v > 127) return 127;
    return v;
}

void pov_render_full(
    const struct point_t *points,
    struct voxel_t       *voxel_grid,
    const struct lut_t   *lut,
    uint32_t             *slice_base,
    int                   n_points,
    int                   n_total,
    int                   slot_start,
    int                   n_slots
) {
    /* ---- m_axi: points + lut 同 bundle gmem_pts (adapter 参数必须一致, 否则 ERROR 214-215) ---- */
#pragma HLS INTERFACE m_axi     port=points     offset=slave bundle=gmem_pts \
    depth=131072 max_read_burst_length=64 num_read_outstanding=16
#pragma HLS INTERFACE m_axi     port=lut        offset=slave bundle=gmem_pts \
    depth=16384  max_read_burst_length=64 num_read_outstanding=16
    /* ---- m_axi: voxel grid 读+写, 独立 bundle gmem_vox. Phase 0 顺序 burst 写, Phase 1 随机写, Phase 2 随机读 ---- */
#pragma HLS INTERFACE m_axi     port=voxel_grid offset=slave bundle=gmem_vox \
    depth=2097152 max_read_burst_length=64 max_write_burst_length=64 \
    num_read_outstanding=16 num_write_outstanding=16
    /* ---- m_axi: compact 切片输出, 独立 bundle gmem_out, widen 64 burst 写 ---- */
#pragma HLS INTERFACE m_axi     port=slice_base offset=slave bundle=gmem_out \
    depth=1474560 max_write_burst_length=256 num_write_outstanding=16 max_widen_bitwidth=64

#pragma HLS INTERFACE s_axilite port=points     bundle=control
#pragma HLS INTERFACE s_axilite port=voxel_grid bundle=control
#pragma HLS INTERFACE s_axilite port=lut        bundle=control
#pragma HLS INTERFACE s_axilite port=slice_base bundle=control
#pragma HLS INTERFACE s_axilite port=n_points   bundle=control
#pragma HLS INTERFACE s_axilite port=n_total    bundle=control
#pragma HLS INTERFACE s_axilite port=slot_start bundle=control
#pragma HLS INTERFACE s_axilite port=n_slots    bundle=control
#pragma HLS INTERFACE s_axilite port=return     bundle=control

    if (n_total  < 1) n_total = 1;
    if (n_slots  < 0) n_slots = 0;
    if (slot_start < 0) slot_start = 0;
    if (n_points < 0) n_points = 0;

    /* =============== Phase 0: 清网格 (顺序写 0, 可 burst) =============== */
    const struct voxel_t ZERO = {0, 0, 0, 0};
CLEAR_GRID:
    for (int i = 0; i < VOXEL_CELLS; i++) {
#pragma HLS PIPELINE II=1
        voxel_grid[i] = ZERO;
    }

    /* =============== Phase 1: 散射体素化 (随机写, last-write) =============== *
     * 与 main.c 体素化逻辑逐字节等价:
     *   vx=clip127(x+64), vy=clip127(y+64), vz=clip127(z+64)
     *   voxel_grid[(vx*128+vy)*128+vz] = {r,g,b,0}
     * 随机 DDR 写 (no burst); II 受写地址依赖限制, 这里读点是顺序 burst, 写是随机. */
SCATTER:
    for (int i = 0; i < n_points; i++) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=100000
#pragma HLS PIPELINE II=1
        struct point_t p = points[i];
        int vx = clip127((int)p.x + VOXEL_HALF);
        int vy = clip127((int)p.y + VOXEL_HALF);
        int vz = clip127((int)p.z + VOXEL_HALF);
        int idx = (vx * VOXEL_RES + vy) * VOXEL_RES + vz;
        struct voxel_t cell;
        cell.r = p.r; cell.g = p.g; cell.b = p.b; cell._pad = 0;
        voxel_grid[idx] = cell;   /* last-write */
    }

    /* =============== Phase 2: gather + pack (== pov_proj, bit-exact) =============== */

    /* ---- LUT -> BRAM (一次, 复用 n_slots 次) ---- */
    static int16_t lut_d [FWI_COUNT];
    static int16_t lut_wy[FWI_COUNT];
LOAD_LUT:
    for (int i = 0; i < FWI_COUNT; i++) {
#pragma HLS PIPELINE II=1
        struct lut_t e = lut[i];
        lut_d[i]  = e.d;
        lut_wy[i] = e.wy;
    }

    /* compact 切片本地缓冲 (8 KB BRAM). */
    static uint32_t slot_local[COMPACT_WORDS];

SLICES_LOOP:
    for (int s = 0; s < n_slots; s++) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=720
        int global_s = slot_start + s;

        int aidx;
        if (n_total == COS_TABLE_N) aidx = global_s;
        else                        aidx = (int)(((long)global_s * COS_TABLE_N) / n_total);
        aidx %= COS_TABLE_N;
        if (aidx < 0) aidx += COS_TABLE_N;
        const int cs = COS_Q15[aidx];
        const int sn = SIN_Q15[aidx];

GATHER:
        for (int w = 0; w < COMPACT_WORDS; w++) {
#pragma HLS PIPELINE II=8        /* 8 voxel gather (随机 DDR 读) / word */
            uint32_t word = 0;
        LANES:
            for (int k = 0; k < 8; k++) {
#pragma HLS UNROLL
                int fwi = (w << 3) | k;
                int d   = lut_d[fwi];
                int wy  = lut_wy[fwi];

                int wx = clamp127(q15_round(d * cs) + VOXEL_HALF);
                int wz = clamp127(q15_round(d * sn) + VOXEL_HALF);

                int vidx = (wx * VOXEL_RES + wy) * VOXEL_RES + wz;
                struct voxel_t v = voxel_grid[vidx];

                /* threshold >= 128. lane bit0=G,bit1=B,bit2=R. */
                uint32_t Gb = (v.g & 0x80) ? 1u : 0u;
                uint32_t Bb = (v.b & 0x80) ? 1u : 0u;
                uint32_t Rb = (v.r & 0x80) ? 1u : 0u;
                uint32_t lane = Gb | (Bb << 1) | (Rb << 2);
                word |= (lane << (k * 3));
            }
            slot_local[w] = word;
        }

        int base_w = global_s * COMPACT_WORDS;
WRITE_SLOT:
        for (int w = 0; w < COMPACT_WORDS; w++) {
#pragma HLS PIPELINE II=1
            slice_base[base_w + w] = slot_local[w];
        }
    }
}
