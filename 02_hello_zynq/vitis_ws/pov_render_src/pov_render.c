/* pov_render.c — POV-3D 点云→切片渲染核心 (纯计算).
 * 见 pov_render.h。算法对齐 tools/_gen_transform_lut.py slice_via_lut。
 *
 * ── 舍入语义 / 后端选择 ───────────────────────────────────────────────────
 * PC 管线用 numpy np.rint(d*cosθ): round-half-to-even (banker's rounding)。
 *
 *   默认 (浮点)   : double cos/sin + C99 rint() (round-half-to-even), 与
 *                   numpy 逐字节全等 (_verify_arm.py 验证: BYTE-EXACT)。
 *                   Cortex-A9 带硬件 VFP, 且本渲染是"算一次"静态任务 (非
 *                   实时环), 浮点开销无所谓 → 选最精确的做默认。
 *   POV_USE_FIXED : Q15 cos/sin 表 (round(cos*32768)) + 整数乘 + 显式
 *                   round-half-to-even。无 FPU 平台 / 想纯整数时用。
 *
 * 定点精度: d ∈ [-64,63], Q15 cos ∈ ±32768, 乘积 ±2^21, 不溢出 int32。
 * 与浮点的差异是 cos 表量化让极少数落在 .5 边界的样本偏 1 像素:
 * 实测 720 片 5.76 MB 仅 489 lit-bit / 10 片不同 (0.001% bits, 1-bit 显示
 * 下亚像素不可见)。提到 Q30 仍剩 128 个真·半整数 tie, 是数学固有非 bug。
 * 详见 tools/_verify_arm.py。
 */
#include "pov_render.h"

/* ───────────────────────── 体素化 ───────────────────────── */

static inline int clip127(int v)
{
    if (v < 0)   return 0;
    if (v > 127) return 127;
    return v;
}

void pov_voxelize(const pov_point_t *pts, int n, uint8_t *vox)
{
    int i;
    for (i = 0; i < n; i++) {
        int vx = clip127((int)pts[i].x + 64);
        int vy = clip127((int)pts[i].y + 64);
        int vz = clip127((int)pts[i].z + 64);
        uint8_t *cell = vox + ((((vx * POV_GRID) + vy) * POV_GRID) + vz) * 3;
        cell[0] = pts[i].r;   /* last-write */
        cell[1] = pts[i].g;
        cell[2] = pts[i].b;
    }
}

/* ───────────────────── 角度 cos/sin 后端 ─────────────────────
 * 默认浮点 (byte-exact); 定义 POV_USE_FIXED 切 Q15 定点 (纯整数, 亚像素差异)。 */
#if !defined(POV_USE_FIXED)
#define POV_FLOAT_BACKEND 1
#endif

#ifdef POV_FLOAT_BACKEND
#include <math.h>
/* 浮点版: 返回 wx/wz = clip(rint(d*c)+64). rint = round-half-to-even (C99). */
static inline void proj_xz(int d, double c, double s, int *wx, int *wz)
{
    *wx = clip127((int)rint((double)d * c) + 64);
    *wz = clip127((int)rint((double)d * s) + 64);
}
#else
/* 定点版: Q15. round-half-to-even on (d*cosQ15)/32768. */

/* d*qcos 是 int32 (|d|<=64, |qcos|<=32768 → |prod|<=2^21). 把 prod/32768
 * 做 round-half-to-even, 返回最近整数。 */
static inline int rint_q15(int32_t prod)
{
    /* 商 q = prod >> 15 (向 -inf), 余数 rem = prod & 0x7FFF (0..32767). */
    int32_t q   = prod >> 15;            /* 算术右移, 向下取整 */
    int32_t rem = prod - (q << 15);      /* 0 .. 32767 */
    if (rem > 16384) {
        q += 1;                          /* > 0.5 → 进位 */
    } else if (rem == 16384) {
        if (q & 1) q += 1;               /* == 0.5 → 取偶 */
    }
    return (int)q;
}

/* Q15 cos/sin 表, 索引 = angle (0..n_slices-1)。最大 720 项。
 * 用静态缓存避免每次 pov_gen_slice 重算 (pov_gen_all 调一次填好)。 */
#define POV_MAX_SLICES 1024
static int16_t s_qcos[POV_MAX_SLICES];
static int16_t s_qsin[POV_MAX_SLICES];
static int     s_table_n = 0;

/* 用积分级数算 cos/sin 而不拉 math.h? 不: 表只算一次 (≤720), 用 math.h
 * 的 double cos/sin 量化成 Q15。裸机链接 libm 的 cos/sin (host 与板端
 * 量化结果一致, 因为都是 IEEE double)。 */
#include <math.h>
static void build_table(int n_slices)
{
    int a;
    if (s_table_n == n_slices) return;       /* 已建 */
    for (a = 0; a < n_slices && a < POV_MAX_SLICES; a++) {
        double th = 2.0 * 3.14159265358979323846 * (double)a / (double)n_slices;
        /* round(cos*32768): 这里用 round-half-away (lround) 量化表本身,
         * 与 _gen_transform_lut.py 注释 "round(cos*32768)" 一致。表的舍入
         * 不影响投影舍入语义 (投影用 rint_q15)。 */
        s_qcos[a] = (int16_t)lround(cos(th) * 32768.0);
        s_qsin[a] = (int16_t)lround(sin(th) * 32768.0);
    }
    s_table_n = n_slices;
}
#endif /* POV_FLOAT_BACKEND */

/* ───────────────────────── 切片生成 ───────────────────────── */

void pov_gen_slice(const uint8_t *vox, const int16_t *lut,
                   int angle, int n_slices, uint32_t *out)
{
    const pov_lut_t *L = (const pov_lut_t *)lut;
    int j;

#ifdef POV_FLOAT_BACKEND
    double th = 2.0 * 3.14159265358979323846 * (double)angle / (double)n_slices;
    double c  = cos(th), s = sin(th);
#else
    int32_t qc, qs;
    build_table(n_slices);
    qc = s_qcos[angle];
    qs = s_qsin[angle];
#endif

    for (j = 0; j < POV_SLICE_WORDS; j++) {
        uint32_t word = 0;
        int k;
        for (k = 0; k < 8; k++) {
            int fwi = (j << 3) + k;
            int d   = L[fwi].d;
            int wy  = L[fwi].wy;
            int wx, wz;
#ifdef POV_FLOAT_BACKEND
            proj_xz(d, c, s, &wx, &wz);
#else
            wx = clip127(rint_q15((int32_t)d * qc) + 64);
            wz = clip127(rint_q15((int32_t)d * qs) + 64);
#endif
            {
                const uint8_t *cell =
                    vox + ((((wx * POV_GRID) + wy) * POV_GRID) + wz) * 3;
                /* 阈值 on = (ch >= 128). lane bit0=G, bit1=B, bit2=R. */
                uint32_t lane = 0;
                if (cell[1] >= 128) lane |= 1u;        /* G → bit0 */
                if (cell[2] >= 128) lane |= 2u;        /* B → bit1 */
                if (cell[0] >= 128) lane |= 4u;        /* R → bit2 */
                word |= lane << (k * 3);
            }
        }
        out[j] = word;
    }
}

void pov_gen_all(const uint8_t *vox, const int16_t *lut,
                 int n_slices, uint32_t *slices)
{
    int a;
#ifndef POV_FLOAT_BACKEND
    build_table(n_slices);                  /* 一次建表 */
#endif
    for (a = 0; a < n_slices; a++) {
        pov_gen_slice(vox, lut, a, n_slices, slices + (size_t)a * POV_SLICE_WORDS);
    }
}
