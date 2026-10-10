/* vox_scatter.c — VXT1 体素表 → 体素网格 scatter (板端/ARM, 纯 C99, 无依赖)
 * 格式与设计理由见 vox_table.h。
 *
 * ── 全部性能都来自一件事: 索引升序 ──────────────────────────────────────
 * 本文件的核心是**一趟单调递增的归并**, 把"清上一帧"和"写本帧"合成一个循环:
 *
 *     上一帧脏格 prev[] (升序)  ──┐
 *                                 ├─→ 一趟 ascending pass over grid[]
 *     本帧索引   cur[]  (升序)  ──┘
 *
 *     prev 独有  → grid[i] = 0        (清)
 *     两边都有   → grid[i] = color    (直接覆写, **清都不用清**)
 *     cur  独有  → grid[i] = color    (写)
 *
 * 三个好处, 都是实打实的:
 *   ① 网格地址全程单调递增 ⇒ DDR 行命中率高、cache 行只被摸一次;
 *      随机散写会把同一条 cache 行来回换进换出。
 *   ② 帧间重叠直接变成省下来的清理: 2°/帧 旋转实测覆写占比 globe 40% /
 *      1bit 配置 56% / anime 8% (细瘦模型转起来重叠少)。"两边都有"那一支
 *      **一次写干清+写两件事**。
 *   ③ 绝不整块 memset: 15.9 MB × 15 Hz(内容帧) 在 A9 上就是 ~34 ms/帧,
 *      占满半个预算。实测 DDR 流量口径下增量清理省 **6.5-64×** (见 README.md)
 *      —— 不是会话里说的 265×, 那个数按字节算, 忽略了散写的粒度是 cache 行。
 *
 * 🔴 唯一需要整清的时刻: 关键帧 / 未 primed (刚上电、丢过帧、上一帧 apply 失败)。
 * 因为增量清理依赖不变式 "prev[] == 网格当前非零格集合", 该不变式一旦破了,
 * 残留的脏格就永远清不掉 —— 会表现为"模型拖着上一姿态的残影", 而且不会自愈。
 */
#include "vox_table.h"

#include <string.h>

void vox_scatter_init(vox_scatter_t *s, uint16_t *grid,
                      uint32_t *idx_a, uint32_t *idx_b, uint32_t cap)
{
    s->grid   = grid;
    s->idx[0] = idx_a;
    s->idx[1] = idx_b;
    s->n_idx[0] = 0;
    s->n_idx[1] = 0;
    s->cap    = cap;
    s->cur    = 0;
    s->primed = 0;          /* 网格内容未知 → 首帧强制整清 */
}

void vox_scatter_desync(vox_scatter_t *s)
{
    s->primed = 0;
}

int vox_scatter_apply(vox_scatter_t *s, const void *body, size_t len,
                      vox_stats_t *st)
{
    const uint8_t *b = (const uint8_t *)body;

    if (len < VXT_HDR_BYTES) return VXT_E_SHORT;

    vxt_hdr_t h;
    memcpy(&h, b, sizeof h);            /* 头部走 memcpy, 不假设 body 对齐 */
    if (memcmp(h.magic, VXT_MAGIC, 4) != 0)          return VXT_E_MAGIC;
    if (h.grid_xz != PV2_VOX_XZ || h.grid_y != PV2_VOX_Y) return VXT_E_GEOM;
    if (h.n_vox > s->cap)                            return VXT_E_CAP;
    if (len != (size_t)VXT_HDR_BYTES + 2u * (size_t)h.n_vox + (size_t)h.idx_bytes)
        return VXT_E_SHORT;

    /* 颜色平面在头之后, 头长 24 B (偶数) ⇒ 只要 body 本身 2 字节对齐, 这里就对齐。
     * 接收缓冲一律按 4 字节对齐分配 (lz4/zlib 的输出缓冲本来就是 malloc 的)。 */
    const uint16_t *col = (const uint16_t *)(const void *)(b + VXT_HDR_BYTES);
    const uint8_t  *vp  = b + VXT_HDR_BYTES + 2u * (size_t)h.n_vox;
    const uint8_t  *ve  = vp + h.idx_bytes;

    uint16_t *grid = s->grid;
    uint32_t *cur  = s->idx[s->cur ^ 1];
    const uint32_t *p  = s->idx[s->cur];
    const uint32_t *pe = p + s->n_idx[s->cur];

    const int full = (h.flags & VXT_FLAG_KEY) || !s->primed;
    if (full) {
        memset(grid, 0, VXT_GRID_BYTES);
        p = pe = NULL;                   /* 上一帧脏格已经被整清吃掉 */
    }

    uint32_t idx = (uint32_t)-1;         /* 约定 idx[-1] = -1 ⇒ 首个 delta-1 = idx[0] */
    uint32_t n_clear = 0, n_keep = 0, n_new = 0;
    const uint32_t n = h.n_vox;

    for (uint32_t k = 0; k < n; k++) {
        /* ---- LEB128 解一个 (delta-1) ---- */
        uint32_t d = 0, sh = 0, byte;
        do {
            if (vp >= ve)   return VXT_E_TRUNC;
            if (sh > 28)    return VXT_E_RANGE;   /* 索引 < 2^23, 4 字节封顶 */
            byte = *vp++;
            d |= (uint32_t)(byte & 0x7Fu) << sh;
            sh += 7;
        } while (byte & 0x80u);

        idx += d + 1u;                   /* 🔴 恒增 ⇒ 单调性天然成立, 无需校验 */
        if (idx >= VXT_CELLS) return VXT_E_RANGE;   /* 越界一次比较搞定 */

        /* ---- 归并: 清掉所有落在 idx 之前的旧脏格 ---- */
        while (p < pe && *p < idx) { grid[*p++] = 0; n_clear++; }
        if (p < pe && *p == idx) { p++; n_keep++; }   /* 覆写即清理, 白赚 */
        else                       n_new++;

        grid[idx] = col[k];
        cur[k] = idx;
    }
    while (p < pe) { grid[*p++] = 0; n_clear++; }     /* 旧表尾巴 */

    /* varint 流必须**恰好**用完 —— 多一字节少一字节都说明载荷错位了。
     * 这是个白拿的完整性校验: 错位会当场报错, 而不是画出一团几何正确的垃圾。 */
    if (vp != ve) return VXT_E_SHORT;

    s->n_idx[s->cur ^ 1] = n;
    s->cur ^= 1;
    s->primed = 1;

    if (st) {
        st->n_vox   = n;
        st->n_clear = n_clear;
        st->n_keep  = n_keep;
        st->n_new   = n_new;
        st->full_clear = full;
    }
    return VXT_OK;
}

/* ── 只解索引, 不碰网格 ──────────────────────────────────────────────────
 * 用途有两个:
 *   · 计时时把"varint 解码 (纯计算, 吃 CPU)"与"散写网格 (吃 DDR 带宽)"分开量,
 *     这两项在 A9 上的瓶颈完全不同, 混在一起量不出该优化谁;
 *   · 如果将来把 scatter 挪到 PL, ARM 仍需把索引解出来喂给 IP —— 这就是那一半。
 * 返回解出的个数, 出错返回负的 VXT_E_*。*/
int vox_decode_indices(const void *body, size_t len, uint32_t *out, uint32_t cap)
{
    const uint8_t *b = (const uint8_t *)body;
    if (len < VXT_HDR_BYTES) return VXT_E_SHORT;
    vxt_hdr_t h;
    memcpy(&h, b, sizeof h);
    if (memcmp(h.magic, VXT_MAGIC, 4) != 0) return VXT_E_MAGIC;
    if (h.n_vox > cap) return VXT_E_CAP;
    const uint8_t *vp = b + VXT_HDR_BYTES + 2u * (size_t)h.n_vox;
    const uint8_t *ve = vp + h.idx_bytes;
    uint32_t idx = (uint32_t)-1;
    for (uint32_t k = 0; k < h.n_vox; k++) {
        uint32_t d = 0, sh = 0, byte;
        do {
            if (vp >= ve) return VXT_E_TRUNC;
            if (sh > 28)  return VXT_E_RANGE;
            byte = *vp++;
            d |= (uint32_t)(byte & 0x7Fu) << sh;
            sh += 7;
        } while (byte & 0x80u);
        idx += d + 1u;
        if (idx >= VXT_CELLS) return VXT_E_RANGE;
        out[k] = idx;
    }
    return (int)h.n_vox;
}
