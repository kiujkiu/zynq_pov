/* mesh_slice.h - HLS IP for mesh cross-section slice rendering.
 *
 * 实现 ARM `cpu_render_mesh_slice_panel` 的加速版本 (helloworld.c:1642).
 *
 * 算法 two-phase:
 *   Phase 1 (segments): 遍历 mesh tris, 每 tri 三顶点 zp = -x*sin + z*cos
 *           sign 检查, cross 0 的 edge lerp 出 (x', y, color) 两点写
 *           本地 BRAM mesh_segs_buf[].
 *   Phase 2 (scanline): per pixel-row (slice_h 行), 找穿过该 y 的 segs,
 *           lerp x_cross, insertion sort, pair-fill + Gouraud lerp 颜色,
 *           写 fb (GBR 字节序).
 *
 * 限制 (跟 ARM 版差别):
 *   - MAX_MESH_VERTS_HLS = 8192  (ARM 16K, 板端裁剪到 ≤ 8K)
 *   - MAX_MESH_TRIS_HLS  = 32768 (= ARM)
 *   - MAX_MESH_SEGS_HLS  = 2048  (ARM 16K, 限制 BRAM 占用)
 *
 * 数据格式 (ARM helloworld.c 已有 packed 9B/6B/3B):
 *   verts:        int16 x,y,z (Q8.4) + u8 r,g,b   = 9B 每个
 *   tris:         u16 i0,i1,i2                    = 6B 每个
 *   tri_colors:   u8 r,g,b (per-tri-color flat)   = 3B 每个 (可空)
 *
 * Driver 使用流程:
 *   1) ARM 把 verts/tris/tri_colors 三个 buffer DMA 到 DDR (already in
 *      MESH_VERTS_ADDR / MESH_TRIS_ADDR / MESH_TRI_COLORS_ADDR)
 *   2) Xil_DCacheFlushRange 三个 buffer + fb panel 区域
 *   3) 设置 IP 寄存器 (verts_ptr, tris_ptr, tri_colors_ptr, n_tris,
 *      n_verts, per_tri_color, angle_deg, slice_w, slice_h, x_half_q4,
 *      y_min_q4, y_max_q4, fb_ptr, fb_stride, origin_x, origin_y), set ap_start
 *   4) 等 ap_done, Xil_DCacheInvalidateRange fb panel
 */
#ifndef MESH_SLICE_H
#define MESH_SLICE_H

#include <stdint.h>

#define MAX_MESH_VERTS_HLS  8192
#define MAX_MESH_TRIS_HLS   32768
#define MAX_MESH_SEGS_HLS   2048
#define MAX_X_CROSS_HLS     64    /* per scanline 最多多少 seg 穿过 — 2K segs / 60 行 ~= 30 平均 */

#ifdef __cplusplus
extern "C" {
#endif

/* HLS top function.
 *
 * 端口分组:
 *   m_axi gmem0  : verts        (read-only, 8192*9B = 72KB max)
 *   m_axi gmem1  : tris         (read-only, 32768*6B = 192KB max)
 *   m_axi gmem2  : tri_colors   (read-only, 32768*3B = 96KB max, 仅 per_tri_color=1)
 *   m_axi gmem3  : fb           (write, 整帧 1280*720*3 = 2.7MB, 实际只写 panel 区)
 *   s_axilite control: 所有标量参数 + 4 个指针
 *
 * 参数 (跟 ARM 版对齐):
 *   verts_bytes     : DDR 地址 (mesh_verts), 9B 每元素
 *   tris_bytes      : DDR 地址 (mesh_tris),  6B 每元素
 *   tri_colors_bytes: DDR 地址 (mesh_tri_colors), 3B 每元素 (per_tri_color=1 时用)
 *   n_verts         : 顶点数
 *   n_tris          : 三角形数
 *   per_tri_color   : 0=Gouraud-on-edge (verts.r/g/b lerp), 1=flat (tri_colors[t])
 *   angle_deg       : 0..359 度
 *   x_half_q4       : 模型 X 范围半值 (Q8.4), 用于 panel 投影缩放
 *   y_min_q4        : 模型 Y 范围下限 (Q8.4)
 *   y_max_q4        : 模型 Y 范围上限 (Q8.4)
 *   slice_w         : panel 宽度 (像素)
 *   slice_h         : panel 高度 (像素)
 *   fb_bytes        : DDR 帧缓冲基址 (写)
 *   fb_stride       : 整帧每行字节数 (1280*3=3840)
 *   origin_x        : panel 在帧内左上 x
 *   origin_y        : panel 在帧内左上 y
 *   do_clear        : 0=skip panel clear (caller ARM 已 memset), 1=IP 内部清灰底.
 *                    省掉 panel clear (160×120×3 cycle = 387 us) 是关键优化.
 */
void mesh_slice_render(
    const unsigned char *verts_bytes,
    const unsigned char *tris_bytes,
    const unsigned char *tri_colors_bytes,
    int n_verts,
    int n_tris,
    int per_tri_color,
    int angle_deg,
    int x_half_q4,
    int y_min_q4,
    int y_max_q4,
    int slice_w,
    int slice_h,
    unsigned char *fb_bytes,
    int fb_stride,
    int origin_x,
    int origin_y,
    int do_clear
);

#ifdef __cplusplus
}
#endif

#endif /* MESH_SLICE_H */
