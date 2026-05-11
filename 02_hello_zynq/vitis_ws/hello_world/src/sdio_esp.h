/*
 * sdio_esp.h - Zynq baremetal SDIO host driver for ESP32-C5 SDIO slave bridge.
 *
 * Talks to an ESP32 running ESP-IDF SDIO slave firmware (pov_bridge.bin).
 * The slave exposes a TX/RX block-oriented pipe via standard SDIO IO card
 * protocol (CMD0/5/3/7 init, CMD52/53 single-byte/block data).
 *
 * Replaces (optionally) the UART CH340 host-PC link with WiFi → ESP32 → SDIO.
 * Conditional compile: only init/recv when ENABLE_SDIO_ESP_BRIDGE is defined
 * non-zero in helloworld.c. Build always links sdio_esp.o.
 *
 * Hardware: Zynq PS SD0 on MIO40-47 (shared with on-board microSD slot —
 * physically disconnect microSD when using ESP32). 4-bit SDIO mode @ 25 MHz
 * initial clock, scaled to ~50 MHz default after init.
 *
 * NOT THREAD-SAFE — all calls assumed from main loop.
 */

#ifndef SDIO_ESP_H
#define SDIO_ESP_H

#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Status codes */
#define SDIO_ESP_OK              0
#define SDIO_ESP_ERR_INIT       -1
#define SDIO_ESP_ERR_CMD        -2
#define SDIO_ESP_ERR_TIMEOUT    -3
#define SDIO_ESP_ERR_BUSY       -4
#define SDIO_ESP_ERR_NO_DATA    -5
#define SDIO_ESP_ERR_PARAM      -6

/* Block size, fixed by ESP32 SDIO slave firmware (ESP-IDF default = 512). */
#define SDIO_ESP_BLOCK_SIZE   512

/* CCCR offsets (SDIO simplified spec Part E1) */
#define SDIO_CCCR_IO_ENABLE         0x02
#define SDIO_CCCR_IO_READY          0x03
#define SDIO_CCCR_INT_ENABLE        0x04
#define SDIO_CCCR_INT_PENDING       0x05
#define SDIO_CCCR_BUS_INTERFACE     0x07  /* bus width */
#define SDIO_CCCR_CARD_CAPABILITY   0x08
#define SDIO_CCCR_BLK_SIZE_LO       0x10  /* Func0 block size */
#define SDIO_CCCR_BLK_SIZE_HI       0x11

/* FBR base for function N: 0x100 * N. Func1 used by ESP32. */
#define SDIO_FBR(n)                 (0x100u * (n))
#define SDIO_FBR_BLK_SIZE_LO(n)     (SDIO_FBR(n) + 0x10)
#define SDIO_FBR_BLK_SIZE_HI(n)     (SDIO_FBR(n) + 0x11)

/* ESP32 host-interrupt source register (slave-specific, in Func1 space).
 * See ESP-IDF components/esp_driver_sdio/include/driver/sdio_slave.h and
 * the ESP-Hosted slave protocol — host interrupt status at function 1
 * offset 0x05 mirrors a bitmask the slave raised. */
#define SDIO_ESP_FUNC               1
#define SDIO_ESP_INTR_ST            (SDIO_FBR(1) + 0x05)
#define SDIO_ESP_INTR_CLR           (SDIO_FBR(1) + 0x08)
#define SDIO_ESP_PKT_LEN_REG        (SDIO_FBR(1) + 0x60)  /* 32b: TX bytes queued */
#define SDIO_ESP_TX_REG             (SDIO_FBR(1) + 0x44)  /* CMD53 read window */
#define SDIO_ESP_RX_REG             (SDIO_FBR(1) + 0x40)  /* CMD53 write window */

/*
 * Init PS SDIO0 controller + run ESP32-as-IO-card init sequence:
 *   1) XSdPs_CfgInitialize(XPAR_XSDPS_0)
 *   2) Power-up + 80 dummy clocks
 *   3) CMD0 GO_IDLE
 *   4) CMD5 SEND_OP_COND  (skip OCR-narrowing — ESP wants OCR=0)
 *   5) CMD3 SEND_RELATIVE_ADDR → RCA
 *   6) CMD7 SELECT_CARD(RCA)
 *   7) CMD52 set block size 512 on CCCR + Func1
 *   8) CMD52 enable Func1 (CCCR IOE.bit1 = 1), poll CCCR IOR.bit1 = 1
 *   9) CMD52 enable host int (INT_ENABLE.bit0|bit1 = 1)
 *   10) (optional) switch bus width to 4-bit
 *
 * Returns SDIO_ESP_OK or negative.
 */
int sdio_esp_init(void);

/*
 * Send `len` bytes from `data` to ESP32 RX path (CMD53 block write to Func1).
 * `len` rounded up to 512-byte block. Blocking, polls.
 *
 * Returns SDIO_ESP_OK or negative.
 */
int sdio_esp_send(const u8 *data, u32 len);

/*
 * Non-blocking read of up to `max_len` bytes from ESP32 TX path.
 *
 *   - Check host int / packet-length register; if 0 → SDIO_ESP_ERR_NO_DATA.
 *   - Otherwise CMD53 block read for min(max_len, queued, multiple of 512).
 *   - *actual filled with byte count actually read.
 *
 * Returns SDIO_ESP_OK, SDIO_ESP_ERR_NO_DATA, or negative error.
 */
int sdio_esp_recv(u8 *buf, u32 max_len, u32 *actual);

/*
 * Read raw host-int status register (8 bits). Bit-meaning is ESP firmware
 * defined; bit0 = new TX packet available, bit1 = slave ready, etc.
 *
 * Returns value 0..0xFF, or negative on bus error.
 */
int sdio_esp_get_status(void);

#ifdef __cplusplus
}
#endif

#endif /* SDIO_ESP_H */
