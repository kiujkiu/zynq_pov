/*
 * led_panel.c — ICND1069 + ICND3019 panel driver (PL led_panel_seq IP backend)
 *
 * Panel: 160 × 180 RGB, 108 ICND1069 (9 chain × 12 cascade) + 24 ICND3019 row drivers.
 * Protocol (ICND1069 V1.2):
 *   init: PRE_ACT + WR_CFG password 0xAA + cfg regs + WR_CFG password 0x55 + EN_OP
 *   frame: VSYNC + 384 row_iter loops, each loop:
 *     - ICND3019 row advance (PL panel_seq_icnd_advance)
 *     - ICND1069 ROW pulse (panel_seq_row_pulse)
 *     - 12 LATCH × 9 chain (panel_seq_word_perchain, last LATCH has LE=1)
 *
 * PL IP (led_panel_seq) drives DCLK/LE/SDI/ROW/icnd_* directly.
 * ARM only writes AXI commands + GPIO bits for OE/ABC/SPI.
 *
 * Public modes (selected via led_panel_multi_mode_diag):
 *   mode_full_white      — 全屏全 chain 全 bit 亮 (sanity check, brightness max)
 *   mode_single_pixel    — chip sweep: 单 bit, target_chain=0, 60 frames/chip
 *   mode_calib_sweep     — 两阶段标定: Phase 1 = 1728 tuple chip×bit sweep,
 *                          Phase 2 = 384 row_iter sweep (固定 C/K/B)
 */

#include "led_panel.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"
#include "panel_seq.h"

/* ===== axi_gpio_panel base (OE/ABC/SPI 还是走它, DCLK/LE/SDI 走 PL IP) ===== */
#ifndef LED_PANEL_GPIO_BASE
#  define LED_PANEL_GPIO_BASE 0x40000000UL
#endif
#define GPIO_DATA_OFF  0x00
#define GPIO_TRI_OFF   0x04

#define BIT(n)    (1u << (n))
#define ABC_AIN   BIT(LED_BIT_AIN)
#define ABC_BIN   BIT(LED_BIT_BIN)
#define ABC_CIN   BIT(LED_BIT_CIN)
#define SPI_CS_M  BIT(LED_BIT_SPI_CS)

/* ===== ICND1069 LE 长度编码 (V1.2 page 5) ===== */
#define LE_DATA_LATCH  1
#define LE_VSYNC       3
#define LE_WR_CFG      5
#define LE_EN_OP       11
#define LE_PRE_ACT     14

#define REG_PASSWORD_A   0x00
#define REG_PASSWORD_B   0x01

#ifndef CHIPS_PER_CHAIN
#  define CHIPS_PER_CHAIN  12
#endif

/* ===== State + GPIO helpers ============================================ */
static u32 gpio_mirror;
static int pins_ok;

static inline void gpio_commit(void)
{
    Xil_Out32((UINTPTR)LED_PANEL_GPIO_BASE + GPIO_DATA_OFF, gpio_mirror);
}
static inline void gpio_set_bits(u32 m) { gpio_mirror |= m;  gpio_commit(); }
static inline void gpio_clr_bits(u32 m) { gpio_mirror &= ~m; gpio_commit(); }
static inline void gpio_write_field(u32 mask, u32 val)
{
    gpio_mirror = (gpio_mirror & ~mask) | (val & mask);
    gpio_commit();
}

int led_panel_init_pins(void)
{
    if (!LED_PANEL_GPIO_BASE) { pins_ok = 0; return -1; }
    Xil_Out32((UINTPTR)LED_PANEL_GPIO_BASE + GPIO_TRI_OFF, 0u);
    /* idle: SPI_CS=1, AIN/BIN/CIN = 1 (chain group enable default high) */
    gpio_mirror = SPI_CS_M | ABC_AIN | ABC_BIN | ABC_CIN;
    gpio_commit();
    pins_ok = 1;
    return 0;
}

/* ===== ICND1069 primitives (via PL panel_seq IP) ======================== */

/* LE marker: 16×CHIPS_PER_CHAIN DCLK shift 0, last word holds LE high for
 * le_count cycles. 16-DCLK trailing gap = chip internal register commit time. */
static void le_marker(u8 le_count)
{
    if (!pins_ok || le_count == 0 || le_count > 31) return;
    for (u8 chip = 0; chip < (u8)(CHIPS_PER_CHAIN - 1); chip++)
        panel_seq_word(0, 0);
    panel_seq_word(0, le_count);
    panel_seq_word(0, 0);
}

/* WR_CFG: broadcast same (addr, val) to all CHIPS_PER_CHAIN cascade chips.
 * Last word LE=LE_WR_CFG (5). Trailing 16-DCLK gap. */
static void wr_cfg(u8 addr, u8 val)
{
    if (!pins_ok) return;
    const u16 word = ((u16)addr << 8) | val;
    for (u8 chip = 0; chip < (u8)(CHIPS_PER_CHAIN - 1); chip++)
        panel_seq_word(word, 0);
    panel_seq_word(word, LE_WR_CFG);
    panel_seq_word(0, 0);
}

static inline void pre_act(void)        { le_marker(LE_PRE_ACT); }
static inline void en_op(void)          { le_marker(LE_EN_OP); }
static inline void vsync_pulse(void)    { le_marker(LE_VSYNC); }

/* ICND3019 row advance: SDI=1 at row_iter==0 starts new frame; SDI=0 shifts
 * existing '1' through the 384-stage chain. PL IP handles setup/hold + 500ns
 * DCLK-high blanking time per datasheet. */
static inline void icnd3019_advance_row(int inject_one)
{
    panel_seq_icnd_advance(inject_one ? 1u : 0u);
}

/* ===== ICND1069 chip init (one-shot, called from led_panel_init) ======== */

/* Full register init per V1.2 manual defaults + GAIN max (0xFF) for brightness.
 * Sequence: PRE_ACT → open password → cfg writes → close password → EN_OP. */
static void panel_init_chip(void)
{
    vsync_pulse();
    en_op();
    pre_act();
    wr_cfg(REG_PASSWORD_A, 0xAA);
    wr_cfg(REG_PASSWORD_B, 0xAA);
    wr_cfg(0x02, 19);     /* SCAN: 1/20 scan = 20-1 */
    wr_cfg(0x03, 0x00);   /* GROUPS: 1 sub-frame */
    wr_cfg(0x04, 0x02);   /* PLL_PRE_DIV default */
    wr_cfg(0x05, 0x04);   /* PLL_LOOP_DIV default */
    wr_cfg(0x06, 0x01);   /* PLL_POST_DIV default */
    wr_cfg(0x07, 0x20);   /* GCLK/row default 128 */
    wr_cfg(0x0D, 0x02);   /* 消隐时间 default */
    wr_cfg(0x0E, 0x06);   /* 第一行暗补偿 default */
    wr_cfg(0x1C, 0xFF);   /* GAIN max (200%) */
    wr_cfg(0x1D, 0xA6);   /* 慢速开启 + 拐点电压 default */
    wr_cfg(0x20, 0x09);   /* magic reg */
    wr_cfg(0x26, 0xAA);   /* 写使能 password 部分 default */
    wr_cfg(REG_PASSWORD_A, 0x55);
    wr_cfg(REG_PASSWORD_B, 0x55);
}

/* ===== SPI master bit-bang (read panel flash for debug) ================= */
static inline u32 gpio_read_miso(void)
{
    return Xil_In32((UINTPTR)LED_PANEL_GPIO_BASE + 0x08) & 1u;
}
static inline u8 spi_xchg_byte(u8 out)
{
    u8 in = 0;
    for (int i = 7; i >= 0; i--) {
        u32 b = (out >> i) & 1u;
        gpio_write_field(BIT(LED_BIT_SPI_MOSI), b ? BIT(LED_BIT_SPI_MOSI) : 0);
        gpio_set_bits(BIT(LED_BIT_SPI_CLK));
        in = (u8)((in << 1) | gpio_read_miso());
        gpio_clr_bits(BIT(LED_BIT_SPI_CLK));
    }
    return in;
}
void led_panel_spi_read_flash_jedec(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;
    xil_printf("[spi] flash JEDEC + 16 bytes @ 0:\r\n");
    gpio_clr_bits(SPI_CS_M);
    (void)spi_xchg_byte(0x9F);
    u8 b1 = spi_xchg_byte(0xFF);
    u8 b2 = spi_xchg_byte(0xFF);
    u8 b3 = spi_xchg_byte(0xFF);
    gpio_set_bits(SPI_CS_M);
    xil_printf("[spi]   JEDEC = %02x %02x %02x\r\n", b1, b2, b3);
    gpio_clr_bits(SPI_CS_M);
    (void)spi_xchg_byte(0x03);
    for (int i = 0; i < 3; i++) (void)spi_xchg_byte(0x00);
    xil_printf("[spi]  ");
    for (int i = 0; i < 16; i++) xil_printf(" %02x", spi_xchg_byte(0xFF));
    xil_printf("\r\n");
    gpio_set_bits(SPI_CS_M);
}

/* ===== Render helpers (shared by modes) ================================ */

/* Render one full frame where target (chain, chip, bit, row_range) is lit.
 *   target_chain = -1 → all 9 chains enabled (set value across all)
 *   target_chip  = -1 → all 12 chips enabled
 *   target_mask  =  0 → nothing lit (frame-blank); otherwise per-chip bit mask
 *   row_lo, row_hi: only light at row_iter ∈ [row_lo, row_hi]; -1 = always
 *
 * panel_seq_set_sdi_mask + chain_data state must be set by caller for
 * advanced modes; this is the common scan/latch skeleton. */
static void render_frame_targeted(int target_chain, int target_chip,
                                  u16 target_mask, int row_lo, int row_hi)
{
    vsync_pulse();
    panel_seq_set_sdi_mask(0x1FF);

    for (int row_iter = 0; row_iter < 384; row_iter++) {
        icnd3019_advance_row(row_iter == 0 ? 1 : 0);
        panel_seq_row_pulse(row_iter == 0 ? 12 : 4);

        int in_row = (row_lo < 0) || (row_iter >= row_lo && row_iter <= row_hi);

        for (u32 latch = 0; latch < CHIPS_PER_CHAIN; latch++) {
            int chip = (int)((u32)(CHIPS_PER_CHAIN - 1) - latch);
            int chip_match = (target_chip < 0) || (chip == target_chip);
            u16 v = (in_row && chip_match) ? target_mask : 0;
            for (int c = 0; c < 9; c++) {
                u16 cv = ((target_chain < 0) || (c == target_chain)) ? v : 0;
                panel_seq_set_chain_data(c, cv);
            }
            u8 le = (latch == (u32)(CHIPS_PER_CHAIN - 1)) ? 1 : 0;
            panel_seq_word_perchain(le);
        }
        panel_seq_word(0, 0);
    }
}

/* ===== Modes =========================================================== */

/* Full white: all chain × all chip × all bit, all row_iter.
 * Brightest possible output. Use as sanity / physical-layout check. */
static void mode_full_white(void)
{
    render_frame_targeted(-1, -1, 0xFFFF, -1, -1);
}

/* ===== Image render: 12 row × 48 col × RGB =============================
 * Logical resolution: 12 chip-rows × 48 cols (= 3 X-regions × 16 bits/chip) × RGB.
 * Mapping (chain → image col):
 *   region   = chain / 3                 // 0=右组(chain 0-2), 1=中组(3-5), 2=左组(6-8)
 *   color    = chain % 3                 // 0=R, 1=G, 2=B
 *   x_base   = (2 - region) * 16         // image col offset (left→right = 0→47)
 *   bit b in chain word ↔ image[chip][x_base + b][color]
 *
 * 1-bit per channel (threshold > 128). Grayscale needs BCM frames — TODO. */
#define PANEL_IMG_W   48
#define PANEL_IMG_H   12

/* Weak symbol — gets overridden if panel_image_data.c provides a strong def.
 * Default test pattern: vertical color bands (3 R, 3 G, 3 B groups) to verify
 * bit→column mapping orientation. */
__attribute__((weak)) const u8 panel_image[PANEL_IMG_H][PANEL_IMG_W][3] = {
    [0 ... 11] = {
        [0  ... 15] = {255, 0, 0},     /* left 16 cols: red */
        [16 ... 31] = {0, 255, 0},     /* mid 16 cols: green */
        [32 ... 47] = {0, 0, 255},     /* right 16 cols: blue */
    }
};

static void mode_image_render(void)
{
    vsync_pulse();
    panel_seq_set_sdi_mask(0x1FF);

    for (int row_iter = 0; row_iter < 384; row_iter++) {
        icnd3019_advance_row(row_iter == 0 ? 1 : 0);
        panel_seq_row_pulse(row_iter == 0 ? 12 : 4);

        for (u32 latch = 0; latch < CHIPS_PER_CHAIN; latch++) {
            int chip = (int)((u32)(CHIPS_PER_CHAIN - 1) - latch);
            for (int c = 0; c < 9; c++) {
                int region = c / 3;
                int color  = c % 3;
                int x_base = (2 - region) * 16;
                u16 mask = 0;
                for (int b = 0; b < 16; b++) {
                    if (panel_image[chip][x_base + b][color] > 128)
                        mask |= (u16)(1u << b);
                }
                panel_seq_set_chain_data(c, mask);
            }
            u8 le = (latch == (u32)(CHIPS_PER_CHAIN - 1)) ? 1 : 0;
            panel_seq_word_perchain(le);
        }
        panel_seq_word(0, 0);
    }
}

/* Chain ID sweep: light ONE chain at a time (all chips, all bits, all rows),
 * cycle 0..8 every 300 frames (~3s @ 100fps). Use to determine chain→X mapping.
 * Each chain lights as a vertical region; eye observes its X position on panel.
 * UART prints current chain every switch for sync. */
static void mode_chain_id(void)
{
    static u32 frame = 0;
    static int last_chain = -1;
    int target_chain = (int)((frame / 300) % 9);
    if (target_chain != last_chain) {
        xil_printf("[chain_id] now lighting chain %d (%c%d)\r\n",
                   target_chain,
                   "RGB"[target_chain % 3], (target_chain / 3) + 1);
        last_chain = target_chain;
    }
    frame++;
    render_frame_targeted(target_chain, -1, 0xFFFF, -1, -1);
}

/* Single pixel sweep: target_chain=0, target_bit=0, target_chip cycles
 * 0..11 every 60 frames. Use to verify chip→Y panel position mapping. */
__attribute__((unused))
static void mode_single_pixel(void)
{
    static u32 frame_x = 0;
    frame_x++;
    int target_chip = (int)((frame_x / 60) % CHIPS_PER_CHAIN);
    render_frame_targeted(/*chain*/ 0, target_chip, /*mask*/ 0x0001, -1, -1);
}

/* Two-phase calibration sweep (UART-synced with host cap_sweep.py).
 *   Phase 1 (1728 tuple): iterate (chain, chip, bit) — print "[CAL] idx C K B"
 *   Phase 2 ( 384 tuple): fixed (P2_CHAIN, P2_CHIP, P2_BIT), sweep row_iter
 *                         — print "[CAL2] idx C K B R" */
#define CALIB_FRAMES_PER_TUPLE     8
#define CALIB_TOTAL                (9 * CHIPS_PER_CHAIN * 16)
#define CALIB_P2_CHAIN             0
#define CALIB_P2_CHIP              6
#define CALIB_P2_BIT               0
#define CALIB_P2_FRAMES_PER_TUPLE  20
#define CALIB_P2_TOTAL             384

__attribute__((unused))
static void mode_calib_sweep(void)
{
    static int phase = 1;
    static u32 idx = 0;
    static u32 frame_in_tuple = 0;
    static int announced = 0;

    if (!announced) {
        xil_printf("[CAL_BEGIN] p1=%d p2=%d p1_frames=%d p2_frames=%d\r\n",
                   CALIB_TOTAL, CALIB_P2_TOTAL,
                   CALIB_FRAMES_PER_TUPLE, CALIB_P2_FRAMES_PER_TUPLE);
        announced = 1;
    }

    if (phase == 1) {
        if (idx >= CALIB_TOTAL) {
            xil_printf("[CAL_END_P1]\r\n");
            phase = 2; idx = 0; frame_in_tuple = 0;
            usleep(500000);
            return;
        }
        int target_chain = (int)(idx / (CHIPS_PER_CHAIN * 16));
        int target_chip  = (int)((idx / 16) % CHIPS_PER_CHAIN);
        int target_bit   = (int)(idx % 16);
        u16 target_mask  = (u16)(1u << target_bit);

        render_frame_targeted(target_chain, target_chip, target_mask, -1, -1);

        if (++frame_in_tuple >= CALIB_FRAMES_PER_TUPLE) {
            usleep(50000);
            xil_printf("[CAL] %u %d %d %d\r\n",
                       (unsigned)idx, target_chain, target_chip, target_bit);
            idx++; frame_in_tuple = 0;
        }
    } else {  /* phase 2 */
        if (idx >= CALIB_P2_TOTAL) {
            xil_printf("[CAL_END_P2]\r\n[CAL_DONE]\r\n");
            phase = 1; idx = 0; frame_in_tuple = 0; announced = 0;
            usleep(3000000);
            return;
        }
        int target_row = (int)idx;
        u16 mask = (u16)(1u << CALIB_P2_BIT);
        render_frame_targeted(CALIB_P2_CHAIN, CALIB_P2_CHIP, mask,
                              target_row, target_row);

        if (++frame_in_tuple >= CALIB_P2_FRAMES_PER_TUPLE) {
            usleep(50000);
            xil_printf("[CAL2] %u %d %d %d %d\r\n",
                       (unsigned)idx, CALIB_P2_CHAIN, CALIB_P2_CHIP,
                       CALIB_P2_BIT, target_row);
            idx++; frame_in_tuple = 0;
        }
    }
}

/* ===== Public API ====================================================== */

/* Active mode selector — change here to pick which mode drives the panel. */
#define LED_PANEL_MODE_FULL_WHITE     1
#define LED_PANEL_MODE_SINGLE_PIXEL   2
#define LED_PANEL_MODE_CALIB_SWEEP    3
#define LED_PANEL_MODE_CHAIN_ID       4
#define LED_PANEL_MODE_IMAGE          5

#ifndef LED_PANEL_MODE
#  define LED_PANEL_MODE  LED_PANEL_MODE_IMAGE
#endif

void led_panel_init(void)
{
    xil_printf("[led_panel] init: W=%d H=%d scan=%d chips/chain=%d chain=%d\r\n",
               PANEL_W, PANEL_H, SCAN_LINES, CHIPS_PER_CHAIN, GROUPS);
    if (led_panel_init_pins() < 0) {
        xil_printf("[led_panel] init_pins FAIL\r\n");
        return;
    }
    panel_init_chip();
    xil_printf("[led_panel] boot init done. mode=%d\r\n", LED_PANEL_MODE);
}

void led_panel_multi_mode_diag(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;
    static int announced = 0;
    if (!announced) {
#if LED_PANEL_MODE == LED_PANEL_MODE_FULL_WHITE
        xil_printf("\r\n=== MODE: FULL WHITE ===\r\n");
#elif LED_PANEL_MODE == LED_PANEL_MODE_SINGLE_PIXEL
        xil_printf("\r\n=== MODE: SINGLE PIXEL (chip sweep 0..11) ===\r\n");
#elif LED_PANEL_MODE == LED_PANEL_MODE_CALIB_SWEEP
        xil_printf("\r\n=== MODE: CALIB SWEEP (P1 1728 + P2 384) ===\r\n");
#elif LED_PANEL_MODE == LED_PANEL_MODE_CHAIN_ID
        xil_printf("\r\n=== MODE: CHAIN ID (one chain at a time, 3s each, 9 chain) ===\r\n");
#elif LED_PANEL_MODE == LED_PANEL_MODE_IMAGE
        xil_printf("\r\n=== MODE: IMAGE RENDER (12 chip × 3 region × RGB) ===\r\n");
#endif
        announced = 1;
    }
#if LED_PANEL_MODE == LED_PANEL_MODE_FULL_WHITE
    mode_full_white();
#elif LED_PANEL_MODE == LED_PANEL_MODE_SINGLE_PIXEL
    mode_single_pixel();
#elif LED_PANEL_MODE == LED_PANEL_MODE_CALIB_SWEEP
    mode_calib_sweep();
#elif LED_PANEL_MODE == LED_PANEL_MODE_CHAIN_ID
    mode_chain_id();
#elif LED_PANEL_MODE == LED_PANEL_MODE_IMAGE
    mode_image_render();
#else
#  error "Unknown LED_PANEL_MODE"
#endif
}
