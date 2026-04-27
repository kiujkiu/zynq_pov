/* testbench.cpp - HLS csim validation.
 *
 * 生成少量已知点, 调用 pov_project() 投影, 对照 "纯软件参考实现"
 * 检查输出帧缓冲像素是否一致. 测试角度 0° 和 90°.
 */
#include "pov_project.h"
#include "cos_sin_lut.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define FB_W 1280
#define FB_H 720
#define FB_STRIDE (FB_W * 3)
#define FB_BYTES  (FB_STRIDE * FB_H)

static uint8_t ref_fb[FB_BYTES];
static uint8_t dut_fb[FB_BYTES];

/* 参考实现: 和 HLS 相同算法的纯软件版本. */
static void ref_project(
    const struct point_t *model, int num_points, int angle_idx,
    uint8_t *fb, int fb_stride, int dst_x, int dst_y,
    int slice_mode, int slice_half_thick)
{
    int16_t c = POV_COS8[angle_idx];
    int16_t s = POV_SIN8[angle_idx];
    /* NOTE: clear + border are done by ARM now; IP only renders points. */
    const int cx = SLICE_W/2, cy = SLICE_H/2;
    for (int i = 0; i < num_points; i++) {
        const struct point_t &p = model[i];
        int32_t rx = ((int32_t)p.x * c + (int32_t)p.z * s) >> 8;
        int32_t rz = (-(int32_t)p.x * s + (int32_t)p.z * c) >> 8;
        bool in_slab = !slice_mode ||
                       (rz <= slice_half_thick && rz >= -slice_half_thick);
        int sx = cx + rx;
        int sy = cy - p.y;
        if (in_slab && sx>=0 && sx<SLICE_W && sy>=0 && sy<SLICE_H) {
            for (int dy=0; dy<2; dy++) for (int dx=0; dx<2; dx++) {
                int px=sx+dx, py=sy+dy;
                if (px<SLICE_W && py<SLICE_H) {
                    int off = (dst_y+py)*fb_stride + (dst_x+px)*3;
                    fb[off]=p.b; fb[off+1]=p.g; fb[off+2]=p.r;
                }
            }
        }
    }
}

static int compare_fb(const uint8_t *a, const uint8_t *b, int len)
{
    int diffs = 0;
    for (int i = 0; i < len; i++) if (a[i] != b[i]) diffs++;
    return diffs;
}

static void gen_test_model(struct point_t *m, int *n_out)
{
    /* 简单测试模型: 4 个角 + 2 个轴端点 */
    struct point_t pts[] = {
        {  40,   0,   0, 0, 255,   0,   0, 0, 0},  /* +X 红 */
        { -40,   0,   0, 0, 128,   0,   0, 0, 0},
        {   0,  30,   0, 0,   0, 255,   0, 0, 0},  /* +Y 绿 */
        {   0, -30,   0, 0,   0, 128,   0, 0, 0},
        {   0,   0,  40, 0,   0,   0, 255, 0, 0},  /* +Z 蓝 */
        {   0,   0, -40, 0,   0,   0, 128, 0, 0},
        {  20,  20,  20, 0, 255, 255, 255, 0, 0},  /* 立方体角 白 */
        { -20,  20,  20, 0, 255, 255, 255, 0, 0},
        {  20, -20,  20, 0, 255, 255, 255, 0, 0},
        { -20, -20,  20, 0, 255, 255, 255, 0, 0},
    };
    int n = sizeof(pts) / sizeof(pts[0]);
    for (int i = 0; i < n; i++) m[i] = pts[i];
    *n_out = n;
}

/* Run one batch test with the given slice_mode + slice_half_thick.
 * Returns 0 on PASS, 1 on FAIL. */
static int run_case(const char *label,
                    const struct point_t *model, int n_pts,
                    int slice_mode, int slice_half_thick)
{
    const int SLOT_BYTES  = SLICE_W * SLICE_H * 3;
    const int SLOT_STRIDE = SLICE_W * 3;
    const int N_SLOTS     = 72;
    const int RING_BYTES  = SLOT_BYTES * N_SLOTS;
    static uint8_t ref_ring[SLOT_BYTES * 72];
    static uint8_t dut_ring[SLOT_BYTES * 72];
    memset(ref_ring, 0, RING_BYTES);
    memset(dut_ring, 0, RING_BYTES);

    int phase = 0;
    for (int s = 0; s < N_SLOTS; s++) {
        int ang = (phase + s) % NUM_ANGLES;
        ref_project(model, n_pts, ang,
                    ref_ring + s * SLOT_BYTES,
                    SLOT_STRIDE, 0, 0,
                    slice_mode, slice_half_thick);
    }

    pov_project_batch(model, n_pts, dut_ring, SLOT_BYTES, SLOT_STRIDE,
                      phase, N_SLOTS, slice_mode, slice_half_thick);

    int total_diffs = compare_fb(ref_ring, dut_ring, RING_BYTES);
    printf("[TB] %s: slice_mode=%d half_thick=%d → %d byte diffs\n",
           label, slice_mode, slice_half_thick, total_diffs);

    /* Also count nonzero pixels in slice_mode=1 case to confirm it actually
     * filters something out vs slice_mode=0. */
    int ref_nonzero = 0;
    for (int i = 0; i < RING_BYTES; i++) if (ref_ring[i]) ref_nonzero++;
    printf("[TB]   ref_ring nonzero bytes: %d\n", ref_nonzero);

    if (total_diffs) {
        int shown = 0;
        for (int s = 0; s < N_SLOTS && shown < 3; s++) {
            int d = compare_fb(ref_ring + s*SLOT_BYTES,
                               dut_ring + s*SLOT_BYTES,
                               SLOT_BYTES);
            if (d) {
                printf("    slot %2d: %d diffs\n", s, d);
                shown++;
            }
        }
        printf("[TB] %s FAIL\n", label);
        return 1;
    }
    printf("[TB] %s PASS\n", label);
    return 0;
}


/* ============================================================ */
/* Voxel slicer test                                             */
/* ============================================================ */

#define VRES 128
#define VHALF 64

/* Software reference identical to HLS pov_voxel_slice_batch */
static void ref_voxel_slice(
    const uint16_t *vg, uint8_t *slot,
    int slot_stride, int angle_idx)
{
    int16_t cs = POV_COS8[angle_idx];
    int16_t sn = POV_SIN8[angle_idx];
    const int cx = SLICE_W/2, cy = SLICE_H/2;
    for (int py = 0; py < SLICE_H; py++) {
        for (int px = 0; px < SLICE_W; px++) {
            int rx = px - cx;
            int ry = cy - py;
            int mx = (rx * cs) >> 8;
            int mz = (rx * sn) >> 8;
            int my = ry;
            int vx = mx + VHALF;
            int vy = my + VHALF;
            int vz = mz + VHALF;
            uint16_t rgb = 0;
            if (vx>=0 && vx<VRES && vy>=0 && vy<VRES && vz>=0 && vz<VRES) {
                rgb = vg[(vz*VRES + vy)*VRES + vx];
            }
            int off = py*slot_stride + px*3;
            if (rgb) {
                uint8_t r5 = (rgb>>11)&0x1F, g6=(rgb>>5)&0x3F, b5=rgb&0x1F;
                slot[off]   = (b5<<3)|(b5>>2);
                slot[off+1] = (g6<<2)|(g6>>4);
                slot[off+2] = (r5<<3)|(r5>>2);
            } else {
                slot[off] = slot[off+1] = slot[off+2] = 0;
            }
        }
    }
}

static int run_voxel_case(const uint16_t *vg, int phase, int n_slots)
{
    const int SLOT_BYTES = SLICE_W * SLICE_H * 3;
    const int SLOT_STRIDE = SLICE_W * 3;
    const int RING_BYTES = SLOT_BYTES * n_slots;
    static uint8_t ref_ring[SLOT_BYTES * 72];
    static uint8_t dut_ring[SLOT_BYTES * 72];
    memset(ref_ring, 0, RING_BYTES);
    memset(dut_ring, 0, RING_BYTES);

    for (int s = 0; s < n_slots; s++) {
        int ang = (phase + s) % NUM_ANGLES;
        ref_voxel_slice(vg, ref_ring + s*SLOT_BYTES, SLOT_STRIDE, ang);
    }
    pov_voxel_slice_batch(vg, dut_ring, SLOT_BYTES, SLOT_STRIDE, phase, n_slots);

    int diffs = compare_fb(ref_ring, dut_ring, RING_BYTES);
    int ref_nz = 0;
    for (int i = 0; i < RING_BYTES; i++) if (ref_ring[i]) ref_nz++;
    printf("[TB] voxel slice batch (n_slots=%d, phase=%d): %d diffs, "
           "ref nonzero %d bytes\n", n_slots, phase, diffs, ref_nz);
    if (diffs) {
        for (int s = 0; s < n_slots; s++) {
            int d = compare_fb(ref_ring + s*SLOT_BYTES,
                               dut_ring + s*SLOT_BYTES, SLOT_BYTES);
            if (d) { printf("    slot %d: %d diffs\n", s, d); break; }
        }
        printf("[TB] voxel slice FAIL\n");
        return 1;
    }
    printf("[TB] voxel slice PASS\n");
    return 0;
}

static void make_test_voxels(uint16_t *vg)
{
    /* Sparse test scene: place voxels at distinctive positions */
    memset(vg, 0, VRES*VRES*VRES*sizeof(uint16_t));
    /* Center point: red */
    vg[(VHALF*VRES + VHALF)*VRES + VHALF] = 0xF800;       /* RGB565 red */
    /* Y axis: vertical green line at center */
    for (int y = VHALF-30; y < VHALF+30; y++) {
        vg[(VHALF*VRES + y)*VRES + VHALF] = 0x07E0;       /* green */
    }
    /* X axis: horizontal blue at y=center */
    for (int x = VHALF-25; x < VHALF+25; x++) {
        vg[(VHALF*VRES + VHALF)*VRES + x] = 0x001F;       /* blue */
    }
    /* Cube corner pixels */
    int s = 20;
    for (int dy=-s; dy<=s; dy+=s*2) for (int dx=-s; dx<=s; dx+=s*2)
        for (int dz=-s; dz<=s; dz+=s*2) {
            int xc = VHALF+dx, yc = VHALF+dy, zc = VHALF+dz;
            vg[(zc*VRES + yc)*VRES + xc] = 0xFFE0;        /* yellow */
        }
}


int main(void)
{
    struct point_t model[MAX_POINTS];
    int n = 0;
    gen_test_model(model, &n);
    printf("[TB] generated %d test points\n", n);

    int fails = 0;
    fails += run_case("projection (slice_mode=0)", model, n, 0, 0);
    fails += run_case("z-slice thick=8",            model, n, 1, 8);
    fails += run_case("z-slice thick=16",           model, n, 1, 16);
    fails += run_case("z-slice thick=2 (very thin)", model, n, 1, 2);

    /* Voxel slicer tests */
    static uint16_t vg[VRES*VRES*VRES];
    make_test_voxels(vg);
    fails += run_voxel_case(vg, 0, 4);
    fails += run_voxel_case(vg, 18, 4);
    fails += run_voxel_case(vg, 0, 12);

    if (fails == 0) {
        printf("[TB] ALL PASS\n");
        return 0;
    }
    printf("[TB] %d cases FAILED\n", fails);
    return 1;
}
