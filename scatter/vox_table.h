/* vox_table.h — 体素表线上格式 "VXT1" + 板端 scatter 接口 (2026-08-05)
 *
 * ── 这一环在整条链路里的位置 ──────────────────────────────────────────────
 *   PC 采样+抗锯齿+体素化 →[体素表]→ WiFi → ARM: **scatter 进网格** → 体素网格(DDR)
 *       → pov_slice_v2 切片 → 切片(DDR) → PL 出口 → mini-LVDS → 48× ICND2260
 *
 * 🔴 板上这一步**只是 scatter, 不是 voxelize**。抗锯齿(ssaa 覆盖率)在 PC 侧已经
 * 折进体素颜色里了 (gen_anime_slices.py 的 acc/cnt 平均 + 覆盖率调暗), 板上只把
 * "占据体素表" 散写进网格 —— 不做三角形采样, 不做覆盖率统计, 信息一点不丢。
 *
 * ── 为什么是"排序 + delta + varint"这个格式 (三个约束同时满足) ─────────────
 *
 * ① **排序是免费的, 而且是三件好事的共同前提**。PC 侧体素化天然产出的就是
 *    np.nonzero() 的升序索引, 一分钱不花。而升序换来:
 *      a) delta 恒 ≥ 1 ⇒ 可编码成小整数 (实测索引 1.02-1.11 B/格, 原始 4 B)
 *      b) 板端写网格的地址**单调递增** ⇒ 散写退化成"带洞的顺序写",
 *         DDR 行命中率高、cache 行不会来回颠簸 (随机散写会)
 *      c) 上一帧的索引表也是升序 ⇒ **清理与写入可以归并成一趟**(见 ③)
 *    ⇒ 排序不是为了压缩比才做的, 是为了**板端**才做的; 压缩比是顺带的。
 *
 * ② **两个平面分开放 (颜色平面 / 索引平面), 不交错**。交错的 6 B 记录里
 *    u32 索引的高位字节几乎恒为 0、颜色字节高熵, 混在一起会把通用压缩器的
 *    上下文打乱。分平面后颜色平面自己内部重复度极高 (同一表面同一色块),
 *    lz4/zlib 能真正吃到。实测差异见 scatter/README.md 的压缩表。
 *
 * ③ **索引升序 ⇒ delta ≥ 1 ⇒ 编码 (delta-1) 是无符号小整数**, LEB128 varint
 *    一字节覆盖 delta ≤ 128。满屏模型 15 万格 / 796 万格 = 1.9% 占据,
 *    平均 delta ≈ 53 ⇒ 绝大多数是 1 字节。
 *    🔴 副作用(白拿的): **解出来的索引必然严格递增**, 板端不需要额外校验单调性,
 *    只需最后一个索引 < 网格格数 —— 一次比较就完成全部边界检查。
 *
 * ── 与 PVS1 的关系: **正交**, 不是新协议 ──────────────────────────────────
 *   hdr.flags |= PVS_FLAG_VOXTAB (1u<<8)   ← bit 0-7 已被 RLE/ZLIB/DELTA/
 *                                            DUAL_FACE/FOLD_A/LZ4/MSTREAM/3BIT 占用
 *     🔴 2026-10-10 改: 原定 bit 7, 但 08-20 的 3-bit 色深 (PVS_FLAG_3BIT) 先占了
 *        bit 7 ⇒ 撞位 (板端会把体素表当 3-bit 切片帧按 0x9000 片距解)。挪到 bit 8。
 *   hdr.n_slices = 0                       ← 本帧不含切片
 *   hdr.raw_len  = VXT1 体的字节数 (解压后)
 *   hdr.comp_len = 线上载荷字节数
 *
 * 压缩位 (LZ4 / ZLIB / MSTREAM) **语义完全不变** —— 它们说的是"载荷怎么解压",
 * VOXTAB 说的是"解压出来的东西怎么解释"。所以接收端只需在解压之后多一个分支,
 * 解压路径一行都不用改。MSTREAM 也照样能用来把 VXT1 体切两条流喂双核。
 *
 * 🔴 三个非法组合 (必须 NAK, 不能静默跑):
 *   · VOXTAB | DELTA      —— DELTA 是"与上一帧 raw 逐字节 XOR", 而 VXT1 体是
 *                            **变长**的, 逐字节 XOR 根本无定义。帧间冗余由
 *                            VXT_FLAG_KEY/增量清理那套机制吃掉, 不走 DELTA。
 *   · VOXTAB | DUAL_FACE  —— 两个 DDR 切片基址是切片流的概念; 体素网格只有一份,
 *                            两个面共用同一个网格 (切片器按 axis_off 各切各的)。
 *   · VOXTAB | FOLD_A     —— 同上, 折叠是切片编号上的对称性, 与体素表无关。
 *   · VOXTAB | 3BIT       —— 3BIT 是切片位平面的片距; 体素表颜色恒为 RGB565。
 *
 * ── 网格布局: 与 pov_slice_v2.h 严格一致 ─────────────────────────────────
 *   idx = (vz * PV2_VOX_XZ + vx) * PV2_VOX_Y + vy      (y 最内维)
 * 🔴 **y 轴与面板行号同向 (自上而下)**。切片器对 y 直拷不翻转 —— 翻转会破坏
 * 连续突发, 整个性能优势就没了。而 gen_anime_slices.py 用 `gy=(H-1)-arange(H)`
 * 读体素 (体素 y 向上), ⇒ **发送端体素化后必须写 vy = (Y-1) - gy**, 否则成像
 * 上下颠倒。这条约定在 gen_voxtab.py 里落实, 并由
 * check_slice_ref.py 拿 gen_anime_slices.py 的读法独立重算、逐字节验证
 * (只比"网格逐字节相同" **查不出** y 翻转错 —— 黄金网格和被测网格出自同一个
 * 工具, 会一起错)。
 */
#ifndef VOX_TABLE_H
#define VOX_TABLE_H

#include <stddef.h>
#include <stdint.h>

#include "../hls_proj/pov_slice_v2.h"     /* PV2_VOX_XZ / PV2_VOX_Y / 布局约定 */

#ifdef __cplusplus
extern "C" {
#endif

/* PVS1 flags 扩展位 (bit 0-7 见 mlkpai_fs03/stream/protocol.h; 本位已同步进那里) */
#ifndef PVS_FLAG_VOXTAB
#define PVS_FLAG_VOXTAB   (1u << 8)
#endif

#define VXT_MAGIC         "VXT1"
#define VXT_MAGIC_U32     0x31545856u          /* 'V','X','T','1' 按 LE u32 读 */
#define VXT_HDR_BYTES     24

/* 网格格数 / 字节数 (编译期由 pov_slice_v2.h 的配置决定) */
#define VXT_CELLS         ((uint32_t)PV2_VOX_XZ * PV2_VOX_XZ * PV2_VOX_Y)
#define VXT_GRID_BYTES    ((size_t)VXT_CELLS * 2u)

/* VXT1 体头部 flags */
#define VXT_FLAG_KEY      (1u << 0)  /* 关键帧: 接收端**必须**先整块清网格再 scatter。
                                      * 增量清理依赖"接收端手里的上一帧索引表 == 网格
                                      * 当前的脏格集合"这个不变式; 连接建立、丢帧、
                                      * 网格尺寸变更之后这个不变式不成立, 只能整清。
                                      * 首帧必须置位。 */

#pragma pack(push, 1)
typedef struct {
    char     magic[4];     /* "VXT1" */
    uint16_t grid_xz;      /* = PV2_VOX_XZ, 接收端必须核对 */
    uint16_t grid_y;       /* = PV2_VOX_Y */
    uint32_t n_vox;        /* 占据体素数 */
    uint32_t idx_bytes;    /* 索引平面字节数 (varint 流, 变长) */
    uint16_t flags;        /* VXT_FLAG_* */
    uint16_t seq;          /* 内容帧序号, 只用于丢帧诊断 (接收端可忽略) */
    uint32_t rsvd;         /* 0 */
} vxt_hdr_t;               /* 24 B */
#pragma pack(pop)

/* VXT1 体排布 (紧凑, 无对齐填充):
 *   [0]                    vxt_hdr_t                       24 B
 *   [24]                   颜色平面 n_vox × u16 RGB565 LE  2*n_vox B
 *   [24 + 2*n_vox]         索引平面 varint(delta-1) 流      idx_bytes B
 *   总长 = 24 + 2*n_vox + idx_bytes  ( == hdr.raw_len )
 *
 * 🔴 颜色平面放**前面**是为了对齐: 头 24 B 是 2 的倍数 ⇒ 颜色平面天然 2 字节
 * 对齐, 板端可以直接当 uint16_t* 用。反过来 (索引在前) 时 idx_bytes 变长,
 * 颜色平面会随机落在奇地址上 —— A9 上未对齐 u16 访问要么慢要么直接 abort。
 *
 * 索引平面 varint: 逐个编码 (idx[k] - idx[k-1] - 1), 约定 idx[-1] = -1
 * (于是首个编码的就是 idx[0] 本身)。LEB128: 低 7 位一组, 最高位 1 = 还有后续。
 */

/* ── 板端 scatter 状态 ───────────────────────────────────────────────────
 * 调用方负责分配。三块内存:
 *   grid  : 体素网格本体 (DDR), VXT_GRID_BYTES
 *   idx[2]: 索引表双缓冲, 各 cap × 4 B —— 一份是"网格当前脏格集合"(上一帧),
 *           一份是本帧解出来的。scatter 完毕后交换。
 * 🔴 为什么要留上一帧的索引表: 清网格**绝不能整块 memset**。
 *   A9 上 memset 15.9 MB ≈ 34 ms (按板上实测 442 MB/s),
 *   15 fps 内容就吃掉半个预算。
 *   ⚠ 便宜多少倍要按 **cache 行**算, 不是按字节: 一次 2 B 散写在 A9 上是
 *   32 B 读 + 32 B 回写。实测 21.5 万格摸到 72,691 条行 (2.96 格/行)
 *   ⇒ 增量 4.44 MB/帧 vs 整清 34.8 MB/帧 = **省 7.8×** (不同载荷 6.5-64×)。
 *   会话里的 "265 倍" 是按 300 KB vs 15.9 MB 算的, 偏乐观一个数量级。 */
typedef struct {
    uint16_t *grid;
    uint32_t *idx[2];      /* idx[cur] = 本帧; idx[cur^1] = 上一帧(= 网格脏格) */
    uint32_t  n_idx[2];
    uint32_t  cap;         /* 每个索引缓冲能装几个 (建议 ≥ 300000) */
    int       cur;
    int       primed;      /* 0 = 网格内容未知, 下一帧强制整清 */
} vox_scatter_t;

typedef struct {
    uint32_t n_vox;        /* 本帧占据体素数 */
    uint32_t n_clear;      /* 真正被清掉的格数 (上一帧有、本帧没有) */
    uint32_t n_keep;       /* 两帧都占据、直接覆写的格数 (省掉的清理) */
    uint32_t n_new;        /* 上一帧没有、本帧新增的格数 */
    int      full_clear;   /* 本帧是否做了整块清理 */
} vox_stats_t;

/* 返回码 */
#define VXT_OK             0
#define VXT_E_SHORT       -1   /* 体长度不足 / 与头部不自洽 */
#define VXT_E_MAGIC       -2
#define VXT_E_GEOM        -3   /* grid_xz/grid_y 与编译期配置不符 */
#define VXT_E_CAP         -4   /* n_vox 超过索引缓冲容量 */
#define VXT_E_RANGE       -5   /* 索引越界 (> 网格格数) */
#define VXT_E_TRUNC       -6   /* varint 流在 n_vox 个值之前就用完了 */

/* 初始化 (只置状态, 不分配内存)。grid/idx/cap 由调用方填好后传进来。 */
void vox_scatter_init(vox_scatter_t *s, uint16_t *grid,
                      uint32_t *idx_a, uint32_t *idx_b, uint32_t cap);

/* 把一个 VXT1 体应用到网格上。body/len 是**解压后**的字节。
 * 成功返回 VXT_OK 并更新双缓冲; 失败时网格保持未定义 (调用方应下一帧要关键帧)。*/
int vox_scatter_apply(vox_scatter_t *s, const void *body, size_t len,
                      vox_stats_t *st);

/* 只解索引不碰网格 (计时拆解 / 将来 scatter 挪 PL 时 ARM 仍要做的那一半)。
 * 返回个数, 或负的 VXT_E_*。 */
int vox_decode_indices(const void *body, size_t len, uint32_t *out, uint32_t cap);

/* 强制下一帧整块清理 (丢帧/重连后调用) */
void vox_scatter_desync(vox_scatter_t *s);

#ifdef __cplusplus
}
#endif
#endif /* VOX_TABLE_H */
