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
 * (不用 volatile: HLS AXI master 自己管内存一致性, 且 C++ 会跟默认拷贝构造冲突)
 *
 * slice_mode:
 *   0 = full projection (所有点都渲染, 适合 HDMI 大画面)
 *   1 = z-slice clipping (只渲染 |rotated_z| <= slice_half_thick 的点,
 *        适合 LED 板的真切片或 36 格小预览)
 * slice_half_thick: only used when slice_mode==1; typical 4..16. */
void pov_project(
    const struct point_t *model,      /* m_axi:gmem0 读模型 */
    int num_points,                   /* s_axilite 控制寄存器 */
    int angle_idx,
    uint8_t *fb,                      /* m_axi:gmem1 写帧缓冲 */
    int fb_stride,
    int dst_x,
    int dst_y,
    int slice_mode,
    int slice_half_thick
);

/* Batch 版: 一次调用渲染 N 个 slice 到 ring buffer 的连续 slot.
 * 关键优化: model 在开头 DMA 到 BRAM 一次, 内部 72 次循环复用,
 *           省掉 72× m_axi gmem0 读的协议开销.
 * ARM 一次 AXI-Lite 设置参数 + ap_start, IP 自己跑 72 slice 再 ap_done.
 *
 * Slot 布局: ring[s] = ring_base + s * slot_bytes, 每 slot 是 SLICE_W*SLICE_H*3 byte.
 * Angle: 第 s 个 slice 的角度 = (s + phase) % NUM_ANGLES.
 */
void pov_project_batch(
    const struct point_t *model,
    int num_points,
    uint8_t *ring_base,     /* 72 个 slot 的起始地址 (DDR) */
    int slot_bytes,         /* SLICE_W * SLICE_H * 3 */
    int slot_stride,        /* 单 slot 内每行字节 = SLICE_W * 3 */
    int phase,              /* 动画相位, 第 0 个 slot 的 angle_idx */
    int n_slots,            /* 72 for 72-slice frame */
    int slice_mode,         /* 0 = projection, 1 = z-slice clipping */
    int slice_half_thick    /* 仅 slice_mode=1 用; 典型 4..16 */
);


/* === Voxel slicer ===
 * 输入: 128³ voxel grid (RGB565, 4 MB), 由 ARM 端从点云 voxelize 得到.
 * 输出: 同 pov_project_batch 写 ring buffer 各 slot.
 * 算法: 对每个 panel pixel (px, py), 反推到 model 坐标 (slab 中心, 即
 *       rotated_z = 0), 查 voxel grid, 非空则写颜色, 否则黑.
 *
 * 与 pov_project_batch 区别:
 *   - 输入是已 voxelize 的体素(每 cell 1 模型单位), 不再迭代 5000 点
 *   - 每个 panel pixel 一次 voxel lookup, 计算量 = panel_w*panel_h
 *   - 适合 LED 板 high-density slice rendering(720 slice × 30 Hz)
 *
 * VOXEL_RES 假设 = 128, cell size = 1 模型单位, world coord 范围 ±64. */
#define VOXEL_RES_HLS    128
#define VOXEL_HALF_HLS   64

/* slot_start: 起始 slot 索引 (4-IP 并行用 — 每个 IP 实例分 18 slot:
 *   IP0: slot_start=0,  n_slots=18    →  slots [0..17]
 *   IP1: slot_start=18, n_slots=18    →  slots [18..35]
 *   IP2: slot_start=36, n_slots=18    →  slots [36..53]
 *   IP3: slot_start=54, n_slots=18    →  slots [54..71]
 * 4 IP 并行可达 ~4× 单 IP 吞吐, 适配 LED panel 720 slice × 30 Hz. */
void pov_voxel_slice_batch(
    const uint16_t *voxel_grid,   /* m_axi:gmem0  128³ RGB565 (4 MB) */
    uint8_t *ring_base,           /* m_axi:gmem1  写 72 slot 各 panel */
    int slot_bytes,
    int slot_stride,
    int phase,
    int slot_start,
    int n_slots
);

#endif
