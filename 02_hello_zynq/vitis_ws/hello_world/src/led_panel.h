/*
 * led_panel.h — POV-3D LED panel ARM bit-bang baseline driver (Task A)
 *
 * Purpose: 上电首次硬件 verify 用. 不依赖 PL hardware, ARM 直接 bit-bang
 * AXI GPIO 驱动 ICND1069 (列驱) + ICND3019 (行驱) 把测试图案推到 panel.
 * bit-bang 慢 (整帧 ~秒级), 仅供静态测试图; 21.6K slice/sec POV 实时
 * 路径是 Task B (PL streamer).
 *
 * Panel: 160 × 180 RGB, 4 chain × 27 cascade ICND1069 (列), 24 cascade
 *        ICND3019 (行), 1/180 row scan 假设.
 *
 * Hardware 假设 (用户拿到 FPC pinout 后改 led_panel.c 顶部的 SIGNAL_*):
 *   - 新 axi_gpio_panel @ 0x41210000, 32-bit channel 1
 *     (现 BD 只有 axi_gpio_0 @ 0x41200000 给 LED1/LED2, 用户后续扩 BD)
 *   - 7-bit Group A (1069 列驱): SDI_0..3 / DCLK / LE / nul
 *   - 3-bit Group B (3019 行驱): DCLK_ROW / RCLK / SDI_ROW
 *   - 通过 74HC245 × 8 做 3.3V→5V 电平转换
 *
 * 不依赖 PL: 整套用 AXI GPIO + Xil_Out32, 板子无 PL 也能跑 (假设 axi_gpio
 * 已存在; 没扩 BD 时在 helloworld.c 关掉 ENABLE_LED_PANEL_TEST).
 */
#ifndef LED_PANEL_H_
#define LED_PANEL_H_

#include "xil_types.h"

#define LED_PANEL_W   160
#define LED_PANEL_H   180

/*
 * 配置 ICND3019 RCLK 模式选择 + ICND1069 REXT 默认电流增益.
 * 调用一次 (boot 时). 内部把 gpio direction 设成全输出, 全 line 拉低.
 */
void led_panel_init(void);

/*
 * 写一个像素到 frame buffer (软件缓存, 不立即推 panel).
 * x ∈ [0, 159], y ∈ [0, 179]. 越界 silently no-op.
 */
void led_panel_set_pixel(int x, int y, u8 r, u8 g, u8 b);

/*
 * Frame buffer 全清零.
 */
void led_panel_clear(void);

/*
 * Bit-bang 整帧 frame buffer 推到 panel.
 * 阻塞调用, 整帧时间见 led_panel.c 注释 (~几 100 ms 量级).
 * 调用前应已 led_panel_set_pixel(...) 填好 fb.
 */
void led_panel_flush(void);

/*
 * 测试图案. 内部调 clear + set_pixel, 不调 flush — caller 调 flush.
 *   0 = 全黑
 *   1 = 全白
 *   2 = 全红
 *   3 = 全绿
 *   4 = 全蓝
 *   5 = 棋盘格 (8×8 像素一格)
 *   6 = 色条 (左右 8 段不同色)
 *   7 = 同心圆
 */
void led_panel_test_pattern(int pattern_id);

#endif /* LED_PANEL_H_ */
