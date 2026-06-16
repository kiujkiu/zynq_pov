/* pov_proj.h - PL HLS point-cloud/voxel -> POV compact slice projection IP
 *
 * Target: Zynq-7020 (xc7z020clg484-2). 让 PL 实时把场景渲染成 POV compact
 * 切片写 DDR, 由 hub75e_panel_seq_v8.v DMA 读出驱动 LED panel.
 *
 * 选定架构 = B (voxel gather via static transform LUT). 见 DESIGN_hls.md.
 *
 * 数据流 (与已验证 PC 管线 bit-exact):
 *   输入 DDR:
 *     - voxel grid: 128^3 个 voxel_t (RGB 1-byte/通道 + pad), 由 ARM 从点云
 *       体素化 (或直接 host 算好). 索引 idx = (wx*128 + wy)*128 + wz.
 *     - transform LUT: 16384 个 lut_t (int16 d, int16 wy), tools/transform_lut.bin
 *       原样灌进 DDR. fwi (full-word-index) 0..16383.
 *   每角度 (slice s, angle θ = 2π·s/n_slices):
 *     for fwi in 0..16383:
 *        d  = LUT[fwi].d ;  wy = LUT[fwi].wy
 *        wx = clamp(round(d·cosθ) + 64, 0, 127)
 *        wz = clamp(round(d·sinθ) + 64, 0, 127)
 *        rgb = voxel[wx][wy][wz]
 *        on  = (rgb 各通道 >= 128)  -> Gb/Rb/Bb 三个 1-bit
 *        lane = Gb | (Bb<<1) | (Rb<<2)        (lane bit0=G,bit1=B,bit2=R)
 *        word_idx = fwi >> 3 ;  k = fwi & 7
 *        compact_word[word_idx] |= lane << (k*3)
 *   输出 DDR: compact slice = 2048 uint32 (8 KB) @ SLICE_BASE + s*0x2000.
 *
 * 与 _gen_transform_lut.py 的 slice_via_lut() 完全等价 (那段已自验证 == PC 管线).
 */
#ifndef POV_PROJ_H
#define POV_PROJ_H

#include <stdint.h>

#define VOXEL_RES    128          /* 128^3 grid */
#define VOXEL_HALF   64
#define FWI_COUNT    16384        /* full-word-index 数 = 一片像素数 (128x128) */
#define COMPACT_WORDS 2048        /* 每片 compact word 数 = FWI_COUNT/8 */
#define COMPACT_BYTES 8192        /* 每片字节 = 0x2000 */
#define MAX_SLICES   720          /* 终极 720 片 */
#define COS_TABLE_N  720          /* cos/sin LUT 分辨率 (Q15) */

/* DDR voxel cell. host 写 r,g,b (每通道 8-bit), pad 对齐 4-byte.
 * "on" 判定 = 通道 >= 128, 所以 host 可以直接放 0 或 255 (或真彩, 阈值在 IP 内). */
struct voxel_t {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t _pad;
};   /* sizeof = 4. 128^3 * 4 = 8 MB grid in DDR. */

/* transform LUT entry (= tools/transform_lut.bin 一行). */
struct lut_t {
    int16_t d;     /* col - 64,  范围 [-64, 63] */
    int16_t wy;    /* 127 - row, 范围 [0, 127] */
};   /* sizeof = 4 */

/* ------------------------------------------------------------------ *
 * Top function: 一次 ap_start 渲染 [slot_start, slot_start+n_slots) 片.
 *
 *   voxel_grid : m_axi gmem0  读 128^3 voxel_t (8 MB)
 *   lut        : m_axi gmem0  读 16384 lut_t (64 KB) — 同 bundle, 开头载 BRAM
 *   slice_base : m_axi gmem1  写 compact 切片 (DDR 0x18000000)
 *   n_total    : 总片数 (角度归一化用, 720)
 *   slot_start : 起始片 (4-IP 并行: IP_i 从 i*ceil(n_total/4) 起)
 *   n_slots    : 本次渲染片数
 *
 * slice s 的 DDR 字节地址 = slice_base + s*COMPACT_BYTES.
 * angle θ = 2π·s / n_total.  cos/sin 用内置 Q15 LUT (COS_TABLE_N=720), 若
 * n_total != 720 则用 angle_idx = s * COS_TABLE_N / n_total 取近似 (n_total=720
 * 时精确).
 * ------------------------------------------------------------------ */
void pov_proj(
    const struct voxel_t *voxel_grid,
    const struct lut_t   *lut,
    uint32_t             *slice_base,
    int                   n_total,
    int                   slot_start,
    int                   n_slots
);

#endif /* POV_PROJ_H */
