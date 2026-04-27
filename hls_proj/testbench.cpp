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

int main(void)
{
    struct point_t model[MAX_POINTS];
    int n = 0;
    gen_test_model(model, &n);
    printf("[TB] generated %d test points\n", n);

    /* Batch test: 72-slot ring buffer, each slot 106×120×3 bytes tight. */
    const int SLOT_BYTES = SLICE_W * SLICE_H * 3;
    const int SLOT_STRIDE = SLICE_W * 3;
    const int N_SLOTS = 72;
    const int RING_BYTES = SLOT_BYTES * N_SLOTS;
    static uint8_t ref_ring[SLOT_BYTES * 72];
    static uint8_t dut_ring[SLOT_BYTES * 72];
    memset(ref_ring, 0, RING_BYTES);
    memset(dut_ring, 0, RING_BYTES);

    /* Reference: call ref_project for each of 72 slots independently. */
    int phase = 0;
    for (int s = 0; s < N_SLOTS; s++) {
        int ang = (phase + s) % NUM_ANGLES;
        ref_project(model, n, ang,
                    ref_ring + s * SLOT_BYTES,
                    SLOT_STRIDE, 0, 0);
    }

    /* DUT: single batch call. */
    pov_project_batch(model, n, dut_ring, SLOT_BYTES, SLOT_STRIDE, phase, N_SLOTS);

    int total_diffs = compare_fb(ref_ring, dut_ring, RING_BYTES);
    printf("[TB] batch 72-slot: %d byte diffs\n", total_diffs);

    /* Also print per-slot diff for the first few that mismatch */
    if (total_diffs) {
        int shown = 0;
        for (int s = 0; s < N_SLOTS && shown < 5; s++) {
            int d = compare_fb(ref_ring + s*SLOT_BYTES,
                               dut_ring + s*SLOT_BYTES,
                               SLOT_BYTES);
            if (d) {
                printf("  slot %2d: %d diffs\n", s, d);
                shown++;
            }
        }
    }

    if (total_diffs == 0) {
        printf("[TB] PASS: batch matches per-slot reference.\n");
        return 0;
    } else {
        printf("[TB] FAIL\n");
        return 1;
    }
}
