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
