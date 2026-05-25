/* panel_seq.h - PL-side ICND1069 timing IP helpers.
 *
 * IP base: 0x40010000 (Vivado BD 自动分配, sdt 没生成 xparameters 因 module
 * ref 不被认, 这里硬编). 单寄存器 0x00:
 *   W: [15:0] data, [20:16] le_count, [24] mode (0=word/1=marker)
 *   R: [0] busy
 */

#ifndef PANEL_SEQ_H
#define PANEL_SEQ_H

#include "xil_io.h"
#include "xil_types.h"

#define PANEL_SEQ_BASE  0x40010000UL
#define PANEL_SEQ_CMD   0x00
#define PANEL_SEQ_BURST 0x04

static inline void panel_seq_wait_idle(void) {
    while (Xil_In32(PANEL_SEQ_BASE + PANEL_SEQ_CMD) & 1u) ;
}

/* Burst: PL 自己重发 next CMD 共 (n_extra + 1) 次, 消除 ARM AXI 抖动.
 * 例: panel_seq_burst_word(0xFFFF, 1, 191) → 192 个等间距 LE=1 latch. */
static inline void panel_seq_burst_word(u16 data, u8 le_count, u16 n_extra) {
    panel_seq_wait_idle();
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_BURST, n_extra);
    u32 cmd = ((u32)(le_count & 0x1Fu) << 16) | data;
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* Word mode: 16 DCLK shifts of `data` (MSB first, broadcast 9 chains),
 * LE 高在最后 `le_count` 个 DCLK. le_count 1=DATA_LATCH, 5=WR_CFG, 7=RD_CFG.
 * 阻塞直到上一条 cmd 完成. */
static inline void panel_seq_word(u16 data, u8 le_count) {
    panel_seq_wait_idle();
    u32 cmd = ((u32)(le_count & 0x1Fu) << 16) | data;
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* Marker mode: 仅 `le_count` 个 DCLK, LE 一直高, SDI=0. */
static inline void panel_seq_marker(u8 le_count) {
    panel_seq_wait_idle();
    u32 cmd = (1u << 24) | ((u32)(le_count & 0x1Fu) << 16);
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* Row marker mode: 仅 `n_dclks` 个 DCLK, ROW 一直高, LE=0, SDI=0.
 * 用于 ICND1069 ROW=12 第一行 marker 或 ROW=4 next-row marker.
 * 比 ARM bit-bang 精确 (PL 计数 DCLK), chip 严格解码 ROW 宽度. */
static inline void panel_seq_row_pulse(u8 n_dclks) {
    panel_seq_wait_idle();
    u32 cmd = (2u << 24) | ((u32)(n_dclks & 0x1Fu) << 16);
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* DCLK keepalive: 用 burst word mode + LE=0, PL 连续 DCLK 不停, PLL 锁不掉.
 * burst 上限 16-bit = 65535+1 extras × 16 DCLK ≈ 1M DCLK 一次, 够用. */
static inline void panel_seq_dclk_keepalive(int n_dclks) {
    int batches = (n_dclks + 15) / 16;
    if (batches <= 0) return;
    if (batches > 65536) batches = 65536;
    panel_seq_burst_word(0, 0, (u16)(batches - 1));
}

#endif
