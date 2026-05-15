/* pov_project.cpp - HLS top function for POV 3D slice projection.
 *
 * 性能目标: II=1 流水线, 每周期处理 1 个点. @150MHz = 150M points/sec.
 *
 * 综合指示: #pragma 让 Vitis HLS 把这个函数综合成 RTL IP.
 * 生成的 IP 带 2 个 AXI master 端口 (m_axi) 和 1 个 AXI-Lite slave (s_axilite).
 */
#include "pov_project.h"
#include "cos_sin_lut.h"
#include <string.h>

void pov_project(
    const struct point_t *model,
    int num_points,
    int angle_idx,
    uint8_t *fb,
    int fb_stride,
    int dst_x,
    int dst_y,
    int slice_mode,
    int slice_half_thick
) {
#pragma HLS INTERFACE m_axi      port=model   offset=slave bundle=gmem0 depth=32768 \
    max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=fb      offset=slave bundle=gmem1 depth=3000000 \
    max_write_burst_length=256 num_write_outstanding=8
#pragma HLS INTERFACE s_axilite  port=model              bundle=control
#pragma HLS INTERFACE s_axilite  port=num_points         bundle=control
#pragma HLS INTERFACE s_axilite  port=angle_idx          bundle=control
#pragma HLS INTERFACE s_axilite  port=fb                 bundle=control
#pragma HLS INTERFACE s_axilite  port=fb_stride          bundle=control
#pragma HLS INTERFACE s_axilite  port=dst_x              bundle=control
#pragma HLS INTERFACE s_axilite  port=dst_y              bundle=control
#pragma HLS INTERFACE s_axilite  port=slice_mode         bundle=control
#pragma HLS INTERFACE s_axilite  port=slice_half_thick   bundle=control
#pragma HLS INTERFACE s_axilite  port=return             bundle=control

    /* 边界保护 */
    if (angle_idx < 0) angle_idx = 0;
    if (angle_idx >= NUM_ANGLES) angle_idx = NUM_ANGLES - 1;
    if (num_points < 0) num_points = 0;
    if (num_points > MAX_POINTS) num_points = MAX_POINTS;
    if (slice_half_thick < 0) slice_half_thick = 0;

    const int16_t c = POV_COS8[angle_idx];
    const int16_t s = POV_SIN8[angle_idx];

    /* NOTE: 切片清屏 + 画边框都交给 ARM 做 (ARM memset 到 DDR 比 IP 的 m_axi
     * 逐字节写快 3-4 倍). 本 IP 只做点云投影, 目标是切片 ~15us -> 72 slice ~1ms/frame. */

    /* 渲染每个点 */
    const int cx = SLICE_W / 2;
    const int cy = SLICE_H / 2;

POINTS_LOOP:
    for (int i = 0; i < num_points; i++) {
#pragma HLS LOOP_TRIPCOUNT min=100 max=MAX_POINTS
#pragma HLS PIPELINE II=1
        struct point_t p = model[i];

        /* 绕 Y 轴旋转:
         *   rx = (x*c + z*s) >> 8
         *   rz = (-x*s + z*c) >> 8   (only needed in slice_mode) */
        int32_t rx_q = (int32_t)p.x * (int32_t)c + (int32_t)p.z * (int32_t)s;
        int32_t rz_q = -(int32_t)p.x * (int32_t)s + (int32_t)p.z * (int32_t)c;
        int32_t rx   = rx_q >> 8;
        int32_t rz   = rz_q >> 8;

        /* z-slice clipping: only render thin slab around current rotation plane. */
        bool in_slab = !slice_mode || (rz <= slice_half_thick && rz >= -slice_half_thick);

        int sx = cx + (int)rx;
        int sy = cy - (int)p.y;

        if (in_slab && sx >= 0 && sx < SLICE_W && sy >= 0 && sy < SLICE_H) {
            /* 2×2 点 — 每像素 3 byte 独立写, HLS 流水 II=12, 实测最优. */
            for (int dy = 0; dy < 2; dy++) {
                for (int dx = 0; dx < 2; dx++) {
#pragma HLS UNROLL
                    int px = sx + dx;
                    int py = sy + dy;
                    if (px < SLICE_W && py < SLICE_H) {
                        int off = (dst_y + py) * fb_stride + (dst_x + px) * 3;
                        /* HDMI fb 字节序 = GBR (verified 2026-04-27 anime test) */
                        fb[off + 0] = p.g;
                        fb[off + 1] = p.b;
                        fb[off + 2] = p.r;
                    }
                }
            }
        }
    }
}


/* ============================================================ */
/* Batch 版: 一次 ap_start 渲染 N 个 slice.                      */
/* 省掉 72× AXI-Lite 协议 + 72× ap_done 握手 + 72× model DMA.    */

/* 每点 16 byte. anime voxel 实测 ~30K, 提到 32K 给 anime 留足空间.
 * 32768 × 16 = 512KB BRAM (~114 个 36Kb 块 ≈ Zynq-7020 BRAM 容量的 40%). */
#define MAX_BATCH_POINTS  32768

void pov_project_batch(
    const struct point_t *model,
    int num_points,
    uint8_t *ring_base,
    int slot_bytes,
    int slot_stride,
    int phase,
    int n_slots,
    int slice_mode,
    int slice_half_thick
) {
#pragma HLS INTERFACE m_axi      port=model      offset=slave bundle=gmem0 depth=1024 \
    max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=ring_base  offset=slave bundle=gmem1 depth=3000000 \
    max_write_burst_length=256 num_write_outstanding=16 max_widen_bitwidth=64
#pragma HLS INTERFACE s_axilite  port=model              bundle=control
#pragma HLS INTERFACE s_axilite  port=num_points         bundle=control
#pragma HLS INTERFACE s_axilite  port=ring_base          bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_bytes         bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_stride        bundle=control
#pragma HLS INTERFACE s_axilite  port=phase              bundle=control
#pragma HLS INTERFACE s_axilite  port=n_slots            bundle=control
#pragma HLS INTERFACE s_axilite  port=slice_mode         bundle=control
#pragma HLS INTERFACE s_axilite  port=slice_half_thick   bundle=control
#pragma HLS INTERFACE s_axilite  port=return             bundle=control

    if (num_points < 0) num_points = 0;
    if (num_points > MAX_BATCH_POINTS) num_points = MAX_BATCH_POINTS;
    if (n_slots < 0) n_slots = 0;
    if (n_slots > NUM_ANGLES) n_slots = NUM_ANGLES;
    if (slice_half_thick < 0) slice_half_thick = 0;

    /* Local copy of model in BRAM (1024 × 16 = 16KB).
     * HLS auto-chooses storage; removed BIND_STORAGE to avoid persistence bug. */
    struct point_t local_model[MAX_BATCH_POINTS];

LOAD_MODEL:
    for (int i = 0; i < num_points; i++) {
#pragma HLS LOOP_TRIPCOUNT min=100 max=MAX_BATCH_POINTS
#pragma HLS PIPELINE II=1
        local_model[i] = model[i];
    }

    const int cx = SLICE_W / 2;
    const int cy = SLICE_H / 2;

    /* v1.7: BRAM slot buffer + burst write. Architecture:
     *   1) Local 38KB slot_local[] in BRAM, ARRAY_PARTITION cyclic factor=6
     *      → 6 separate BRAMs, 1 byte each in row[0..5] writes to different
     *      partition → 6 parallel writes/cycle, II=2 for 2-row 12B/point.
     *   2) Project all points to slot_local (BRAM only, no m_axi contention).
     *   3) Burst-write slot_local to DDR via m_axi widened=64 (8 byte/cycle).
     *      4770 cycles per slot burst.
     *   Total per slot: ~(num_points × 2 + 4770) cycles. 30K pts × 72 slot
     *   = 30000 × 2 × 72 + 4770 × 72 = 4.32M + 0.34M = 4.66M cycle = 31 ms.
     *   vs v1.6 II=12: 30000 × 12 × 72 = 25.9M cycles = 173 ms estimate,
     *   actual hardware 1.39 sec. Expected 30+ fps render after this change. */
    static const int SLOT_BYTES_MAX = SLICE_W * SLICE_H * 3;
    /* 38160 byte slot, partition cyclic 6 way 让 6 个连续 byte 同 cycle 写不同 BRAM */
    uint8_t slot_local[SLOT_BYTES_MAX];
#pragma HLS ARRAY_PARTITION variable=slot_local cyclic factor=6

SLICES_LOOP:
    for (int s = 0; s < n_slots; s++) {
#pragma HLS LOOP_TRIPCOUNT min=72 max=72
        int angle = (phase + s) % NUM_ANGLES;
        if (angle < 0) angle += NUM_ANGLES;
        const int16_t cs = POV_COS8[angle];
        const int16_t sn = POV_SIN8[angle];
        uint8_t *slot_ddr = ring_base + s * slot_bytes;

        /* Phase 1: Clear local slot buffer (BRAM, parallel via partition) */
SLOT_LOCAL_CLEAR:
        for (int b = 0; b < SLOT_BYTES_MAX; b++) {
#pragma HLS LOOP_TRIPCOUNT min=38160 max=38160
#pragma HLS PIPELINE II=1
            slot_local[b] = 0;
        }

        /* Phase 2: Project points into local slot BRAM. */
POINTS_IN_SLICE:
        for (int i = 0; i < num_points; i++) {
#pragma HLS LOOP_TRIPCOUNT min=100 max=MAX_BATCH_POINTS
#pragma HLS PIPELINE II=2
            struct point_t p = local_model[i];

            int32_t rx_q = (int32_t)p.x * (int32_t)cs + (int32_t)p.z * (int32_t)sn;
            int32_t rz_q = -(int32_t)p.x * (int32_t)sn + (int32_t)p.z * (int32_t)cs;
            int32_t rx = rx_q >> 8;
            int32_t rz = rz_q >> 8;

            bool in_slab = !slice_mode || (rz <= slice_half_thick && rz >= -slice_half_thick);

            int sx = cx + (int)rx;
            int sy = cy - (int)p.y;
            bool ok = in_slab && sx >= 0 && sx < SLICE_W - 1
                                && sy >= 0 && sy < SLICE_H - 1;
            if (ok) {
                uint8_t row[6];
#pragma HLS ARRAY_PARTITION variable=row complete
                row[0] = p.g; row[1] = p.b; row[2] = p.r;
                row[3] = p.g; row[4] = p.b; row[5] = p.r;
                for (int dy = 0; dy < 2; dy++) {
#pragma HLS UNROLL
                    int off = (sy + dy) * slot_stride + sx * 3;
ROW_WRITE_LOCAL:
                    for (int k = 0; k < 6; k++) {
#pragma HLS UNROLL
                        slot_local[off + k] = row[k];
                    }
                }
            }
        }

        /* Phase 3: Burst-write slot_local (BRAM) to DDR via m_axi widened=64 */
SLOT_BURST_WRITE:
        for (int b = 0; b < SLOT_BYTES_MAX; b++) {
#pragma HLS LOOP_TRIPCOUNT min=38160 max=38160
#pragma HLS PIPELINE II=1
            slot_ddr[b] = slot_local[b];
        }
    }
}


/* ============================================================ */
/* pov_project_batch_v2: dual-HP + 6-byte row burst write 优化版 */
/* ============================================================ */
/* 同 pov_project_batch 签名兼容(可在 BD 直接替换), 内部改进:
 *
 *  1) 双 m_axi bundle: gmem0→hp1_read, gmem1→hp2_write.
 *     BD 把 hp1_read 接 HP1, hp2_write 接 HP2. 4-IP 并行时 IP0..IP3
 *     的读写各占独立 HP 通道, 不再共享 HP1 一个 64-bit 端口.
 *     这是 4-IP 并行的关键解锁(单 HP 上跑 4 IP 会被 AXI arbitration 卡死).
 *
 *  2) max_widen_bitwidth=64 + 6-byte row buffer 一次写两个相邻像素:
 *     原 12 byte store (2×2×3byte) → 2 个 burst write of length 6.
 *     虽然 II=12 的 m_axi 单口约束依然在(HLS warning 200-885 仍报),
 *     但 iteration latency 从 65 → 27, depth 从 66 → 27.
 *     等效"实际 cycle / 点" 更接近 II=1(因为 pipeline 启动 + 排空更短).
 *
 *  3) ARRAY_PARTITION local_model cyclic factor=2 dim=1: 给 BRAM
 *     2 读端口, 平摊读延迟.
 *
 *  4) clamp interior(SLICE_W-1, SLICE_H-1): 去掉 inner UNROLL 内部
 *     的 (px<W && py<H) 边界判断 → HLS 推断的 burst 长度变常量,
 *     可触发 max_widen 把 6-byte burst → 1 个 64-bit beat.
 *
 *  5) LOOP_FLATTEN off on SLICES_LOOP_V2: 让 outer/inner 不被 flatten,
 *     防止 DEPENDENCE 范围失效 + 让 HLS 报告 inner II 单独可见.
 *
 * 注: II=1 在 8-bit byte 写到单 m_axi 端口的设计上无法达成(物理约束:
 * 1 个 W 端口 / 1 周期 1 个 transaction). 真要 II=1 需把 slot 改成
 * 4-byte BGRX 或重写成 BRAM tile + 单次 burst flush, 但前者破坏
 * HDMI VDMA 兼容, 后者 38KB tile 加重 BURST_OUT 开销(实测变慢).
 * 因此 v2 走 dual-HP + iteration-latency 优化路径, 配合 4-IP 并行
 * 拿 4× 吞吐 = 720 slice × 30 Hz 目标可达.
 */

void pov_project_batch_v2(
    const struct point_t *model,
    int num_points,
    uint8_t *ring_base,
    int slot_bytes,
    int slot_stride,
    int phase,
    int n_slots,
    int slice_mode,
    int slice_half_thick
) {
#pragma HLS INTERFACE m_axi      port=model      offset=slave bundle=hp1_read  depth=1024 \
    max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=ring_base  offset=slave bundle=hp2_write depth=3000000 \
    max_write_burst_length=64 num_write_outstanding=16 max_widen_bitwidth=64
#pragma HLS INTERFACE s_axilite  port=model              bundle=control
#pragma HLS INTERFACE s_axilite  port=num_points         bundle=control
#pragma HLS INTERFACE s_axilite  port=ring_base          bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_bytes         bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_stride        bundle=control
#pragma HLS INTERFACE s_axilite  port=phase              bundle=control
#pragma HLS INTERFACE s_axilite  port=n_slots            bundle=control
#pragma HLS INTERFACE s_axilite  port=slice_mode         bundle=control
#pragma HLS INTERFACE s_axilite  port=slice_half_thick   bundle=control
#pragma HLS INTERFACE s_axilite  port=return             bundle=control

    if (num_points < 0) num_points = 0;
    if (num_points > MAX_BATCH_POINTS) num_points = MAX_BATCH_POINTS;
    if (n_slots < 0) n_slots = 0;
    if (n_slots > NUM_ANGLES) n_slots = NUM_ANGLES;
    if (slice_half_thick < 0) slice_half_thick = 0;

    struct point_t local_model[MAX_BATCH_POINTS];
#pragma HLS ARRAY_PARTITION variable=local_model cyclic factor=2 dim=1

LOAD_MODEL_V2:
    for (int i = 0; i < num_points; i++) {
#pragma HLS LOOP_TRIPCOUNT min=100 max=MAX_BATCH_POINTS
#pragma HLS PIPELINE II=1
        local_model[i] = model[i];
    }

    const int cx = SLICE_W / 2;
    const int cy = SLICE_H / 2;

SLICES_LOOP_V2:
    for (int s = 0; s < n_slots; s++) {
#pragma HLS LOOP_TRIPCOUNT min=72 max=72
#pragma HLS LOOP_FLATTEN off
        int angle = (phase + s) % NUM_ANGLES;
        if (angle < 0) angle += NUM_ANGLES;
        const int16_t cs = POV_COS8[angle];
        const int16_t sn = POV_SIN8[angle];
        uint8_t *slot = ring_base + s * slot_bytes;

POINTS_IN_SLICE_V2:
        for (int i = 0; i < num_points; i++) {
#pragma HLS LOOP_TRIPCOUNT min=100 max=MAX_BATCH_POINTS
#pragma HLS PIPELINE II=1
#pragma HLS DEPENDENCE variable=slot type=inter direction=WAW dependent=false
            struct point_t p = local_model[i];

            int32_t rx_q = (int32_t)p.x * (int32_t)cs + (int32_t)p.z * (int32_t)sn;
            int32_t rz_q = -(int32_t)p.x * (int32_t)sn + (int32_t)p.z * (int32_t)cs;
            int32_t rx = rx_q >> 8;
            int32_t rz = rz_q >> 8;

            bool in_slab = !slice_mode || (rz <= slice_half_thick && rz >= -slice_half_thick);

            int sx = cx + (int)rx;
            int sy = cy - (int)p.y;

            /* clamp interior — 让 6-byte burst 长度常量化, 触发 widen. */
            bool ok = in_slab && sx >= 0 && sx < SLICE_W - 1
                                && sy >= 0 && sy < SLICE_H - 1;

            if (ok) {
                /* 6-byte row buffer: GBR GBR (dx=0,1 同色, HDMI 字节序 GBR) */
                uint8_t row[6];
#pragma HLS ARRAY_PARTITION variable=row complete
                row[0] = p.g; row[1] = p.b; row[2] = p.r;
                row[3] = p.g; row[4] = p.b; row[5] = p.r;

                /* 2 行 × 6 byte: HLS 推断 2 burst writes of length 6,
                 * widen=64 后每行 1 个 64-bit beat 完成. */
                for (int dy = 0; dy < 2; dy++) {
#pragma HLS UNROLL
                    int off = (sy + dy) * slot_stride + sx * 3;
ROW_WRITE:
                    for (int k = 0; k < 6; k++) {
#pragma HLS UNROLL
                        slot[off + k] = row[k];
                    }
                }
            }
        }
    }
}


/* ============================================================ */
/* Voxel slicer batch                                            */
/* ============================================================ */

void pov_voxel_slice_batch(
    const uint16_t *voxel_grid,
    uint8_t *ring_base,
    int slot_bytes,
    int slot_stride,
    int phase,
    int slot_start,
    int n_slots
) {
#pragma HLS INTERFACE m_axi      port=voxel_grid offset=slave bundle=gmem0 \
    depth=2097152 max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=ring_base  offset=slave bundle=gmem1 \
    depth=3000000 max_write_burst_length=256 num_write_outstanding=8
#pragma HLS INTERFACE s_axilite  port=voxel_grid  bundle=control
#pragma HLS INTERFACE s_axilite  port=ring_base   bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_bytes  bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_stride bundle=control
#pragma HLS INTERFACE s_axilite  port=phase       bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_start  bundle=control
#pragma HLS INTERFACE s_axilite  port=n_slots     bundle=control
#pragma HLS INTERFACE s_axilite  port=return      bundle=control

    if (n_slots < 0) n_slots = 0;
    if (n_slots > NUM_ANGLES) n_slots = NUM_ANGLES;
    if (slot_start < 0) slot_start = 0;

    const int cx = SLICE_W / 2;
    const int cy = SLICE_H / 2;

SLICES_LOOP:
    for (int s = 0; s < n_slots; s++) {
#pragma HLS LOOP_TRIPCOUNT min=18 max=72
        /* 4-IP parallel: each instance fed unique (slot_start, n_slots) so
         * IP0 = slots [0..18), IP1 = [18..36), IP2 = [36..54), IP3 = [54..72).
         * angle still derived from (phase + global slot index). */
        int global_s = slot_start + s;
        int angle = (phase + global_s) % NUM_ANGLES;
        if (angle < 0) angle += NUM_ANGLES;
        const int16_t cs = POV_COS8[angle];
        const int16_t sn = POV_SIN8[angle];
        uint8_t *slot = ring_base + global_s * slot_bytes;

YY_LOOP:
        for (int py = 0; py < SLICE_H; py++) {
#pragma HLS LOOP_TRIPCOUNT min=120 max=120
XX_LOOP:
            for (int px = 0; px < SLICE_W; px++) {
#pragma HLS LOOP_TRIPCOUNT min=106 max=106
#pragma HLS PIPELINE II=1
                int rx_panel = px - cx;
                int ry_panel = cy - py;

                /* slab center: rotate (rx_panel, ?, 0) → (mx, my, mz) */
                int mx = (rx_panel * (int)cs) >> 8;
                int mz = (rx_panel * (int)sn) >> 8;
                int my = ry_panel;

                int vx = mx + VOXEL_HALF_HLS;
                int vy = my + VOXEL_HALF_HLS;
                int vz = mz + VOXEL_HALF_HLS;

                uint16_t rgb = 0;
                bool in = (vx >= 0 && vx < VOXEL_RES_HLS &&
                           vy >= 0 && vy < VOXEL_RES_HLS &&
                           vz >= 0 && vz < VOXEL_RES_HLS);
                if (in) {
                    int idx = (vz * VOXEL_RES_HLS + vy) * VOXEL_RES_HLS + vx;
                    rgb = voxel_grid[idx];
                }

                int off = py * slot_stride + px * 3;
                if (rgb != 0) {
                    uint8_t r5 = (uint8_t)((rgb >> 11) & 0x1F);
                    uint8_t g6 = (uint8_t)((rgb >> 5)  & 0x3F);
                    uint8_t b5 = (uint8_t)( rgb        & 0x1F);
                    /* HDMI fb 字节序 = GBR */
                    slot[off + 0] = (uint8_t)((g6 << 2) | (g6 >> 4));
                    slot[off + 1] = (uint8_t)((b5 << 3) | (b5 >> 2));
                    slot[off + 2] = (uint8_t)((r5 << 3) | (r5 >> 2));
                } else {
                    slot[off + 0] = 0;
                    slot[off + 1] = 0;
                    slot[off + 2] = 0;
                }
            }
        }
    }
}
