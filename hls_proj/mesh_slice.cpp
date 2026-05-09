/* mesh_slice.cpp - HLS implementation of mesh cross-section slice render.
 *
 * 移植自 helloworld.c::cpu_render_mesh_slice_panel(L1642).
 * 性能目标: 板端 ARM 1.5 ms/cell -> HLS 期望 5-10x 加速 (~150-300 us/cell).
 *   - HLS estimate 历史偏乐观 14x (DDR m_axi 写实际慢得多, 见 feedback)
 *   - 实测可能停在 3-5x, 仍能把 24-cell 总耗时从 71ms 降到 ~20ms (~50 FPS)
 *
 * 设计决策:
 *   - Verts 在 IP 内部预读到 BRAM (8K * 9B = 72KB), phase1 random access OK
 *   - Tris 流式读 (32K * 6B = 192KB DDR streaming)
 *   - tri_colors 流式读 (32K * 3B 仅 per_tri_color=1 时), 跟 tri 顺序对齐
 *   - mesh_segs_buf 留在 BRAM (2048 segs * 16B = 32KB) — phase2 random access
 *   - x_cross / cr_arr / cg_arr / cb_arr: per scanline 临时 BRAM 数组 (64 entry)
 *   - 输出 fb 用 m_axi 顺序写, GBR 字节序
 *   - cos/sin 360 LUT 在芯片上 ROM
 */
#include "mesh_slice.h"
#include "mesh_slice_lut.h"

/* HLS struct for an in-BRAM segment record (16B padded). */
struct mesh_seg_hls_t {
    int16_t  xa, ya;
    int16_t  xb, yb;
    uint8_t  ra, ga, ba;
    uint8_t  rb, gb, bb;
    uint8_t  _pad0, _pad1;
};

/* HLS-friendly vertex storage in BRAM. */
struct vert_hls_t {
    int16_t x;
    int16_t y;
    int16_t z;
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t _pad0;
    uint8_t _pad1;
};  /* 12B aligned, OK for HLS */

static inline int clamp_byte(int v) {
#pragma HLS INLINE
    if (v < 0)   return 0;
    if (v > 255) return 255;
    return v;
}

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
) {
#pragma HLS INTERFACE m_axi      port=verts_bytes      offset=slave bundle=gmem0 \
    depth=73728 max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=tris_bytes       offset=slave bundle=gmem1 \
    depth=196608 max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=tri_colors_bytes offset=slave bundle=gmem2 \
    depth=98304 max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE m_axi      port=fb_bytes         offset=slave bundle=gmem3 \
    depth=2764800 max_write_burst_length=256 num_write_outstanding=8
#pragma HLS INTERFACE s_axilite  port=verts_bytes       bundle=control
#pragma HLS INTERFACE s_axilite  port=tris_bytes        bundle=control
#pragma HLS INTERFACE s_axilite  port=tri_colors_bytes  bundle=control
#pragma HLS INTERFACE s_axilite  port=n_verts           bundle=control
#pragma HLS INTERFACE s_axilite  port=n_tris            bundle=control
#pragma HLS INTERFACE s_axilite  port=per_tri_color     bundle=control
#pragma HLS INTERFACE s_axilite  port=angle_deg         bundle=control
#pragma HLS INTERFACE s_axilite  port=x_half_q4         bundle=control
#pragma HLS INTERFACE s_axilite  port=y_min_q4          bundle=control
#pragma HLS INTERFACE s_axilite  port=y_max_q4          bundle=control
#pragma HLS INTERFACE s_axilite  port=slice_w           bundle=control
#pragma HLS INTERFACE s_axilite  port=slice_h           bundle=control
#pragma HLS INTERFACE s_axilite  port=fb_bytes          bundle=control
#pragma HLS INTERFACE s_axilite  port=fb_stride         bundle=control
#pragma HLS INTERFACE s_axilite  port=origin_x          bundle=control
#pragma HLS INTERFACE s_axilite  port=origin_y          bundle=control
#pragma HLS INTERFACE s_axilite  port=do_clear          bundle=control
#pragma HLS INTERFACE s_axilite  port=return            bundle=control

    /* ---- bounds clamp ---- */
    if (angle_deg < 0)   angle_deg = 0;
    if (angle_deg >= 360) angle_deg %= 360;
    if (n_verts < 0) n_verts = 0;
    if (n_verts > MAX_MESH_VERTS_HLS) n_verts = MAX_MESH_VERTS_HLS;
    if (n_tris  < 0) n_tris  = 0;
    if (n_tris  > MAX_MESH_TRIS_HLS)  n_tris  = MAX_MESH_TRIS_HLS;
    if (slice_w < 1) slice_w = 1;
    if (slice_h < 1) slice_h = 1;
    if (slice_w > 320) slice_w = 320;
    if (slice_h > 240) slice_h = 240;

    const int c_q8 = (int)MESH_COS360[angle_deg];
    const int s_q8 = (int)MESH_SIN360[angle_deg];

    /* ---- (a) Optional panel clear to gray 80 (do_clear=1).
     * 推荐 do_clear=0 + ARM 预 memset, 省 ~387 us/cell (160×120×3 cycle).
     * ARM 端 memset 一次性把 24 个 panel 整片 1280×720 灰底, 比 IP 内逐 panel
     * 慢得多 (memset DDR ~30us/cell vs IP m_axi ~387us/cell). */
    if (do_clear) {
CLEAR_ROWS:
        for (int yy = 0; yy < slice_h; yy++) {
#pragma HLS LOOP_TRIPCOUNT min=120 max=240
CLEAR_COLS:
            for (int xx = 0; xx < slice_w; xx++) {
#pragma HLS LOOP_TRIPCOUNT min=160 max=320
#pragma HLS PIPELINE II=3
                int off = (origin_y + yy) * fb_stride + (origin_x + xx) * 3;
                fb_bytes[off + 0] = 80;
                fb_bytes[off + 1] = 80;
                fb_bytes[off + 2] = 80;
            }
        }
    }

    /* ---- (b) Load verts to BRAM ---- */
    static vert_hls_t local_verts[MAX_MESH_VERTS_HLS];
#pragma HLS BIND_STORAGE variable=local_verts type=ram_2p impl=bram

LOAD_VERTS:
    for (int i = 0; i < n_verts; i++) {
#pragma HLS LOOP_TRIPCOUNT min=512 max=MAX_MESH_VERTS_HLS
#pragma HLS PIPELINE II=9
        int b = i * 9;
        unsigned char b0 = verts_bytes[b + 0];
        unsigned char b1 = verts_bytes[b + 1];
        unsigned char b2 = verts_bytes[b + 2];
        unsigned char b3 = verts_bytes[b + 3];
        unsigned char b4 = verts_bytes[b + 4];
        unsigned char b5 = verts_bytes[b + 5];
        unsigned char b6 = verts_bytes[b + 6];
        unsigned char b7 = verts_bytes[b + 7];
        unsigned char b8 = verts_bytes[b + 8];
        vert_hls_t v;
        v.x = (int16_t)((uint16_t)b0 | ((uint16_t)b1 << 8));
        v.y = (int16_t)((uint16_t)b2 | ((uint16_t)b3 << 8));
        v.z = (int16_t)((uint16_t)b4 | ((uint16_t)b5 << 8));
        v.r = b6;
        v.g = b7;
        v.b = b8;
        v._pad0 = 0;
        v._pad1 = 0;
        local_verts[i] = v;
    }

    /* ---- (c) Phase 1: collect segments ---- */
    static mesh_seg_hls_t mesh_segs[MAX_MESH_SEGS_HLS];
#pragma HLS BIND_STORAGE variable=mesh_segs type=ram_2p impl=bram
    int n_segs = 0;

PHASE1_TRIS:
    for (int t = 0; t < n_tris; t++) {
#pragma HLS LOOP_TRIPCOUNT min=1024 max=MAX_MESH_TRIS_HLS
        /* PIPELINE II=8 achievable but pushes LUT to 97% (no headroom for
         * future 4× IP). Default no-pipeline gives 92 cyc/iter, 32K trip =
         * 3M cycle = 20 ms (worst). LUT ~ 56%. Trade speed for area. */
        /* Read 6B tri index. */
        int tb = t * 6;
        uint16_t i0 = (uint16_t)tris_bytes[tb + 0] | ((uint16_t)tris_bytes[tb + 1] << 8);
        uint16_t i1 = (uint16_t)tris_bytes[tb + 2] | ((uint16_t)tris_bytes[tb + 3] << 8);
        uint16_t i2 = (uint16_t)tris_bytes[tb + 4] | ((uint16_t)tris_bytes[tb + 5] << 8);

        /* Optional per-tri flat color. */
        uint8_t tri_r = 0, tri_g = 0, tri_b_ = 0;
        if (per_tri_color) {
            int cb_off = t * 3;
            tri_r  = tri_colors_bytes[cb_off + 0];
            tri_g  = tri_colors_bytes[cb_off + 1];
            tri_b_ = tri_colors_bytes[cb_off + 2];
        }

        if ((int)i0 >= n_verts || (int)i1 >= n_verts || (int)i2 >= n_verts) continue;

        vert_hls_t v0 = local_verts[i0];
        vert_hls_t v1 = local_verts[i1];
        vert_hls_t v2 = local_verts[i2];

        int zp0 = -(int)v0.x * s_q8 + (int)v0.z * c_q8;
        int zp1 = -(int)v1.x * s_q8 + (int)v1.z * c_q8;
        int zp2 = -(int)v2.x * s_q8 + (int)v2.z * c_q8;

        int n_pos = (zp0 > 0 ? 1 : 0) + (zp1 > 0 ? 1 : 0) + (zp2 > 0 ? 1 : 0);
        if (n_pos == 0 || n_pos == 3) continue;

        /* Iterate 3 edges, collect up to 2 crossings. */
        int cx_arr[2];
        int cy_arr[2];
        uint8_t cr_arr[2], cg_arr[2], cb_arr_[2];
        int nc = 0;

EDGE_LOOP:
        for (int e = 0; e < 3; e++) {
            int ia, ib;
            int zpa, zpb;
            int va_x, va_y, va_z;
            int vb_x, vb_y, vb_z;
            uint8_t va_r, va_g, va_b;
            uint8_t vb_r, vb_g, vb_b;
            if (e == 0) { zpa=zp0; zpb=zp1; va_x=v0.x; va_y=v0.y; va_z=v0.z;
                          va_r=v0.r; va_g=v0.g; va_b=v0.b;
                          vb_x=v1.x; vb_y=v1.y; vb_z=v1.z;
                          vb_r=v1.r; vb_g=v1.g; vb_b=v1.b; }
            else if (e == 1) { zpa=zp1; zpb=zp2; va_x=v1.x; va_y=v1.y; va_z=v1.z;
                          va_r=v1.r; va_g=v1.g; va_b=v1.b;
                          vb_x=v2.x; vb_y=v2.y; vb_z=v2.z;
                          vb_r=v2.r; vb_g=v2.g; vb_b=v2.b; }
            else { zpa=zp2; zpb=zp0; va_x=v2.x; va_y=v2.y; va_z=v2.z;
                          va_r=v2.r; va_g=v2.g; va_b=v2.b;
                          vb_x=v0.x; vb_y=v0.y; vb_z=v0.z;
                          vb_r=v0.r; vb_g=v0.g; vb_b=v0.b; }
            /* Note: avoid using ia/ib (silence unused warnings). */
            (void)ia; (void)ib;
            if (nc >= 2) continue;
            bool same_sign = ((zpa > 0) == (zpb > 0));
            if (same_sign) continue;
            int denom = zpa - zpb;
            if (denom == 0) continue;

            int xa_proj = va_x * c_q8 + va_z * s_q8;
            int xb_proj = vb_x * c_q8 + vb_z * s_q8;
            long long delta = ((long long)zpa * (long long)(xb_proj - xa_proj)) / denom;
            int xp_q12 = xa_proj + (int)delta;
            int xp_q4  = xp_q12 >> 8;

            long long dy = ((long long)zpa * (long long)(vb_y - va_y)) / denom;
            int yp_q4 = va_y + (int)dy;

            uint8_t rr_u, gg_u, bb_u;
            if (per_tri_color) {
                rr_u = tri_r;  gg_u = tri_g;  bb_u = tri_b_;
            } else {
                int t_q8 = (int)(((long long)zpa * 256LL) / denom);
                int rr = (int)va_r + (((int)vb_r - (int)va_r) * t_q8 >> 8);
                int gg = (int)va_g + (((int)vb_g - (int)va_g) * t_q8 >> 8);
                int bbi = (int)va_b + (((int)vb_b - (int)va_b) * t_q8 >> 8);
                rr_u = (uint8_t)clamp_byte(rr);
                gg_u = (uint8_t)clamp_byte(gg);
                bb_u = (uint8_t)clamp_byte(bbi);
            }
            cx_arr[nc] = xp_q4; cy_arr[nc] = yp_q4;
            cr_arr[nc] = rr_u; cg_arr[nc] = gg_u; cb_arr_[nc] = bb_u;
            nc++;
        }

        if (nc == 2 && n_segs < MAX_MESH_SEGS_HLS) {
            mesh_seg_hls_t seg;
            seg.xa = (int16_t)cx_arr[0];
            seg.ya = (int16_t)cy_arr[0];
            seg.ra = cr_arr[0]; seg.ga = cg_arr[0]; seg.ba = cb_arr_[0];
            seg.xb = (int16_t)cx_arr[1];
            seg.yb = (int16_t)cy_arr[1];
            seg.rb = cr_arr[1]; seg.gb = cg_arr[1]; seg.bb = cb_arr_[1];
            seg._pad0 = 0;
            seg._pad1 = 0;
            mesh_segs[n_segs] = seg;
            n_segs++;
        }
    }

    if (n_segs == 0) return;

    /* ---- (d) Phase 2: scanline fill ---- */
    int span_q4 = y_max_q4 - y_min_q4;
    if (span_q4 < 1) span_q4 = 1;
    int two_xhalf = 2 * x_half_q4;
    if (two_xhalf < 1) two_xhalf = 1;

    int x_cross[MAX_X_CROSS_HLS];
    uint8_t scl_r[MAX_X_CROSS_HLS];
    uint8_t scl_g[MAX_X_CROSS_HLS];
    uint8_t scl_b[MAX_X_CROSS_HLS];
#pragma HLS BIND_STORAGE variable=x_cross type=ram_2p impl=bram
#pragma HLS BIND_STORAGE variable=scl_r type=ram_2p impl=bram
#pragma HLS BIND_STORAGE variable=scl_g type=ram_2p impl=bram
#pragma HLS BIND_STORAGE variable=scl_b type=ram_2p impl=bram

PHASE2_ROWS:
    for (int py = 0; py < slice_h; py++) {
#pragma HLS LOOP_TRIPCOUNT min=120 max=240
        int yh_q4 = y_max_q4 - (py * span_q4 / slice_h);
        int nc = 0;

SEG_SCAN:
        for (int s = 0; s < n_segs; s++) {
#pragma HLS LOOP_TRIPCOUNT min=64 max=MAX_MESH_SEGS_HLS
#pragma HLS PIPELINE II=2
            mesh_seg_hls_t seg = mesh_segs[s];
            int ya = (int)seg.ya;
            int yb = (int)seg.yb;
            int da = ya - yh_q4;
            int db = yb - yh_q4;
            if ((da ^ db) >= 0) continue;
            if (ya == yb) continue;
            int denom = yb - ya;
            int t_q8 = ((yh_q4 - ya) * 256) / denom;
            int dx = ((seg.xb - seg.xa) * t_q8) >> 8;
            int x_q4 = seg.xa + dx;
            int dr = ((seg.rb - seg.ra) * t_q8) >> 8;
            int dg = ((seg.gb - seg.ga) * t_q8) >> 8;
            int dbi = ((seg.bb - seg.ba) * t_q8) >> 8;
            int rr = seg.ra + dr;
            int gg = seg.ga + dg;
            int bbi = seg.ba + dbi;
            if (nc < MAX_X_CROSS_HLS) {
                x_cross[nc] = x_q4;
                scl_r[nc]   = (uint8_t)clamp_byte(rr);
                scl_g[nc]   = (uint8_t)clamp_byte(gg);
                scl_b[nc]   = (uint8_t)clamp_byte(bbi);
                nc++;
            }
        }

        if (nc < 2) continue;

        /* Insertion sort by x_cross. */
INS_SORT:
        for (int i = 1; i < nc; i++) {
#pragma HLS LOOP_TRIPCOUNT min=2 max=MAX_X_CROSS_HLS
            int x = x_cross[i];
            uint8_t r = scl_r[i], g = scl_g[i], bv = scl_b[i];
            int j = i - 1;
INS_INNER:
            while (j >= 0 && x_cross[j] > x) {
#pragma HLS LOOP_TRIPCOUNT min=0 max=MAX_X_CROSS_HLS
                x_cross[j + 1] = x_cross[j];
                scl_r[j + 1]   = scl_r[j];
                scl_g[j + 1]   = scl_g[j];
                scl_b[j + 1]   = scl_b[j];
                j--;
            }
            x_cross[j + 1] = x;
            scl_r[j + 1]   = r;
            scl_g[j + 1]   = g;
            scl_b[j + 1]   = bv;
        }

        /* Pair-fill scanline. */
PAIR_FILL:
        for (int i = 0; i + 1 < nc; i += 2) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=32
            int xa_pix = ((x_cross[i]   + x_half_q4) * slice_w) / two_xhalf;
            int xb_pix = ((x_cross[i+1] + x_half_q4) * slice_w) / two_xhalf;
            uint8_t ra = scl_r[i],   ga = scl_g[i],   ba = scl_b[i];
            uint8_t rb = scl_r[i+1], gb = scl_g[i+1], bb = scl_b[i+1];
            if (xa_pix > xb_pix) {
                int tt = xa_pix; xa_pix = xb_pix; xb_pix = tt;
                uint8_t t8;
                t8 = ra; ra = rb; rb = t8;
                t8 = ga; ga = gb; gb = t8;
                t8 = ba; ba = bb; bb = t8;
            }
            if (xa_pix < 0) xa_pix = 0;
            if (xb_pix > slice_w - 1) xb_pix = slice_w - 1;
            if (xa_pix > xb_pix) continue;
            int span = xb_pix - xa_pix;
            int row_off = (origin_y + py) * fb_stride + origin_x * 3;

PIXEL_FILL:
            for (int x_pix = xa_pix; x_pix <= xb_pix; x_pix++) {
#pragma HLS LOOP_TRIPCOUNT min=1 max=320
#pragma HLS PIPELINE II=3
                int t_q8;
                if (span > 0) {
                    t_q8 = ((x_pix - xa_pix) * 256) / span;
                } else {
                    t_q8 = 0;
                }
                int rr = (int)ra + (((int)rb - (int)ra) * t_q8 >> 8);
                int gg = (int)ga + (((int)gb - (int)ga) * t_q8 >> 8);
                int bbb = (int)ba + (((int)bb - (int)ba) * t_q8 >> 8);
                int off = row_off + x_pix * 3;
                /* HDMI fb 字节序 = GBR */
                fb_bytes[off + 0] = (unsigned char)clamp_byte(gg);
                fb_bytes[off + 1] = (unsigned char)clamp_byte(bbb);
                fb_bytes[off + 2] = (unsigned char)clamp_byte(rr);
            }
        }
    }
}
