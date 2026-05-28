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

/* Cascade chips per chain. 官方 dsl 解出来 = 1 (每命令 16 DCLK). 完全模仿. */
#ifndef CHIPS_PER_CHAIN
/* 2026-05-27 v9: 回 cascade=12 + 恢复 init */
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

/* 所有 LE 命令 (含 marker 类) 都必须前面有 ≥16 DCLK shift (manual page 5).
 * 多级联时 = cascade × 16. 用 word mode 实现: shift 全 0 数据 cascade 次, 末次末 LE 高 le_count. */
static void le_marker(u8 le_count)
{
    if (!pins_ok) return;
    if (le_count == 0 || le_count > 31) return;
    for (u8 chip = 0; chip < (u8)(CHIPS_PER_CHAIN - 1); chip++) {
        panel_seq_word(0, 0);             /* shift no-LE */
    }
    panel_seq_word(0, le_count);          /* 末 word: 末 le_count DCLK 高 LE */
    /* 2026-05-27: 16 DCLK 全 0 gap, chip 内部 commit 时间 (官方 bin 反解 ~9 DCLK 间隙). */
    panel_seq_word(0, 0);
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
    /* 2026-05-27: 16 DCLK 全 0 gap, chip 写 register file 内部 commit 时间. */
    panel_seq_word(0, 0);
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

/* 多模式诊断 loop. 每 5 秒切换一个 mode, UART 打印当前 mode 名称.
 * scope 接 ICND1069 任意 chip OUT pin (常亮 / 微闪 / 完全黑) + ICND3019 OUT0 (LOW=选中).
 * panel 直视 — 任何 mode 看到 LED 亮哪怕 1 颗都报回. */
static void mode_a_minimal(void);
static void mode_perchain_bars(void);
static void mode_chip_sweep(void);
static void mode_bit_sweep(void);
static void mode_color_grid(void);
static void mode_b_gain_max(void);
static void mode_c_scan_20(void);
static void mode_d_alt_data(void);
static void mode_e_warmup_long(void);

static void mode_f_soft_rst(void);
static void mode_g_n1_cascade(void);
static void mode_h_pure_shift(void);
static void mode_i_periodic_oe(void);

void led_panel_multi_mode_diag(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;
    /* 锁定 Mode A 持续跑, 方便用 scope 在 chip OUT pin 上观察 */
    static int announced = 0;
    if (!announced) {
        xil_printf("\r\n=== LOCKED MODE A: 无 init, 仅 LATCH 0xFFFF + EN_OP (持续) ===\r\n");
        announced = 1;
    }
    for (u32 i = 0; i < 5000; i++) mode_color_grid();
    return;
    /* 旧的 9 模式轮换 (已禁用):
     * static int mode = 0; ... */
}

/* Mode A: 最简但发 ROW 脉冲. chip 必须收到 ROW marker 才会启动行扫描.
 * 每帧: VSYNC + 16 DCLK gap + ROW=12 (first-row marker) + 192 LATCH + EN_OP (首帧) + keepalive
 * BIN 心跳每 100 帧, scope 验证 ICND3019 路径仍通. */
/* 仿造官方波形: SCAN=1/20 + 每帧 20 ROW × 52 DCLK wide + 每行 16 LATCH × 12 chip cascade.
 * 跟前一版 (1/1 scan + 1 ROW=12) 完全不同, 跟硬件 panel 拓扑匹配概率高很多. */
static void icnd3019_advance_row(int inject_one);   /* fwd decl */
static void mode_a_minimal(void)
{
    /* 2026-05-27 22:30: chip 卡死救援 — 显式重写所有寄存器到 datasheet 默认值
     * (之前 SCAN=19 / GAIN=0xFF 错值留在 chip RAM, 上电不复位). */
    static int recovery_done = 0;
    if (!recovery_done) {
        vsync_pulse();
        en_op();
        pre_act();
        wr_cfg(REG_PASSWORD_A, 0xAA);        /* 开 password */
        wr_cfg(REG_PASSWORD_B, 0xAA);
        /* 显式写回所有寄存器默认值 (per ICND1069 V1.2 manual) */
        wr_cfg(0x02, 19);                    /* SCAN: 1/20 scan = 20-1 */
        wr_cfg(0x03, 0x00);                  /* GROUPS: 1 sub-frame */
        wr_cfg(0x04, 0x02);                  /* PLL_PRE_DIV default */
        wr_cfg(0x05, 0x04);                  /* PLL_LOOP_DIV default */
        wr_cfg(0x06, 0x01);                  /* PLL_POST_DIV default */
        wr_cfg(0x07, 0x20);                  /* GCLK/row default 128 */
        wr_cfg(0x0D, 0x02);                  /* 消隐时间 default */
        wr_cfg(0x0E, 0x06);                  /* 第一行暗补偿 default */
        wr_cfg(0x1C, 0xC0);                  /* GAIN default (不是 0xFF!) */
        wr_cfg(0x1D, 0xA6);                  /* 慢速开启 + 拐点电压 default */
        wr_cfg(0x20, 0x09);                  /* magic reg */
        wr_cfg(0x26, 0xAA);                  /* 写使能 password 部分 default */
        wr_cfg(REG_PASSWORD_A, 0x55);        /* 关 password */
        wr_cfg(REG_PASSWORD_B, 0x55);
        recovery_done = 1;
    }
    /* 之后每帧只 VSYNC + ROW + LATCH */
    vsync_pulse();
    panel_seq_dclk_keepalive(200);

    /* ICND3019 CHAIN PROBE (2026-05-28): 循环 4 个 SDI 策略 verify 行扫描.
     * mask 固定全亮 (白色), 重点测哪些物理行被 3019 chain 选通.
     *   phase 0: SDI=1 only at row 0 (current behavior, '1' walks chain)
     *   phase 1: SDI=1 always (all chain pos = 1, 全部 row 通道 enable)
     *   phase 2: SDI=0 always (no row 通道 enable → 应全黑, sanity check)
     *   phase 3: SDI=1 first 8 row, 0 else (前 8 chain pos=1, 看是否亮 8 区)
     * 30 帧每 phase = 0.12s, 肉眼可辨. */
    static u32 frame_count = 0;
    frame_count++;
    panel_seq_set_sdi_mask(0x1FF);   /* all chains, white */

    u32 phase = (frame_count / 30) % 4;
    for (int row = 0; row < 384; row++) {
        u32 sdi_bit = 0;
        switch (phase) {
            case 0: sdi_bit = (row == 0) ? 1 : 0; break;
            case 1: sdi_bit = 1; break;
            case 2: sdi_bit = 0; break;
            case 3: sdi_bit = (row < 8) ? 1 : 0; break;
        }
        icnd3019_advance_row(sdi_bit);
        panel_seq_row_pulse(row == 0 ? 12 : 4);
        if (CHIPS_PER_CHAIN > 1) {
            panel_seq_burst_word(0xFFFF, 0, CHIPS_PER_CHAIN - 2);
        }
        panel_seq_word(0xFFFF, 1);
        panel_seq_word(0, 0);
    }
}

/* 2026-05-27: 移到 PL IP. ICND3019 datasheet:
 *   - SDI=1 移入 → LINE[N] 输出 LOW (通道打开, LED ON, 共阴扫描)
 *   - 每行 1 个 DCLK 脉冲, DCLK HIGH = 消影时间 ≥500ns
 *   - chip 内部 setup/hold 由 PL FSM 严格保证
 * inject_one=1: 第 0 行注入 1 启动扫描; inject_one=0: 后续行 shift 0 进 chain. */
static void icnd3019_advance_row(int inject_one)
{
    panel_seq_icnd_advance(inject_one ? 1u : 0u);
}

/* mode_color_grid: 9 chain × 12 chip = 108 cell 图像测试.
 * 每行 chip 控制不同 row band, 每 row band 一个色:
 *   chip 0..3 (top 4 stripe)    = RED
 *   chip 4..7 (middle 4 stripe) = GREEN
 *   chip 8..11 (bottom 4 stripe) = BLUE
 * panel 应显示 3 段横向色带 (top红 / mid绿 / bot蓝). 全 9 chain 全亮.
 * 验证 per-row chain_data 切换 = image-like display 能力. */
static void mode_color_grid(void)
{
    static int init = 0;
    if (!init) {
        vsync_pulse(); en_op(); pre_act();
        wr_cfg(REG_PASSWORD_A, 0xAA); wr_cfg(REG_PASSWORD_B, 0xAA);
        wr_cfg(0x02, 19);   wr_cfg(0x03, 0x00);
        wr_cfg(0x04, 0x02); wr_cfg(0x05, 0x04); wr_cfg(0x06, 0x01);
        wr_cfg(0x07, 0x20); wr_cfg(0x0D, 0x02); wr_cfg(0x0E, 0x06);
        wr_cfg(0x1C, 0xC0); wr_cfg(0x1D, 0xA6);
        wr_cfg(0x20, 0x09); wr_cfg(0x26, 0xAA);
        wr_cfg(REG_PASSWORD_A, 0x55); wr_cfg(REG_PASSWORD_B, 0x55);
        init = 1;
    }
    vsync_pulse();
    panel_seq_set_sdi_mask(0x1FF);

    for (int row_iter = 0; row_iter < 384; row_iter++) {
        icnd3019_advance_row(row_iter == 0 ? 1 : 0);
        panel_seq_row_pulse(row_iter == 0 ? 12 : 4);

        for (u32 latch = 0; latch < CHIPS_PER_CHAIN; latch++) {
            /* cascade chip index: chip 0 = LATCH 11 (last), chip 11 = LATCH 0 (first) */
            int chip = (int)((u32)(CHIPS_PER_CHAIN - 1) - latch);
            /* 3 row bands: 0..3 R, 4..7 G, 8..11 B */
            int row_band = (chip < 4) ? 0 : (chip < 8) ? 1 : 2;
            u16 r_val = (row_band == 0) ? 0xFFFF : 0;
            u16 g_val = (row_band == 1) ? 0xFFFF : 0;
            u16 b_val = (row_band == 2) ? 0xFFFF : 0;
            /* all 3 col regions 同色 */
            for (int region = 0; region < 3; region++) {
                panel_seq_set_chain_data(region * 3 + 0, r_val);
                panel_seq_set_chain_data(region * 3 + 1, g_val);
                panel_seq_set_chain_data(region * 3 + 2, b_val);
            }
            u8 le = (latch == (u32)(CHIPS_PER_CHAIN - 1)) ? 1 : 0;
            panel_seq_word_perchain(le);
        }
        panel_seq_word(0, 0);
    }
}

/* mode_bit_sweep: 锁定 chain 0 + chip 5, 循环 16 bit 位置看亮点哪边走.
 * - 横向移动 → bit 控制 col within chip
 * - 纵向移动 → bit 控制 row within chip stripe */
static void mode_bit_sweep(void)
{
    static int init = 0;
    if (!init) {
        vsync_pulse(); en_op(); pre_act();
        wr_cfg(REG_PASSWORD_A, 0xAA); wr_cfg(REG_PASSWORD_B, 0xAA);
        wr_cfg(0x02, 19);   wr_cfg(0x03, 0x00);
        wr_cfg(0x04, 0x02); wr_cfg(0x05, 0x04); wr_cfg(0x06, 0x01);
        wr_cfg(0x07, 0x20); wr_cfg(0x0D, 0x02); wr_cfg(0x0E, 0x06);
        wr_cfg(0x1C, 0xC0); wr_cfg(0x1D, 0xA6);
        wr_cfg(0x20, 0x09); wr_cfg(0x26, 0xAA);
        wr_cfg(REG_PASSWORD_A, 0x55); wr_cfg(REG_PASSWORD_B, 0x55);
        init = 1;
    }
    vsync_pulse();
    panel_seq_set_sdi_mask(0x1FF);

    static u32 frame = 0;
    frame++;
    /* 16 bit position cycle (30 帧每位 = 0.25s) */
    u32 target_bit = (frame / 30) % 16;
    /* 锁定 chip 5 (中间, 不偏顶/底) on chain 0 (R1=右区 red) */
    const u32 TARGET_CHIP = 5;
    const u32 target_latch = (u32)(CHIPS_PER_CHAIN - 1) - TARGET_CHIP;

    /* 全 chain 默认 0 */
    for (int c = 0; c < 9; c++) panel_seq_set_chain_data(c, 0);

    for (int row = 0; row < 384; row++) {
        icnd3019_advance_row(row == 0 ? 1 : 0);
        panel_seq_row_pulse(row == 0 ? 12 : 4);
        for (u32 latch = 0; latch < CHIPS_PER_CHAIN; latch++) {
            /* chain 0 only, target latch = (1<<bit), 其他 = 0 */
            u16 v = (latch == target_latch) ? (u16)(1u << target_bit) : 0;
            panel_seq_set_chain_data(0, v);
            u8 le = (latch == (u32)(CHIPS_PER_CHAIN - 1)) ? 1 : 0;
            panel_seq_word_perchain(le);
        }
        panel_seq_word(0, 0);
    }
}

/* mode_chip_sweep: 单 chip-position 探针. 每 60 帧切一个 chip (0..11),
 * 只让该 chip 的 16 输出全亮 (chain_data 在该 LATCH 时 = 0xFFFF, 其他 = 0).
 * 看 panel 红色光带在右 1/3 region 内的位置 → 确定 chip ↔ 物理列 group 映射. */
static void mode_chip_sweep(void)
{
    static int init = 0;
    if (!init) {
        vsync_pulse(); en_op(); pre_act();
        wr_cfg(REG_PASSWORD_A, 0xAA); wr_cfg(REG_PASSWORD_B, 0xAA);
        wr_cfg(0x02, 19);   wr_cfg(0x03, 0x00);
        wr_cfg(0x04, 0x02); wr_cfg(0x05, 0x04); wr_cfg(0x06, 0x01);
        wr_cfg(0x07, 0x20); wr_cfg(0x0D, 0x02); wr_cfg(0x0E, 0x06);
        wr_cfg(0x1C, 0xC0); wr_cfg(0x1D, 0xA6);
        wr_cfg(0x20, 0x09); wr_cfg(0x26, 0xAA);
        wr_cfg(REG_PASSWORD_A, 0x55); wr_cfg(REG_PASSWORD_B, 0x55);
        init = 1;
    }
    vsync_pulse();
    panel_seq_set_sdi_mask(0x1FF);

    static u32 frame = 0;
    frame++;
    /* 4 phase, 60 帧切, 每 phase 点 3 个相邻 chip 增亮: 0-2 / 3-5 / 6-8 / 9-11 */
    u32 phase = (frame / 60) % 4;
    u32 lit_lo = phase * 3;
    u32 lit_hi = lit_lo + 2;

    /* 全部 9 chain 都点 (亮度 max), 全色白 */
    for (int c = 0; c < 9; c++) panel_seq_set_chain_data(c, 0);

    for (int row = 0; row < 384; row++) {
        icnd3019_advance_row(row == 0 ? 1 : 0);
        panel_seq_row_pulse(row == 0 ? 12 : 4);

        for (u32 latch = 0; latch < CHIPS_PER_CHAIN; latch++) {
            /* V4: snapshot at queue time → 不再需要 wait_can_accept */
            u16 v = (latch >= lit_lo && latch <= lit_hi) ? 0xFFFF : 0x0000;
            for (int c = 0; c < 9; c++) panel_seq_set_chain_data(c, v);
            u8 le = (latch == (u32)(CHIPS_PER_CHAIN - 1)) ? 1 : 0;
            panel_seq_word_perchain(le);
        }
        panel_seq_word(0, 0);
    }
}

/* mode_perchain_bars: V3 per-chain SDI 测试. 3 段竖条 R/G/B.
 * 需要 PL IP V3 (mode 2'b11 + chain_data buffer). 同 init 同 row scan,
 * 区别: LATCH 用 panel_seq_word_perchain 写每 chain 独立数据. */
static void mode_perchain_bars(void)
{
    static int recovery_done = 0;
    if (!recovery_done) {
        vsync_pulse();
        en_op();
        pre_act();
        wr_cfg(REG_PASSWORD_A, 0xAA);
        wr_cfg(REG_PASSWORD_B, 0xAA);
        wr_cfg(0x02, 19);   wr_cfg(0x03, 0x00);
        wr_cfg(0x04, 0x02); wr_cfg(0x05, 0x04); wr_cfg(0x06, 0x01);
        wr_cfg(0x07, 0x20); wr_cfg(0x0D, 0x02); wr_cfg(0x0E, 0x06);
        wr_cfg(0x1C, 0xC0); wr_cfg(0x1D, 0xA6);
        wr_cfg(0x20, 0x09); wr_cfg(0x26, 0xAA);
        wr_cfg(REG_PASSWORD_A, 0x55);
        wr_cfg(REG_PASSWORD_B, 0x55);
        recovery_done = 1;
    }
    vsync_pulse();
    panel_seq_set_sdi_mask(0x1FF);

    /* 3 段竖条: region1=R, region2=G, region3=B */
    panel_seq_set_chain_data(0, 0xFFFF);  /* R1 ON */
    panel_seq_set_chain_data(1, 0x0000);  /* G1 */
    panel_seq_set_chain_data(2, 0x0000);  /* B1 */
    panel_seq_set_chain_data(3, 0x0000);  /* R2 */
    panel_seq_set_chain_data(4, 0xFFFF);  /* G2 ON */
    panel_seq_set_chain_data(5, 0x0000);  /* B2 */
    panel_seq_set_chain_data(6, 0x0000);  /* R3 */
    panel_seq_set_chain_data(7, 0x0000);  /* G3 */
    panel_seq_set_chain_data(8, 0xFFFF);  /* B3 ON */

    for (int row = 0; row < 384; row++) {
        icnd3019_advance_row(row == 0 ? 1 : 0);
        panel_seq_row_pulse(row == 0 ? 12 : 4);
        /* per-chain mode: 12 word shift (12 chip cascade), LE on last */
        for (int chip = 0; chip < CHIPS_PER_CHAIN - 1; chip++) {
            panel_seq_word_perchain(0);
        }
        panel_seq_word_perchain(1);
        panel_seq_word(0, 0);
    }
}

/* Mode B: 显式 GAIN=0xFF, 余同 mode A */
static void mode_b_gain_max(void)
{
    static int init_done = 0;
    if (!init_done) {
        pre_act();
        wr_cfg(REG_PASSWORD_A, 0xAA);
        wr_cfg(REG_PASSWORD_B, 0xAA);
        wr_cfg(0x1C, 0xFF);   /* GAIN 200% MAX */
        wr_cfg(REG_PASSWORD_A, 0x55);
        wr_cfg(REG_PASSWORD_B, 0x55);
        init_done = 1;
    }
    static int en_op_done = 0;
    panel_seq_burst_word(0xFFFF, 1, CHIPS_PER_CHAIN * 16 - 1);
    if (!en_op_done) { en_op(); en_op_done = 1; }
    panel_seq_dclk_keepalive(1000);
}

/* Mode C: SCAN=19 (1/20 真实硬件配置) + 20 ROW per frame */
static void mode_c_scan_20(void)
{
    static int init_done = 0;
    if (!init_done) {
        pre_act();
        wr_cfg(REG_PASSWORD_A, 0xAA);
        wr_cfg(REG_PASSWORD_B, 0xAA);
        wr_cfg(REG_SCAN, 19);     /* 1/20 scan = 真实 panel 行数 */
        wr_cfg(0x1C, 0xFF);
        wr_cfg(REG_PASSWORD_A, 0x55);
        wr_cfg(REG_PASSWORD_B, 0x55);
        init_done = 1;
    }
    static int en_op_done = 0;
    vsync_pulse();
    panel_seq_word(0, 0);   /* 16 DCLK gap */

    /* 20 行 scan: ROW=12 first, ROW=4 next, 每行 16 LATCH */
    for (int row = 0; row < 20; row++) {
        panel_seq_row_pulse(row == 0 ? 12 : 4);
        icnd3019_clk();   /* 3019 chain advance per row */
        for (int ch = 0; ch < 16; ch++) {
            panel_seq_burst_word(0xFFFF, 0, CHIPS_PER_CHAIN - 2);
            panel_seq_word(0xFFFF, 1);
        }
    }
    if (!en_op_done) { en_op(); en_op_done = 1; }
    panel_seq_dclk_keepalive(500);
}

/* Mode D: 帧间数据 toggle 0xAAAA / 0x5555, 给 scope 看 OUT 是否跟变 */
static void mode_d_alt_data(void)
{
    static int en_op_done = 0;
    static int toggle = 0;
    u16 data = toggle ? 0xAAAA : 0x5555;
    panel_seq_burst_word(data, 1, CHIPS_PER_CHAIN * 16 - 1);
    if (!en_op_done) { en_op(); en_op_done = 1; }
    panel_seq_dclk_keepalive(1000);
    toggle ^= 1;
}

/* Mode E: 长 DCLK 暖机 (PLL 锁) 后再 init, 跑 5 帧静止 */
static void mode_e_warmup_long(void)
{
    /* 100K DCLK 暖机, PLL 有充足时间锁 */
    for (int b = 0; b < 100; b++) panel_seq_burst_word(0, 0, 999);
    panel_seq_wait_idle();
    pre_act();
    wr_cfg(REG_PASSWORD_A, 0xAA);
    wr_cfg(REG_PASSWORD_B, 0xAA);
    wr_cfg(0x1C, 0xFF);
    wr_cfg(REG_PASSWORD_A, 0x55);
    wr_cfg(REG_PASSWORD_B, 0x55);
    for (int f = 0; f < 5000; f++) {
        panel_seq_burst_word(0xFFFF, 1, CHIPS_PER_CHAIN * 16 - 1);
        if (f == 0) en_op();
        panel_seq_dclk_keepalive(1000);
    }
}

/* Mode F: SOFT_RST (LE=9) 首发, 复位 chip 内部状态再 init */
static void mode_f_soft_rst(void)
{
    static int init_done = 0;
    if (!init_done) {
        panel_seq_marker(9);   /* SOFT_RST: LE 高 9 DCLK */
        panel_seq_dclk_keepalive(200);
        pre_act();
        wr_cfg(REG_PASSWORD_A, 0xAA);
        wr_cfg(REG_PASSWORD_B, 0xAA);
        wr_cfg(0x1C, 0xFF);
        wr_cfg(REG_PASSWORD_A, 0x55);
        wr_cfg(REG_PASSWORD_B, 0x55);
        init_done = 1;
    }
    static int en_op_done = 0;
    panel_seq_burst_word(0xFFFF, 1, CHIPS_PER_CHAIN * 16 - 1);
    if (!en_op_done) { en_op(); en_op_done = 1; }
    panel_seq_dclk_keepalive(1000);
}

/* Mode G: N=1 cascade — 假设 chip 实际不是 12 级联, 每 SDI chain 只 1 chip.
 * 每帧 16 LATCH × 16-bit shift, 每 LATCH 末位 LE=1. */
static void mode_g_n1_cascade(void)
{
    static int en_op_done = 0;
    for (int ch = 0; ch < 16; ch++) {
        panel_seq_word(0xFFFF, 1);   /* 16 DCLK shift + LE=1, 假设 N=1 */
    }
    if (!en_op_done) { en_op(); en_op_done = 1; }
    panel_seq_dclk_keepalive(1000);
}

/* Mode H: 纯 shift + LE, **完全不发任何 ICND1069 协议命令**.
 * 假设丝印 ICND1069 但 chip 实际是 FM6124-protocol (shift+latch+OE only). */
static void mode_h_pure_shift(void)
{
    /* 不发 PRE_ACT, 不发 EN_OP, 不发 VSYNC.
     * 只 shift 192 bit (12 chip × 16-bit) + 1 LE pulse. */
    panel_seq_burst_word(0xFFFF, 0, CHIPS_PER_CHAIN - 2);  /* 11 word LE=0 */
    panel_seq_word(0xFFFF, 1);                              /* 末 word LE=1 */
    panel_seq_dclk_keepalive(1000);
}

/* Mode I: ROW 周期性脉冲 1kHz, 可能 chip 需要持续 sync */
static void mode_i_periodic_oe(void)
{
    static int en_op_done = 0;
    static int row_counter = 0;
    panel_seq_burst_word(0xFFFF, 1, CHIPS_PER_CHAIN * 16 - 1);
    if (!en_op_done) { en_op(); en_op_done = 1; }
    /* 每 1ms 一个 ROW pulse */
    row_counter++;
    if (row_counter % 1 == 0) {
        panel_seq_row_pulse(4);   /* ROW=4 next-row marker */
    }
    panel_seq_dclk_keepalive(1000);
}

/* 公开接口: RD_CFG bring-up test (PL IP 版).
 *   WR_CFG REG_SCAN=0x35 (验证写) → RD_CFG REG_SCAN → ARM polls MISO 期间 PL fire dummy DCLK.
 *   chip alive 则 MISO 上能看到 chain 推 0x35 出来的 bit pattern (有 transitions).
 *   chip dead/SDO 断 → MISO 一直 0 或 1, 无 transitions. */
void led_panel_rd_cfg_test_burst(void)
{
    if (!pins_ok && led_panel_init_pins() < 0) return;

    /* trigger marker: PRE_ACT (14 DCLK LE) 容易在 dsl 上锁 */
    panel_seq_marker(14);
    panel_seq_dclk_keepalive(200);   /* gap */

    /* 标准 init: PRE_ACT + open password + WR_CFG SCAN=0x35 + close password */
    pre_act();
    wr_cfg(REG_PASSWORD_A, 0xAA);
    wr_cfg(REG_PASSWORD_B, 0xAA);
    wr_cfg(REG_SCAN, 0x35);          /* 写一个识别值 */
    wr_cfg(REG_PASSWORD_A, 0x55);
    wr_cfg(REG_PASSWORD_B, 0x55);

    panel_seq_dclk_keepalive(200);

    /* MISO baseline: RD_CFG 前 MISO 状态. axi_gpio ch2 input at +0x08 bit 0. */
    panel_seq_wait_idle();
    u32 miso_before = Xil_In32((UINTPTR)LED_PANEL_GPIO_BASE + 0x08) & 1u;

    /* RD_CFG: 12 chip cascade × 16-bit shift + last LE=7. wr_cfg with addr only. */
    rd_cfg(REG_SCAN);

    /* RD_CFG 后 chip 在 SDO 推数据. 立即 fire 32 个 dummy word (512 DCLK) 把数据 clock 出来.
     * ARM 在 PL 跑期间持续 poll MISO, 数 transitions/hi/lo. */
    panel_seq_burst_word(0, 0, 31);  /* 32 words × 16 DCLK = 512 DCLK */

    u32 miso_hi = 0, miso_lo = 0, miso_trans = 0;
    u32 prev = miso_before;
    for (int i = 0; i < 5000; i++) {
        u32 cur = Xil_In32((UINTPTR)LED_PANEL_GPIO_BASE + 0x08) & 1u;
        if (cur != prev) miso_trans++;
        if (cur) miso_hi++; else miso_lo++;
        prev = cur;
    }

    panel_seq_wait_idle();

    xil_printf("[rd_cfg] wrote SCAN=0x35, MISO before=%u, samples 5000: hi=%u lo=%u trans=%u\r\n",
               (unsigned)miso_before, (unsigned)miso_hi, (unsigned)miso_lo, (unsigned)miso_trans);
    xil_printf("  trans>10 = chip alive, SDO has data; trans=0 = chip dead or SDO not on J1.9\r\n");

    /* 1 sec gap */
    for (volatile u32 i = 0; i < 100000000UL; i++) ;
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
/* 2026-05-27: 移到 PL IP. ARM bit-bang 完全废弃. */
static inline void icnd3019_clk(void)        { panel_seq_icnd_advance(0); }
static inline void icnd3019_load_first(void) { panel_seq_icnd_advance(1); }
static inline void icnd3019_next_row(void)   { panel_seq_icnd_advance(0); }

/* ICND3019 init: no-op, 用 POR 默认状态 (最早能亮的版本). */
static void icnd3019_init(void)
{
    (void)0;
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

    /* SDI 全 1, DATA_LATCH (LE=1) for each 16-bit cell.
     * 预写 SDI 顺序: SDI/LE set up 后才 DCLK ↑, panel buffer 延迟 settle 容裕. */
    for (u8 scan = 0; scan < SCAN_LINES; scan++) {
        gpio_write_field(SDI_MASK, SDI_MASK);
        gpio_clr_bits(LE_M);
        for (int i = 0; i < CHIPS_PER_CHAIN * 16; i++) {
            for (u8 j = 0; j < 16; j++) {
                pulse_dclk();
                /* DCLK ↓ 后立即预写下个 LE state: 在第 15 cycle (LE=1) 之前
                 * (即 j=14 之后) 预设 LE=1, 然后 DCLK ↑ 时 LE 已经 settle */
                if (j == 14) gpio_set_bits(LE_M);
                else if (j == 15) gpio_clr_bits(LE_M);
            }
        }
        gpio_clr_bits(LE_M);
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
    xil_printf("[led_panel] starting icnd3019_init (21 RCLK + 384 BIN + load_first)...\r\n");
    icnd3019_init();   /* ICND3019 RCLK 配置 + chain clear + load_first */
    xil_printf("[led_panel] icnd3019_init done. AIN=%u BIN=%u CIN=%u (post-init mirror)\r\n",
               (unsigned)((gpio_mirror >> LED_BIT_AIN) & 1),
               (unsigned)((gpio_mirror >> LED_BIT_BIN) & 1),
               (unsigned)((gpio_mirror >> LED_BIT_CIN) & 1));
    /* 不跑 icnd1069_init: 它会写 SCAN=53 (1/54) + 提前 EN_OP, 跟 Mode A 测试冲突.
     * 让 multi_mode_diag 各 mode 自己决定 ICND1069 init 是否做 / 做哪些. */
    led_panel_clear();
    xil_printf("[led_panel] boot init done (skipped icnd1069_init — multi_mode 各自处理)\r\n");
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
