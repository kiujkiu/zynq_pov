/*
 * led_panel.c — ARM bit-bang ICND1069 + ICND3019 LED panel driver
 *
 * Updated 2026-05-09 to follow ICND1069 编程指导 V1.2 (May 2024,
 * 深圳映己鸿鹄科技有限公司专用).  See led_panel.h for the protocol
 * summary.  The V1.1-era prototype used LE=2 / LE=1 to differentiate
 * latch from PWM data; V1.2 reassigns the LE codes — every command now
 * goes through the new led_panel_le_pulse() / led_panel_le_marker()
 * helpers and the matching LED_LE_* constants.
 *
 * The flush path uses the V1.2 display timing:
 *   VSYNC (LE=3) -> 16 DCLK gap -> ROW12 -> for each row:
 *      LED_PANEL_CHIPS_PER_CHAIN * 16 DATA_LATCH (LE=1) commands ->
 *      ROW4 (next-row marker)
 *
 * Default register map is the one from the V1.2 datasheet register
 * table (page 24-25) with scan_minus1 / subframes_minus1 user-tunable
 * for the actual panel scan count.
 */

#include "led_panel.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"

/* ====================================================================
 * Pinout — TBD.  Defaults below mean "no panel wired".  When the BD adds
 * an AXI_GPIO for the panel FPC, override these macros at build time
 * (-DLED_PANEL_GPIO_BASE=0x41210000 etc.) or edit them here.
 *
 * Suggested allocation on a single 32-bit AXI_GPIO channel-1 word:
 *   bit  0 -> SDI chain 0
 *   bit  1 -> SDI chain 1
 *   bit  2 -> SDI chain 2
 *   bit  3 -> SDI chain 3
 *   bit  4 -> DCLK
 *   bit  5 -> LE
 *   bit  6 -> ROW
 * The ICND3019 row driver shares the same DCLK + ROW lines (ROW signal
 * doubles as the row-scan advance for the row cascade per V1.2 page 9).
 * ====================================================================*/

#ifndef LED_PANEL_GPIO_BASE
#  define LED_PANEL_GPIO_BASE     0UL          /* 0 = not wired yet */
#endif
#ifndef LED_PANEL_GPIO_DATA_OFF
#  define LED_PANEL_GPIO_DATA_OFF 0x00         /* axi_gpio data reg */
#endif
#ifndef LED_PANEL_GPIO_TRI_OFF
#  define LED_PANEL_GPIO_TRI_OFF  0x04         /* axi_gpio tri reg  */
#endif

#ifndef LED_SDI0_BIT
#  define LED_SDI0_BIT            0
#endif
#ifndef LED_SDI1_BIT
#  define LED_SDI1_BIT            1
#endif
#ifndef LED_SDI2_BIT
#  define LED_SDI2_BIT            2
#endif
#ifndef LED_SDI3_BIT
#  define LED_SDI3_BIT            3
#endif
#ifndef LED_DCLK_BIT
#  define LED_DCLK_BIT            4
#endif
#ifndef LED_LE_BIT
#  define LED_LE_BIT              5
#endif
#ifndef LED_ROW_BIT
#  define LED_ROW_BIT             6
#endif

#define LED_SDI_MASK   ((1u << LED_SDI0_BIT) | (1u << LED_SDI1_BIT) | \
                        (1u << LED_SDI2_BIT) | (1u << LED_SDI3_BIT))
#define LED_DCLK_MASK  (1u << LED_DCLK_BIT)
#define LED_LE_MASK    (1u << LED_LE_BIT)
#define LED_ROW_MASK   (1u << LED_ROW_BIT)

/* ====================================================================
 * Internal state
 * ====================================================================*/

static u8  fb[LED_PANEL_H][LED_PANEL_W][3];    /* software frame buffer */
static u32 s_gpio_mirror = 0;                  /* shadow of GPIO data   */
static int s_pins_ok     = 0;
static int s_warned      = 0;

/* ====================================================================
 * Low-level GPIO helpers (read-modify-write avoided via mirror)
 * ====================================================================*/

static inline void gpio_commit(void)
{
    if (LED_PANEL_GPIO_BASE)
        Xil_Out32((UINTPTR)LED_PANEL_GPIO_BASE + LED_PANEL_GPIO_DATA_OFF,
                  s_gpio_mirror);
}

static inline void gpio_set(u32 mask)
{
    s_gpio_mirror |= mask;
    gpio_commit();
}

static inline void gpio_clr(u32 mask)
{
    s_gpio_mirror &= ~mask;
    gpio_commit();
}

static inline void gpio_put_masked(u32 mask, u32 value)
{
    s_gpio_mirror = (s_gpio_mirror & ~mask) | (value & mask);
    gpio_commit();
}

static inline void dclk_pulse(void)
{
    gpio_set(LED_DCLK_MASK);
    gpio_clr(LED_DCLK_MASK);
}

/* ====================================================================
 * V1.2 protocol primitives
 * ====================================================================*/

int led_panel_init_pins(void)
{
    if (!LED_PANEL_GPIO_BASE) {
        if (!s_warned) {
            xil_printf("[led_panel] WARN: GPIO base undefined; driver "
                       "running in stub mode (set LED_PANEL_GPIO_BASE "
                       "and rebuild once FPC pinout is in the BD).\r\n");
            s_warned = 1;
        }
        s_pins_ok = 0;
        return -1;
    }

    /* All panel pins as outputs (TRI = 0). */
    Xil_Out32((UINTPTR)LED_PANEL_GPIO_BASE + LED_PANEL_GPIO_TRI_OFF, 0x00);
    s_gpio_mirror = 0;                          /* idle: LE/DCLK/ROW low */
    gpio_commit();
    s_pins_ok = 1;
    return 0;
}

/* Emit one 16-DCLK frame holding `sdi_data` MSB-first on every SDI lane.
 * LE is driven high during the LAST `le_count` rising edges; on LE
 * falling the chip latches the command per V1.2 page 4-7.  The same word
 * is broadcast to all 4 chains (suitable for register writes that target
 * every chip on every chain). */
void led_panel_le_pulse(u8 le_count, u16 sdi_data)
{
    if (!s_pins_ok) return;
    if (le_count == 0 || le_count > 16) return;

    const u8 le_start = (u8)(16 - le_count); /* edge idx when LE rises */

    for (u8 i = 0; i < 16; i++) {
        u32 bit = (sdi_data >> (15 - i)) & 1u;
        gpio_put_masked(LED_SDI_MASK, bit ? LED_SDI_MASK : 0);

        if (i >= le_start) gpio_set(LED_LE_MASK);
        else               gpio_clr(LED_LE_MASK);

        dclk_pulse(); /* rising edge samples LE + SDI */
    }
    gpio_clr(LED_LE_MASK);  /* falling edge -> latch */
    gpio_clr(LED_SDI_MASK);
}

/* No-payload marker (VSYNC / EN_OP / DIS_OP / SOFT_RST / PRE_ACT).
 * Datasheet permits the compact form: DCLK count == le_count with LE
 * held high for all of them; SDI is don't care (page 4 figure). */
void led_panel_le_marker(u8 le_count)
{
    if (!s_pins_ok) return;
    if (le_count == 0) return;
    gpio_set(LED_LE_MASK);
    for (u8 i = 0; i < le_count; i++) dclk_pulse();
    gpio_clr(LED_LE_MASK);
}

/* Shift one 16-bit word through the cascade with LE held low (data
 * propagates SDO to next chip but no latching). */
static inline void shift16_no_le(u16 word)
{
    gpio_clr(LED_LE_MASK);
    for (u8 i = 0; i < 16; i++) {
        u32 bit = (word >> (15 - i)) & 1u;
        gpio_put_masked(LED_SDI_MASK, bit ? LED_SDI_MASK : 0);
        dclk_pulse();
    }
}

void led_panel_write_cfg(u8 addr, u8 val)
{
    if (!s_pins_ok) return;
    /* WR_CFG word: hi 8b = addr, lo 8b = val.  Repeat for every cascade
     * slot so all chips on a chain latch the same value on the SAME LE
     * falling edge.  Only the LAST iteration drives LE=5. */
    const u16 word = (u16)((u16)addr << 8) | val;
    for (u8 chip = 0; chip < LED_PANEL_CHIPS_PER_CHAIN - 1; chip++) {
        shift16_no_le(word);
    }
    led_panel_le_pulse(LED_LE_WR_CFG, word);
    gpio_clr(LED_SDI_MASK);
}

void led_panel_pre_act(void)
{
    led_panel_le_marker(LED_LE_PRE_ACT);
}

void led_panel_password(u8 v)
{
    if (!s_pins_ok) return;
    led_panel_write_cfg(LED_REG_PASSWORD_A, v);
    led_panel_write_cfg(LED_REG_PASSWORD_B, v);
}

void led_panel_vsync(void)
{
    led_panel_le_marker(LED_LE_VSYNC);
}

void led_panel_en_op(void)
{
    led_panel_le_marker(LED_LE_EN_OP);
}

void led_panel_dis_op(void)
{
    led_panel_le_marker(LED_LE_DIS_OP);
}

void led_panel_init_default(u8 scan_minus1, u8 subframes_minus1)
{
    if (!s_pins_ok && led_panel_init_pins() < 0) return;

    /* V1.2 写寄存器流程 (page 7-8):
     *   1) PRE_ACT (LE=14)
     *   2) WR 0x00 = 0xAA, WR 0x01 = 0xAA   -- set password
     *   3) WR <regs ...>                    -- actual config
     *   4) WR 0x00 = 0x55, WR 0x01 = 0x55   -- close password
     *
     * Default values lifted verbatim from V1.2 register table (page 24).
     * R/G/B chips share the same address space on a single die; on the
     * 鹿小班 panel the R/G/B colours are distributed across DIFFERENT
     * chains, so we broadcast the R-column defaults to every chip and
     * defer per-chain tuning to a later optimisation pass. */
    led_panel_pre_act();
    led_panel_password(0xAA);

    led_panel_write_cfg(LED_REG_SCAN,         scan_minus1 & 0x3F);
    led_panel_write_cfg(LED_REG_GROUPS,       subframes_minus1 & 0x7F);
    led_panel_write_cfg(LED_REG_PLL_PRE,      0x02);
    led_panel_write_cfg(LED_REG_PLL_LOOP,     0x04);
    led_panel_write_cfg(LED_REG_PLL_POST,     0x01);
    led_panel_write_cfg(LED_REG_DCLK_PER_ROW, 0x20); /* 128 GCLK / row */
    led_panel_write_cfg(LED_REG_COUPLE1,      0x1F);
    led_panel_write_cfg(LED_REG_BLANK_TIME,   0x02);
    led_panel_write_cfg(LED_REG_ROW1_COMP_T,  0x06);
    led_panel_write_cfg(LED_REG_BLANK_START,  0x01);
    led_panel_write_cfg(LED_REG_LOW_UNIFORM,  0xDF);
    /* 0x11..0x16 stay at chip defaults (skip) */
    led_panel_write_cfg(LED_REG_ROW1_COMP_A,  0x15);
    led_panel_write_cfg(LED_REG_ROW1_COMP_B,  0x00);
    led_panel_write_cfg(LED_REG_GAIN,         0xC0); /* 150% gain      */
    led_panel_write_cfg(LED_REG_SLOW_KNEE,    0xA6);
    led_panel_write_cfg(LED_REG_BLANK_LEVEL,  0x40);
    led_panel_write_cfg(LED_REG_COUPLE2_EN,   0x00);
    led_panel_write_cfg(LED_REG_COUPLE2_LV,   0x02);
    led_panel_write_cfg(LED_REG_MISC_21,      0x01);
    led_panel_write_cfg(LED_REG_COUPLE2_BST,  0x1C);
    led_panel_write_cfg(LED_REG_LOWGREY_COMP, 0x00);
    led_panel_write_cfg(LED_REG_MISC_24,      0x01);
    led_panel_write_cfg(LED_REG_MISC_25,      0x02);
    led_panel_write_cfg(LED_REG_MISC_26,      0xAA);
    led_panel_write_cfg(LED_REG_MISC_27,      0xAA);

    led_panel_password(0x55);
}

/* ====================================================================
 * ROW pulses (V1.2 page 9)
 * ====================================================================*/

static inline void row_pulse(u8 dclks_high)
{
    if (!s_pins_ok) return;
    gpio_set(LED_ROW_MASK);
    for (u8 i = 0; i < dclks_high; i++) dclk_pulse();
    gpio_clr(LED_ROW_MASK);
}

void led_panel_row12(void) { row_pulse(12); }
void led_panel_row4(void)  { row_pulse(4);  }

/* ====================================================================
 * Frame-buffer DATA_LATCH stream
 * ====================================================================*/

/* 8-bit fb sample -> 16-bit greyscale (replicate v * 257, full range). */
static inline u16 grey16_from_u8(u8 v)
{
    return (u16)((u32)v * 257u);
}

/* Push one DATA_LATCH for every (chip, channel) on one row.  V1.2 page 6
 * data order: chain-tail first, OUT15..OUT0 per chip, chip N-1 first. */
static void emit_row_latches(int y)
{
    if (!s_pins_ok) return;
    /* Walk cascade tail -> head, OUT15 -> OUT0.  All four SDI chains
     * carry the same green-channel sample for now (placeholder mapping
     * — a true chain mapping requires the final FPC pinout). */
    for (int chip = LED_PANEL_CHIPS_PER_CHAIN - 1; chip >= 0; chip--) {
        for (int ch = 15; ch >= 0; ch--) {
            int col = chip * LED_PANEL_CH_PER_CHIP + (15 - ch);
            u8 sample = 0;
            if (col < LED_PANEL_W) {
                /* placeholder: send green channel.  Real mapping must
                 * dispatch R/G/B per chain after FPC pinout known. */
                sample = fb[y][col][1];
            }
            led_panel_le_pulse(LED_LE_DATA_LATCH, grey16_from_u8(sample));
        }
    }
}

/* ====================================================================
 * Legacy API (kept for existing helloworld.c compatibility)
 * ====================================================================*/

void led_panel_init(void)
{
    xil_printf("[led_panel] init: gpio_base=0x%x\r\n",
               (unsigned)LED_PANEL_GPIO_BASE);
    if (led_panel_init_pins() < 0) {
        led_panel_clear();
        return;                   /* stub mode: don't try to talk */
    }

    /* Apply default register map.  Scan = 32 rows (max for ICND1069 SCAN
     * field is 64; 鹿小班 panel uses external ICND3019 to multiplex the
     * remaining rows to 180).  Sub-frames = 8 (default refresh ratio,
     * matches reg0x07 = 0x20 -> 128 GCLK/row). */
    led_panel_init_default(/*scan_minus1=*/31, /*subframes_minus1=*/7);

    /* Push one black frame so the next EN_OP comes after valid data. */
    led_panel_clear();
    led_panel_flush();

    /* Enable PWM outputs. */
    led_panel_en_op();

    xil_printf("[led_panel] init done\r\n");
}

void led_panel_set_pixel(int x, int y, u8 r, u8 g, u8 b)
{
    if (x < 0 || x >= LED_PANEL_W || y < 0 || y >= LED_PANEL_H) return;
    fb[y][x][0] = r;
    fb[y][x][1] = g;
    fb[y][x][2] = b;
}

void led_panel_clear(void)
{
    for (int y = 0; y < LED_PANEL_H; y++)
        for (int x = 0; x < LED_PANEL_W; x++) {
            fb[y][x][0] = 0;
            fb[y][x][1] = 0;
            fb[y][x][2] = 0;
        }
}

void led_panel_flush(void)
{
    if (!s_pins_ok && led_panel_init_pins() < 0) return;

    /* V1.2 显示时序 (page 10):
     *   1) VSYNC
     *   2) wait 16 DCLK
     *   3) ROW12 (group-1 row-1 marker)
     *   4) row data
     *   5) ROW4 (next row marker)
     *   6) ... until all rows clocked
     *
     * For a single-subframe burst we send VSYNC once per call.  Higher
     * PWM ratios (reg0x03 sub-frames) re-issue the same frame; bit-bang
     * speed isn't fast enough to exploit that here. */
    led_panel_vsync();
    for (u8 i = 0; i < 16; i++) dclk_pulse();
    led_panel_row12();

    for (int y = 0; y < LED_PANEL_H; y++) {
        emit_row_latches(y);
        led_panel_row4();
    }
}

/* ====================================================================
 * Test patterns (frame-buffer only; caller flushes)
 * ====================================================================*/

static void pat_solid(u8 r, u8 g, u8 b)
{
    for (int y = 0; y < LED_PANEL_H; y++)
        for (int x = 0; x < LED_PANEL_W; x++)
            led_panel_set_pixel(x, y, r, g, b);
}

static void pat_checker(void)
{
    for (int y = 0; y < LED_PANEL_H; y++)
        for (int x = 0; x < LED_PANEL_W; x++) {
            int cell = ((x >> 3) ^ (y >> 3)) & 1;
            u8 v = cell ? 0xFF : 0x00;
            led_panel_set_pixel(x, y, v, v, v);
        }
}

static void pat_color_bars(void)
{
    static const u8 bars[8][3] = {
        {0,0,0}, {255,0,0}, {0,255,0}, {255,255,0},
        {0,0,255}, {255,0,255}, {0,255,255}, {255,255,255}
    };
    int seg_w = LED_PANEL_W / 8;        /* = 20 */
    for (int y = 0; y < LED_PANEL_H; y++)
        for (int x = 0; x < LED_PANEL_W; x++) {
            int s = x / seg_w;
            if (s > 7) s = 7;
            led_panel_set_pixel(x, y, bars[s][0], bars[s][1], bars[s][2]);
        }
}

static void pat_concentric_circles(void)
{
    int cx = LED_PANEL_W / 2;
    int cy = LED_PANEL_H / 2;
    for (int y = 0; y < LED_PANEL_H; y++)
        for (int x = 0; x < LED_PANEL_W; x++) {
            int dx = x - cx;
            int dy = y - cy;
            int d2 = dx*dx + dy*dy;
            int r_q  = d2 / 32;
            int ring = r_q & 7;
            u8 v = (ring & 1) ? 0xFF : 0x20;
            led_panel_set_pixel(x, y, v, v, v);
        }
}

void led_panel_test_pattern(int pattern_id)
{
    led_panel_clear();
    switch (pattern_id) {
        case 0: /* black, already cleared */ break;
        case 1: pat_solid(0xFF, 0xFF, 0xFF); break;
        case 2: pat_solid(0xFF, 0x00, 0x00); break;
        case 3: pat_solid(0x00, 0xFF, 0x00); break;
        case 4: pat_solid(0x00, 0x00, 0xFF); break;
        case 5: pat_checker(); break;
        case 6: pat_color_bars(); break;
        case 7: pat_concentric_circles(); break;
        default:
            xil_printf("[led_panel] unknown pattern %d, using black\r\n",
                       pattern_id);
            break;
    }
}
