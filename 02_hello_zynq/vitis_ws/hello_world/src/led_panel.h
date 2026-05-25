/*
 * led_panel.h — HUB75-style LED panel ARM bit-bang driver
 *
 * Panel 协议 (从 FPC 接线图 image-20260518-140625-dy36.jpg 抽出):
 *   - 3 RGB 数据组并行: (R1,G1,B1), (R2,G2,B2), (R3,G3,B3)
 *   - 3-bit 行地址: AIN/BIN/CIN → 8 scan lines (1/8 scan)
 *   - DCLK 每个上升沿移入一列, LAT 高锁存一行
 *   - GCLK 副时钟 (ICND1069 内置 PLL, 可 NC)
 *   - SPI 4 线 (CLK/CS/MOSI/MISO): panel 上电时主控读 flash 配置 ICND1069 寄存器,
 *     FPGA 运行时 SPI 保持 idle (CS=1). 烧 flash 用单独工具.
 *
 *  Panel 几何 (待 user 实测 PANEL_W 真实值):
 *    PANEL_H = SCAN_LINES * GROUPS = 8 × 3 = 24 行
 *    row 0..7   → group 0 (走 R1/G1/B1)
 *    row 8..15  → group 1 (走 R2/G2/B2)
 *    row 16..23 → group 2 (走 R3/G3/B3)
 *    group 内 row index = ABC scan line (000..111)
 *
 *  灰阶: panel 内部 ICND1069 16-bit PWM (96 MHz GCLK PLL) 自己 handles,
 *  FPGA 每个 DCLK 周期只送 1-bit on/off; 多次 BCM 累积可做软件 PWM, 但
 *  先用 1-bit 测亮即可.
 *
 *  性能: ARM bit-bang ~5-10 fps, 只够物理 bring-up.
 *  真 POV 时序 (21.6 K slice/s) 由 PL Verilog led_panel_drv IP 接管.
 */
#ifndef LED_PANEL_H_
#define LED_PANEL_H_

#include "xil_types.h"

/* === Panel geometry ================================================== */
#ifndef PANEL_W
#define PANEL_W        160        /* user 确认 160 column */
#endif
#define PANEL_H        180        /* user 确认 180 row */
/* 厂家规格书 P0.9375COB: 驱动方式 1/54 scan, 模组分辨率 160×180 */
#define SCAN_LINES     54         /* reg 0x02 = SCAN_LINES - 1 = 53 (0x35) */
#define GROUPS         9          /* 9 chain 并行 (R1/G1/B1 R2/G2/B2 R3/G3/B3) */

/* legacy alias for existing helloworld.c includes */
#define LED_PANEL_W    PANEL_W
#define LED_PANEL_H    PANEL_H

/* === axi_gpio bit assignment — must match led_pins.xdc =============== */
#define LED_BIT_DCLK     0
#define LED_BIT_LE       1   /* 接线图标"LAT"实际是 ICND1069 LE 引脚 */
#define LED_BIT_LAT      LED_BIT_LE  /* legacy alias */
#define LED_BIT_ROW      2   /* 接线图标"GCLK"实际是 ICND1069 ROW 引脚 (datasheet V1.2 page 3 + page 9) */
#define LED_BIT_GCLK     LED_BIT_ROW /* legacy alias */
#define LED_BIT_OE       LED_BIT_ROW /* legacy alias */
#define LED_BIT_R1       3
#define LED_BIT_G1       4
#define LED_BIT_B1       5
#define LED_BIT_R2       6
#define LED_BIT_G2       7
#define LED_BIT_B2       8
#define LED_BIT_R3       9
#define LED_BIT_G3       10   /* GPIO1.18 / AA18 / IO_L12N_T1_MRCC_33 */
#define LED_BIT_B3       11
#define LED_BIT_AIN      12
#define LED_BIT_BIN      13
#define LED_BIT_CIN      14
#define LED_BIT_SPI_CLK  15
#define LED_BIT_SPI_CS   16
#define LED_BIT_SPI_MOSI 17

/* === Legacy API (helloworld.c 还在用这些) =========================== */
void led_panel_init(void);
void led_panel_set_pixel(int x, int y, u8 r, u8 g, u8 b);
void led_panel_clear(void);
void led_panel_flush(void);
void led_panel_test_pattern(int pattern_id);
   /* pattern: 0=black 1=white 2=R 3=G 4=B 5=checker 6=color-bars 7=circles */

/* === Low-level helpers ================================================ */
int  led_panel_init_pins(void);    /* set GPIO direction + idle state */
void led_panel_scan_frame(void);    /* 1 个完整 frame: 8 scan × W col, 软件 BCM 可选 */
void led_panel_spi_read_flash_jedec(void);  /* dump panel SPI flash JEDEC ID + 头 32 字节 */
void led_panel_icnd3019_slow_scan(void);    /* 慢速 (200ms/step) chain advance, 不动 ICND1069, 测 OUT 用 */
void led_panel_rd_cfg_test_burst(void);     /* 反推: PRE_ACT + init + RD_CFG, 100ms 沉默后重复, 用逻辑分析仪看 SDO 是否有回应 */
void led_panel_force_all_white_test(void);  /* 暴力全亮: 最简 init + 全 0xFFFF + OE 强制低, 跳过 scan ratio + ROW pulse */
void led_panel_max_dclk_speed_test(void);   /* 测 ARM 极限 DCLK 速度 */

#endif /* LED_PANEL_H_ */
