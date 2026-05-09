/* mesh_slice_4x.h — driver helper for povlab:user:mesh_slice_render:1.0 IP.
 *
 * IP synthesized via hls_proj/run_mesh_slice_synth.tcl (Phase 9.5 task G).
 * 移植自 helloworld.c::cpu_render_mesh_slice_panel (1.5 ms/cell on ARM).
 * HLS 期望 5-10× 加速 (estimate 历史偏乐观 14×, 实测可能 3-5× 因 m_axi DDR 写带宽).
 *
 * 当前是 1× 实例 driver. 4× 实例并行 (各 IP 跑 6 cell, 24 cell 总) 待 BD
 * 集成完后扩展, 跟 voxel_slicer_4ip.h 同结构.
 *
 * 寄存器布局 (跟 hls_proj/proj_mesh_slice/.../xmesh_slice_render_hw.h 一致,
 * Vitis HLS 2024.2 综合 verified 2026-05-09):
 *
 *   0x00 AP_CTRL    (bit0 ap_start, bit1 ap_done, bit2 ap_idle)
 *   0x04 GIE
 *   0x08 IER
 *   0x0C ISR
 *   0x10 verts_bytes_lo
 *   0x14 verts_bytes_hi
 *   0x1C tris_bytes_lo
 *   0x20 tris_bytes_hi
 *   0x28 tri_colors_bytes_lo
 *   0x2C tri_colors_bytes_hi
 *   0x34 n_verts
 *   0x3C n_tris
 *   0x44 per_tri_color
 *   0x4C angle_deg
 *   0x54 x_half_q4
 *   0x5C y_min_q4
 *   0x64 y_max_q4
 *   0x6C slice_w
 *   0x74 slice_h
 *   0x7C fb_bytes_lo
 *   0x80 fb_bytes_hi
 *   0x88 fb_stride
 *   0x90 origin_x
 *   0x98 origin_y
 *   0xA0 do_clear (0=skip clear panel, 1=IP 内填灰底 80; 推荐 0)
 *
 * Performance estimate (HLS report, 150 MHz):
 *   - Min  73 us/cell (do_clear=0, ~1K tri 小 mesh, panel 160×120)
 *   - Max  85 ms/cell (do_clear=1, 32K tris worst case, 240×320 panel)
 *   - Real ~300-500 us/cell (anime mesh ~2-4K tris culled, 160×120, do_clear=0)
 *   ARM baseline 1.5 ms/cell -> 期望 3-20× 加速
 *   注: HLS estimate 偏乐观 14× (m_axi DDR 写实际慢得多, 见 feedback_hls_cycle_estimate_optimistic).
 *       板上实测必须 measure 后再调.
 */
#ifndef MESH_SLICE_4X_H
#define MESH_SLICE_4X_H

#include "xil_io.h"

/* PS GP0 临时基址 (BD 接好 IP 后用 xparameters.h XPAR_*_BASEADDR 替换). */
#ifndef MESH_SLICE_BASE_0
#define MESH_SLICE_BASE_0  0x43C60000UL
#endif

#define MESH_SLICE_AP_CTRL          0x00
#define MESH_SLICE_GIE              0x04
#define MESH_SLICE_IER              0x08
#define MESH_SLICE_ISR              0x0C
#define MESH_SLICE_VERTS_LO         0x10
#define MESH_SLICE_VERTS_HI         0x14
#define MESH_SLICE_TRIS_LO          0x1C
#define MESH_SLICE_TRIS_HI          0x20
#define MESH_SLICE_TRI_COLORS_LO    0x28
#define MESH_SLICE_TRI_COLORS_HI    0x2C
#define MESH_SLICE_N_VERTS          0x34
#define MESH_SLICE_N_TRIS           0x3C
#define MESH_SLICE_PER_TRI_COLOR    0x44
#define MESH_SLICE_ANGLE_DEG        0x4C
#define MESH_SLICE_X_HALF_Q4        0x54
#define MESH_SLICE_Y_MIN_Q4         0x5C
#define MESH_SLICE_Y_MAX_Q4         0x64
#define MESH_SLICE_SLICE_W          0x6C
#define MESH_SLICE_SLICE_H          0x74
#define MESH_SLICE_FB_LO            0x7C
#define MESH_SLICE_FB_HI            0x80
#define MESH_SLICE_FB_STRIDE        0x88
#define MESH_SLICE_ORIGIN_X         0x90
#define MESH_SLICE_ORIGIN_Y         0x98
#define MESH_SLICE_DO_CLEAR         0xA0

#define MESH_SLICE_AP_START_BIT     0x01
#define MESH_SLICE_AP_DONE_BIT      0x02
#define MESH_SLICE_AP_IDLE_BIT      0x04

static inline void mesh_slice_w(u32 base, u32 off, u32 v) {
    Xil_Out32(base + off, v);
}
static inline u32 mesh_slice_r(u32 base, u32 off) {
    return Xil_In32(base + off);
}

/* Configure all parameters for a single render and trigger ap_start.
 * Caller must:
 *   - Xil_DCacheFlushRange the verts/tris/tri_colors buffers (not changing? skip)
 *   - Xil_DCacheFlushRange the panel rect on fb (so IP doesn't fight cached writes)
 *   - After return: Xil_DCacheInvalidateRange the panel rect
 */
static inline void mesh_slice_fire(
    u32 base,
    u32 verts_addr,         /* DDR 地址, mesh_verts (9B 每元素) */
    u32 tris_addr,          /* DDR 地址, mesh_tris (6B 每元素) */
    u32 tri_colors_addr,    /* DDR 地址, mesh_tri_colors (3B 每元素), per_tri_color=1 才用 */
    u32 n_verts,
    u32 n_tris,
    u32 per_tri_color,
    u32 angle_deg,
    int x_half_q4,
    int y_min_q4,
    int y_max_q4,
    u32 slice_w,
    u32 slice_h,
    u32 fb_addr,
    u32 fb_stride,
    u32 origin_x,
    u32 origin_y,
    u32 do_clear)         /* 0 = caller pre-cleared panel, 1 = IP 内清灰底 */
{
    mesh_slice_w(base, MESH_SLICE_VERTS_LO,      verts_addr);
    mesh_slice_w(base, MESH_SLICE_VERTS_HI,      0);
    mesh_slice_w(base, MESH_SLICE_TRIS_LO,       tris_addr);
    mesh_slice_w(base, MESH_SLICE_TRIS_HI,       0);
    mesh_slice_w(base, MESH_SLICE_TRI_COLORS_LO, tri_colors_addr);
    mesh_slice_w(base, MESH_SLICE_TRI_COLORS_HI, 0);
    mesh_slice_w(base, MESH_SLICE_N_VERTS,       n_verts);
    mesh_slice_w(base, MESH_SLICE_N_TRIS,        n_tris);
    mesh_slice_w(base, MESH_SLICE_PER_TRI_COLOR, per_tri_color);
    mesh_slice_w(base, MESH_SLICE_ANGLE_DEG,     angle_deg);
    mesh_slice_w(base, MESH_SLICE_X_HALF_Q4,     (u32)x_half_q4);
    mesh_slice_w(base, MESH_SLICE_Y_MIN_Q4,      (u32)y_min_q4);
    mesh_slice_w(base, MESH_SLICE_Y_MAX_Q4,      (u32)y_max_q4);
    mesh_slice_w(base, MESH_SLICE_SLICE_W,       slice_w);
    mesh_slice_w(base, MESH_SLICE_SLICE_H,       slice_h);
    mesh_slice_w(base, MESH_SLICE_FB_LO,         fb_addr);
    mesh_slice_w(base, MESH_SLICE_FB_HI,         0);
    mesh_slice_w(base, MESH_SLICE_FB_STRIDE,     fb_stride);
    mesh_slice_w(base, MESH_SLICE_ORIGIN_X,      origin_x);
    mesh_slice_w(base, MESH_SLICE_ORIGIN_Y,      origin_y);
    mesh_slice_w(base, MESH_SLICE_DO_CLEAR,      do_clear);
    /* Trigger. */
    u32 v = mesh_slice_r(base, MESH_SLICE_AP_CTRL);
    mesh_slice_w(base, MESH_SLICE_AP_CTRL, v | MESH_SLICE_AP_START_BIT);
}

/* Block until ap_done. Returns 0 = ok, 1 = timeout. */
static inline int mesh_slice_wait(u32 base, u32 timeout_iters) {
    for (u32 t = 0; t < timeout_iters; t++) {
        if (mesh_slice_r(base, MESH_SLICE_AP_CTRL) & MESH_SLICE_AP_DONE_BIT) return 0;
    }
    return 1;
}

#endif /* MESH_SLICE_4X_H */
