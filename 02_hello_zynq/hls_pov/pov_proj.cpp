/* pov_proj.cpp - synthesizable HLS top for PL voxel->compact-slice projection.
 *
 * 架构 B: voxel gather via static transform LUT (见 DESIGN_hls.md / pov_proj.h).
 *
 * 综合产物: 1 个 AXI-Lite slave (control) + 2 个 m_axi master:
 *   gmem0 (读 voxel grid + LUT), gmem1 (写 compact 切片).
 *
 * 性能策略:
 *   - LUT (16384 x 4B = 64 KB) 开头一次 DMA 进 BRAM (lut_d[], lut_wy[]),
 *     n_slots 次复用, 省 n_slots 次 64 KB 读.
 *   - voxel grid 8 MB 太大留 DDR, 每像素 1 次随机 m_axi 读 (gather). 这是吞吐瓶颈.
 *   - 每片在本地 BRAM 凑满 2048 word 的 compact buffer, 最后 burst 写 DDR
 *     (顺序 burst, widen=64 → 比逐 word 写 DDR 快).
 *
 * 注: 单 IP 的 voxel gather 是随机 DDR 读, 实测会远超 HLS 估算 (见 memory
 * feedback_hls_cycle_estimate_optimistic). 真正达 720 片/帧靠 4-IP 并行 +
 * 离线批算 (one-shot 整 720 片到 DDR ring), 不在显示热路径. 见 DESIGN_hls.md.
 */
#include "pov_proj.h"
#include "cos_sin_q15.h"

/* round(prod / 32768), 对称舍入 (round-half-away-from-zero). 与 host 参考一致. */
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

void pov_proj(
    const struct voxel_t *voxel_grid,
    const struct lut_t   *lut,
    uint32_t             *slice_base,
    int                   n_total,
    int                   slot_start,
    int                   n_slots
) {
#pragma HLS INTERFACE m_axi     port=voxel_grid offset=slave bundle=gmem0 \
    depth=2097152 max_read_burst_length=64 num_read_outstanding=16
#pragma HLS INTERFACE m_axi     port=lut        offset=slave bundle=gmem0 \
    depth=16384 max_read_burst_length=64 num_read_outstanding=16
#pragma HLS INTERFACE m_axi     port=slice_base offset=slave bundle=gmem1 \
    depth=1474560 max_write_burst_length=256 num_write_outstanding=16 max_widen_bitwidth=64
#pragma HLS INTERFACE s_axilite port=voxel_grid bundle=control
#pragma HLS INTERFACE s_axilite port=lut        bundle=control
#pragma HLS INTERFACE s_axilite port=slice_base bundle=control
#pragma HLS INTERFACE s_axilite port=n_total    bundle=control
#pragma HLS INTERFACE s_axilite port=slot_start bundle=control
#pragma HLS INTERFACE s_axilite port=n_slots    bundle=control
#pragma HLS INTERFACE s_axilite port=return     bundle=control

    if (n_total  < 1) n_total = 1;
    if (n_slots  < 0) n_slots = 0;
    if (slot_start < 0) slot_start = 0;

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

    /* compact 切片本地缓冲 (8 KB BRAM), partition 让 pack 阶段并行无冲突. */
    static uint32_t slot_local[COMPACT_WORDS];

SLICES_LOOP:
    for (int s = 0; s < n_slots; s++) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=720
        int global_s = slot_start + s;

        /* angle_idx into 720-entry Q15 table. n_total==720 时 = global_s. */
        int aidx;
        if (n_total == COS_TABLE_N) aidx = global_s;
        else                        aidx = (int)(((long)global_s * COS_TABLE_N) / n_total);
        aidx %= COS_TABLE_N;
        if (aidx < 0) aidx += COS_TABLE_N;
        const int cs = COS_Q15[aidx];
        const int sn = SIN_Q15[aidx];

        /* gather + pack. word 外层 / 8 lane 内层: 每个 compact word 在本地
         * 寄存器累积 8 个 lane, 一次写 slot_local[w], 无 read-modify-write
         * 跨迭代依赖 → II=1 干净 (无需 CLEAR_SLOT, word 直接覆盖写). */
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

                /* threshold >= 128. lane bit0=G,bit1=B,bit2=R (= _gen_transform_lut). */
                uint32_t Gb = (v.g & 0x80) ? 1u : 0u;
                uint32_t Bb = (v.b & 0x80) ? 1u : 0u;
                uint32_t Rb = (v.r & 0x80) ? 1u : 0u;
                uint32_t lane = Gb | (Bb << 1) | (Rb << 2);
                word |= (lane << (k * 3));
            }
            slot_local[w] = word;
        }

        /* burst-write compact slice to DDR: slice_base[global_s*2048 .. +2047] */
        int base_w = global_s * COMPACT_WORDS;
WRITE_SLOT:
        for (int w = 0; w < COMPACT_WORDS; w++) {
#pragma HLS PIPELINE II=1
            slice_base[base_w + w] = slot_local[w];
        }
    }
}
