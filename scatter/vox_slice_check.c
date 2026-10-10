/* vox_slice_check.c — 端到端: VXT1 表 → scatter → **pov_slice_v2** → 切片文件
 *
 * 🔴 pov_slice_v2.cpp/.h **只读不改** (另一个 agent 正在综合打包它)。这里只是把它
 * 当普通 C 编进来跑 csim 级别的验证 —— #pragma HLS 在 gcc 下被忽略, 语义等价。
 *
 * 输出 slices_from_scatter.bin 交给 check_slice_ref.py 与 Python 参考逐字节比。
 * 那一步才是真正的**取向自检**: 参考侧用 gen_anime_slices.py 的读法
 * (`vox[wx, (H-1)-row, wz]`, 体素 y 向上), 本侧是 scatter 写进去的 y 已翻好的网格
 * 经切片器直拷。两边对上, 才证明 "vy = (Y-1) - gy" 这条约定端到端成立。
 *
 * 用法: ./vox_slice_check <目录> [片数] [axis_off_q8] [mirror_u] [phase]
 */
#include "vox_table.h"
#include "pov_slice_v2.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

int main(int argc, char **argv)
{
    const char *dir = (argc > 1) ? argv[1] : ".";
    int n_slots = (argc > 2) ? atoi(argv[2]) : 8;
    int off_q8  = (argc > 3) ? atoi(argv[3]) : 0;
    int mirror  = (argc > 4) ? atoi(argv[4]) : 1;
    int phase   = (argc > 5) ? atoi(argv[5]) : 0;

    char path[1024];
    snprintf(path, sizeof path, "%s/manifest.txt", dir);
    FILE *mf = fopen(path, "r");
    if (!mf) { fprintf(stderr, "✗ 打不开 manifest\n"); return 1; }
    int XZ, Y, nf;
    if (fscanf(mf, "%d %d %d", &XZ, &Y, &nf) != 3) return 1;
    char v0[256], g0[256]; long n0;
    if (fscanf(mf, "%255s %255s %ld", v0, g0, &n0) != 3) return 1;
    fclose(mf);
    if (XZ != PV2_VOX_XZ || Y != PV2_VOX_Y) {
        fprintf(stderr, "✗ 几何不匹配\n"); return 1;
    }

    uint16_t *grid = NULL;
    if (posix_memalign((void **)&grid, 4096, VXT_GRID_BYTES)) return 1;
    uint32_t cap = 600000;
    uint32_t *ia = malloc((size_t)cap * 4), *ib = malloc((size_t)cap * 4);
    vox_scatter_t s; vox_scatter_init(&s, grid, ia, ib, cap);

    snprintf(path, sizeof path, "%s/%s", dir, v0);
    size_t bl; void *b = slurp(path, &bl);
    if (!b) return 1;
    vox_stats_t st;
    int rc = vox_scatter_apply(&s, b, bl, &st);
    if (rc != VXT_OK) { fprintf(stderr, "✗ scatter rc=%d\n", rc); return 1; }
    printf("scatter ok: %u 格\n", st.n_vox);

    size_t se = (size_t)PV2_SLOT_ELEMS * n_slots;
    uint16_t *slots = NULL;
    if (posix_memalign((void **)&slots, 4096, se * 2)) return 1;
    memset(slots, 0xA5, se * 2);          /* 毒药值: 漏写会显出来 */

    pov_slice_v2((const uint64_t *)grid, (uint64_t *)slots,
                 phase, 0, n_slots, off_q8, mirror);

    snprintf(path, sizeof path, "%s/slices_from_scatter.bin", dir);
    FILE *o = fopen(path, "wb");
    if (!o) return 1;
    fwrite(slots, 2, se, o);
    fclose(o);
    printf("切片写出: %s  (%d 片 × %d 元素, phase=%d off_q8=%d mirror=%d)\n",
           path, n_slots, PV2_SLOT_ELEMS, phase, off_q8, mirror);
    return 0;
}
