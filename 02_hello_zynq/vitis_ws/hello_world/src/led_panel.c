/*
 * led_panel.c — POV-3D LED panel ARM bit-bang baseline driver
 *
 * Hardware 协议:
 *   ICND1069 (列驱, 16ch PWM 恒流, 27 cascade × 4 chain):
 *     - SDI/DCLK 串行移位 PWM 灰度数据 (16-bit/通道).
 *     - LE 不同长度脉冲 = 不同指令 (1 DCLK = 数据写, 2 = 锁存,
 *       3+ = 寄存器配置). 详见 ICND1069_datasheet_CN_2023_V1.1.pdf 第 3-9 页.
 *     - DCLK ≤ 25 MHz; bit-bang 远低于这个上限, 不需要管 setup/hold.
 *
 *   ICND3019 (行驱, 16ch NMOS 1.5A, 24 cascade):
 *     - SDI/DCLK 串行移位 row 选择 bit; 1 个 DCLK 推 1 行扫描;
 *       上升沿换行. DCLK 高电平 ≥ 500 ns 是消影时间.
 *     - RCLK 个数 (8-23) 配模式: RCLK=13 = 普通 / 2.5V 消隐 (默认).
 *
 * Scan 策略 (假设): 1/180 row scan
 *   for row in 0..179:
 *     1) shift 1069 chain (4 路并行), 每路 27 cascade × 16 ch × 16-bit
 *        = 27 × 256 = 6912 bit / chain, 4 chain 同时跑 = 1728 列信号
 *     2) LE pulse (length=2) latch 列驱
 *     3) ICND3019 SDI shift 1 bit (this row 的"亮"位置在 cascade chain
 *        里只有 1 个 1, 其余 0); 总 384 bit 全推一次, 然后 RCLK rising
 *        edge 换行 — 但实际更省: 只在 row 0 推满一帧 row pattern, 之后
 *        每 row 只推 1 个 DCLK (3019 内部 shift register 自然滚动).
 *        TODO: 用户实测 panel 拓扑后选其一.
 *     4) sleep ~1 ms (人眼测试模式不挑刷新率)
 *
 * 列分布 (假设, 待用户实测):
 *   - 1728 列信号 ÷ (160 × 3 RGB) = 3.6 — 不整除. 推测 panel 是 4 quadrant
 *     (每 quadrant 80×90 像素), 4 chain 各驱 1 quadrant 的 90 行 × 80 列 × 3
 *     = 21600 列信号? 也不整除. 更可能是 panel 用 27×16=432 ch / chain ×
 *     4 = 1728, 而 480 RGB 信号里有 ~80 个未连或公共, 或 panel 实际是
 *     180×96 (含公共 / 16 ch round up). 用户拿 FPC pinout 后改下面
 *     COLS_PER_CHAIN_BITS / fb→cascade mapping.
 *   下面把 mapping 抽成 panel_chain_pwm_for_row(...) 一个函数, 用户改这
 *   一个就行.
 *
 * 性能 (估算):
 *   AXI GPIO 写 1 次 ~100 ns (HP slave + interconnect + GPIO 寄存器).
 *   每个 DCLK = 2 次写 (拉高 + 拉低) = 200 ns.
 *   1 行 1069 数据: 6912 DCLK × 200 ns = 1.38 ms (4 chain 并行同时算)
 *   1 行 3019 数据: 384 DCLK × 200 ns = 77 us (满推) 或 1 DCLK = 200 ns (滚动)
 *   180 行: 180 × (1.38 ms + 0.2 ms LE/RCLK + 1 ms sleep) ≈ 470 ms / 帧.
 *   ≈ 2 FPS, 测试图案够用.
 *
 * 不依赖 PL: 全部 logic 跑在 ARM, 通过 AXI GPIO 寄存器写 IO 线.
 * 没有 PL 实例时 helloworld.c 关掉 ENABLE_LED_PANEL_TEST 即可.
 */

#include "led_panel.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"

/* =====================================================================
 *  GPIO 寄存器映射 (TODO: 用户拿到 FPC pinout 后核对)
 *
 *  axi_gpio_panel @ 0x41210000 (假定). 现 BD 没有, 需要用户 BD 加一个:
 *    1) 在 BD 加 AXI GPIO IP, 重命名 axi_gpio_panel
 *    2) 设 32-bit single-channel, all-output
 *    3) 接 axi_periph_interconnect, 分 base 0x41210000
 *    4) external 出 32 个 pin, 在 .xdc 绑到 FPC 引脚
 *    5) 重 generate output products / wrapper / impl, 出新 .xsa, update_hw
 *
 *  没扩 BD 之前, helloworld.c 把 ENABLE_LED_PANEL_TEST 设 0; 否则
 *  Xil_Out32(GPIO_PANEL_BASE, ...) 会写不存在的地址 (DataAbort 死机).
 * ===================================================================== */
#define GPIO_PANEL_BASE      0x41210000UL
#define GPIO_DATA_OFFSET     0x00     /* AXI GPIO channel 1 data reg */
#define GPIO_TRI_OFFSET      0x04     /* tri-state (0=output, 1=input) */

/* GPIO bit positions — TODO: 用户根据 FPC 改 */
#define SIGNAL_DCLK_COL      0   /* ICND1069 DCLK */
#define SIGNAL_LE            1   /* ICND1069 LE (脉冲长度=指令) */
#define SIGNAL_SDI_0         2   /* ICND1069 chain 0 SDI */
#define SIGNAL_SDI_1         3   /* ICND1069 chain 1 SDI */
#define SIGNAL_SDI_2         4   /* ICND1069 chain 2 SDI */
#define SIGNAL_SDI_3         5   /* ICND1069 chain 3 SDI */
#define SIGNAL_DCLK_ROW      8   /* ICND3019 DCLK */
#define SIGNAL_RCLK          9   /* ICND3019 RCLK */
#define SIGNAL_SDI_ROW      10   /* ICND3019 SDI */
/* 剩余 bit 留给 future panel control / OE / 245-OE etc. */

/* =====================================================================
 *  Panel 拓扑常量 (假设, TODO 实测改)
 * ===================================================================== */
#define N_ROW_CASCADE       24            /* ICND3019 cascade 数 */
#define ROW_BITS_TOTAL      (N_ROW_CASCADE * 16)   /* = 384 */

#define N_COL_CASCADE       27            /* 每 chain 上 ICND1069 cascade 数 */
#define COL_CH_PER_IC       16            /* 1069 PWM ch/IC */
#define COL_BITS_PER_CH     16            /* PWM 灰度位宽 */
#define N_COL_CHAIN         4             /* 并行 chain 数 (SDI_0..3) */
#define COLS_PER_CHAIN      (N_COL_CASCADE * COL_CH_PER_IC)   /* 432 ch */

/* =====================================================================
 *  Frame buffer (静态, 86.4 KB — fits SRAM/cache 没事)
 * ===================================================================== */
static u8 fb[LED_PANEL_H][LED_PANEL_W][3];

/* GPIO 当前镜像值 (避免 read-modify-write 把别 bit 推错) */
static volatile u32 gpio_state = 0;

/* =====================================================================
 *  低层 GPIO bit-bang
 * ===================================================================== */
static inline void gpio_write(void)
{
    Xil_Out32(GPIO_PANEL_BASE + GPIO_DATA_OFFSET, gpio_state);
}

static inline void gpio_set(u32 bit)
{
    gpio_state |= (1u << bit);
    gpio_write();
}

static inline void gpio_clr(u32 bit)
{
    gpio_state &= ~(1u << bit);
    gpio_write();
}

static inline void gpio_set_bits(u32 mask)
{
    gpio_state |= mask;
    gpio_write();
}

static inline void gpio_clr_bits(u32 mask)
{
    gpio_state &= ~mask;
    gpio_write();
}

/* 把 mask 上的 bit 设成 val (val 也是 bit-mask 形式: 1 = high, 0 = low) */
static inline void gpio_put(u32 mask, u32 val)
{
    gpio_state = (gpio_state & ~mask) | (val & mask);
    gpio_write();
}

/* =====================================================================
 *  ICND1069 协议
 * ===================================================================== */

/* 一个 DCLK 沿 (上升). 4 路 SDI 已经预先放好. */
static inline void col_dclk_pulse(void)
{
    gpio_set(SIGNAL_DCLK_COL);
    gpio_clr(SIGNAL_DCLK_COL);
}

/*
 * LE pulse: 在 DCLK 低 → 高的 dclk_count 个时钟周期里 LE 保持高.
 * dclk_count 决定指令:
 *   1 = 写 PWM 数据 (实际数据移位时 LE 在最后一个 DCLK 之前就拉高)
 *   2 = 全局锁存 (latch)
 *   ≥3 = 寄存器配置 (gain / mode 等)
 *
 * 这里实现的是 datasheet "LE 在 DCLK 上升沿前拉高, 持续 dclk_count
 * 个 DCLK 高电平期" 模式. 准确波形见 ICND1069_datasheet_CN 第 3-9 页.
 * TODO: 用户首板 bring-up 时拿示波器抓一下波形对一遍.
 */
static void col_le_pulse(int dclk_count)
{
    /* 拉高 LE, 然后跑 dclk_count 个 DCLK pulse, 最后 LE 拉低 */
    gpio_set(SIGNAL_LE);
    for (int i = 0; i < dclk_count; i++) {
        col_dclk_pulse();
    }
    gpio_clr(SIGNAL_LE);
}

/*
 * 把 4 路 chain 的 PWM 数据并行 shift 进 ICND1069 cascade.
 * pwm_data[chain][cascade_idx][ch_idx_in_ic] = u16 PWM 灰度.
 * 格式:
 *   pwm_data[c][k][ch] 共 4 × 27 × 16 = 1728 个 u16.
 *   先移高 cascade (= 链尾) 的高 ch 高位, 后移低 cascade (= 链头) 低 ch
 *   低位 — datasheet 标准移位顺序.
 * 完成后 LE pulse (length=1) 写入数据 latch buffer (尚未送 PWM 输出),
 * 调 col_latch() 触发实际 latch.
 */
static void col_shift_pwm_4chain(const u16 pwm_data[N_COL_CHAIN][N_COL_CASCADE][COL_CH_PER_IC])
{
    /* shift 顺序: 链尾 → 链头, 高 ch → 低 ch, MSB → LSB.
     * 4 chain SDI 在每 DCLK 同时摆放各自 bit. */
    const u32 sdi_mask =
        (1u << SIGNAL_SDI_0) | (1u << SIGNAL_SDI_1) |
        (1u << SIGNAL_SDI_2) | (1u << SIGNAL_SDI_3);

    for (int cas = N_COL_CASCADE - 1; cas >= 0; cas--) {
        for (int ch = COL_CH_PER_IC - 1; ch >= 0; ch--) {
            for (int b = COL_BITS_PER_CH - 1; b >= 0; b--) {
                u32 sdi_val = 0;
                if ((pwm_data[0][cas][ch] >> b) & 1u) sdi_val |= (1u << SIGNAL_SDI_0);
                if ((pwm_data[1][cas][ch] >> b) & 1u) sdi_val |= (1u << SIGNAL_SDI_1);
                if ((pwm_data[2][cas][ch] >> b) & 1u) sdi_val |= (1u << SIGNAL_SDI_2);
                if ((pwm_data[3][cas][ch] >> b) & 1u) sdi_val |= (1u << SIGNAL_SDI_3);
                gpio_put(sdi_mask, sdi_val);
                col_dclk_pulse();
            }
        }
    }
}

/* 全局锁存当前 shift register → PWM 输出 */
static inline void col_latch(void)
{
    col_le_pulse(2);  /* LE length=2 = data latch */
}

/* =====================================================================
 *  ICND3019 协议
 * ===================================================================== */

static inline void row_dclk_pulse(void)
{
    /* DCLK 高电平 ≥ 500 ns 是消影时间. AXI GPIO 1 次写 ~100 ns,
     * 加几个 nop 保险. */
    gpio_set(SIGNAL_DCLK_ROW);
    for (volatile int i = 0; i < 8; i++) { /* ~800 ns */ }
    gpio_clr(SIGNAL_DCLK_ROW);
}

static inline void row_rclk_pulse(void)
{
    gpio_set(SIGNAL_RCLK);
    gpio_clr(SIGNAL_RCLK);
}

/*
 * 配 ICND3019 模式: RCLK 个数选 mode.
 *   13 = 普通模式, 2.5V 消隐 (datasheet default 推荐)
 *   其他 8-23 见 datasheet 第 3 页表格.
 * 上电后调一次.
 */
static void row_config_mode(int rclk_count)
{
    /* 模式配置: 不 shift 任何 SDI, 单纯连续 RCLK. */
    gpio_clr(SIGNAL_SDI_ROW);
    for (int i = 0; i < rclk_count; i++) {
        row_rclk_pulse();
    }
}

/*
 * 给 cascade 推 row pattern: 384 bit, 当前要亮的 row 位置 = 1, 其余 = 0.
 * row_idx ∈ [0, 179] (bit pos in cascade chain).
 * 完成后 panel 当前行 = row_idx.
 */
static void row_select_full(int row_idx)
{
    for (int b = ROW_BITS_TOTAL - 1; b >= 0; b--) {
        if (b == row_idx) gpio_set(SIGNAL_SDI_ROW);
        else              gpio_clr(SIGNAL_SDI_ROW);
        row_dclk_pulse();
    }
}

/*
 * 滚动模式: 假设 cascade 已经初始化好一个 "1" 在 row 0, 之后每行
 * 只 shift 1 bit (新进的 SDI = 0), bit "1" 沿链滚动.
 * 整帧 180 行用此函数 179 次, 第 0 行用 row_select_full(0).
 *
 * TODO: 用户实测验证 — 也可能 panel 内部硬件就是 "1 row at a time"
 * shift register, 那这个就对; 也可能 panel 要 row driver 主动推满 384
 * bit, 那 fallback 用 row_select_full().
 */
static void row_select_advance(void)
{
    gpio_clr(SIGNAL_SDI_ROW);
    row_dclk_pulse();
}

/* =====================================================================
 *  Frame buffer → PWM mapping (TODO: 用户改这个)
 *
 *  把 fb[y][x][rgb] (160 列 × RGB) 映射到 4 chain × 27 cascade × 16 ch
 *  PWM 数据. 假设拓扑: 4 quadrant 80×90 像素, 每 chain 驱 1 quadrant.
 *
 *  这里给一个 placeholder mapping (不一定对):
 *    chain 0: 左上象限 (x=0..79, y=0..89)
 *    chain 1: 右上象限 (x=80..159, y=0..89)
 *    chain 2: 左下象限 (x=0..79, y=90..179)
 *    chain 3: 右下象限 (x=80..159, y=90..179)
 *  每 chain 处理 80 列 × 3 RGB = 240 ch (实际 432 可用, 多余的 ch 写 0).
 *
 *  PWM 编码: 8-bit fb 值 << 8 = 16-bit PWM (或 << 7 防止 0xFF 0xFF
 *  把 1069 配的 max-current 拉满烧 LED, 这里取折中 << 7 = 50% 占空).
 * ===================================================================== */
static u16 panel_pwm[N_COL_CHAIN][N_COL_CASCADE][COL_CH_PER_IC];

static inline u16 fb_to_pwm(u8 v)
{
    /* 8-bit gray → 16-bit PWM, 上限 ~50% 防止 inrush */
    return (u16)(((u32)v) << 7);
}

static void build_pwm_for_row(int y)
{
    /* 清零 placeholder (未连 channel 写 0 = 灭灯) */
    for (int c = 0; c < N_COL_CHAIN; c++)
        for (int k = 0; k < N_COL_CASCADE; k++)
            for (int h = 0; h < COL_CH_PER_IC; h++)
                panel_pwm[c][k][h] = 0;

    /* y 落在上半还是下半, 决定用 chain 0/1 还是 2/3 */
    int upper = (y < 90);
    int chain_left  = upper ? 0 : 2;
    int chain_right = upper ? 1 : 3;

    /* 80 列 × 3 RGB = 240 ch. cascade k 含 ch 0..15.
     * 把 ch idx = (col_in_quadrant * 3) + rgb; cascade_idx = ch_idx / 16. */
    for (int x = 0; x < 80; x++) {
        for (int rgb = 0; rgb < 3; rgb++) {
            int ch_idx_left  = x * 3 + rgb;
            int cas_left     = ch_idx_left / COL_CH_PER_IC;
            int sub_left     = ch_idx_left % COL_CH_PER_IC;
            panel_pwm[chain_left][cas_left][sub_left] = fb_to_pwm(fb[y][x][rgb]);

            int ch_idx_right = x * 3 + rgb;
            int cas_right    = ch_idx_right / COL_CH_PER_IC;
            int sub_right    = ch_idx_right % COL_CH_PER_IC;
            panel_pwm[chain_right][cas_right][sub_right] = fb_to_pwm(fb[y][80 + x][rgb]);
        }
    }
}

/* =====================================================================
 *  Public API
 * ===================================================================== */

void led_panel_init(void)
{
    xil_printf("[led_panel] init: gpio_base=0x%x\r\n", (unsigned)GPIO_PANEL_BASE);
    /* 设 axi_gpio direction 为全输出 (TRI = 0) */
    Xil_Out32(GPIO_PANEL_BASE + GPIO_TRI_OFFSET, 0x00000000);
    gpio_state = 0;
    gpio_write();

    /* ICND3019 模式配置: RCLK=13 普通模式 */
    row_config_mode(13);

    /* ICND1069 默认上电 gain = 100% (8-bit 增益寄存器), 不主动配置.
     * TODO: 想改电流就调 col_le_pulse(N) (N≥3, datasheet 第 3-9 页表格).
     * 板子 REXT 决定 base 电流 = 12 / Rext × Gain.
     * 例: Rext = 1 kΩ + Gain = 100% → 12 mA / ch. */

    /* 初始化 row pointer 到 row 0 */
    row_select_full(0);

    led_panel_clear();
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
    /* row 0 用 full select; 之后 row N 用 advance (滚动模式).
     * 如果实测 panel 不滚动, 改 row_select_full(y) 替换 row_select_advance. */
    for (int y = 0; y < LED_PANEL_H; y++) {
        build_pwm_for_row(y);
        col_shift_pwm_4chain(panel_pwm);
        col_latch();

        if (y == 0) row_select_full(0);
        else        row_select_advance();

        /* 行间空闲 — 让 1069 PWM 跑出灰度 (内部 96 MHz GCLK / 65536 ≈ 1.46 kHz) */
        usleep(1000);
    }
}

/* =====================================================================
 *  测试图案
 * ===================================================================== */

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
    /* 8 段: K R G Y B M C W */
    static const u8 bars[8][3] = {
        {0,0,0}, {255,0,0}, {0,255,0}, {255,255,0},
        {0,0,255}, {255,0,255}, {0,255,255}, {255,255,255}
    };
    int seg_w = LED_PANEL_W / 8;  /* = 20 */
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
            /* 整数近似 sqrt: 用 d2 / 32 当量化半径 */
            int r_q = d2 / 32;
            int ring = r_q & 7;   /* 0..7 ring index */
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
            xil_printf("[led_panel] unknown pattern %d, using black\r\n", pattern_id);
            break;
    }
}
