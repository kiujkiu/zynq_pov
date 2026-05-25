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

/* ===== DCLK / LE primitives ============================================
 * 2026-05-22: DCLK/LE/SDI 改由 PL led_panel_seq IP 驱动 (ARM bit-bang 1.67 MHz
 * 跑不动 chip 4 MHz min). ARM 这边 pulse_dclk/le_pulse_broadcast/le_marker 退化为
 * 调 panel_seq_* helper. gpio_set/clr_bits 还是控 OE/ABC/SPI bit, axi_gpio 通道
 * 保留 18-bit output (bit 0/1/3-11 是 dead, Vivado auto LOC 到无连接 pin). */
#include "panel_seq.h"

/* pulse_dclk 残留 stub — 不需要再 ARM toggle, PL IP 自动. 留空避免误用. */
static inline void pulse_dclk(void) { (void)0; }

/* Broadcast 16-bit word on all 9 SDI chain, LE 高最后 le_count 个 DCLK. */
static void le_pulse_broadcast(u8 le_count, u16 sdi_data)
{
    if (!pins_ok) return;
    if (le_count == 0 || le_count > 16) return;
    panel_seq_word(sdi_data, le_count);
    return;
    /* legacy code below kept for ref but unreachable */
    const u8 le_start = (u8)(16 - le_count);

    u32 b0 = (sdi_data >> 15) & 1u;
    gpio_write_field(SDI_MASK, b0 ? SDI_MASK : 0);
    if (0 >= le_start) gpio_set_bits(LE_M); else gpio_clr_bits(LE_M);

    for (u8 i = 0; i < 16; i++) {
        pulse_dclk();
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
 * VSYNC 都用这个. 2026-05-22: 走 PL IP. */
static void le_marker(u8 le_count)
{
    if (!pins_ok) return;
    if (le_count == 0 || le_count > 31) return;
    panel_seq_marker(le_count);
}

/* WR_CFG: 写 cascade chain 所有 chip 同一寄存器同一值 (broadcast).
 * 实现: 把 16-bit word shift CHIPS_PER_CHAIN 次 (LE=0), 末次 LE 高 5 DCLK.
 * 同样使用 "预写 → DCLK ↑↓" 顺序保证 SDI 在 DCLK ↑ 之前 settle. */
static void wr_cfg(u8 addr, u8 val)
{
    if (!pins_ok) return;
    const u16 word = ((u16)addr << 8) | val;
    /* 2026-05-22: PL IP 版. shift word CHIPS_PER_CHAIN-1 次 no-LE (broadcast),
     * 末次 LE=5 (WR_CFG). PL IP 自动处理 SDI settle 时序. */
    for (u8 chip = 0; chip < (u8)(CHIPS_PER_CHAIN - 1); chip++) {
        panel_seq_word(word, 0);
    }
    panel_seq_word(word, LE_WR_CFG);
}

static void pre_act(void)     { le_marker(LE_PRE_ACT); }
static void en_op(void)       { le_marker(LE_EN_OP); }

/* RD_CFG: PL IP 版, 跟 wr_cfg 同, 末次 LE=7. */
static void rd_cfg(u8 addr)
{
    if (!pins_ok) return;
    const u16 word = ((u16)addr << 8);
    for (u8 chip = 0; chip < (u8)(CHIPS_PER_CHAIN - 1); chip++) {
        panel_seq_word(word, 0);
    }
    panel_seq_word(word, 7);
}

/* legacy rd_cfg body (deleted, kept stub forward decl above). */
static void __attribute__((unused)) rd_cfg_legacy(u8 addr)
{
    if (!pins_ok) return;
    const u16 word = ((u16)addr << 8);
    gpio_clr_bits(LE_M);
    u32 b0 = (word >> 15) & 1u;
    gpio_write_field(SDI_MASK, b0 ? SDI_MASK : 0);
    for (u8 chip = 0; chip < CHIPS_PER_CHAIN - 1; chip++) {
        for (u8 i = 0; i < 16; i++) {
            pulse_dclk();
            u8 next_i = (u8)((i + 1) % 16);
            u32 bn = (word >> (15 - next_i)) & 1u;
            gpio_write_field(SDI_MASK, bn ? SDI_MASK : 0);
        }
    }
    le_pulse_broadcast(7 /* LE_RD_CFG */, word);
}

/* RD_CFG + 同时采样 axi_gpio_panel ch2 输入 (SPI_MISO_IN @ J1.9).
 * 如果 chip SDO 物理连到 J1.9, 这里会读到 16-bit chain SDO 数据.
 * 写法: pulse_dclk 16×CHIPS_PER_CHAIN 次, 每次后采样 ch2 数据.
 * 返回 chain 末尾那 16 个 bit 组成的 u16 (假设 chip 在第一个 chip 位置). */
static u32 rd_cfg_and_sample_sdo(u8 addr)
{
    if (!pins_ok) return 0xDEADBEEF;
    rd_cfg(addr);
    /* RD_CFG 后 chip 在 SDO 推数据. 准备 SDI 低, LE 低, 让 chain 静默. */
    gpio_clr_bits(LE_M);
    gpio_write_field(SDI_MASK, 0);

    /* shift 16 × CHIPS_PER_CHAIN DCLK, 收 16*CHIPS_PER_CHAIN 个 bit */
    u32 sdo_history = 0;
    for (u8 i = 0; i < 16u * CHIPS_PER_CHAIN; i++) {
        pulse_dclk();
        /* axi_gpio ch2 data register @ +0x08, 1-bit input (SPI_MISO_IN) */
        u32 b = Xil_In32((UINTPTR)LED_PANEL_GPIO_BASE + 0x08) & 1u;
        sdo_history = (sdo_history << 1) | b;
    }
    return sdo_history;  /* 末尾 32 bit (含最后 32 个采样) */
}

/* Forward decl needed: vsync_pulse + icnd3019 helpers static def below in file. */
static void vsync_pulse(void);
static inline void icnd3019_load_first(void);
static inline void icnd3019_clk(void);

/* 公开接口: 纯 DCLK 速率测试. 死循环 toggle DCLK, 不写别的 GPIO,
 * 用逻辑分析仪量 max DCLK 频率. 跑 1 秒后回. */
void led_panel_max_dclk_speed_test(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;
    /* mirror 设为只 DCLK 状态 base (保留 SPI_CS 高, 其余 0) */
    gpio_mirror = SPI_CS_M;
    volatile u32 *gpio = (volatile u32 *)(LED_PANEL_GPIO_BASE + GPIO_DATA_OFF);
    /* 跑 ~10M 个 toggle (= 5M DCLK cycles). 如果 10 MHz 跑 1 秒, 5M=半秒. */
    for (u32 i = 0; i < 5000000UL; i++) {
        *gpio = SPI_CS_M | DCLK_M;
        *gpio = SPI_CS_M;
    }
}

/* 公开接口: 暴力全亮测试. 跳过 scan ratio + ROW pulse,
 * 让 chip 在最简单状态输出. 用逻辑分析仪扎 chip OUT pin 看是否有 PWM. */
void led_panel_force_all_white_test(void)
{
    /* 严格按手册协议:
     *   boot 1 次: PRE_ACT + password + PLL/SCAN/GAIN + password close (NO EN_OP)
     *   首帧:    VSYNC + 16 DCLK + ROW=12 + 192 LATCH + EN_OP (only once!)
     *   后续帧:  VSYNC + 16 DCLK + ROW=12 + 192 LATCH
     *   (manual: 芯片上电后通道默认关, "完成第一帧数据接收后"才发 EN_OP 开输出) */
    static int boot_done = 0;
    static int en_op_done = 0;

    if (!pins_ok && led_panel_init_pins() < 0) return;

    if (!boot_done) {
        /* 最小 init: 不写任何寄存器, 全部用 power-on default.
         * 默认 PLL = PRE 2/LOOP 4/POST 1 → GCLK = 8.33 × 2 = 16.7 MHz ✓ 在 7-96 MHz 范围.
         * 默认 GAIN = 0xC0 = 150%, 够亮. 默认 SCAN 未明, 但每帧只发 1 ROW=12 marker.
         * EN_OP 还是要发 (chip 上电默认 OFF), 但移到首帧 LATCH 后面. */
        boot_done = 1;
    }

    /* 每帧 protocol: VSYNC + 16 DCLK gap + ROW=12 + 16 LATCH (每 LATCH cascade 12 chip) + BIN.
     * 关键修正: 手册一个 DATA_LATCH 应该 shift N×16 bits (N=12 cascade) + 1 LE=1.
     * 每行 16 LATCH 覆盖 16 channel, 不是 192 LATCH. 官方波形实测 LATCH:ROW ≈ 16:1. */
    vsync_pulse();
    panel_seq_word(0, 0);          /* 16 DCLK gap */
    panel_seq_row_pulse(12);       /* ROW=12 first-row marker */
    icnd3019_clk();                /* ICND3019 chain advance */

    /* 16 LATCH per row: 每 LATCH = 11 word LE=0 (shift chip 1..11) + 1 word LE=1 (shift chip 12 + LATCH all) */
    for (int ch = 0; ch < 16; ch++) {
        panel_seq_burst_word(0xFFFF, 0, CHIPS_PER_CHAIN - 2);  /* 11 words LE=0 */
        panel_seq_word(0xFFFF, 1);                             /* 1 word LE=1 (LATCH 该 channel) */
    }

    /* 首帧 LATCH 完成后才能发 EN_OP. 之后 EN_OP 状态一直保持. */
    if (!en_op_done) {
        en_op();
        en_op_done = 1;
    }

    /* DCLK keepalive: 让 PLL 不失锁 + chip 跑 PWM 显示 */
    panel_seq_dclk_keepalive(5000);
}

/* 公开接口: RD_CFG bring-up test. 每帧发一次:
 *   PRE_ACT + password(0xAA) + WR_CFG reg=0x02 val=53 + password(0x55)
 *   + EN_OP + 100us gap (sequence boundary marker)
 *   + RD_CFG reg=0x02
 * 之后 100ms 全沉默给逻辑分析仪稳定 trigger. */
void led_panel_rd_cfg_test_burst(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;

    /* 同步标记: 50-DCLK LE 让 trigger 容易锁 */
    le_marker(50);
    for (int i = 0; i < 8; i++) pulse_dclk();

    /* 标准 init */
    pre_act();
    for (int i = 0; i < 8; i++) pulse_dclk();
    wr_cfg(REG_PASSWORD_A, 0xAA);
    wr_cfg(REG_PASSWORD_B, 0xAA);
    wr_cfg(REG_SCAN, (u8)(SCAN_LINES - 1));
    wr_cfg(REG_PASSWORD_A, 0x55);
    wr_cfg(REG_PASSWORD_B, 0x55);
    en_op();
    for (int i = 0; i < 8; i++) pulse_dclk();

    /* === 关键: RD_CFG + 同时通过 J1.9 SPI_MISO_IN 采样 SDO ===
     * 如果 chip SDO 物理连到 J1.9, sample 出来的值会含 reg 0x02 = 53 = 0x35.
     * 如果一直 0 或一直 1, 说明 SDO 不在这条线上, 要换探针物理位置. */
    u32 sdo = rd_cfg_and_sample_sdo(REG_SCAN);
    xil_printf("[rd_cfg] reg=0x%02x wrote=0x%02x sdo_tail32=0x%08x\r\n",
               REG_SCAN, (u8)(SCAN_LINES - 1), (unsigned)sdo);

    /* 100ms 静默, 让示波器有清晰 sequence 边界 */
    for (volatile u32 i = 0; i < 5000000UL; i++) ;
}
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
    /* ICND3019 datasheet: DCLK 脉宽 (高电平) 建议 ≥500ns 当消影时间.
     * ARM AXI write ~40ns 不够, 必须加 busy-loop delay 到 ~1µs 高. */
    gpio_set_bits(ABC_BIN);                          /* DCLK ↑ */
    for (volatile int i = 0; i < 300; i++) ;         /* ~1µs HIGH (>500ns blanking) */
    gpio_clr_bits(ABC_BIN);                          /* DCLK ↓ */
    for (volatile int i = 0; i < 100; i++) ;         /* ~300ns LOW (display gap + setup) */
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
 * 普通模式 + 2.5V 消隐: N=21 (Reg=1101) — datasheet default.
 * 然后清 384-bit chain + load_first 选第 1 行 (这步必须做 1 次, 否则 chain
 * 残留导致多行被拉低或没行被拉低, 全黑). 只在 boot 调用 1 次, 不能放进 main
 * loop, 否则 ARM 70µs GPIO toggle 期间 PL DCLK 停 → ICND1069 PLL 失锁 → 不亮. */
static void icnd3019_init(void)
{
    if (!pins_ok) return;
    /* 确保 DCLK (BIN) 低. ICND3019 datasheet: RCLK 配置区域必须 DCLK 低, 前后各 100ns 空白. */
    gpio_clr_bits(ABC_BIN);
    for (volatile int i = 0; i < 100; i++) ;
    /* 发 21 个 RCLK (CIN) 脉冲 → Reg<3:0>=13 (普通模式 + 2.5V 消隐).
     * 每个 RCLK pulse 同样需要足够宽度 (~500ns) chip 才能采到. */
    for (int i = 0; i < 21; i++) {
        gpio_set_bits(ABC_CIN);
        for (volatile int j = 0; j < 200; j++) ;     /* ~600ns HIGH */
        gpio_clr_bits(ABC_CIN);
        for (volatile int j = 0; j < 100; j++) ;     /* ~300ns LOW */
    }
    for (volatile int i = 0; i < 100; i++) ;         /* 配置后 100ns 空白 */
    /* chain clear 384 个 0, 然后 load_first 注 "1" 选行 0. */
    gpio_clr_bits(ABC_AIN);
    for (int i = 0; i < 24 * 16; i++) icnd3019_clk();
    icnd3019_load_first();
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

    /* === TEST MARKER (2026-05-21 debug) ====================================
     * 每帧开头发 3 个 LE 标记宽度 50/14/11 DCLK, 验证 le_marker() 是否
     * 真能产生宽 LE 脉冲. 如逻辑分析仪看不到这 3 个宽脉冲, 说明 le_marker
     * 函数本身有 bug, 不是 boot 单次 init 错过窗口. */
    le_marker(50);              /* 77us, 明显不同于任何协议命令 */
    for (int i = 0; i < 8; i++) pulse_dclk();  /* gap */
    le_marker(LE_PRE_ACT);      /* 14 DCLK */
    for (int i = 0; i < 8; i++) pulse_dclk();  /* gap */
    le_marker(LE_EN_OP);        /* 11 DCLK */
    for (int i = 0; i < 8; i++) pulse_dclk();  /* gap */

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
    /* DEBUG: 连续 BIN toggle, ~50 kHz. scope 不需要 trigger 也能看到方波.
     * SDI=0 → 只 shift 0, chain 会清空. 然后偶尔 load_first 注入一个 1. */
    gpio_clr_bits(ABC_AIN);   /* SDI=0 */
    while (1) {
        for (int i = 0; i < 1000; i++) {
            icnd3019_clk();
            /* icnd3019_clk 内置已有 ~1.3µs 总周期 */
        }
        /* 每 1000 个 BIN pulse 后 load 一个 1 进 chain, 让 OUT 也可见变化 */
        gpio_set_bits(ABC_AIN);
        icnd3019_clk();
        gpio_clr_bits(ABC_AIN);
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
