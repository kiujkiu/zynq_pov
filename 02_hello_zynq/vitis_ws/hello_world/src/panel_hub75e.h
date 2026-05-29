/* panel_hub75e.h - HUB75E FM6124 panel PL driver thin shell.
 *
 * IP: hub75e_panel_seq @ 0x40020000 (BD 集成时分配, 跟旧 panel_seq 0x40010000 不冲突)
 *
 * 寄存器:
 *   0x00 CTRL    [0]=enable [3:1]=test_mode [4]=addr_mode_sr [12:8]=addr_bits
 *   0x04 COLOR   [5:0]={B2,G2,R2,B1,G1,R1}
 *   0x08 PARAM   [11:0]=width-1 [23:16]=stripe_w [31:24]=walk_speed
 *   0x0C STATUS  [0]=running [12:8]=cur_addr [31:16]=frame_count
 *
 * Phase 1: 1-bit 色深, 内置 8 test pattern (整片单色/横竖条/棋盘/walk/渐变).
 * Phase 2: 上 BCM + frame buffer (BRAM/DDR).
 */

#ifndef PANEL_HUB75E_H
#define PANEL_HUB75E_H

#include "xil_io.h"
#include "xil_types.h"
#include "sleep.h"

#define HUB75E_BASE      0x40020000UL
#define HUB75E_R_CTRL    0x00
#define HUB75E_R_COLOR   0x04
#define HUB75E_R_PARAM   0x08
#define HUB75E_R_STATUS  0x0C

/* CTRL bits */
#define HUB75E_CTRL_ENABLE     (1u << 0)
#define HUB75E_CTRL_MODE_POS   1
#define HUB75E_CTRL_MODE_MASK  (0x7u << 1)
#define HUB75E_CTRL_ADDR_SR    (1u << 4)
#define HUB75E_CTRL_ABITS_POS  8
#define HUB75E_CTRL_ABITS_MASK (0x1Fu << 8)

/* test_mode 编号 */
#define HUB75E_MODE_SOLID       0   /* 全屏单色, COLOR 控 */
#define HUB75E_MODE_HSTRIPE     1   /* 横条 8 色 */
#define HUB75E_MODE_VSTRIPE     2   /* 竖条 8 色 */
#define HUB75E_MODE_CHECKER     3   /* 棋盘 */
#define HUB75E_MODE_ROW_WALK    4   /* 单行 walk, 验证 ADDR */
#define HUB75E_MODE_COL_WALK    5   /* 单列 walk, 验证 shift */
#define HUB75E_MODE_GRADIENT    6   /* col 渐变 */
#define HUB75E_MODE_FULL_WHITE  7   /* 全亮白 */

/* COLOR helpers: top half (R1/G1/B1) bit 0..2, bot half (R2/G2/B2) bit 3..5 */
#define HUB75E_COLOR(r1,g1,b1,r2,g2,b2) \
    (((b2)&1)<<5 | ((g2)&1)<<4 | ((r2)&1)<<3 | ((b1)&1)<<2 | ((g1)&1)<<1 | ((r1)&1))

#define HUB75E_COLOR_BOTH(r,g,b) HUB75E_COLOR(r,g,b,r,g,b)

static inline void hub75e_w(u32 off, u32 val) {
    Xil_Out32(HUB75E_BASE + off, val);
}
static inline u32 hub75e_r(u32 off) {
    return Xil_In32(HUB75E_BASE + off);
}

/* ---- High-level API ---- */

/* 关 panel, 清状态, 默认 1/32 scan (5-bit ADDR), 128 col, ABCDE mode. */
static inline void hub75e_init(void) {
    hub75e_w(HUB75E_R_CTRL,  0);
    hub75e_w(HUB75E_R_COLOR, 0);
    hub75e_w(HUB75E_R_PARAM, 0);   /* 0 → 内置默认 (width=128, stripe=8, walk=10) */
}

static inline void hub75e_enable(int on) {
    u32 v = hub75e_r(HUB75E_R_CTRL);
    v = on ? (v | HUB75E_CTRL_ENABLE) : (v & ~HUB75E_CTRL_ENABLE);
    hub75e_w(HUB75E_R_CTRL, v);
}

/* 切 test pattern (不改 enable / addr_mode). */
static inline void hub75e_set_mode(u32 mode) {
    u32 v = hub75e_r(HUB75E_R_CTRL);
    v = (v & ~HUB75E_CTRL_MODE_MASK) | ((mode & 0x7u) << HUB75E_CTRL_MODE_POS);
    hub75e_w(HUB75E_R_CTRL, v);
}

/* ADDR mode: 0=ABCDE (默认), 1=shift register (multivox vortex 风格). */
static inline void hub75e_set_addr_mode(int sr) {
    u32 v = hub75e_r(HUB75E_R_CTRL);
    v = sr ? (v | HUB75E_CTRL_ADDR_SR) : (v & ~HUB75E_CTRL_ADDR_SR);
    hub75e_w(HUB75E_R_CTRL, v);
}

/* 1/N scan: bits=5 → 1/32, bits=4 → 1/16, bits=3 → 1/8. */
static inline void hub75e_set_scan(u32 bits) {
    u32 v = hub75e_r(HUB75E_R_CTRL);
    v = (v & ~HUB75E_CTRL_ABITS_MASK) | ((bits & 0x1Fu) << HUB75E_CTRL_ABITS_POS);
    hub75e_w(HUB75E_R_CTRL, v);
}

static inline void hub75e_set_color(u32 rgb_packed) {
    hub75e_w(HUB75E_R_COLOR, rgb_packed & 0x3Fu);
}

static inline void hub75e_set_param(u32 width, u32 stripe_w, u32 walk_speed) {
    u32 v = ((width - 1) & 0xFFFu)
          | ((stripe_w & 0xFFu) << 16)
          | ((walk_speed & 0xFFu) << 24);
    hub75e_w(HUB75E_R_PARAM, v);
}

static inline u32 hub75e_status(void) {
    return hub75e_r(HUB75E_R_STATUS);
}
static inline u32 hub75e_frame_count(void) {
    return (hub75e_status() >> 16) & 0xFFFFu;
}
static inline int hub75e_is_running(void) {
    return hub75e_status() & 0x1u;
}

/* 一键启动: addr_mode + mode + enable. */
static inline void hub75e_start(int addr_sr, u32 mode, u32 color) {
    u32 v = HUB75E_CTRL_ENABLE
          | ((mode & 0x7u) << HUB75E_CTRL_MODE_POS)
          | (addr_sr ? HUB75E_CTRL_ADDR_SR : 0)
          | (5u << HUB75E_CTRL_ABITS_POS);   /* 1/32 scan */
    hub75e_w(HUB75E_R_COLOR, color & 0x3Fu);
    hub75e_w(HUB75E_R_PARAM, 0);             /* width=128, stripe=8, walk=10 */
    hub75e_w(HUB75E_R_CTRL,  v);
}

#endif /* PANEL_HUB75E_H */
