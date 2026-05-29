/*
 * led_panel.h — ICND1069+ICND3019 panel driver public API
 *
 * Panel: 160 × 180 RGB, 108 ICND1069 (9 chain × 12 cascade) + 24 ICND3019.
 * Pin-level protocol (DCLK/LE/SDI/ROW/icnd_*) driven by PL led_panel_seq IP.
 * ARM only orchestrates per-frame data via AXI writes + OE/ABC/SPI GPIO.
 *
 * Active mode selected at compile time via LED_PANEL_MODE (see led_panel.c).
 */
#ifndef LED_PANEL_H_
#define LED_PANEL_H_

#include "xil_types.h"

/* === Panel geometry ================================================== */
#ifndef PANEL_W
#  define PANEL_W      160
#endif
#define PANEL_H        180
#define SCAN_LINES     54           /* manufacturer spec, 1/54 scan */
#define GROUPS         9            /* 9 SDI chain parallel */
#define LED_PANEL_W    PANEL_W      /* legacy alias */
#define LED_PANEL_H    PANEL_H

/* === axi_gpio_panel bit assignment — must match led_pins.xdc ========= */
#define LED_BIT_DCLK      0
#define LED_BIT_LE        1
#define LED_BIT_ROW       2
#define LED_BIT_R1        3
#define LED_BIT_G1        4
#define LED_BIT_B1        5
#define LED_BIT_R2        6
#define LED_BIT_G2        7
#define LED_BIT_B2        8
#define LED_BIT_R3        9
#define LED_BIT_G3        10
#define LED_BIT_B3        11
#define LED_BIT_AIN       12
#define LED_BIT_BIN       13
#define LED_BIT_CIN       14
#define LED_BIT_SPI_CLK   15
#define LED_BIT_SPI_CS    16
#define LED_BIT_SPI_MOSI  17

/* === Public API ====================================================== */
int  led_panel_init_pins(void);             /* low-level GPIO direction + idle */
void led_panel_init(void);                  /* full boot init: pins + chip cfg */
void led_panel_spi_read_flash_jedec(void);  /* one-shot debug: read panel flash JEDEC */
void led_panel_multi_mode_diag(void);       /* main render loop (mode = LED_PANEL_MODE) */

#endif /* LED_PANEL_H_ */
