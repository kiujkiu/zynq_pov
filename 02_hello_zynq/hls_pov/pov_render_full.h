/* pov_render_full.h - 路线 B1 HLS top: 点云 -> 清网格 -> 散射体素化 -> gather 切片.
 *
 * Target: Zynq-7020 (xc7z020clg484-2).
 *
 * 与 A 路径 (pov_proj) 区别:
 *   A: ARM 散射点云 -> 128^3 voxel_grid (DDR) -> pov_proj 只做 gather.
 *   B1: ARM 只把点云 DMA 进 DDR. 本 IP 一条龙做:
 *        Phase 0 清 128^3 voxel_grid (DDR scratch, 8MB, 顺序 burst 写 0)
 *        Phase 1 散射: 读 n_points 个 point_t, 写 voxel_grid[clip坐标]={r,g,b,0} (last-write)
 *        Phase 2 gather: 与现 pov_proj 完全相同 (LUT->BRAM, 逐角度 gather->pack->burst 写 ring)
 *
 * 三阶段对 voxel_grid 有顺序依赖 (清完才散射, 散射完才 gather), 不能跨阶段 dataflow.
 * Phase 2 的 gather/pack/write 逻辑逐字节复用 pov_proj, 保证 bit-exact.
 *
 * 数据格式 (与已验证管线对齐):
 *   point_t (16B 小端): int16 x,y,z,pad0; uint8 r,g,b,pad1; int32 pad2.
 *   voxel_t (4B): uint8 r,g,b,_pad. 网格 128^3, idx=(vx*128+vy)*128+vz, vx=clip(x+64,0,127).
 *   lut_t (4B): int16 d, int16 wy. 同 transform_lut.bin.
 *   compact slice: 2048 uint32 (8 KB) @ slice_base + s*0x2000.
 */
#ifndef POV_RENDER_FULL_H
#define POV_RENDER_FULL_H

#include <stdint.h>

#define VOXEL_RES     128          /* 128^3 grid */
#define VOXEL_HALF    64
#define VOXEL_CELLS   (128*128*128) /* 2097152 cell */
#define FWI_COUNT     16384         /* full-word-index 数 = 一片像素数 (128x128) */
#define COMPACT_WORDS 2048          /* 每片 compact word 数 = FWI_COUNT/8 */
#define COMPACT_BYTES 8192          /* 每片字节 = 0x2000 */
#define MAX_SLICES    720
#define COS_TABLE_N   720           /* cos/sin LUT 分辨率 (Q15) */

/* point_t: 与 main.c / anime_points.bin 一致. 16B, 小端. */
struct point_t {
    int16_t  x;
    int16_t  y;
    int16_t  z;
    int16_t  pad0;
    uint8_t  r;
    uint8_t  g;
    uint8_t  b;
    uint8_t  pad1;
    int32_t  pad2;
};   /* sizeof = 16 */

/* DDR voxel cell. host 写 r,g,b (每通道 8-bit), pad 对齐 4-byte. "on" = 通道 >= 128. */
struct voxel_t {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t _pad;
};   /* sizeof = 4. 128^3 * 4 = 8 MB grid in DDR. */

/* transform LUT entry (= tools/transform_lut.bin 一行). */
struct lut_t {
    int16_t d;     /* col - 64,  范围 [-64, 63] */
    int16_t wy;    /* 127 - row, 范围 [0, 127] */
};   /* sizeof = 4 */

/* ------------------------------------------------------------------ *
 * Top: 一次 ap_start = 点云 -> 清网格 -> 散射 -> gather [slot_start, +n_slots) 片.
 *
 *   points     : m_axi gmem_pts  读 n_points 个 point_t (DDR)
 *   n_points   : 点数
 *   voxel_grid : m_axi gmem_vox  读+写 128^3 voxel_t (DDR scratch, 8 MB)
 *   lut        : m_axi gmem_pts  读 16384 lut_t (64 KB) — 同 pts bundle, 开头载 BRAM
 *   slice_base : m_axi gmem_out  写 compact 切片 (DDR ring)
 *   n_total    : 总片数 (角度归一化用, 720)
 *   slot_start : 起始片 (4-IP 并行时 IP_i 从 i*ceil(n_total/4) 起)
 *   n_slots    : 本次渲染片数
 * ------------------------------------------------------------------ */
void pov_render_full(
    const struct point_t *points,
    struct voxel_t       *voxel_grid,
    const struct lut_t   *lut,
    uint32_t             *slice_base,
    int                   n_points,
    int                   n_total,
    int                   slot_start,
    int                   n_slots
);

#endif /* POV_RENDER_FULL_H */
