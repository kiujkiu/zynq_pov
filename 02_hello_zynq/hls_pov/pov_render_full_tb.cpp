/* pov_render_full_tb.cpp - 路线 B1 host 测试台 (g++, 不用 vitis_hls).
 *
 * 编译: g++ -O2 -std=c++11 pov_render_full_tb.cpp pov_render_full.cpp -o pov_render_full_tb
 * 运行: ./pov_render_full_tb
 *   需要工作目录有:
 *     tools/anime_points.bin   (raw point_t[], 无头; 30803 点)
 *     tools/transform_lut.bin  (16384 个 lut_t)
 *   tb 自动在 ./ 和 ../../tools/ 找.
 *
 * 验证策略 (逐字节通过判据):
 *   golden = 参考散射 (== main.c clip127 体素化) 造 voxel_grid_ref
 *            + 参考 gather (== pov_proj 逻辑) -> golden_slices.
 *   out    = pov_render_full(points, scratch, lut, ...) 一条龙 -> out_slices.
 *   两者必须 100% 逐字节相同:
 *     - B1 Phase0+1 (清+散射) 必须复现参考散射的 grid;
 *     - B1 Phase2 (gather) 必须复现参考 gather.
 *   任何 word 不同 = FAIL (B1 与 A 路径逻辑分歧).
 */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <vector>
#include "pov_render_full.h"
#include "cos_sin_q15.h"

static std::vector<uint8_t> load_try(const char *name, const char *subpath) {
    /* 依次尝试 ./name 和 subpath/name */
    char p0[512]; snprintf(p0, sizeof p0, "%s", name);
    char p1[512]; snprintf(p1, sizeof p1, "%s%s", subpath, name);
    const char *paths[2] = { p0, p1 };
    for (int t = 0; t < 2; t++) {
        FILE *f = fopen(paths[t], "rb");
        if (!f) continue;
        fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
        std::vector<uint8_t> b(n);
        if (fread(b.data(), 1, n, f) != (size_t)n) { fclose(f); continue; }
        fclose(f);
        fprintf(stderr, "loaded %s (%ld bytes)\n", paths[t], n);
        return b;
    }
    fprintf(stderr, "cannot find %s (tried ./ and %s)\n", name, subpath);
    exit(2);
}

/* ---- 参考实现 (与 main.c / pov_proj 逐字节等价, B1 之外的独立黄金) ---- */
static inline int ref_clip127(int v){ return v<0?0:(v>127?127:v); }
static inline int ref_q15_round(int prod){
    if (prod >= 0) return (prod + (1 << 14)) >> 15;
    else           return -(((-prod) + (1 << 14)) >> 15);
}

int main(void) {
    const char *sub = "../../tools/";   /* tb 在 02_hello_zynq/hls_pov/, tools 在 repo 根 */

    std::vector<uint8_t> ptsb = load_try("anime_points.bin", sub);
    std::vector<uint8_t> lutb = load_try("transform_lut.bin", sub);

    if (lutb.size() != (size_t)FWI_COUNT*4) {
        fprintf(stderr, "FATAL lut size %zu != %d\n", lutb.size(), FWI_COUNT*4);
        return 2;
    }
    int n_points = (int)(ptsb.size() / sizeof(struct point_t));
    fprintf(stderr, "n_points = %d\n", n_points);

    const struct point_t *points = (const struct point_t *)ptsb.data();
    const struct lut_t   *lut    = (const struct lut_t   *)lutb.data();

    const int N = MAX_SLICES;   /* 720 */

    /* ======== 参考 (golden) ======== */
    /* (a) 参考散射 -> voxel_grid_ref */
    std::vector<struct voxel_t> vref((size_t)VOXEL_CELLS);
    memset(vref.data(), 0, vref.size()*sizeof(struct voxel_t));
    for (int i = 0; i < n_points; i++) {
        const struct point_t &p = points[i];
        int vx = ref_clip127((int)p.x + VOXEL_HALF);
        int vy = ref_clip127((int)p.y + VOXEL_HALF);
        int vz = ref_clip127((int)p.z + VOXEL_HALF);
        int idx = (vx * VOXEL_RES + vy) * VOXEL_RES + vz;
        vref[idx].r = p.r; vref[idx].g = p.g; vref[idx].b = p.b; vref[idx]._pad = 0;
    }
    /* (b) 参考 gather (== pov_proj) -> golden_slices */
    std::vector<uint32_t> golden((size_t)N*COMPACT_WORDS, 0);
    for (int s = 0; s < N; s++) {
        int cs = COS_Q15[s], sn = SIN_Q15[s];
        for (int w = 0; w < COMPACT_WORDS; w++) {
            uint32_t word = 0;
            for (int k = 0; k < 8; k++) {
                int fwi = (w << 3) | k;
                int d  = lut[fwi].d;
                int wy = lut[fwi].wy;
                int wx = ref_q15_round(d * cs) + VOXEL_HALF; wx = ref_clip127(wx);
                int wz = ref_q15_round(d * sn) + VOXEL_HALF; wz = ref_clip127(wz);
                int vidx = (wx * VOXEL_RES + wy) * VOXEL_RES + wz;
                const struct voxel_t &v = vref[vidx];
                uint32_t Gb = (v.g & 0x80) ? 1u : 0u;
                uint32_t Bb = (v.b & 0x80) ? 1u : 0u;
                uint32_t Rb = (v.r & 0x80) ? 1u : 0u;
                uint32_t lane = Gb | (Bb << 1) | (Rb << 2);
                word |= (lane << (k * 3));
            }
            golden[(size_t)s*COMPACT_WORDS + w] = word;
        }
    }

    /* ======== B1 一条龙 ======== */
    /* scratch grid 预填非 0 垃圾, 检验 Phase 0 清网格确实生效 */
    std::vector<struct voxel_t> scratch((size_t)VOXEL_CELLS);
    memset(scratch.data(), 0xAB, scratch.size()*sizeof(struct voxel_t));

    std::vector<uint32_t> out((size_t)N*COMPACT_WORDS, 0xDEADBEEF);
    pov_render_full(points, scratch.data(), lut, out.data(),
                    n_points, N, 0, N);

    /* dump 供二次核对 */
    FILE *fo = fopen("tb_full_out_compact.bin", "wb");
    if (fo) { fwrite(out.data(), 4, out.size(), fo); fclose(fo); }

    /* ======== 逐字节比对 ======== */
    /* 先验证 B1 散射后的 grid == 参考 grid (额外诊断, 比对 scratch) */
    long grid_diff = 0;
    for (size_t i = 0; i < (size_t)VOXEL_CELLS; i++) {
        if (memcmp(&scratch[i], &vref[i], sizeof(struct voxel_t)) != 0) grid_diff++;
    }

    int exact_slices = 0, diff_slices = 0;
    long total_word_diffs = 0;
    int worst_slice = -1, worst_diff = 0;
    std::vector<int> diff_angles;
    for (int s = 0; s < N; s++) {
        int wd = 0;
        for (int w = 0; w < COMPACT_WORDS; w++) {
            if (out[(size_t)s*COMPACT_WORDS + w] != golden[(size_t)s*COMPACT_WORDS + w]) wd++;
        }
        if (wd == 0) exact_slices++;
        else {
            diff_slices++; total_word_diffs += wd;
            if (wd > worst_diff) { worst_diff = wd; worst_slice = s; }
            if (diff_angles.size() < 40) diff_angles.push_back(s);
        }
    }

    printf("=== pov_render_full host TB (B1: 点云->清->散射->gather, anime, 720 片) ===\n");
    printf("n_points                       : %d\n", n_points);
    printf("Phase0+1 grid cells != ref     : %ld / %d  (应为 0)\n", grid_diff, VOXEL_CELLS);
    printf("Phase2 slices bit-exact vs ref : %d / %d (%.2f%%)\n",
           exact_slices, N, 100.0*exact_slices/N);
    printf("slices differing               : %d\n", diff_slices);
    printf("total differing words          : %ld  (of %d)\n",
           total_word_diffs, N*COMPACT_WORDS);
    if (worst_slice >= 0)
        printf("worst slice                    : %d (%d/%d words)\n",
               worst_slice, worst_diff, COMPACT_WORDS);
    if (!diff_angles.empty()) {
        printf("first differing slice indices  : ");
        for (size_t i = 0; i < diff_angles.size(); i++) printf("%d ", diff_angles[i]);
        printf("\n");
    }

    /* PASS = B1 与参考 (ARM 散射 + pov_proj gather) 100% 逐字节相同, grid 也一致. */
    int pass = (grid_diff == 0) && (exact_slices == N);
    printf("\nRESULT: %s  (B1 vs 参考: grid %s, slices %d/%d bit-exact)\n",
           pass ? "PASS" : "FAIL",
           grid_diff == 0 ? "match" : "MISMATCH",
           exact_slices, N);
    return pass ? 0 : 1;
}
