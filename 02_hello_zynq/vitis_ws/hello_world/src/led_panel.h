/*
 * led_panel.h — ARM bit-bang ICND1069 + ICND3019 LED panel driver
 *
 * Updated to follow ICND1069 编程指导 V1.2 (2024-05, 深圳映己鸿鹄科技
 * 有限公司专用).  The original V1.1-era prototype used LE=2 for latch +
 * LE=1 for PWM data; V1.2 redefines LE entirely (see table below).  All
 * legacy entry points (led_panel_init / led_panel_set_pixel /
 * led_panel_clear / led_panel_flush / led_panel_test_pattern) are kept
 * with the same signatures so existing helloworld.c paths still build.
 *
 * Protocol summary (V1.2 编程指导, page 5-10):
 *
 *   DCLK   continuous clock (4 MHz < FDCLK < 16 MHz, default 12.5 MHz)
 *   LE     command-length encoding — DCLK rising edges with LE high
 *            1  DATA_LATCH   latch 16-bit greyscale, MSB first (D[15:0])
 *            3  VSYNC        frame sync
 *            5  WR_CFG       write reg, hi 8b = addr, lo 8b = value
 *            7  RD_CFG       read reg (debug only)
 *            9  SOFT_RST     soft reset (non-register)
 *           11  EN_OP        enable PWM outputs
 *           12  DIS_OP       disable PWM outputs
 *           14  PRE_ACT      write enable (precedes WR_CFG bursts)
 *
 *   For data-bearing commands the 16-bit SDI window covers exactly 16
 *   DCLK rising edges; LE is held high during the LAST N of them.
 *
 *   WR_CFG sequence (page 7-8):
 *     PRE_ACT -> WR 0x00=0xAA -> WR 0x01=0xAA   (password open)
 *             -> WR <regs ...>                  (config)
 *             -> WR 0x00=0x55 -> WR 0x01=0x55   (password close)
 *
 *   Display timing (page 10):
 *     1) VSYNC (LE=3)
 *     2) wait 16 DCLK
 *     3) ROW = 12 DCLK high (group-1 row-1 marker)
 *     4) per row: 16 ch * cascade-depth DATA_LATCH commands, chain
 *        tail first, OUT15..OUT0
 *     5) ROW = 4 DCLK high (next row)
 *     6) repeat until all groups * scan_rows latches sent, then VSYNC
 *
 * Panel target (POV-3D 鹿小班 v0):
 *   - 160 x 180 RGB pixel grid
 *   - 4 parallel SDI chains (chain 0..3), 27 ICND1069 chips per chain
 *   - 24 ICND3019 row drivers cascaded externally
 *
 * Hardware assumption:
 *   axi_gpio_panel @ LED_PANEL_GPIO_BASE (overridable via build flag).
 *   Default 0 means "FPC not wired yet" — every call is a safe no-op
 *   that emits one warning.  Set ENABLE_LED_PANEL_TEST=1 + provide a
 *   real GPIO base to actually drive the panel.
 *
 * Performance: bit-bang ~2 FPS — only good for physical-link bring-up.
 * Real POV timing (21.6 K slice/s) is owned by a PL Verilog core.
 */
#ifndef LED_PANEL_H_
#define LED_PANEL_H_

#include "xil_types.h"

/* === Panel geometry =================================================== */
#define LED_PANEL_W              160          /* pixel columns        */
#define LED_PANEL_H              180          /* pixel rows           */
#define LED_PANEL_CHAINS         4            /* parallel SDI lanes   */
#define LED_PANEL_CHIPS_PER_CHAIN 27          /* ICND1069 cascade     */
#define LED_PANEL_CH_PER_CHIP    16           /* OUT0..OUT15          */
#define LED_PANEL_ROWS           LED_PANEL_H  /* alias for clarity    */

/* === LE command lengths (DCLK rising edges with LE high) ============== */
#define LED_LE_DATA_LATCH        1
#define LED_LE_VSYNC             3
#define LED_LE_WR_CFG            5
#define LED_LE_RD_CFG            7
#define LED_LE_SOFT_RST          9
#define LED_LE_EN_OP             11
#define LED_LE_DIS_OP            12
#define LED_LE_PRE_ACT           14

/* === Key register addresses (V1.2 register table, page 24-25) ========= */
#define LED_REG_PASSWORD_A       0x00 /* part-1 of password (0xAA / 0x55) */
#define LED_REG_PASSWORD_B       0x01 /* part-2                           */
#define LED_REG_SCAN             0x02 /* bit[5:0] = scan_num - 1          */
#define LED_REG_GROUPS           0x03 /* bit[6:0] = sub_frames - 1        */
#define LED_REG_PLL_PRE          0x04 /* default 0x02                     */
#define LED_REG_PLL_LOOP         0x05 /* default 0x04                     */
#define LED_REG_PLL_POST         0x06 /* default 0x01                     */
#define LED_REG_DCLK_PER_ROW     0x07 /* GCLK/4 per row (default 0x20)    */
#define LED_REG_COUPLE1          0x0C /* default 0x1F                     */
#define LED_REG_BLANK_TIME       0x0D /* default 0x02                     */
#define LED_REG_ROW1_COMP_T      0x0E /* default 0x06                     */
#define LED_REG_BLANK_START      0x0F /* default 0x01                     */
#define LED_REG_LOW_UNIFORM      0x10 /* default 0xDF                     */
#define LED_REG_OPEN_DET         0x16 /* 0x01 = enable open detect        */
#define LED_REG_ROW1_COMP_A      0x18 /* default 0x15                     */
#define LED_REG_ROW1_COMP_B      0x19 /* default 0x00                     */
#define LED_REG_GAIN             0x1C /* current gain (default 0xC0)      */
#define LED_REG_SLOW_KNEE        0x1D /* default 0xA6                     */
#define LED_REG_BLANK_LEVEL      0x1E /* default 0x40                     */
#define LED_REG_COUPLE2_EN       0x1F /* default 0x00                     */
#define LED_REG_COUPLE2_LV       0x20 /* default 0x02                     */
#define LED_REG_MISC_21          0x21 /* default 0x01                     */
#define LED_REG_COUPLE2_BST      0x22 /* default 0x1C                     */
#define LED_REG_LOWGREY_COMP     0x23 /* default 0x00                     */
#define LED_REG_MISC_24          0x24 /* default 0x01                     */
#define LED_REG_MISC_25          0x25 /* default 0x02                     */
#define LED_REG_MISC_26          0x26 /* default 0xAA                     */
#define LED_REG_MISC_27          0x27 /* default 0xAA                     */

/* === Legacy API (kept for binary compatibility) ======================= */

/* Boot-time init: set GPIO direction, push default register map (PRE_ACT
 * + password-open + V1.2 defaults + password-close), zero the frame
 * buffer, leave outputs ENABLED.  Safe to call multiple times. */
void led_panel_init(void);

/* Update one pixel in the software frame buffer.  No I/O. */
void led_panel_set_pixel(int x, int y, u8 r, u8 g, u8 b);

/* Software frame buffer -> all black (no I/O). */
void led_panel_clear(void);

/* Push the entire frame buffer to the panel via bit-bang VSYNC + ROW +
 * 16-bit DATA_LATCH stream.  Blocking, ~2 FPS. */
void led_panel_flush(void);

/* Built-in test patterns (fills the frame buffer only, caller flushes).
 *   0 black  1 white  2 red  3 green  4 blue
 *   5 checker  6 color-bars  7 concentric circles  */
void led_panel_test_pattern(int pattern_id);

/* === V1.2 protocol primitives (new) =================================== */

/* Set GPIO direction + idle state.  Returns 0 on success, -1 if base
 * address is undefined (no FPC pinout yet). */
int  led_panel_init_pins(void);

/* Low-level LE pulse: emit 16 DCLKs while shifting `sdi_data` MSB-first
 * on every chain, holding LE high during the LAST `le_count` edges.
 * Falling edge of LE latches the command per ICND1069 V1.2 spec. */
void led_panel_le_pulse(u8 le_count, u16 sdi_data);

/* No-payload LE marker (VSYNC / EN_OP / DIS_OP / SOFT_RST / PRE_ACT):
 * runs only `le_count` DCLKs with LE held high. */
void led_panel_le_marker(u8 le_count);

/* WR_CFG: build addr|val word + broadcast across the whole cascade so
 * every chip latches on the same LE-falling edge. */
void led_panel_write_cfg(u8 addr, u8 val);

/* PRE_ACT (LE=14, write enable). */
void led_panel_pre_act(void);

/* Open (v=0xAA) or close (v=0x55) the WR_CFG password gate.  Issues
 * both WR 0x00=v and WR 0x01=v. */
void led_panel_password(u8 v);

/* VSYNC (LE=3). */
void led_panel_vsync(void);

/* EN_OP (LE=11) / DIS_OP (LE=12). */
void led_panel_en_op(void);
void led_panel_dis_op(void);

/* Push the default register init sequence from the V1.2 datasheet
 * register table.  Wraps PRE_ACT -> password open -> WR ... ->
 * password close.  Caller picks scan_minus1 / subframes_minus1. */
void led_panel_init_default(u8 scan_minus1, u8 subframes_minus1);

/* ROW pulses: 12-DCLK-high marks group-1 row-1, 4-DCLK-high marks any
 * subsequent row advance. */
void led_panel_row12(void);
void led_panel_row4(void);

#endif /* LED_PANEL_H_ */
