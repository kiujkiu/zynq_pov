/* pov_project.h - POV 3D projection HLS IP interface
 *
 * 每次调用把一个 3D 点云投影到切片网格中的一格:
 *   model   : DDR 里的点云数组 (AXI master 读)
 *   fb      : DDR 帧缓冲 (AXI master 写, 只写这一片的区域)
 *   angle_idx: 0..71 (对应 0°..355° 每 5°)
 *   dst_x,dst_y: 这一片在整帧里的左上角像素坐标
 *   fb_stride: 整帧每行字节数 (1280*3=3840 for 720p)
 */
#ifndef POV_PROJECT_H
#define POV_PROJECT_H

#include <stdint.h>

#define SLICE_W     106
#define SLICE_H     120
#define NUM_ANGLES  72
#define MAX_POINTS  32768   /* 支持最多 32K 点模型 */

/* 16-byte aligned struct: 3 coords + 3 color channels + padding.
 * 16 bytes = 2×64b AXI beat, 对 HLS 综合友好. */
struct point_t {
    int16_t  x;
    int16_t  y;
    int16_t  z;
    int16_t  _pad0;
    uint8_t  r;
    uint8_t  g;
    uint8_t  b;
    uint8_t  _pad1;
    int32_t  _pad2;
};  /* sizeof = 16 */

/* HLS top function.
 * (不用 volatile: HLS AXI master 自己管内存一致性, 且 C++ 会跟默认拷贝构造冲突) */
void pov_project(
    const struct point_t *model,      /* m_axi:gmem0 读模型 */
    int num_points,                   /* s_axilite 控制寄存器 */
    int angle_idx,
    uint8_t *fb,                      /* m_axi:gmem1 写帧缓冲 */
    int fb_stride,
    int dst_x,
    int dst_y
);

#endif
