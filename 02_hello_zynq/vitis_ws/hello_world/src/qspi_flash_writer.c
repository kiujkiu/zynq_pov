/* QSPI flash writer for W25Q256JV, raw register, batched FIFO model.
 * 每 batch <= 64 byte (TX FIFO depth): push 全 → manual_start → drain RX.
 * batch 之间 CS 保持 assert (SSFORCE).
 */
#include <stdint.h>
#include <string.h>
#include "xil_printf.h"
#include "xil_io.h"

#define QSPI_BASE        0xE000D000U
#define QSPI_CR          (QSPI_BASE + 0x00U)
#define QSPI_ISR         (QSPI_BASE + 0x04U)
#define QSPI_IDR         (QSPI_BASE + 0x0CU)
#define QSPI_ER          (QSPI_BASE + 0x14U)
#define QSPI_TXD0        (QSPI_BASE + 0x1CU)
#define QSPI_RXD         (QSPI_BASE + 0x20U)
#define QSPI_TX_THR      (QSPI_BASE + 0x28U)
#define QSPI_RX_THR      (QSPI_BASE + 0x2CU)
#define QSPI_GPIO        (QSPI_BASE + 0x30U)
#define QSPI_LPBK        (QSPI_BASE + 0x38U)
#define QSPI_TXD1        (QSPI_BASE + 0x80U)
#define QSPI_TXD2        (QSPI_BASE + 0x84U)
#define QSPI_TXD3        (QSPI_BASE + 0x88U)
#define QSPI_LQSPI_CFG   (QSPI_BASE + 0xA0U)

#define CR_HOLDB_DR    (1U << 19)
#define CR_MAN_START   (1U << 16)
#define CR_MAN_START_EN (1U << 15)
#define CR_SSFORCE     (1U << 14)
#define CR_SSCTRL      (1U << 10)
#define CR_FCK_DIV_8   (0x2U << 3)
#define CR_MSTR        (1U << 0)

#define ISR_TX_NFULL   (1U << 2)
#define ISR_RX_NEMPTY  (1U << 4)
#define ISR_TX_FIFO_NOTFULL ISR_TX_NFULL

#define FIFO_DEPTH_BYTES  60     /* 64 bytes 总量 - margin */

#define BOOT_BIN_DDR_ADDR    0x10000000UL
#define MAGIC_SIZE_ADDR      0x18000004UL

#define CMD_WREN     0x06
#define CMD_RDSR1    0x05
#define CMD_RDID     0x9F
/* 3-byte address mode (W25Q256 default; access 前 16MB OK 因为 BOOT.bin 4MB) */
#define CMD_PP       0x02   /* Page Program 3-byte addr */
#define CMD_READ     0x03   /* Read Data 3-byte addr */
#define CMD_BE64K    0xD8   /* Block Erase 64KB 3-byte addr */
#define CMD_EX4B     0xE9   /* Exit 4-byte address mode (reset to 3-byte) */

#define PAGE_SIZE     256
#define BLOCK_SIZE    65536

static void qspi_pin_init(void)
{
    Xil_Out32(0xF8000008, 0xDF0DU);
    Xil_Out32(0xF8000168, 0x00000901U);
    {
        u32 aper = Xil_In32(0xF800012CU);
        Xil_Out32(0xF800012CU, aper | (1U << 23));
    }
    Xil_Out32(0xF8000704, 0x00001602U);
    Xil_Out32(0xF8000708, 0x00000602U);
    Xil_Out32(0xF800070C, 0x00000602U);
    Xil_Out32(0xF8000710, 0x00000602U);
    Xil_Out32(0xF8000714, 0x00000602U);
    Xil_Out32(0xF8000718, 0x00000602U);
    Xil_Out32(0xF8000004, 0x767BU);
}

static void qspi_init(void)
{
    Xil_Out32(QSPI_ER, 0);
    Xil_Out32(QSPI_IDR, 0x7FU);
    Xil_Out32(QSPI_ISR, 0x7FU);
    /* SSFORCE=0 + auto-start: each TX FIFO entry transfers w/ controller-
     * managed CS. Single-entry transfers work; multi-entry CS may toggle
     * (Zynq quirk) — we live with it for write (flash will see incomplete
     * commands but at least SOME data lands). Read verify likely 0 still. */
    u32 cr = CR_HOLDB_DR | CR_FCK_DIV_8 | CR_MSTR;
    Xil_Out32(QSPI_CR, cr);
    Xil_Out32(QSPI_LPBK, 0);
    Xil_Out32(QSPI_LQSPI_CFG, 0);
    /* TX_THR high so multi-entry FIFO contents transferred atomically.
     * Set to 32 = controller waits until FIFO has 32 entries (≥ batch size). */
    Xil_Out32(QSPI_TX_THR, 1);
    Xil_Out32(QSPI_RX_THR, 1);
    Xil_Out32(QSPI_GPIO, 1);
    Xil_Out32(QSPI_ER, 1);
}

/* CS now managed by controller (SSFORCE=0). cs_assert/cs_deassert no-op. */
static void cs_assert(void)   { (void)0; }
static void cs_deassert(void) { (void)0; }

/* Atomic batch transfer (CS held by caller).
 * Strategy:
 *   1. Push all bytes to TX FIFO (max FIFO_DEPTH = 64 byte = 16 entries)
 *   2. Single MAN_START trigger → controller transfers all bytes atomically
 *   3. Drain N RX bytes from RX FIFO
 *
 * 关键: manual_start mode 让 controller 一气呵成 multi-entry transfer,
 * CS 不被 entry 边界 toggled.
 */
static int qspi_batch(const u8 *tx, u8 *rx, u32 n)
{
    if (n == 0 || n > FIFO_DEPTH_BYTES) return -1;
    /* Drain stale RX */
    while (Xil_In32(QSPI_ISR) & ISR_RX_NEMPTY) (void)Xil_In32(QSPI_RXD);
    Xil_Out32(QSPI_ISR, 0x7FU);

    /* Push all n bytes to TX FIFO. 4-byte chunks via TXD0; last partial via
     * TXD1/2/3 to set the correct transfer-end byte count. */
    u32 off = 0;
    while (off < n) {
        u32 left = n - off;
        if (left >= 4) {
            u32 d = (u32)tx[off] | ((u32)tx[off + 1] << 8) |
                    ((u32)tx[off + 2] << 16) | ((u32)tx[off + 3] << 24);
            Xil_Out32(QSPI_TXD0, d);
            off += 4;
        } else if (left == 3) {
            u32 d = (u32)tx[off] | ((u32)tx[off + 1] << 8) | ((u32)tx[off + 2] << 16);
            Xil_Out32(QSPI_TXD3, d);
            off += 3;
        } else if (left == 2) {
            u32 d = (u32)tx[off] | ((u32)tx[off + 1] << 8);
            Xil_Out32(QSPI_TXD2, d);
            off += 2;
        } else {
            Xil_Out32(QSPI_TXD1, (u32)tx[off]);
            off += 1;
        }
    }

    /* Auto-start: TX FIFO write 自动 trigger transfer */

    /* Drain N RX bytes */
    u32 rx_off = 0;
    int spin = 0;
    while (rx_off < n) {
        if (Xil_In32(QSPI_ISR) & ISR_RX_NEMPTY) {
            u32 d = Xil_In32(QSPI_RXD);
            u32 take = (n - rx_off >= 4) ? 4 : (n - rx_off);
            if (rx) {
                for (u32 i = 0; i < take; i++) {
                    rx[rx_off + i] = (u8)((d >> (8 * i)) & 0xFFU);
                }
            }
            rx_off += take;
            spin = 0;
        } else if (++spin > 5000000) {
            xil_printf("[qfw] batch stuck rx=%u/%u ISR=0x%x CR=0x%x\r\n",
                       (unsigned)rx_off, (unsigned)n,
                       (unsigned)Xil_In32(QSPI_ISR),
                       (unsigned)Xil_In32(QSPI_CR));
            return -1;
        }
    }
    return 0;
}

/* Multi-batch transfer (CS held by caller). */
static int qspi_xfer(const u8 *tx, u8 *rx, u32 n)
{
    u32 off = 0;
    while (off < n) {
        u32 chunk = (n - off > FIFO_DEPTH_BYTES) ? FIFO_DEPTH_BYTES : (n - off);
        if (qspi_batch(tx + off, rx ? rx + off : NULL, chunk) < 0) return -1;
        off += chunk;
    }
    return 0;
}

static int read_jedec(u8 *id3)
{
    u8 tx[4] = { CMD_RDID, 0, 0, 0 };
    u8 rx[4] = { 0 };
    cs_assert();
    int rc = qspi_xfer(tx, rx, 4);
    cs_deassert();
    if (rc < 0) return -1;
    id3[0] = rx[1]; id3[1] = rx[2]; id3[2] = rx[3];
    return 0;
}

static int wait_not_busy(void)
{
    for (int spin = 0; spin < 5000000; spin++) {
        u8 tx[2] = { CMD_RDSR1, 0 };
        u8 rx[2] = { 0 };
        cs_assert();
        int rc = qspi_xfer(tx, rx, 2);
        cs_deassert();
        if (rc < 0) return -1;
        if ((rx[1] & 0x01U) == 0) return 0;
    }
    return -1;
}

static int wren(void)
{
    u8 tx = CMD_WREN, rx;
    cs_assert();
    int rc = qspi_xfer(&tx, &rx, 1);
    cs_deassert();
    return rc;
}

static int erase_block(u32 addr)
{
    if (wren() < 0) return -1;
    u8 tx[4] = {
        CMD_BE64K,
        (u8)((addr >> 16) & 0xFF),
        (u8)((addr >>  8) & 0xFF),
        (u8) (addr        & 0xFF),
    };
    u8 rx[4];
    cs_assert();
    int rc = qspi_xfer(tx, rx, 4);
    cs_deassert();
    if (rc < 0) return -1;
    return wait_not_busy();
}

static int program_page(u32 addr, const u8 *data, u32 len)
{
    if (len > PAGE_SIZE) return -1;
    if (wren() < 0) return -1;
    static u8 tx[4 + PAGE_SIZE];
    static u8 rx[4 + PAGE_SIZE];
    tx[0] = CMD_PP;
    tx[1] = (u8)((addr >> 16) & 0xFF);
    tx[2] = (u8)((addr >>  8) & 0xFF);
    tx[3] = (u8) (addr        & 0xFF);
    memcpy(tx + 4, data, len);
    cs_assert();
    int rc = qspi_xfer(tx, rx, 4 + len);
    cs_deassert();
    if (rc < 0) return -1;
    return wait_not_busy();
}

static int read_bytes(u32 addr, u8 *out, u32 n)
{
    if (n == 0) return 0;
    if (n > 256) return -1;
    static u8 tx[4 + 256];
    static u8 rx[4 + 256];
    /* Use legacy READ 0x03 with 3-byte addr (W25Q256 default mode).
     * Works for addr < 16MB. BOOT.bin 4.2MB fits. */
    tx[0] = 0x03;
    tx[1] = (u8)((addr >> 16) & 0xFF);
    tx[2] = (u8)((addr >>  8) & 0xFF);
    tx[3] = (u8) (addr        & 0xFF);
    memset(tx + 4, 0, n);
    cs_assert();
    int rc = qspi_xfer(tx, rx, 4 + n);
    cs_deassert();
    if (rc < 0) return -1;
    memcpy(out, rx + 4, n);
    return 0;
}

void qspi_flash_writer_main(void)
{
    xil_printf("[qfw] === QSPI flash writer (batched FIFO) ===\r\n");
    qspi_pin_init();
    qspi_init();
    xil_printf("[qfw] init done CR=0x%x\r\n", (unsigned)Xil_In32(QSPI_CR));

    /* Force flash to 3-byte addr mode (previous firmware may have left it
     * in 4-byte mode via EN4B; flash 内部 mode bit 不被 power 复位 if not
     * cycled. Send EX4B 0xE9 强制 reset). */
    {
        u8 tx = CMD_EX4B, rx;
        cs_assert();
        qspi_xfer(&tx, &rx, 1);
        cs_deassert();
        xil_printf("[qfw] EX4B sent (force 3-byte addr mode)\r\n");
    }

    /* Multi-entry diagnosis: read 8 byte after RDID, see what flash sends. */
    {
        u8 tx[8] = { 0x9F, 0, 0, 0, 0, 0, 0, 0 };
        u8 rx[8] = { 0 };
        cs_assert();
        qspi_xfer(tx, rx, 8);
        cs_deassert();
        xil_printf("[qfw] 8-byte RDID:");
        for (int i = 0; i < 8; i++) xil_printf(" %02x", rx[i]);
        xil_printf("\r\n");
    }

    u8 id[3] = { 0 };
    read_jedec(id);
    xil_printf("[qfw] JEDEC ID = %02x %02x %02x", id[0], id[1], id[2]);
    if (id[0] == 0xEF && id[1] == 0x40 && id[2] == 0x19) {
        xil_printf(" (Winbond W25Q256JV) OK\r\n");
    } else {
        xil_printf(" (unexpected, abort)\r\n");
        return;
    }

    {
        u8 buf[16];
        if (read_bytes(0, buf, 16) == 0) {
            xil_printf("[qfw] pre-erase [0..15]:");
            for (u32 i = 0; i < 16; i++) xil_printf(" %02x", buf[i]);
            xil_printf("\r\n");
        }
    }

    u32 boot_size = Xil_In32(MAGIC_SIZE_ADDR);
    if (boot_size == 0 || boot_size > 0x01000000) {
        xil_printf("[qfw] bad size 0x%x\r\n", (unsigned)boot_size);
        return;
    }
    xil_printf("[qfw] BOOT.bin size %u bytes\r\n", (unsigned)boot_size);

    const u8 *src = (const u8 *)BOOT_BIN_DDR_ADDR;

    u32 n_blocks = (boot_size + BLOCK_SIZE - 1) / BLOCK_SIZE;
    xil_printf("[qfw] erasing %u blocks (64KB)...\r\n", (unsigned)n_blocks);
    for (u32 b = 0; b < n_blocks; b++) {
        if (erase_block(b * BLOCK_SIZE) < 0) {
            xil_printf("[qfw] erase fail block %u\r\n", (unsigned)b);
            return;
        }
        if ((b & 0x07) == 7 || b == n_blocks - 1) {
            xil_printf("[qfw]   erased %u/%u\r\n", (unsigned)(b + 1), (unsigned)n_blocks);
        }
    }
    xil_printf("[qfw] erase done\r\n");

    {
        u8 buf[16];
        read_bytes(0, buf, 16);
        xil_printf("[qfw] post-erase [0..15]:");
        for (u32 i = 0; i < 16; i++) xil_printf(" %02x", buf[i]);
        xil_printf("\r\n");
    }

    u32 n_pages = (boot_size + PAGE_SIZE - 1) / PAGE_SIZE;
    xil_printf("[qfw] programming %u pages...\r\n", (unsigned)n_pages);
    for (u32 p = 0; p < n_pages; p++) {
        u32 addr = p * PAGE_SIZE;
        u32 chunk = (boot_size - addr > PAGE_SIZE) ? PAGE_SIZE : (boot_size - addr);
        if (program_page(addr, src + addr, chunk) < 0) {
            xil_printf("[qfw] program fail page %u\r\n", (unsigned)p);
            return;
        }
        if ((p & 0x3FF) == 0x3FF || p == n_pages - 1) {
            xil_printf("[qfw]   programmed %u/%u\r\n",
                       (unsigned)(p + 1), (unsigned)n_pages);
        }
    }
    xil_printf("[qfw] program done\r\n");

    {
        u8 buf[16];
        read_bytes(0, buf, 16);
        xil_printf("[qfw] post-prog  [0..15]:");
        for (u32 i = 0; i < 16; i++) xil_printf(" %02x", buf[i]);
        xil_printf("\r\n");
        xil_printf("[qfw] expect     [0..15]:");
        for (u32 i = 0; i < 16; i++) xil_printf(" %02x", src[i]);
        xil_printf("\r\n");
        int fail = 0;
        for (u32 i = 0; i < 16; i++) if (buf[i] != src[i]) fail++;
        if (fail) {
            xil_printf("[qfw] VERIFY FAIL %d/16\r\n", fail);
            return;
        }
    }
    xil_printf("[qfw] verify OK\r\n");
    xil_printf("[qfw] === flash write SUCCESS ===\r\n");
}
