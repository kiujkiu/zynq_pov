/* pov_slice_v2_tb.cpp — pov_slice_v2 对拍测试台 (2026-08-04)
 *
 * 判据: 与 gen_pv2_golden.py 的**定点**参考逐位相同 (同一张 Q8 LUT、同样的
 * +128>>8 取整)。任何不一致都是真 bug, 不是量化差异。
 *
 * 用法:
 *   python3 gen_pv2_golden.py --cfg 1bit --out golden_1bit
 *   vitis_hls -f run_csim.tcl        (需 -DPV2_CFG_1BIT, 且 argv[1]=golden 目录)
 */
#include "pov_slice_v2.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

static bool read_all(const char *path, void *dst, size_t bytes) {
    FILE *f = fopen(path, "rb");
    if (!f) { printf("  ✗ 打不开 %s\n", path); return false; }
    size_t got = fread(dst, 1, bytes, f);
    long extra = 0;
    if (got == bytes) { char c; extra = fread(&c, 1, 1, f); }
    fclose(f);
    if (got != bytes) {
        printf("  ✗ %s 长度不足: 读到 %zu, 期望 %zu\n", path, got, bytes);
        return false;
    }
    if (extra) { printf("  ✗ %s 比期望长\n", path); return false; }
    return true;
}

int main(int argc, char **argv) {
    const char *dir = (argc > 1) ? argv[1] : "golden_1bit";
    char path[512];

    /* ---- 读 cases.txt: W H N phase n_slots n_cases ---- */
    snprintf(path, sizeof path, "%s/cases.txt", dir);
    FILE *cf = fopen(path, "r");
    if (!cf) { printf("✗ 打不开 %s — 先跑 gen_pv2_golden.py\n", path); return 1; }
    int W, H, N, phase, n_slots, n_cases;
    if (fscanf(cf, "%d %d %d %d %d %d", &W, &H, &N, &phase, &n_slots, &n_cases) != 6) {
        printf("✗ cases.txt 头部格式不对\n"); fclose(cf); return 1;
    }

    /* 🔴 先核对几何: 编译期配置必须与黄金一致, 否则后面全是无意义的失配 */
    printf("黄金: %d×%d / %d 档   编译期: %d×%d / %d 档\n",
           W, H, N, PV2_PANEL_W, PV2_PANEL_H, PV2_NUM_ANGLES);
    if (W != PV2_PANEL_W || H != PV2_PANEL_H || N != PV2_NUM_ANGLES) {
        printf("✗ 几何不匹配 — 1bit 配置要 -DPV2_CFG_1BIT, 目标配置不要加\n");
        fclose(cf); return 1;
    }

    std::vector<int> off_q8(n_cases), mir(n_cases);
    for (int i = 0; i < n_cases; i++)
        if (fscanf(cf, "%d %d", &off_q8[i], &mir[i]) != 2) {
            printf("✗ cases.txt case %d 格式不对\n", i); fclose(cf); return 1;
        }
    fclose(cf);

    /* ---- 体素网格 ---- */
    const size_t vox_elems = (size_t)PV2_VOX_XZ * PV2_VOX_XZ * PV2_VOX_Y;
    std::vector<uint16_t> vox(vox_elems);
    snprintf(path, sizeof path, "%s/voxels.bin", dir);
    if (!read_all(path, vox.data(), vox_elems * sizeof(uint16_t))) return 1;
    printf("体素 %zu 元素 (%.2f MB)\n", vox_elems, vox_elems * 2.0 / 1048576.0);

    /* ---- 逐 case 对拍 ---- */
    const size_t slice_elems = (size_t)PV2_SLOT_ELEMS;
    const size_t out_elems   = slice_elems * n_slots;
    std::vector<uint16_t> got(out_elems), want(out_elems);

    int fail = 0;
    for (int c = 0; c < n_cases; c++) {
        snprintf(path, sizeof path, "%s/golden_case%d.bin", dir, c);
        if (!read_all(path, want.data(), out_elems * sizeof(uint16_t))) { fail++; continue; }

        /* 填毒药值: 若 IP 漏写某些位置, 会显出来而不是碰巧等于 0 */
        std::memset(got.data(), 0xA5, out_elems * sizeof(uint16_t));

        pov_slice_v2(reinterpret_cast<const uint64_t *>(vox.data()),
                     reinterpret_cast<uint64_t *>(got.data()),
                     phase, 0, n_slots, off_q8[c], mir[c]);

        size_t bad = 0; size_t first = 0;
        for (size_t i = 0; i < out_elems; i++)
            if (got[i] != want[i]) { if (!bad) first = i; bad++; }

        printf("case%d  axis_off_q8=%-5d mirror_u=%d  ", c, off_q8[c], mir[c]);
        if (!bad) {
            printf("✅ %zu 元素逐位相同\n", out_elems);
        } else {
            size_t s = first / slice_elems, r = first % slice_elems;
            printf("❌ %zu/%zu 不符 (%.3f%%); 首个: 片%zu 列%zu 行%zu  得 0x%04X 期望 0x%04X\n",
                   bad, out_elems, 100.0 * bad / out_elems,
                   s, r / PV2_PANEL_H, r % PV2_PANEL_H, got[first], want[first]);
            fail++;
        }
    }

    if (fail) printf("\n✗ %d/%d case 失败\n", fail, n_cases);
    else      printf("\n✅ 全部 %d 个 case 通过\n", n_cases);
    fflush(stdout);

    /* 🔴 已知环境问题 (Windows 版 Vitis HLS 2024.2, 2026-08-04):
     * 无论 `return 0` 还是 `exit(0)`, csim_design 都报 "nonzero return value"。
     * 已用 [DIAG] 打印证实 rc 确实是 0; 单独跑 csim.exe 则报 Windows 加载器
     * 错误 53 (缺 Vitis 运行时 DLL)。**根因未定位。**
     * ⇒ **判据以上面打印的 ✅/✗ 为准, 不要看 csim_design 的退出状态。**
     * 自动化时应 grep 日志里的 "全部 N 个 case 通过"。 */
    exit(fail ? 1 : 0);
}
