/* pov_eta_rd_tb.cpp — csim 对拍: pov_eta_rd 的 XOR 必须等于按 pov_slice_v2 原地址算法算的 XOR
 * (证明"平坦拍序号 -> (slice, px, beat)"的改写没有改变读的地址集合与顺序)。
 * 体素网格用伪随机填充 (16 MB, csim 在主机上跑没问题)。
 * ⚠ 本机 csim_design 恒报 nonzero return value (见 hls_proj/run_pv2.tcl 注释), 判据看打印。
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <hls_burst_maxi.h>
#include "pov_slice_v2.h"
#include "pov_slice_v2_lut.h"

void pov_eta_rd(hls::burst_maxi<uint64_t> voxel, int phase, int n_slots,
                int axis_off_q8, int mirror_u, int pf_cols, uint64_t *xor_out);

/* 逐字照抄 pov_slice_v2.cpp 的地址算法 (只读 + XOR) */
static uint64_t ref_xor(const uint64_t *voxel, int phase, int n_slots, int axis_off_q8, int mirror_u)
{
    uint64_t acc = 0;
    for (int s = 0; s < n_slots; s++) {
        int angle = (phase + s) % PV2_NUM_ANGLES;
        if (angle < 0) angle += PV2_NUM_ANGLES;
        const int cs = PV2_COS8[angle], sn = PV2_SIN8[angle];
        const int off_x_q8 = -((axis_off_q8 * sn) >> 8);
        const int off_z_q8 =  ((axis_off_q8 * cs) >> 8);
        for (int px = 0; px < PV2_PANEL_W; px++) {
            int u = px - PV2_CX;
            if (mirror_u) u = -u;
            const int rx = ((u * cs + off_x_q8 + 128) >> 8) + PV2_VOX_HALF;
            const int rz = ((u * sn + off_z_q8 + 128) >> 8) + PV2_VOX_HALF;
            const bool inside = (rx >= 0) && (rx < PV2_VOX_XZ) && (rz >= 0) && (rz < PV2_VOX_XZ);
            const int vx = inside ? rx : 0, vz = inside ? rz : 0;
            const long src = ((long)vz * PV2_VOX_XZ + vx) * PV2_COL_BEATS;
            for (int b = 0; b < PV2_COL_BEATS; b++) acc ^= voxel[src + b];   /* 不做 inside 屏蔽, 与 pov_eta_rd 一致 */
        }
    }
    return acc;
}

int main()
{
    const size_t nwords = (size_t)PV2_VOX_XZ * PV2_VOX_XZ * PV2_COL_BEATS;   /* 1,990,656 */
    uint64_t *vox = (uint64_t *)malloc(nwords * sizeof(uint64_t));
    uint64_t x = 0x9E3779B97F4A7C15ull;
    for (size_t i = 0; i < nwords; i++) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; vox[i] = x; }

    struct { int phase, n, aoff, mir, pf; } cases[] = {
        {0, 1, 0, 0, 2}, {151, 1, 0, 0, 2}, {0, 1, 0, 0, 0}, {0, 3, 0, 0, 6},
        {600, 5, 4391, 1, 2}, {7, 0, 0, 0, 2},
    };
    int fails = 0, n = sizeof(cases) / sizeof(cases[0]);
    for (int c = 0; c < n; c++) {
        uint64_t got = 0xFFFFFFFFFFFFFFFFull;
        hls::burst_maxi<uint64_t> m(vox);
        pov_eta_rd(m, cases[c].phase, cases[c].n, cases[c].aoff, cases[c].mir, cases[c].pf, &got);
        uint64_t exp = ref_xor(vox, cases[c].phase, cases[c].n, cases[c].aoff, cases[c].mir);
        bool ok = (got == exp);
        printf("%s case %d: phase=%d n=%d aoff=%d mir=%d pf=%d  got=%016llx exp=%016llx\n",
               ok ? "PASS" : "FAIL", c, cases[c].phase, cases[c].n, cases[c].aoff, cases[c].mir,
               cases[c].pf, (unsigned long long)got, (unsigned long long)exp);
        if (!ok) fails++;
    }
    printf("%s: %d/%d cases\n", fails ? "TB_FAIL" : "TB_PASS", n - fails, n);
    free(vox);
    return fails ? 1 : 0;
}
