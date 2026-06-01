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

#define HUB75E_BASE         0x40020000UL
#define HUB75E_R_CTRL       0x00
#define HUB75E_R_COLOR      0x04   /* BCM: 24-bit RGB 顶半色 (R[7:0] G[15:8] B[23:16]) */
#define HUB75E_R_PARAM      0x08
#define HUB75E_R_STATUS     0x0C
#define HUB75E_R_COLOR_BOT  0x10   /* BCM: 24-bit RGB 底半色 (0 时跟 COLOR 同色) */
#define HUB75E_R_TUNIT      0x14   /* BCM T_unit cycles, 默认 96 (~1.28 µs @ 75 MHz) */

/* CTRL bits */
#define HUB75E_CTRL_ENABLE     (1u << 0)
#define HUB75E_CTRL_MODE_POS   1
#define HUB75E_CTRL_MODE_MASK  (0x7u << 1)
#define HUB75E_CTRL_ADDR_SR    (1u << 4)
#define HUB75E_CTRL_USE_FB     (1u << 5)   /* 1=从 framebuffer 读 pixel, 0=用 LUT pattern */
#define HUB75E_CTRL_ABITS_POS  8
#define HUB75E_CTRL_ABITS_MASK (0x1Fu << 8)

/* Framebuffer 地址 (panel 128×64, 顶半 row 0..31, 底半 row 32..63) */
#define HUB75E_FB_TOP_BASE     (HUB75E_BASE | 0x8000UL)  /* top half pixels */
#define HUB75E_FB_BOT_BASE     (HUB75E_BASE | 0xC000UL)  /* bot half pixels */

/* test_mode 编号 */
#define HUB75E_MODE_SOLID       0   /* 全屏单色, COLOR 控 */
#define HUB75E_MODE_HSTRIPE     1   /* 横条 8 色 */
#define HUB75E_MODE_VSTRIPE     2   /* 竖条 8 色 */
#define HUB75E_MODE_CHECKER     3   /* 棋盘 */
#define HUB75E_MODE_ROW_WALK    4   /* 单行 walk, 验证 ADDR */
#define HUB75E_MODE_COL_WALK    5   /* 单列 walk, 验证 shift */
#define HUB75E_MODE_GRADIENT    6   /* col 渐变 */
#define HUB75E_MODE_FULL_WHITE  7   /* 全亮白 */

/* BCM 24-bit RGB pack: R / G / B 各 0-255. PL 内部 R 在低字节, B 在高字节 */
#define HUB75E_RGB24(r,g,b)  (((u32)(b)&0xFF)<<16 | ((u32)(g)&0xFF)<<8 | ((u32)(r)&0xFF))

/* 旧 1-bit API 兼容: 把 R/G/B (0/1) 映射到 0/0xFF 满亮度 */
#define HUB75E_COLOR_BOTH(r,g,b) HUB75E_RGB24((r)?0xFF:0, (g)?0xFF:0, (b)?0xFF:0)
#define HUB75E_COLOR(r1,g1,b1,r2,g2,b2) HUB75E_RGB24((r1)?0xFF:0, (g1)?0xFF:0, (b1)?0xFF:0) /* 顶半色, 底半用 _BOT reg */

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

/* 24-bit RGB 顶半色 (mode 0 SOLID + mode 1 HSTRIPE 等会用) */
static inline void hub75e_set_color(u32 rgb24) {
    hub75e_w(HUB75E_R_COLOR, rgb24 & 0x00FFFFFFu);
}

/* 24-bit RGB 底半色 (mode 0 用; 0 时跟 top 同色) */
static inline void hub75e_set_color_bot(u32 rgb24) {
    hub75e_w(HUB75E_R_COLOR_BOT, rgb24 & 0x00FFFFFFu);
}

/* BCM T_unit (cycles), 越大越亮但帧率越低. 默认 96 (~1.28 µs @ 75 MHz aclk). */
static inline void hub75e_set_tunit(u32 cycles) {
    hub75e_w(HUB75E_R_TUNIT, cycles & 0xFFu);
}

/* ---- Framebuffer API ---- */

/* 切到 framebuffer 显示模式 (跳过 LUT pattern, 用 BRAM 数据). */
static inline void hub75e_use_fb(int on) {
    u32 v = hub75e_r(HUB75E_R_CTRL);
    v = on ? (v | HUB75E_CTRL_USE_FB) : (v & ~HUB75E_CTRL_USE_FB);
    hub75e_w(HUB75E_R_CTRL, v);
}

/* 单像素写 (x: 0..127, y: 0..63, rgb24: R[7:0] G[15:8] B[23:16]) */
static inline void hub75e_fb_set(u32 x, u32 y, u32 rgb24) {
    volatile u32 *fb = (volatile u32 *)((y < 32) ? HUB75E_FB_TOP_BASE : HUB75E_FB_BOT_BASE);
    u32 row = (y < 32) ? y : (y - 32);
    fb[row * 128 + x] = rgb24 & 0xFFFFFFu;
}

/* 整片填同一色 (4096+4096 = 8192 AXI writes, ~0.5 ms @ 75 MHz AXI). */
static inline void hub75e_fb_fill(u32 rgb24) {
    volatile u32 *fb_top = (volatile u32 *)HUB75E_FB_TOP_BASE;
    volatile u32 *fb_bot = (volatile u32 *)HUB75E_FB_BOT_BASE;
    rgb24 &= 0xFFFFFFu;
    for (u32 i = 0; i < 32 * 128; i++) {
        fb_top[i] = rgb24;
        fb_bot[i] = rgb24;
    }
}

/* 横条/竖条等 demo helper, 演示 framebuffer 写图像能力 */
static inline void hub75e_fb_demo_vstripe(void) {
    const u32 colors[8] = {0x0000FF, 0x00FF00, 0xFF0000, 0xFFFFFF,
                           0x00FFFF, 0xFF00FF, 0xFFFF00, 0x000000};
    for (u32 y = 0; y < 64; y++) {
        for (u32 x = 0; x < 128; x++) {
            hub75e_fb_set(x, y, colors[(x / 16) & 7]);
        }
    }
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
