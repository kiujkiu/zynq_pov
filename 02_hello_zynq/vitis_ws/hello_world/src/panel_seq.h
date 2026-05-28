/* panel_seq.h - PL-side ICND1069 timing IP helpers.
 *
 * IP base: 0x40010000 (Vivado BD 自动分配, sdt 没生成 xparameters 因 module
 * ref 不被认, 这里硬编). 单寄存器 0x00:
 *   W: [15:0] data, [22:16] count (0..127), [25:24] mode (00=word/01=marker_LE/10=marker_ROW)
 *   R: [0] busy (processing or queued), [1] cmd_pending (queue full)
 *
 * V2 (2026-05-27): free-running DCLK 12.5MHz 50% + 1 槽 cmd queue → ARM 可在
 * PL 处理当前命令时就预先写下一条, PL chain 0 间隙, 匹配官方背靠背 WR_CFG.
 */

#ifndef PANEL_SEQ_H
#define PANEL_SEQ_H

#include "xil_io.h"
#include "xil_types.h"

#define PANEL_SEQ_BASE      0x40010000UL
#define PANEL_SEQ_CMD       0x00
#define PANEL_SEQ_BURST     0x04
#define PANEL_SEQ_ICND      0x08   /* ICND3019 cmd: bit[31]=type (0=adv,1=cfg), bit[0]=SDI, bit[3:0]=reg */
#define PANEL_SEQ_SDI_MASK  0x0C   /* 9-bit per-chain SDI enable mask, default 0x1FF */

#define PANEL_SEQ_ST_BUSY      0x1u
#define PANEL_SEQ_ST_PENDING   0x2u
#define PANEL_SEQ_ST_ICND_BUSY 0x4u

/* 等待 PL 完全 drain (没 active, 没 queued). 用于序列收尾, 不用于 enqueue. */
static inline void panel_seq_wait_idle(void) {
    while (Xil_In32(PANEL_SEQ_BASE + PANEL_SEQ_CMD) & PANEL_SEQ_ST_BUSY) ;
}

/* 等 queue 槽空 (cmd_pending=0), 就可写下一条 cmd. PL 在 active cmd
 * bits_left==1 那拍把 pending chain 进来, 0 间隙. */
static inline void panel_seq_wait_can_accept(void) {
    while (Xil_In32(PANEL_SEQ_BASE + PANEL_SEQ_CMD) & PANEL_SEQ_ST_PENDING) ;
}

/* Burst: PL 自己重发 next CMD 共 (n_extra + 1) 次, 消除 ARM AXI 抖动.
 * 例: panel_seq_burst_word(0xFFFF, 1, 191) → 192 个等间距 LE=1 latch. */
static inline void panel_seq_burst_word(u16 data, u8 le_count, u16 n_extra) {
    panel_seq_wait_can_accept();
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_BURST, n_extra);
    u32 cmd = ((u32)(le_count & 0x7Fu) << 16) | data;
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* Word mode: 16 DCLK shifts of `data` (MSB first, broadcast 9 chains),
 * LE 高在最后 `le_count` 个 DCLK. le_count 1=DATA_LATCH, 5=WR_CFG, 7=RD_CFG.
 * 等 queue 槽空就写, PL chain 0 间隙. */
static inline void panel_seq_word(u16 data, u8 le_count) {
    panel_seq_wait_can_accept();
    u32 cmd = ((u32)(le_count & 0x7Fu) << 16) | data;
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* Marker mode: 仅 `le_count` 个 DCLK, LE 一直高, SDI=0. */
static inline void panel_seq_marker(u8 le_count) {
    panel_seq_wait_can_accept();
    u32 cmd = (1u << 24) | ((u32)(le_count & 0x7Fu) << 16);
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* Row marker mode: 仅 `n_dclks` 个 DCLK (0..127), ROW 一直高, LE=0, SDI=0. */
static inline void panel_seq_row_pulse(u8 n_dclks) {
    panel_seq_wait_can_accept();
    u32 cmd = (2u << 24) | ((u32)(n_dclks & 0x7Fu) << 16);
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* DCLK keepalive: free-running DCLK 后理论上不需要, 留作 no-op 安全保留. */
static inline void panel_seq_dclk_keepalive(int n_dclks) {
    (void)n_dclks;   /* DCLK 永远跑, no-op */
}

/* SDI 9-bit per-chain mask. 1 = chain enabled, 0 = chain forced 0.
 * bit[0]=R1, [1]=G1, [2]=B1, [3]=R2, [4]=G2, [5]=B2, [6]=R3, [7]=G3, [8]=B3
 * 例: 0x049 = R-only, 0x092 = G-only, 0x124 = B-only, 0x1FF = all (white) */
static inline void panel_seq_set_sdi_mask(u32 mask) {
    /* wdata[31:30]=00 → write sdi_mask */
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_SDI_MASK, mask & 0x1FFu);
}

/* 写 per-chain data buffer (chain idx 0-8, 16-bit value).
 * 2026-05-28 v3: 配合 panel_seq_word_perchain() 实现任意 per-pixel 色. */
static inline void panel_seq_set_chain_data(u8 chain, u16 data) {
    /* wdata[31:30]=01 → write chain_data[idx], idx in [19:16], data in [15:0] */
    u32 w = 0x40000000u | ((u32)(chain & 0xFu) << 16) | data;
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_SDI_MASK, w);
}

/* per-chain word mode: 用 chain_data[0..8] buffer 各自 shift 16 DCLK,
 * 最后 le_count 个 DCLK 拉高 LE. 调用前先用 panel_seq_set_chain_data(N, ...) 设 9 chain. */
static inline void panel_seq_word_perchain(u8 le_count) {
    panel_seq_wait_can_accept();
    /* mode = 2'b11 (per-chain word), data field unused */
    u32 cmd = (3u << 24) | ((u32)(le_count & 0x7Fu) << 16);
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_CMD, cmd);
}

/* ICND3019 helpers ----------------------------------------------------------- */

/* 等 ICND3019 FSM 空闲（advance 或 config 完成）. */
static inline void panel_seq_icnd_wait_idle(void) {
    while (Xil_In32(PANEL_SEQ_BASE + PANEL_SEQ_CMD) & PANEL_SEQ_ST_ICND_BUSY) ;
}

/* ICND3019 advance row: 1 DCLK 脉冲, SDI = sdi_bit.
 * sdi_bit=1 → 该行 LINE[N] 输出 LOW (通道打开, LED ON, 共阴扫描).
 * sdi_bit=0 → 该行 LINE[N] 输出 HIGH (通道关闭).
 * PL 自动管 setup/hold/DCLK 高电平 ~850ns (datasheet ≥500ns). */
static inline void panel_seq_icnd_advance(u8 sdi_bit) {
    panel_seq_icnd_wait_idle();
    /* bit[31]=0 (advance), bit[0]=SDI */
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_ICND, sdi_bit & 1u);
}

/* ICND3019 config register: 写 reg<3:0> 配置消隐模式 + 消隐电位.
 *   reg[3]=0: 增强模式 / =1: 普通模式
 *   reg[2:0]: 消隐电位 (000=NA, 001=1.5V, ..., 111=3.0V @ VDD=5V)
 *   默认 0xD = 1101 = 普通+101=2.5V (可不写, 用 chip 出厂默认).
 * PL 自动发 (reg+8) 个 RCLK 脉冲, 前后空白 ≥100ns. 必须 chip DCLK LOW 期间发. */
static inline void panel_seq_icnd_config(u8 reg) {
    panel_seq_icnd_wait_idle();
    /* bit[31]=1 (config), bit[3:0]=reg */
    Xil_Out32(PANEL_SEQ_BASE + PANEL_SEQ_ICND, 0x80000000u | (reg & 0xFu));
}

#endif
