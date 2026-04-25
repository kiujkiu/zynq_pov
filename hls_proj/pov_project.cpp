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
    int dst_y
) {
#pragma HLS INTERFACE m_axi      port=model   offset=slave bundle=gmem0 depth=32768 \
    max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=fb      offset=slave bundle=gmem1 depth=3000000 \
    max_write_burst_length=256 num_write_outstanding=8
#pragma HLS INTERFACE s_axilite  port=model            bundle=control
#pragma HLS INTERFACE s_axilite  port=num_points       bundle=control
#pragma HLS INTERFACE s_axilite  port=angle_idx        bundle=control
#pragma HLS INTERFACE s_axilite  port=fb                bundle=control
#pragma HLS INTERFACE s_axilite  port=fb_stride        bundle=control
#pragma HLS INTERFACE s_axilite  port=dst_x            bundle=control
#pragma HLS INTERFACE s_axilite  port=dst_y            bundle=control
#pragma HLS INTERFACE s_axilite  port=return           bundle=control

    /* 边界保护 */
    if (angle_idx < 0) angle_idx = 0;
    if (angle_idx >= NUM_ANGLES) angle_idx = NUM_ANGLES - 1;
    if (num_points < 0) num_points = 0;
    if (num_points > MAX_POINTS) num_points = MAX_POINTS;

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

        /* 绕 Y 轴旋转: x' = x*c + z*s (>> 8), y' = y */
        int32_t rx_q = (int32_t)p.x * (int32_t)c + (int32_t)p.z * (int32_t)s;
        int32_t rx   = rx_q >> 8;

        int sx = cx + (int)rx;
        int sy = cy - (int)p.y;

        if (sx >= 0 && sx < SLICE_W && sy >= 0 && sy < SLICE_H) {
            /* 2×2 点 — 每像素 3 byte 独立写, HLS 流水 II=12, 实测最优. */
            for (int dy = 0; dy < 2; dy++) {
                for (int dx = 0; dx < 2; dx++) {
#pragma HLS UNROLL
                    int px = sx + dx;
                    int py = sy + dy;
                    if (px < SLICE_W && py < SLICE_H) {
                        int off = (dst_y + py) * fb_stride + (dst_x + px) * 3;
                        fb[off + 0] = p.b;
                        fb[off + 1] = p.g;
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

/* 每点 16 byte, MAX_POINTS 太大放 BRAM 塞不下; 限制 batch 最大支持的点数. */
#define MAX_BATCH_POINTS  1024

void pov_project_batch(
    const struct point_t *model,
    int num_points,
    uint8_t *ring_base,
    int slot_bytes,
    int slot_stride,
    int phase,
    int n_slots
) {
#pragma HLS INTERFACE m_axi      port=model      offset=slave bundle=gmem0 depth=1024 \
    max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=ring_base  offset=slave bundle=gmem1 depth=3000000 \
    max_write_burst_length=256 num_write_outstanding=8
#pragma HLS INTERFACE s_axilite  port=model       bundle=control
#pragma HLS INTERFACE s_axilite  port=num_points  bundle=control
#pragma HLS INTERFACE s_axilite  port=ring_base   bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_bytes  bundle=control
#pragma HLS INTERFACE s_axilite  port=slot_stride bundle=control
#pragma HLS INTERFACE s_axilite  port=phase       bundle=control
#pragma HLS INTERFACE s_axilite  port=n_slots     bundle=control
#pragma HLS INTERFACE s_axilite  port=return      bundle=control

    if (num_points < 0) num_points = 0;
    if (num_points > MAX_BATCH_POINTS) num_points = MAX_BATCH_POINTS;
    if (n_slots < 0) n_slots = 0;
    if (n_slots > NUM_ANGLES) n_slots = NUM_ANGLES;

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

SLICES_LOOP:
    for (int s = 0; s < n_slots; s++) {
#pragma HLS LOOP_TRIPCOUNT min=72 max=72
        /* Use explicit modulo — HLS synthesis of while-loop reduction has
         * been seen to compile weirdly on hardware. */
        int angle = (phase + s) % NUM_ANGLES;
        if (angle < 0) angle += NUM_ANGLES;
        const int16_t cs = POV_COS8[angle];
        const int16_t sn = POV_SIN8[angle];
        uint8_t *slot = ring_base + s * slot_bytes;

POINTS_IN_SLICE:
        for (int i = 0; i < num_points; i++) {
#pragma HLS LOOP_TRIPCOUNT min=100 max=MAX_BATCH_POINTS
#pragma HLS PIPELINE II=1
            struct point_t p = local_model[i];

            int32_t rx_q = (int32_t)p.x * (int32_t)cs + (int32_t)p.z * (int32_t)sn;
            int32_t rx = rx_q >> 8;

            int sx = cx + (int)rx;
            int sy = cy - (int)p.y;

            if (sx >= 0 && sx < SLICE_W && sy >= 0 && sy < SLICE_H) {
                for (int dy = 0; dy < 2; dy++) {
                    for (int dx = 0; dx < 2; dx++) {
#pragma HLS UNROLL
                        int px = sx + dx;
                        int py = sy + dy;
                        if (px < SLICE_W && py < SLICE_H) {
                            int off = py * slot_stride + px * 3;
                            slot[off + 0] = p.b;
                            slot[off + 1] = p.g;
                            slot[off + 2] = p.r;
                        }
                    }
                }
            }
        }
    }
}
