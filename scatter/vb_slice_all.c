/* vb_slice_all.c — 验证板 (vb358) 离线端到端: VXT1 序列 → scatter → pov_slice_v2 全角度双面
 *
 * 板端那两段代码 (vox_scatter.c + hls_proj/pov_slice_v2.cpp) **原样**编进来跑:
 *   每个 .vxt 依次 vox_scatter_apply (增量清理, 跟板上一样跨帧维持网格),
 *   每帧切 面A 全部 PV2_NUM_ANGLES 片 + 面B 全部片, 追加写到输出文件。
 * 输出排布: 逐帧 [面A N×W×H u16][面B N×W×H u16], 每片列优先 slot[px][py]。
 * 对拍 (独立浮点参考) 在 vb358_e2e.py。
 *
 * 编译: make CFG=vb358 vb_slice_all       (x86; aarch64 见 Makefile 的 vb_slice_all_a64)
 * 用法: ./vb_slice_all <out.bin> <n_slices> <offA_q8> <mirA> <phA> <offB_q8> <mirB> <phB> f0.vxt [f1.vxt ...]
 *   n_slices 只用来核对编译期 PV2_NUM_ANGLES (profile 与编译配置必须一致)。
 */
#define _POSIX_C_SOURCE 200809L
#include "vox_table.h"
#include "pov_slice_v2.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static void *slurp(const char *path, size_t *len)
{
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "✗ 打不开 %s\n", path); return NULL; }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    void *p = NULL;
    if (posix_memalign(&p, 64, (size_t)n + 64) != 0) { fclose(f); return NULL; }
    if (fread(p, 1, (size_t)n, f) != (size_t)n) { fclose(f); free(p); return NULL; }
    fclose(f); *len = (size_t)n; return p;
}

static double now_s(void)
{
    struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}

int main(int argc, char **argv)
{
    if (argc < 10) {
        fprintf(stderr, "用法: %s out.bin n_slices offA_q8 mirA phA offB_q8 mirB phB f0.vxt [...]\n",
                argv[0]);
        return 2;
    }
    const char *out = argv[1];
    const int n = atoi(argv[2]);
    const int offA = atoi(argv[3]), mirA = atoi(argv[4]), phA = atoi(argv[5]);
    const int offB = atoi(argv[6]), mirB = atoi(argv[7]), phB = atoi(argv[8]);
    if (n != PV2_NUM_ANGLES) {
        fprintf(stderr, "✗ profile n_slices=%d 与编译配置 PV2_NUM_ANGLES=%d 不符 (make CFG=?)\n",
                n, PV2_NUM_ANGLES);
        return 1;
    }

    uint16_t *grid = NULL;
    if (posix_memalign((void **)&grid, 4096, VXT_GRID_BYTES)) return 1;
    const uint32_t cap = VXT_CELLS;                  /* 探针体是满网格 */
    uint32_t *ia = malloc((size_t)cap * 4), *ib = malloc((size_t)cap * 4);
    if (!ia || !ib) return 1;
    vox_scatter_t s;
    vox_scatter_init(&s, grid, ia, ib, cap);

    const size_t face_elems = (size_t)PV2_SLOT_ELEMS * PV2_NUM_ANGLES;
    uint16_t *slots = NULL;
    if (posix_memalign((void **)&slots, 4096, face_elems * 2)) return 1;

    FILE *o = fopen(out, "wb");
    if (!o) { fprintf(stderr, "✗ 打不开 %s\n", out); return 1; }

    double t_sc = 0, t_sl = 0;
    for (int fi = 9; fi < argc; fi++) {
        size_t bl;
        void *b = slurp(argv[fi], &bl);
        if (!b) return 1;
        vox_stats_t st;
        double t0 = now_s();
        int rc = vox_scatter_apply(&s, b, bl, &st);
        t_sc += now_s() - t0;
        free(b);
        if (rc != VXT_OK) { fprintf(stderr, "✗ %s scatter rc=%d\n", argv[fi], rc); return 1; }
        printf("  %s: n_vox=%u clear=%u keep=%u new=%u full=%d\n", argv[fi],
               st.n_vox, st.n_clear, st.n_keep, st.n_new, st.full_clear);

        const int face[2][3] = { { offA, mirA, phA }, { offB, mirB, phB } };
        for (int f = 0; f < 2; f++) {
            memset(slots, 0xA5, face_elems * 2);      /* 毒药值: 漏写会显出来 */
            t0 = now_s();
            pov_slice_v2((const uint64_t *)grid, (uint64_t *)slots,
                         face[f][2], 0, PV2_NUM_ANGLES, face[f][0], face[f][1]);
            t_sl += now_s() - t0;
            if (fwrite(slots, 2, face_elems, o) != face_elems) return 1;
        }
    }
    fclose(o);
    const int nf = argc - 9;
    printf("切片写出 %s: %d 帧 × 2 面 × %d 片 × %d×%d (x86 计时: scatter %.2f ms/帧, "
           "切片 %.1f µs/片)\n", out, nf, PV2_NUM_ANGLES, PV2_PANEL_W, PV2_PANEL_H,
           1e3 * t_sc / nf, 1e6 * t_sl / (nf * 2.0 * PV2_NUM_ANGLES));
    return 0;
}
