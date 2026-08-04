/* pov_slice_v2.h — ICND2260 双面 POV 体素切片器 (2026-08-04)
 *
 * 取代 pov_project_batch: 那个版本单 IP 占 66% BRAM (local_model[32768]×16B = 512KB),
 * 4 路并行物理不可能; 且每片有 89,050 cycle 与点数无关的清屏/回写固定开销。
 * 详见 memory project_pov3d_hls_slicer_arch。
 *
 * ── 核心结构 ────────────────────────────────────────────────────────────
 * 关键几何事实: **y 轴不参与旋转**。面板第 px 列的 216 个像素, 全部来自体素网格里
 * 同一根"柱子" (vx,vz) 的连续 y。所以一列 = 一次 PV2_PANEL_H 个元素的连续拷贝。
 *
 * 再把 slot 也存成**列优先** slot[px][py] —— 这恰好就是面板要的顺序
 * (ICND2260 一个扫描行 = 4 个 zone 各取一列的全部 216 行), 于是读写两端同时连续:
 *
 *      voxel[(vz*XZ + vx)*Y + vy]   vy 连续  →  432 B 突发读
 *      slot [ px*Y + py]            py 连续  →  432 B 突发写
 *
 * 每片 = 192 列 × 216 元素 = 41,472 次拷贝; 64-bit widen 后 4 元素/拍
 * ⇒ ~10,368 cycle/片 = 69 µs @150MHz。目标 73.7 µs/片 ⇒ **单 IP 即达标**。
 *
 * ── 偏心面 ──────────────────────────────────────────────────────────────
 * v3.1 是偏心双面: 面A 穿心 (axis_off=0), 面B 垂距 13.4mm。世界坐标同 gen_anime_slices.py:
 *      world = u·û(θ) + axis_off·n̂(θ),  û=(cos,sin), n̂=(-sin,cos)
 * 偏移只改每列的 (vx,vz), 不改"一列 = 一根连续柱子"这个结构。
 *
 * ── 像素格式 ────────────────────────────────────────────────────────────
 * 体素与切片都是 RGB565 (2 B/px)。切片器是**纯搬运, 零转换**。
 * 展开成 ICND2260 线上的 16-bit/通道由 PL 出口做 (左移对齐, 几十个 LUT)。
 * DDR 代价: 82,944 B/片 × 13,575 片/s = 1.13 GB/s 单向, 双向 2.25 GB/s
 * (对比 8-8-8 的 3.38 GB/s, PS DDR3 峰值 4.26)。
 */
#ifndef POV_SLICE_V2_H
#define POV_SLICE_V2_H

#include <stdint.h>

/* ── 面板几何 (150 × 168.75 mm, 像素间距 0.78125 mm) ── */
#define PV2_PANEL_W    192          /* 沿半径 (整直径) */
#define PV2_PANEL_H    216          /* 沿高度 */

/* ── 体素网格: xz 平面 192×192, y 216。**y 是最内维** ──
 * idx = (vz * PV2_VOX_XZ + vx) * PV2_VOX_Y + vy
 * 大小 = 192×192×216×2 B = 15.9 MB */
#define PV2_VOX_XZ     192
#define PV2_VOX_Y      216
#define PV2_VOX_HALF   96           /* PV2_VOX_XZ / 2 */

/* 面板列 px → 半径坐标 u = px - PV2_CX */
#define PV2_CX         96           /* PV2_PANEL_W / 2 */

/* 每片尺寸 (列优先, RGB565) */
#define PV2_SLOT_ELEMS (PV2_PANEL_W * PV2_PANEL_H)      /* 41,472 元素 */
#define PV2_SLOT_BYTES (PV2_SLOT_ELEMS * 2)             /* 82,944 B */

/* 🔴 m_axi 端口按 64 位声明 (不指望自动 widen, 见 .cpp 注释)。
 * PV2_VOX_Y=216 恰好被 4 整除 ⇒ 一列 = 54 拍, 无余数无对齐问题。 */
#define PV2_COL_BEATS  (PV2_VOX_Y / 4)                  /* 54 */
#define PV2_SLOT_BEATS (PV2_SLOT_ELEMS / 4)             /* 10,368 */

/* 切一批片。4 路并行时各 IP 分不同的 (slot_start, n_slots)。
 *
 *   voxel      : m_axi bundle=vox — (z,x,y) 布局 RGB565 体素网格
 *   slot_base  : m_axi bundle=out — 环形缓冲基址, 第 g 片 = slot_base + g*PV2_SLOT_ELEMS
 *   phase      : 第 0 片的角度索引 (0..602)
 *   slot_start : 本 IP 负责的起始片号 (全局)
 *   n_slots    : 本 IP 负责的片数
 *   axis_off_q8: 该面到转轴的垂距, Q8 定点 (像素<<8)。穿心面 = 0,
 *                v3.1 面B = 13.4mm / 0.78125 = 17.152 px → 4391
 *   mirror_u   : 非 0 则 u 取反 (屏 X 轴物理方向与 û(θ) 相反, 见 gen_anime_slices.py)
 */
void pov_slice_v2(
    const uint64_t *voxel,        /* 按 64 位取, 4 个 RGB565/拍 */
    uint64_t *slot_base,
    int phase,
    int slot_start,
    int n_slots,
    int axis_off_q8,
    int mirror_u
);

#endif
