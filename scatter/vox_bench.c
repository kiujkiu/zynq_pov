/* vox_bench.c — scatter 环节的对拍 + 计时台 (x86 离线, 不碰板子)
 *
 * 三件事:
 *   ① **逐字节对拍**: VXT1 表 → scatter → 与 gen_voxtab.py 直接体素化出的黄金网格
 *      逐字节相同。这是本环节的正确性判据。
 *   ② **计时**: scatter / 增量清理 / 整块 memset 各自耗时, 给余量表用。
 *   ③ **增量清理的正确性**(比 ① 更难): 连着放多帧, 每帧都对拍。若清理漏了格,
 *      上一帧的残影会留在网格里, 第 2 帧起立刻暴露 —— 只测第 1 帧是测不出来的。
 *
 * 用法: ./vox_bench <目录>            (目录 = gen_voxtab.py --out)
 *       ./vox_bench <目录> --rep 20   (重复 20 轮取中位数)
 */
#include "vox_table.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static double now_ms(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec * 1e3 + t.tv_nsec * 1e-6;
}

static void *slurp(const char *path, size_t *len)
{
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "✗ 打不开 %s\n", path); return NULL; }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    void *p = NULL;
    if (posix_memalign(&p, 64, (size_t)n + 64) != 0) { fclose(f); return NULL; }
    if (fread(p, 1, (size_t)n, f) != (size_t)n) { fclose(f); free(p); return NULL; }
    fclose(f);
    *len = (size_t)n;
    return p;
}

static int cmp_d(const void *a, const void *b)
{
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

#define MAXF 64

int main(int argc, char **argv)
{
    const char *dir = (argc > 1) ? argv[1] : ".";
    int rep = 5;
    for (int i = 2; i < argc; i++)
        if (!strcmp(argv[i], "--rep") && i + 1 < argc) rep = atoi(argv[++i]);

    char path[1024];
    snprintf(path, sizeof path, "%s/manifest.txt", dir);
    FILE *mf = fopen(path, "r");
    if (!mf) { fprintf(stderr, "✗ 打不开 %s — 先跑 gen_voxtab.py\n", path); return 1; }
    int XZ, Y, nf;
    if (fscanf(mf, "%d %d %d", &XZ, &Y, &nf) != 3) { fprintf(stderr, "✗ manifest 头\n"); return 1; }
    printf("清单: 网格 %d×%d×%d, %d 帧   编译期: %d×%d×%d\n",
           XZ, XZ, Y, nf, PV2_VOX_XZ, PV2_VOX_XZ, PV2_VOX_Y);
    if (XZ != PV2_VOX_XZ || Y != PV2_VOX_Y) {
        fprintf(stderr, "✗ 几何不匹配 — 1bit 配置要 -DPV2_CFG_1BIT\n"); return 1;
    }
    if (nf > MAXF) nf = MAXF;

    char vxt[MAXF][256], gold[MAXF][256];
    long nvox[MAXF];
    for (int i = 0; i < nf; i++)
        if (fscanf(mf, "%255s %255s %ld", vxt[i], gold[i], &nvox[i]) != 3) {
            fprintf(stderr, "✗ manifest 第 %d 行\n", i); return 1;
        }
    fclose(mf);

    /* ---- 分配 ---- */
    uint16_t *grid = NULL;
    if (posix_memalign((void **)&grid, 4096, VXT_GRID_BYTES) != 0) {
        fprintf(stderr, "✗ 网格分配失败 (%.1f MB)\n", VXT_GRID_BYTES / 1048576.0); return 1;
    }
    uint32_t cap = 600000;
    uint32_t *ia = malloc((size_t)cap * 4), *ib = malloc((size_t)cap * 4);
    vox_scatter_t s;
    vox_scatter_init(&s, grid, ia, ib, cap);

    void *body[MAXF]; size_t blen[MAXF];
    for (int i = 0; i < nf; i++) {
        snprintf(path, sizeof path, "%s/%s", dir, vxt[i]);
        body[i] = slurp(path, &blen[i]);
        if (!body[i]) return 1;
    }

    /* ---- ① + ③ 对拍 (连续多帧, 走增量清理路径) ---- */
    int fail = 0, checked = 0;
    printf("\n── 逐字节对拍 (与直接体素化的黄金网格) ──\n");
    for (int i = 0; i < nf; i++) {
        vox_stats_t st;
        int rc = vox_scatter_apply(&s, body[i], blen[i], &st);
        if (rc != VXT_OK) { printf("f%03d ✗ apply rc=%d\n", i, rc); fail++; continue; }
        if (gold[i][0] == '-') continue;
        snprintf(path, sizeof path, "%s/%s", dir, gold[i]);
        size_t gl;
        void *g = slurp(path, &gl);
        if (!g) { fail++; continue; }
        if (gl != VXT_GRID_BYTES) { printf("f%03d ✗ 黄金长度 %zu\n", i, gl); fail++; free(g); continue; }
        size_t bad = 0, first = 0;
        const uint16_t *gg = (const uint16_t *)g;
        for (uint32_t k = 0; k < VXT_CELLS; k++)
            if (grid[k] != gg[k]) { if (!bad) first = k; bad++; }
        checked++;
        if (bad) {
            uint32_t vz = (uint32_t)(first / (PV2_VOX_XZ * PV2_VOX_Y));
            uint32_t r  = (uint32_t)(first % (PV2_VOX_XZ * PV2_VOX_Y));
            printf("f%03d ✗ %zu/%u 格不符; 首个 idx=%zu (vz=%u vx=%u vy=%u) "
                   "得 0x%04X 期望 0x%04X\n", i, bad, VXT_CELLS, first,
                   vz, r / PV2_VOX_Y, r % PV2_VOX_Y, grid[first], gg[first]);
            fail++;
        } else {
            printf("f%03d ✅ %u 格逐字节相同  (占据 %u, 覆写 %u, 清理 %u, 新增 %u%s)\n",
                   i, VXT_CELLS, st.n_vox, st.n_keep, st.n_clear, st.n_new,
                   st.full_clear ? ", 整清" : "");
        }
        free(g);
    }
    if (!checked) printf("⚠ 没有黄金网格可比 (--golden 0?)\n");

    /* ---- ② 计时 ---- */
    printf("\n── 计时 (x86, %d 轮取中位数) ──\n", rep);
    double t_apply[MAXF][64], t_full[64], t_memset[64], t_dec[64];
    uint32_t *tmp = malloc((size_t)cap * 4);
    for (int r = 0; r < rep; r++) {
        vox_scatter_desync(&s);              /* 第 0 帧走整清路径 */
        for (int i = 0; i < nf; i++) {
            double t0 = now_ms();
            vox_scatter_apply(&s, body[i], blen[i], NULL);
            double t1 = now_ms();
            if (i == 0) t_full[r] = t1 - t0; else t_apply[i][r] = t1 - t0;
        }
        double t0 = now_ms();
        memset(grid, 0, VXT_GRID_BYTES);
        t_memset[r] = now_ms() - t0;
        t0 = now_ms();
        vox_decode_indices(body[nf > 1 ? 1 : 0], blen[nf > 1 ? 1 : 0], tmp, cap);
        t_dec[r] = now_ms() - t0;
    }
    qsort(t_full, rep, sizeof(double), cmp_d);
    qsort(t_memset, rep, sizeof(double), cmp_d);
    qsort(t_dec, rep, sizeof(double), cmp_d);

    double sum = 0; int cnt = 0;
    long nv_sum = 0;
    for (int i = 1; i < nf; i++) {
        qsort(t_apply[i], rep, sizeof(double), cmp_d);
        sum += t_apply[i][rep / 2]; cnt++; nv_sum += nvox[i];
    }
    double inc = cnt ? sum / cnt : 0.0;
    long nv_avg = cnt ? nv_sum / cnt : nvox[0];

    printf("整清帧 (memset 全网格 + 全量写)  : %8.3f ms   n_vox=%ld\n", t_full[rep / 2], nvox[0]);
    printf("增量帧 (归并清理 + 写)           : %8.3f ms   n_vox≈%ld  ⇒ %.1f ns/格\n",
           inc, nv_avg, inc * 1e6 / (double)(nv_avg ? nv_avg : 1));
    printf("  其中 varint 解码 (不碰网格)    : %8.3f ms   ⇒ %.1f ns/格 (纯计算)\n",
           t_dec[rep / 2], t_dec[rep / 2] * 1e6 / (double)(nv_avg ? nv_avg : 1));
    printf("  其余 = 散写网格 (吃 DDR)       : %8.3f ms\n", inc - t_dec[rep / 2]);
    printf("裸 memset 整网格 (%.1f MB)       : %8.3f ms   ⇒ %.0f MB/s\n",
           VXT_GRID_BYTES / 1048576.0, t_memset[rep / 2],
           VXT_GRID_BYTES / 1048576.0 / (t_memset[rep / 2] / 1e3));

    /* ---- ③ 与硬件无关的 DDR 流量口径 ─────────────────────────────────────
     * 🔴 x86 的墙钟在这里**会骗人**: 本机 memset 有 20+ GB/s, 整块清 15.9 MB
     * 只要 0.7 ms, 于是"增量清理"看起来毫无优势甚至更慢。而 Zynq-7020 的 A9
     * 实测 memcpy 只有 ~442 MB/s (pov_rxd 的 cpy 20 ms / 8.85 MB), 差 30-50 倍。
     * ⇒ 唯一能跨机器比较的量是**摸到的 cache 行数 / DDR 字节数**, 下面直接数。
     * A9/PL310 的 cache 行 = 32 B; 写分配 ⇒ 每摸一条行 = 读 32 + 回写 32。 */
    {
        const uint32_t LINE = 32, CPL = LINE / 2;    /* 每行 16 个体素 */
        long lines_tot = 0; int lf = 0;
        for (int i = 1; i < nf; i++) {
            int n = vox_decode_indices(body[i], blen[i], tmp, cap);
            if (n <= 0) continue;
            long lines = 0; uint32_t last = 0xFFFFFFFFu;
            for (int k = 0; k < n; k++) {
                uint32_t ln = tmp[k] / CPL;
                if (ln != last) { lines++; last = ln; }
            }
            lines_tot += lines; lf++;
        }
        double lines_avg = lf ? (double)lines_tot / lf : 0;
        double inc_bytes = lines_avg * LINE * 2.0;   /* 读入 + 回写 */
        double full_bytes = (double)VXT_GRID_BYTES * 2.0 + inc_bytes;
        printf("\n── DDR 流量 (与机器无关; 32 B cache 行, 写分配) ──\n");
        printf("增量: 摸到 %.0f 条行 (%.2f 格/行) ⇒ %.2f MB/帧\n",
               lines_avg, nv_avg / (lines_avg > 0 ? lines_avg : 1), inc_bytes / 1048576.0);
        printf("整清: memset %.1f MB(读+写 %.1f MB) + 上面那些 ⇒ %.2f MB/帧\n",
               VXT_GRID_BYTES / 1048576.0, VXT_GRID_BYTES * 2.0 / 1048576.0,
               full_bytes / 1048576.0);
        printf("⇒ **增量清理省 %.1f× 的 DDR 流量**\n", full_bytes / inc_bytes);

        /* A9 外推 (估算, 明确标注): 用板上实测的两个常数
         *   BW  = 442 MB/s  (pov_rxd 单线程 memcpy 8.85 MB / 20 ms)
         *   IPC : varint 解码按 x86 时间 × 8 折算 (A9 666MHz 顺序双发 vs x86 乱序) */
        const double A9_BW = 442.0, A9_CPU_K = 8.0;
        double a9_dec = t_dec[rep / 2] * A9_CPU_K;
        double a9_mem = inc_bytes / 1048576.0 / A9_BW * 1000.0;
        printf("\n── A9 外推 (⚠ 估算, 未上板) BW=442MB/s, CPU×%.0f ──\n", A9_CPU_K);
        printf("增量帧 ≈ 解码 %.1f ms + DDR %.1f ms = **%.1f ms**\n",
               a9_dec, a9_mem, a9_dec + a9_mem);
        printf("若每帧整清 ≈ + %.1f ms (memset %.1f MB @%.0f MB/s) = %.1f ms  ← 会直接超预算\n",
               VXT_GRID_BYTES / 1048576.0 / A9_BW * 1000.0, VXT_GRID_BYTES / 1048576.0,
               A9_BW, a9_dec + a9_mem + VXT_GRID_BYTES / 1048576.0 / A9_BW * 1000.0);
    }
    free(tmp);

    /* ---- ④ 负面用例: 坏载荷必须**当场报错**, 不能静默写坏网格 ──────────
     * 板端拿到的是 WiFi 上来的字节, 出错是常态。这里逐条验证每种畸形载荷都能
     * 被抓住 —— 不抓住的后果是 15.9 MB 网格里出现随机脏格, 而且永远清不掉。 */
    {
        printf("\n── 负面用例 (坏载荷必须被拒) ──\n");
        int nf_ok = 0, nf_bad = 0;
        uint8_t *c = malloc(blen[0]);
        #define NEG(desc, want, setup) do {                                   \
            memcpy(c, body[0], blen[0]); size_t L = blen[0]; setup;            \
            vox_scatter_desync(&s);                                            \
            int r_ = vox_scatter_apply(&s, c, L, NULL);                        \
            if (r_ == (want)) { nf_ok++; printf("  ✅ %-22s → rc=%d\n", desc, r_); } \
            else { nf_bad++; printf("  ✗ %-22s → rc=%d, 期望 %d\n", desc, r_, (want)); } \
        } while (0)

        NEG("魔数错",   VXT_E_MAGIC, c[0] = 'X');
        NEG("尾部截断", VXT_E_SHORT, L = blen[0] - 1);
        NEG("头部截断", VXT_E_SHORT, L = 12);
        NEG("几何不符", VXT_E_GEOM,  c[6] = 0x99);            /* grid_y 低字节 */
        NEG("n_vox 超容量", VXT_E_CAP, { uint32_t big = cap + 1; memcpy(c + 8, &big, 4); });
        /* 索引越界: 把最后一个 varint 换成一个巨大的 delta。做法是直接改 idx_bytes
         * 与流内容不现实, 改用手工构造的极小体。*/
        {
            uint8_t mini[24 + 2 + 5];
            memcpy(mini, VXT_MAGIC, 4);
            uint16_t xz = PV2_VOX_XZ, yy = PV2_VOX_Y, fl = VXT_FLAG_KEY, sq = 0;
            uint32_t nv = 1, ib = 5, rs = 0;
            memcpy(mini + 4, &xz, 2); memcpy(mini + 6, &yy, 2);
            memcpy(mini + 8, &nv, 4); memcpy(mini + 12, &ib, 4);
            memcpy(mini + 16, &fl, 2); memcpy(mini + 18, &sq, 2);
            memcpy(mini + 20, &rs, 4);
            mini[24] = 0xFF; mini[25] = 0xFF;                  /* 颜色 */
            /* LEB128 编 0x0FFFFFFF (远超 796 万格) */
            mini[26] = 0xFF; mini[27] = 0xFF; mini[28] = 0xFF; mini[29] = 0x7F; mini[30] = 0x00;
            vox_scatter_desync(&s);
            int r_ = vox_scatter_apply(&s, mini, sizeof mini, NULL);
            if (r_ == VXT_E_RANGE) { nf_ok++; printf("  ✅ %-22s → rc=%d\n", "索引越界", r_); }
            else { nf_bad++; printf("  ✗ %-22s → rc=%d, 期望 %d\n", "索引越界", r_, VXT_E_RANGE); }
        }
        free(c);
        printf("  小计 %d 通过 / %d 失败\n", nf_ok, nf_bad);
        fail += nf_bad;
        vox_scatter_desync(&s);
    }

    printf("\n%s\n", fail ? "✗ 有对拍失败" : "✅ 全部对拍通过");
    return fail ? 1 : 0;
}
