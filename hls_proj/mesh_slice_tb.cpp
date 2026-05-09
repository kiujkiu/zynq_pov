/* mesh_slice_tb.cpp - C-simulation testbench for mesh_slice_render().
 *
 * 生成最小 mesh (1 个 tri) 跨过 z=0 切平面, 跑 mesh_slice_render 在 0° 和 90°
 * 角度, 检查输出 fb 至少有非灰度像素 (= 实际有渲染).
 *
 * 不严格 bit-exact 对比 ARM 版 (helloworld.c 内有 long-long 中间精度).
 */
#include "mesh_slice.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define FB_W 1280
#define FB_H 720
#define FB_STRIDE (FB_W * 3)
#define FB_BYTES  (FB_STRIDE * FB_H)
#define PANEL_W 160
#define PANEL_H 120

static unsigned char fb[FB_BYTES];
static unsigned char verts_buf[MAX_MESH_VERTS_HLS * 9];
static unsigned char tris_buf[MAX_MESH_TRIS_HLS * 6];
static unsigned char tcol_buf[MAX_MESH_TRIS_HLS * 3];

/* Pack a vertex into 9-byte form. */
static void pack_vert(unsigned char *dst, int x, int y, int z, int r, int g, int b) {
    int16_t xx = (int16_t)x, yy = (int16_t)y, zz = (int16_t)z;
    dst[0] = (unsigned char)(xx & 0xFF);
    dst[1] = (unsigned char)((xx >> 8) & 0xFF);
    dst[2] = (unsigned char)(yy & 0xFF);
    dst[3] = (unsigned char)((yy >> 8) & 0xFF);
    dst[4] = (unsigned char)(zz & 0xFF);
    dst[5] = (unsigned char)((zz >> 8) & 0xFF);
    dst[6] = (unsigned char)r;
    dst[7] = (unsigned char)g;
    dst[8] = (unsigned char)b;
}

static void pack_tri(unsigned char *dst, int i0, int i1, int i2) {
    dst[0] = (unsigned char)(i0 & 0xFF);
    dst[1] = (unsigned char)((i0 >> 8) & 0xFF);
    dst[2] = (unsigned char)(i1 & 0xFF);
    dst[3] = (unsigned char)((i1 >> 8) & 0xFF);
    dst[4] = (unsigned char)(i2 & 0xFF);
    dst[5] = (unsigned char)((i2 >> 8) & 0xFF);
}

static int count_nongray(int origin_x, int origin_y, int w, int h) {
    int n = 0;
    for (int yy = 0; yy < h; yy++) {
        for (int xx = 0; xx < w; xx++) {
            int off = (origin_y + yy) * FB_STRIDE + (origin_x + xx) * 3;
            if (fb[off+0] != 80 || fb[off+1] != 80 || fb[off+2] != 80) n++;
        }
    }
    return n;
}

int main() {
    /* ---- Build a tetrahedron mesh: 4 verts + 4 tris ----
     * Vertices in Q8.4: model unit = value/16. So x=160 = 10 model unit.
     * Tet apex high y, 3 base verts low y. Each tri spans z range so crosses
     * z'=0 plane at any rotation angle (with y not horizontal). */
    int n_verts = 4;
    pack_vert(&verts_buf[0*9],    0,  120,    0, 200,  50,  50);  /* v0 apex (x=0, y=top, z=0) */
    pack_vert(&verts_buf[1*9], -160,  -80, -160,  50, 200,  50);  /* v1 base SW */
    pack_vert(&verts_buf[2*9],  160,  -80, -160,  50,  50, 200);  /* v2 base SE */
    pack_vert(&verts_buf[3*9],    0,  -80,  180, 200, 200,  50);  /* v3 base N */

    int n_tris = 4;
    pack_tri(&tris_buf[0*6], 0, 1, 2);   /* front face apex-SW-SE */
    pack_tri(&tris_buf[1*6], 0, 2, 3);   /* right face apex-SE-N */
    pack_tri(&tris_buf[2*6], 0, 3, 1);   /* left face apex-N-SW */
    pack_tri(&tris_buf[3*6], 1, 3, 2);   /* base (y=-80) */

    tcol_buf[0]=255; tcol_buf[1]=0;   tcol_buf[2]=0;
    tcol_buf[3]=0;   tcol_buf[4]=255; tcol_buf[5]=0;
    tcol_buf[6]=0;   tcol_buf[7]=0;   tcol_buf[8]=255;
    tcol_buf[9]=255; tcol_buf[10]=255; tcol_buf[11]=0;

    int x_half_q4 = 200;     /* > 160, slight pad */
    int y_min_q4  = -100;
    int y_max_q4  = 100;

    int origin_x = 0, origin_y = 0;
    int slice_w = PANEL_W, slice_h = PANEL_H;

    int test_angles[3] = {0, 45, 90};
    int total_nongray = 0;
    for (int ti = 0; ti < 3; ti++) {
        memset(fb, 0xCC, FB_BYTES);    /* fill with 0xCC to detect untouched */
        int ang = test_angles[ti];
        mesh_slice_render(verts_buf, tris_buf, tcol_buf,
                           n_verts, n_tris,
                           /*per_tri_color=*/0,
                           ang,
                           x_half_q4, y_min_q4, y_max_q4,
                           slice_w, slice_h,
                           fb, FB_STRIDE, origin_x, origin_y,
                           /*do_clear=*/1);
        int n = count_nongray(origin_x, origin_y, slice_w, slice_h);
        printf("angle=%d  non-gray pixels in panel = %d\n", ang, n);
        total_nongray += n;

        /* sanity check: at least *some* pixels rendered, and panel cleared
         * (NOT 0xCC anymore). */
        int n_uncleared = 0;
        for (int yy = 0; yy < slice_h; yy++) {
            for (int xx = 0; xx < slice_w; xx++) {
                int off = (origin_y + yy) * FB_STRIDE + (origin_x + xx) * 3;
                if (fb[off+0] == 0xCC && fb[off+1] == 0xCC && fb[off+2] == 0xCC) {
                    n_uncleared++;
                }
            }
        }
        if (n_uncleared > 0) {
            printf("ERROR: %d pixels still 0xCC (clear didn't run)\n", n_uncleared);
            return 1;
        }
    }

    /* per-tri-color test: should give pure red+green flat triangles. */
    memset(fb, 0xCC, FB_BYTES);
    mesh_slice_render(verts_buf, tris_buf, tcol_buf,
                       n_verts, n_tris,
                       /*per_tri_color=*/1,
                       45,
                       x_half_q4, y_min_q4, y_max_q4,
                       slice_w, slice_h,
                       fb, FB_STRIDE, origin_x, origin_y,
                       /*do_clear=*/1);
    int n = count_nongray(origin_x, origin_y, slice_w, slice_h);
    printf("angle=45 per_tri_color=1  non-gray pixels = %d\n", n);
    total_nongray += n;

    if (total_nongray < 10) {
        printf("ERROR: total non-gray pixels = %d (suspect render fail)\n", total_nongray);
        return 1;
    }
    printf("OK: testbench passed, total %d non-gray pixels\n", total_nongray);
    return 0;
}
