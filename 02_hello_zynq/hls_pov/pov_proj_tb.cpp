/* pov_proj_tb.cpp - host gcc/g++ 测试台 (不需 vitis_hls).
 *
 * 验证 pov_proj() 逻辑与 PC 管线 (tools/_gen_globe_slices.py -> compact) 对齐.
 *
 * 编译:  g++ -O2 -std=c++11 pov_proj_tb.cpp pov_proj.cpp -o pov_proj_tb
 * 运行:  ./pov_proj_tb            (输入 bin 在同目录, 由 _gen_tb_inputs.py 产)
 *
 * HLS #pragma 在 host gcc 下被忽略 (warning), top function 逻辑照常跑.
 *
 * 两层比对:
 *   1) golden = tools 的 globe_slices_720_compact.bin (PC float np.rint 管线).
 *      报告每片是否 bit-exact. 预期绝大多数片完全相同; 仅 cos/sin 量化 + 半值
 *      舍入差异的角度有 < 几 word 的差 (axis/half-angle), 量化报告.
 *   2) 输出我方 compact 到 tb_out_compact.bin, 供二次核对.
 */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <vector>
#include "pov_proj.h"

static std::vector<uint8_t> load(const char *path, size_t expect) {
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "cannot open %s\n", path); exit(2); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    std::vector<uint8_t> b(n);
    if (fread(b.data(), 1, n, f) != (size_t)n) { fprintf(stderr, "short read %s\n", path); exit(2); }
    fclose(f);
    if (expect && (size_t)n != expect)
        fprintf(stderr, "WARN %s size %ld != expected %zu\n", path, n, expect);
    return b;
}

int main(void) {
    const int N = MAX_SLICES;   /* 720 */

    /* ---- load inputs ---- */
    std::vector<uint8_t> vox = load("tb_globe_voxel.bin",
                                    (size_t)VOXEL_RES*VOXEL_RES*VOXEL_RES*4);
    std::vector<uint8_t> lutb = load("tb_transform_lut.bin",
                                     (size_t)FWI_COUNT*4);
    std::vector<uint8_t> gold = load("tb_globe_golden_compact.bin",
                                     (size_t)N*COMPACT_BYTES);

    const struct voxel_t *voxel_grid = (const struct voxel_t *)vox.data();
    const struct lut_t   *lut        = (const struct lut_t   *)lutb.data();

    /* ---- run IP over all 720 slices ---- */
    std::vector<uint32_t> out((size_t)N*COMPACT_WORDS, 0);
    pov_proj(voxel_grid, lut, out.data(), N, 0, N);

    /* dump our output */
    FILE *fo = fopen("tb_out_compact.bin", "wb");
    fwrite(out.data(), 4, out.size(), fo);
    fclose(fo);

    /* ---- compare per slice vs golden ---- */
    const uint32_t *g = (const uint32_t *)gold.data();
    int exact_slices = 0, diff_slices = 0;
    long total_word_diffs = 0;
    int worst_slice = -1, worst_diff = 0;
    std::vector<int> diff_angles;
    for (int s = 0; s < N; s++) {
        int wd = 0;
        for (int w = 0; w < COMPACT_WORDS; w++) {
            if (out[(size_t)s*COMPACT_WORDS + w] != g[(size_t)s*COMPACT_WORDS + w]) wd++;
        }
        if (wd == 0) exact_slices++;
        else {
            diff_slices++; total_word_diffs += wd;
            if (wd > worst_diff) { worst_diff = wd; worst_slice = s; }
            if (diff_angles.size() < 40) diff_angles.push_back(s);
        }
    }

    printf("=== pov_proj host TB (globe, 720 slices) ===\n");
    printf("slices bit-exact vs PC golden : %d / %d (%.2f%%)\n",
           exact_slices, N, 100.0*exact_slices/N);
    printf("slices differing              : %d\n", diff_slices);
    printf("total differing words         : %ld  (of %d total)\n",
           total_word_diffs, N*COMPACT_WORDS);
    printf("avg differing words / diff-slice: %.2f\n",
           diff_slices ? (double)total_word_diffs/diff_slices : 0.0);
    if (worst_slice >= 0)
        printf("worst slice                   : %d (%d/%d words differ)\n",
               worst_slice, worst_diff, COMPACT_WORDS);
    if (!diff_angles.empty()) {
        printf("first differing slice indices : ");
        for (size_t i = 0; i < diff_angles.size(); i++) printf("%d ", diff_angles[i]);
        printf("\n");
    }

    /* PASS criterion: >= 95% slices bit-exact AND每个 diff-slice 差异小 (<5%% words).
     * 差异根源 = cos/sin Q15 量化 + 半值舍入 (np.rint round-half-even vs 定点
     * round-half-away) 在 axis/half 角度. 不是逻辑错误. */
    double exact_pct = 100.0*exact_slices/N;
    double worst_pct = 100.0*worst_diff/COMPACT_WORDS;
    int pass = (exact_pct >= 95.0) && (worst_pct < 5.0);
    printf("\nRESULT: %s  (exact %.1f%% >= 95%% , worst-slice word-diff %.2f%% < 5%%)\n",
           pass ? "PASS" : "FAIL", exact_pct, worst_pct);
    return pass ? 0 : 1;
}
