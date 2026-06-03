/*
 * led_panel.c — ICND1069 V1.2 LE 协议 driver (ARM bit-bang)
 *
 * 修正历史 (2026-05-18):
 *   v3 — 加入 ROW 信号正确驱动 + PANEL_H=180 + SCAN_LINES=20
 *
 * 接线图协议重新解释 (按 ICND1069 编程指导 V1.2):
 *   J1.10 (DCLK)  → ICND1069 DCLK
 *   J1.12 (LAT)   → ICND1069 LE  (长度编码命令)
 *   J1.14 (GCLK)  → **ICND1069 ROW** (高电平宽度 12/4 DCLK 编码行同步)
 *                  注意接线图作者标"GCLK 可 NC"是错的!
 *   J1.16/18/19/20/21/22/23/24/25 (9 RGB 数据线) → 9 个 SDI chain
 *   J1.26/27/28 (CIN/BIN/AIN) → panel 上 ICND3019 行驱 SDI/DCLK/RCLK
 *                  AIN = ICND3019 SDI (chain 输入 "1" 选第 1 行)
 *                  BIN = ICND3019 DCLK (每 ↑ 移到下一行)
 *                  CIN = ICND3019 RCLK (init 寄存器配置)
 *   J1.11/13/15/9 (SPI 4 线) → panel 上 25VA16AT1G flash, idle 保持
 *
 * Panel: 160 × 180 RGB, 108 ICND1069 (9 chain × 12 cascade) + 24 ICND3019.
 * 1/20 scan: 9 chain × 20 row each = 180 row. 寄存器 0x02 = 19 (scan-1).
 *
 * 协议流程:
 *   init: PRE_ACT + WR_CFG password + 配置寄存器 + WR_CFG 关 password + EN_OP
 *   每帧: VSYNC + 16 DCLK 等 + 第 1 scan (ROW 高 12 DCLK 同时数据 shift) +
 *         其余 scan (ROW 高 4 DCLK 同时数据 shift) + 帧结束
 *   每 scan 需 DATA_LATCH (LE=1) × CHIPS_PER_CHAIN × 16 ch 次 (broadcast 9 chain)
 *   每 scan 后 row_advance (ICND3019 chain 移到下一行)
 */

#include "led_panel.h"
#include "xil_io.h"
#include "xil_printf.h"

#ifndef LED_PANEL_GPIO_BASE
#  define LED_PANEL_GPIO_BASE 0x40000000UL
#endif
#define GPIO_DATA_OFF  0x00
#define GPIO_TRI_OFF   0x04

#define BIT(n)  (1u << (n))
#define DCLK_M    BIT(LED_BIT_DCLK)
#define LE_M      BIT(LED_BIT_LE)
#define ROW_M     BIT(LED_BIT_ROW)
#define R1_M      BIT(LED_BIT_R1)
#define G1_M      BIT(LED_BIT_G1)
#define B1_M      BIT(LED_BIT_B1)
#define R2_M      BIT(LED_BIT_R2)
#define G2_M      BIT(LED_BIT_G2)
#define B2_M      BIT(LED_BIT_B2)
#define R3_M      BIT(LED_BIT_R3)
#define G3_M      BIT(LED_BIT_G3)
#define B3_M      BIT(LED_BIT_B3)
#define SDI_MASK  (R1_M|G1_M|B1_M|R2_M|G2_M|B2_M|R3_M|G3_M|B3_M)
#define ABC_AIN   BIT(LED_BIT_AIN)
#define ABC_BIN   BIT(LED_BIT_BIN)
#define ABC_CIN   BIT(LED_BIT_CIN)
#define SPI_CS_M  BIT(LED_BIT_SPI_CS)

/* LE 长度编码 (V1.2 page 5) */
#define LE_DATA_LATCH  1
#define LE_VSYNC       3
#define LE_WR_CFG      5
#define LE_EN_OP       11
#define LE_DIS_OP      12
#define LE_PRE_ACT     14

/* 寄存器 */
#define REG_PASSWORD_A   0x00
#define REG_PASSWORD_B   0x01
#define REG_SCAN         0x02   /* bit[5:0] = scan-1 */
#define REG_GROUPS       0x03   /* sub-frames-1 */

/* Cascade chips per chain. 9 chain × 12 = 108 (匹配接线图 9 RGB 数据线 + 108 chip).
 * 注: cascade 链长错 → password broadcast 错位 → init 失败 → panel 全黑. */
#ifndef CHIPS_PER_CHAIN
#  define CHIPS_PER_CHAIN  12
#endif

/* ===== state ========================================================== */
static u8  fb[PANEL_H][PANEL_W][3];
static u32 gpio_mirror;
static int pins_ok;
static int warned;

static inline void gpio_commit(void)
{
    if (LED_PANEL_GPIO_BASE)
        Xil_Out32((UINTPTR)LED_PANEL_GPIO_BASE + GPIO_DATA_OFF, gpio_mirror);
}
static inline void gpio_set_bits(u32 m) { gpio_mirror |= m; gpio_commit(); }
static inline void gpio_clr_bits(u32 m) { gpio_mirror &= ~m; gpio_commit(); }
static inline void gpio_write_field(u32 mask, u32 val)
{
    gpio_mirror = (gpio_mirror & ~mask) | (val & mask);
    gpio_commit();
}

int led_panel_init_pins(void)
{
    if (!LED_PANEL_GPIO_BASE) {
        if (!warned) {
            xil_printf("[led_panel] WARN: LED_PANEL_GPIO_BASE=0\r\n");
            warned = 1;
        }
        pins_ok = 0;
        return -1;
    }
    Xil_Out32((UINTPTR)LED_PANEL_GPIO_BASE + GPIO_TRI_OFF, 0u);
    /* idle: SPI_CS=1, AIN/BIN/CIN 默认 1 (假设它们是 panel chain group enable) */
    gpio_mirror = SPI_CS_M | ABC_AIN | ABC_BIN | ABC_CIN;
    gpio_commit();
    pins_ok = 1;
    return 0;
}

/* ===== DCLK / LE primitives ========================================== */
static inline void pulse_dclk(void)
{
    gpio_set_bits(DCLK_M);
    gpio_clr_bits(DCLK_M);
}

/* Broadcast 16-bit word on all 9 SDI chain, LE high last `le_count` DCLK
 * → ICND1069 解析为 LE=`le_count` 命令 (在 LE 下降沿 latch).
 * panel 上 SDI 经 2 次 74HC245 buffer 有延迟, 必须确保 DCLK ↑ 之前 SDI 已 settle:
 *   预写下一 bit → DCLK ↑↓ (chip 在 ↑ 采当前 SDI). */
static void le_pulse_broadcast(u8 le_count, u16 sdi_data)
{
    if (!pins_ok) return;
    if (le_count == 0 || le_count > 16) return;
    const u8 le_start = (u8)(16 - le_count);

    /* 预写 bit 0 + LE state 0, 让 DCLK ↑ 前 SDI 已 settle */
    u32 b0 = (sdi_data >> 15) & 1u;
    gpio_write_field(SDI_MASK, b0 ? SDI_MASK : 0);
    if (0 >= le_start) gpio_set_bits(LE_M); else gpio_clr_bits(LE_M);

    for (u8 i = 0; i < 16; i++) {
        pulse_dclk();  /* chip 在 ↑ 采 SDI[i] (已 settle) */
        /* 在 DCLK ↓ 之后立即写 SDI[i+1], 给 buffer 延迟时间 settle */
        if (i < 15) {
            u32 bn = (sdi_data >> (15 - (i + 1))) & 1u;
            gpio_write_field(SDI_MASK, bn ? SDI_MASK : 0);
            if ((i + 1) >= le_start) gpio_set_bits(LE_M);
            else                     gpio_clr_bits(LE_M);
        }
    }
    gpio_clr_bits(LE_M);
    gpio_clr_bits(SDI_MASK);
}

/* Marker-only (no data): LE 高 le_count DCLK. PRE_ACT / EN_OP / DIS_OP /
 * VSYNC 都用这个. */
static void le_marker(u8 le_count)
{
    if (!pins_ok) return;
    if (le_count == 0) return;
    gpio_set_bits(LE_M);
    for (u8 i = 0; i < le_count; i++) pulse_dclk();
    gpio_clr_bits(LE_M);
}

/* WR_CFG: 写 cascade chain 所有 chip 同一寄存器同一值 (broadcast).
 * 实现: 把 16-bit word shift CHIPS_PER_CHAIN 次 (LE=0), 末次 LE 高 5 DCLK.
 * 同样使用 "预写 → DCLK ↑↓" 顺序保证 SDI 在 DCLK ↑ 之前 settle. */
static void wr_cfg(u8 addr, u8 val)
{
    if (!pins_ok) return;
    const u16 word = ((u16)addr << 8) | val;
    /* prefill cascade with the same word (LE=0). 预写 bit 0. */
    gpio_clr_bits(LE_M);
    u32 b0 = (word >> 15) & 1u;
    gpio_write_field(SDI_MASK, b0 ? SDI_MASK : 0);

    for (u8 chip = 0; chip < CHIPS_PER_CHAIN - 1; chip++) {
        for (u8 i = 0; i < 16; i++) {
            pulse_dclk();
            /* 写下个 bit (current chip 内 next bit 或 next chip 的 bit 0) */
            u8 next_i = (i + 1) % 16;
            u32 bn = (word >> (15 - next_i)) & 1u;
            gpio_write_field(SDI_MASK, bn ? SDI_MASK : 0);
        }
    }
    /* 最后一颗 chip: 使用 le_pulse_broadcast (内含预写顺序) */
    le_pulse_broadcast(LE_WR_CFG, word);
}

static void pre_act(void)     { le_marker(LE_PRE_ACT); }
static void en_op(void)       { le_marker(LE_EN_OP); }
__attribute__((unused)) static void dis_op(void) { le_marker(LE_DIS_OP); }
static void vsync_pulse(void) { le_marker(LE_VSYNC); }
static void password(u8 v)
{
    wr_cfg(REG_PASSWORD_A, v);
    wr_cfg(REG_PASSWORD_B, v);
}

/* ROW 信号: 高电平宽度编码 (12 DCLK = group-1 row-1, 4 DCLK = next row).
 * SDI 数据 shift 跟 ROW 信号同步进行 (ICND1069 期望). */
static void row_pulse(u8 dclks_high)
{
    if (!pins_ok) return;
    gpio_set_bits(ROW_M);
    for (u8 i = 0; i < dclks_high; i++) pulse_dclk();
    gpio_clr_bits(ROW_M);
}

/* ===== ICND3019 行扫 ================================================
 * ICND3019 datasheet:
 *   AIN (chip SDI):  chain 数据输入
 *   BIN (chip DCLK): 上升沿 shift register +1
 *   CIN (chip RCLK): DCLK 低期间 N 个 RCLK 上升沿配置寄存器, Reg[3:0]=N-8
 *   默认 Reg=1101 (= N=21, 普通模式 + 2.5V 消隐)
 *
 * 一颗 ICND3019 16 channel NMOS, 24 颗 cascade × 16 = 384 row select.
 * panel 用其中 180 (剩 204 备用 / NC).
 */
static inline void icnd3019_clk(void)
{
    gpio_set_bits(ABC_BIN);   /* DCLK ↑ */
    gpio_clr_bits(ABC_BIN);   /* DCLK ↓ */
}
static inline void icnd3019_load_first(void)
{
    /* 帧开始: SDI=1, 1 个 DCLK 上升沿 → chain shift in "1" → 选中第 1 行 (OUT0 拉低) */
    gpio_set_bits(ABC_AIN);
    icnd3019_clk();
    gpio_clr_bits(ABC_AIN);
}
static inline void icnd3019_next_row(void)
{
    /* SDI=0, 1 个 DCLK 上升沿 → 移到下一行 */
    gpio_clr_bits(ABC_AIN);
    icnd3019_clk();
}

/* ICND3019 寄存器配置: DCLK 低期间发 N 个 RCLK ↑, 设 Reg[3:0] = N - 8.
 * 普通模式 + 2.5V 消隐: N=21 (Reg=1101) — datasheet default. */
static void icnd3019_init(void)
{
    if (!pins_ok) return;
    /* 确保 DCLK (BIN) 低 */
    gpio_clr_bits(ABC_BIN);
    /* 发 21 个 RCLK (CIN) ↑ 设置普通模式 */
    for (int i = 0; i < 21; i++) {
        gpio_set_bits(ABC_CIN);
        gpio_clr_bits(ABC_CIN);
    }
}

/* ===== Init ========================================================== */
static void icnd1069_init(void)
{
    /* DCLK warmup — 持续 DCLK 让 ICND1069 内部 PLL 锁相 */
    for (int i = 0; i < 2000; i++) pulse_dclk();

    /* V1.2 page 7-8 写寄存器流程 */
    pre_act();
    password(0xAA);

    wr_cfg(REG_SCAN,   (u8)(SCAN_LINES - 1));  /* scan-1 = 53 for 1/54 */
    wr_cfg(REG_GROUPS, 0x07);                   /* 8 sub-frames - 1 */
    wr_cfg(0x04,       0x02);                   /* PLL_PRE_DIV */
    wr_cfg(0x05,       0x04);                   /* PLL_LOOP_DIV */
    wr_cfg(0x06,       0x01);                   /* PLL_POST_DIV */
    wr_cfg(0x07,       0x20);                   /* DCLK per row / 4 */
    wr_cfg(0x1C,       0xFF);                   /* GAIN 200% (max bright for debug) */

    password(0x55);
    en_op();

    /* 再 warmup 让 EN_OP 之后 PWM 启动 */
    for (int i = 0; i < 2000; i++) pulse_dclk();
}

/* ===== 数据发送 (每 scan 一行) ===================================== */
/* 9 chain × 12 chip × 16 ch × 16 bit-grey 数据.
 * cascade order: chain tail (last chip OUT15) → head (first chip OUT0).
 * 每 chip 16 ch grey scale = 16 × DATA_LATCH 命令 (LE=1).
 * 但 broadcast 9 chain 同时 — 每 LE pulse 锁存 9 个 chain 同 ch 的 16-bit. */
static void emit_row_data(u8 scan)
{
    /* 9 chain 同一 scan 各对应 panel 上不同 group (R1=group0, G1=group1, ...
     * 物理 row index 内部由 panel 上 ICND3019 行选 + ICND1069 scan 联合决定.
     * 此处简化: 假设 chain g 服务 panel row 范围 [g*20 ~ g*20+19], scan 0..19. */
    for (int chip = CHIPS_PER_CHAIN - 1; chip >= 0; chip--) {
        for (int ch = 15; ch >= 0; ch--) {
            int col = chip * 16 + (15 - ch);
            u8 c[9][3] = {{0}};   /* [chain][color], 实际只取 col % 3 那个 */
            if (col >= 0 && col < PANEL_W) {
                for (int g = 0; g < GROUPS; g++) {
                    int prow = g * SCAN_LINES + scan;
                    if (prow < PANEL_H) {
                        c[g][0] = fb[prow][col][0];
                        c[g][1] = fb[prow][col][1];
                        c[g][2] = fb[prow][col][2];
                    }
                }
            }
            /* 每 chain 单独 16-bit grey scale (8-bit *257 expand).
             * SDI 9 chain: R1/G1/B1 = group 0 r/g/b; R2/G2/B2 = group 1;
             *              R3/G3/B3 = group 2. (但 9 chain 数据组只 3 group 不到 9)
             * 简化: 每 chain 都用 group 0 r 灰度 测试 panel 是否反应. */
            const u16 gs[9] = {
                (u16)((u32)c[0][0] * 257u),  /* R1 chain */
                (u16)((u32)c[0][1] * 257u),  /* G1 chain */
                (u16)((u32)c[0][2] * 257u),  /* B1 chain */
                (u16)((u32)c[1][0] * 257u),  /* R2 */
                (u16)((u32)c[1][1] * 257u),  /* G2 */
                (u16)((u32)c[1][2] * 257u),  /* B2 */
                (u16)((u32)c[2][0] * 257u),  /* R3 */
                (u16)((u32)c[2][1] * 257u),  /* G3 */
                (u16)((u32)c[2][2] * 257u),  /* B3 */
            };
            /* shift 16 bit, last cycle LE high (= LE=1 = DATA_LATCH) */
            for (u8 i = 0; i < 16; i++) {
                u32 v = 0;
                if ((gs[0] >> (15-i)) & 1) v |= R1_M;
                if ((gs[1] >> (15-i)) & 1) v |= G1_M;
                if ((gs[2] >> (15-i)) & 1) v |= B1_M;
                if ((gs[3] >> (15-i)) & 1) v |= R2_M;
                if ((gs[4] >> (15-i)) & 1) v |= G2_M;
                if ((gs[5] >> (15-i)) & 1) v |= B2_M;
                if ((gs[6] >> (15-i)) & 1) v |= R3_M;
                if ((gs[7] >> (15-i)) & 1) v |= G3_M;
                if ((gs[8] >> (15-i)) & 1) v |= B3_M;
                gpio_write_field(SDI_MASK, v);
                if (i == 15) gpio_set_bits(LE_M); else gpio_clr_bits(LE_M);
                pulse_dclk();
            }
            gpio_clr_bits(LE_M);
        }
    }
    gpio_clr_bits(SDI_MASK);
}

/* ===== Frame scan ===================================================== */
/* Sanity 模式: 持续 send all-white DATA_LATCH, 验证 init + EN_OP 是否生效.
 * panel 任何 LED 亮 = init OK, 协议方向对.
 * 全黑 = init seq 没生效 或 chain map 完全错. */
#ifndef LED_PANEL_SANITY
#define LED_PANEL_SANITY 1
#endif

#if LED_PANEL_SANITY
/* INIT_REPEAT 模式: 每帧前重发完整 ICND1069 init seq (PRE_ACT + password +
 * 寄存器 + password 关 + EN_OP). 这样示波器持续抓 LE=14/5/11 各种长度脉冲,
 * 能直接 verify init 信号正确到达 panel 上 ICND1069. */
#ifndef LED_PANEL_INIT_REPEAT
#define LED_PANEL_INIT_REPEAT 1
#endif

void led_panel_scan_frame(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;

#if LED_PANEL_INIT_REPEAT
    /* 每帧重发 ICND1069 init: 示波器能持续抓到 LE 各种长度 */
    icnd1069_init();
#endif

    vsync_pulse();
    for (u8 i = 0; i < 16; i++) pulse_dclk();

    for (u8 scan = 0; scan < SCAN_LINES; scan++) {
        for (int i = 0; i < CHIPS_PER_CHAIN * 16; i++) {
            for (u8 j = 0; j < 16; j++) {
                gpio_write_field(SDI_MASK, SDI_MASK);
                if (j == 15) gpio_set_bits(LE_M); else gpio_clr_bits(LE_M);
                pulse_dclk();
            }
            gpio_clr_bits(LE_M);
        }
        gpio_clr_bits(SDI_MASK);
        row_pulse(scan == 0 ? 12 : 4);
    }
}
#else
void led_panel_scan_frame(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;

    vsync_pulse();
    for (u8 i = 0; i < 16; i++) pulse_dclk();

    icnd3019_load_first();

    for (u8 scan = 0; scan < SCAN_LINES; scan++) {
        emit_row_data(scan);
        row_pulse(scan == 0 ? 12 : 4);
        if (scan < SCAN_LINES - 1) icnd3019_next_row();
    }
}
#endif

/* 慢速 ICND3019 chain advance — 不动 ICND1069, 让 user 测 OUT 引脚跟踪 */
void led_panel_icnd3019_slow_scan(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;
    icnd3019_init();
    while (1) {
        /* load row 0 + slow scan all 384 row */
        icnd3019_load_first();
        for (volatile u32 d = 0; d < 20000000UL; d++) ;  /* ~200ms */
        for (int row = 1; row < 24*16; row++) {
            icnd3019_next_row();
            for (volatile u32 d = 0; d < 20000000UL; d++) ;
        }
    }
}

/* ===== SPI master bit-bang (read panel flash for debug) =============== */
static inline u32 gpio_read_miso(void)
{
    if (!LED_PANEL_GPIO_BASE) return 0;
    u32 v = Xil_In32((UINTPTR)LED_PANEL_GPIO_BASE + 0x08);
    return v & 1u;
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

/* ===== Legacy API ==================================================== */
void led_panel_init(void)
{
    xil_printf("[led_panel] ICND1069 V1.2 + ROW driver init: W=%d H=%d scan=%d chips/chain=%d chain=%d\r\n",
               PANEL_W, PANEL_H, SCAN_LINES, CHIPS_PER_CHAIN, GROUPS);
    if (led_panel_init_pins() < 0) return;
    icnd3019_init();   /* ICND3019 RCLK 配置 + 进入普通模式 */
    icnd1069_init();
    led_panel_clear();
    xil_printf("[led_panel] ICND3019 + ICND1069 init done\r\n");
}

void led_panel_set_pixel(int x, int y, u8 r, u8 g, u8 b)
{
    if (x < 0 || x >= PANEL_W || y < 0 || y >= PANEL_H) return;
    fb[y][x][0] = r;
    fb[y][x][1] = g;
    fb[y][x][2] = b;
}

void led_panel_clear(void)
{
    for (int y = 0; y < PANEL_H; y++)
        for (int x = 0; x < PANEL_W; x++)
            fb[y][x][0] = fb[y][x][1] = fb[y][x][2] = 0;
}

void led_panel_flush(void)
{
    led_panel_scan_frame();
}

/* ===== Test patterns ================================================== */
static void pat_solid(u8 r, u8 g, u8 b)
{
    for (int y = 0; y < PANEL_H; y++)
        for (int x = 0; x < PANEL_W; x++)
            led_panel_set_pixel(x, y, r, g, b);
}
static void pat_checker(void)
{
    for (int y = 0; y < PANEL_H; y++)
        for (int x = 0; x < PANEL_W; x++) {
            int c = ((x >> 3) ^ (y >> 3)) & 1;
            u8 v = c ? 0xFF : 0x00;
            led_panel_set_pixel(x, y, v, v, v);
        }
}
static void pat_color_bars(void)
{
    static const u8 bars[8][3] = {
        {0,0,0}, {255,0,0}, {0,255,0}, {255,255,0},
        {0,0,255}, {255,0,255}, {0,255,255}, {255,255,255}
    };
    int seg_w = PANEL_W / 8;
    if (seg_w < 1) seg_w = 1;
    for (int y = 0; y < PANEL_H; y++)
        for (int x = 0; x < PANEL_W; x++) {
            int s = x / seg_w;
            if (s > 7) s = 7;
            led_panel_set_pixel(x, y, bars[s][0], bars[s][1], bars[s][2]);
        }
}
static void pat_groups(void)
{
    for (int y = 0; y < PANEL_H; y++) {
        u8 r=0,g=0,b=0;
        int grp = (y / SCAN_LINES) % 3;
        if (grp == 0) r = 0xFF;
        else if (grp == 1) g = 0xFF;
        else b = 0xFF;
        for (int x = 0; x < PANEL_W; x++)
            led_panel_set_pixel(x, y, r, g, b);
    }
}
static void pat_scan_lines(void)
{
    for (int y = 0; y < PANEL_H; y++) {
        int vi = ((y % SCAN_LINES) + 1) * (256 / SCAN_LINES);
        if (vi > 0xFF) vi = 0xFF;
        u8 v = (u8)vi;
        for (int x = 0; x < PANEL_W; x++)
            led_panel_set_pixel(x, y, v, v, v);
    }
}
void led_panel_test_pattern(int pattern_id)
{
    led_panel_clear();
    switch (pattern_id) {
        case 0: break;
        case 1: pat_solid(0xFF, 0xFF, 0xFF); break;
        case 2: pat_solid(0xFF, 0x00, 0x00); break;
        case 3: pat_solid(0x00, 0xFF, 0x00); break;
        case 4: pat_solid(0x00, 0x00, 0xFF); break;
        case 5: pat_checker(); break;
        case 6: pat_color_bars(); break;
        case 7: pat_groups(); break;
        case 8: pat_scan_lines(); break;
        default: break;
    }
}
