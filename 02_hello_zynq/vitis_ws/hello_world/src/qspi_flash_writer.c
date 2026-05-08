/* QSPI flash writer for W25Q256JV on 鹿小班 Zynq, raw register access.
 * 4-byte transfer 单位 (Zynq PS QSPI controller convention) — 写 TXD0 一次
 * 4 byte, RX 同步收 4 byte. 不能 1-byte at a time, hardware 不支持稳定.
 *
 * 4-byte address commands (W25Q256 默认 3-byte address mode 但 0x12/0x13/0xDC
 * 是 4-byte 寻址 opcode 不需要 EN4B).
 */
#include <stdint.h>
#include <string.h>
#include "xil_printf.h"
#include "xil_io.h"

#define QSPI_BASE        0xE000D000U
#define QSPI_CR          (QSPI_BASE + 0x00U)
#define QSPI_ISR         (QSPI_BASE + 0x04U)
#define QSPI_IER         (QSPI_BASE + 0x08U)
#define QSPI_IDR         (QSPI_BASE + 0x0CU)
#define QSPI_ER          (QSPI_BASE + 0x14U)
#define QSPI_DR          (QSPI_BASE + 0x18U)
#define QSPI_TXD0        (QSPI_BASE + 0x1CU)
#define QSPI_RXD         (QSPI_BASE + 0x20U)
#define QSPI_SICR        (QSPI_BASE + 0x24U)
#define QSPI_TX_THR      (QSPI_BASE + 0x28U)
#define QSPI_RX_THR      (QSPI_BASE + 0x2CU)
#define QSPI_GPIO        (QSPI_BASE + 0x30U)
#define QSPI_LPBK        (QSPI_BASE + 0x38U)
#define QSPI_TXD1        (QSPI_BASE + 0x80U)
#define QSPI_TXD2        (QSPI_BASE + 0x84U)
#define QSPI_TXD3        (QSPI_BASE + 0x88U)
#define QSPI_LQSPI_CFG   (QSPI_BASE + 0xA0U)

/* CR bits (per Xilinx xqspips_hw.h, UG585 §12) */
#define CR_HOLDB_DR    (1U << 19)
#define CR_MAN_START   (1U << 16)        /* MANSTRT - manual transfer trigger */
#define CR_MAN_START_EN (1U << 15)       /* MANSTRTEN */
#define CR_SSFORCE     (1U << 14)        /* Force slave select (manual CS) */
#define CR_REF_CLK     (1U << 8)         /* Should be 0 */
#define CR_SSCTRL      (1U << 10)        /* SS decode: 0=SS0 asserted, 1=deasserted */
#define CR_FCK_DIV_4   (0x1U << 3)
#define CR_FCK_DIV_64  (0x5U << 3)
#define CR_CPHA        (1U << 2)
#define CR_CPOL        (1U << 1)
#define CR_MSTR        (1U << 0)

/* ISR bits (per Xilinx xqspips_hw.h) */
#define ISR_RX_OVR     (1U << 0)
#define ISR_TX_NFULL   (1U << 2)
#define ISR_TX_FULL    (1U << 3)
#define ISR_RX_NEMPTY  (1U << 4)

#define BOOT_BIN_DDR_ADDR    0x10000000UL
#define MAGIC_SIZE_ADDR      0x18000004UL

#define CMD_WREN              0x06
#define CMD_RDSR1             0x05
#define CMD_RDID              0x9F
#define CMD_PP4B              0x12
#define CMD_READ4B            0x13
#define CMD_BE64K_4B          0xDC
#define CMD_EN4B              0xB7  /* Enter 4-byte address mode */

#define PAGE_SIZE             256
#define BLOCK_SIZE            65536

static void qspi_pin_init(void)
{
    Xil_Out32(0xF8000008, 0xDF0DU);                 /* SLCR_UNLOCK */
    Xil_Out32(0xF8000168, 0x00000901U);             /* QSPI clk */
    {
        u32 aper = Xil_In32(0xF800012CU);
        Xil_Out32(0xF800012CU, aper | (1U << 23));  /* LQSPI_CPU_1XCLKACT */
    }
    Xil_Out32(0xF8000704, 0x00001602U);
    Xil_Out32(0xF8000708, 0x00000602U);
    Xil_Out32(0xF800070C, 0x00000602U);
    Xil_Out32(0xF8000710, 0x00000602U);
    Xil_Out32(0xF8000714, 0x00000602U);
    Xil_Out32(0xF8000718, 0x00000602U);
    Xil_Out32(0xF8000004, 0x767BU);                 /* SLCR_LOCK */
}

static void qspi_init(void)
{
    Xil_Out32(QSPI_ER, 0);
    Xil_Out32(QSPI_IDR, 0x7FU);
    Xil_Out32(QSPI_ISR, 0x7FU);
    /* CR: master, HOLDB high, prescaler /4, manual CS via SSFORCE,
     * 初始 SSCTRL=1 (deassert), CPOL=0/CPHA=0 (W25Q256 mode 0).
     * 不用 manual start; auto-start = TX FIFO 写入即 begin transfer. */
    u32 cr = CR_HOLDB_DR | CR_SSFORCE | CR_SSCTRL |
             CR_FCK_DIV_4 | CR_MSTR;
    Xil_Out32(QSPI_CR, cr);
    Xil_Out32(QSPI_LPBK, 0);
    Xil_Out32(QSPI_LQSPI_CFG, 0);
    Xil_Out32(QSPI_TX_THR, 1);
    Xil_Out32(QSPI_RX_THR, 1);
    Xil_Out32(QSPI_GPIO, 1);                  /* WP_N high */
    Xil_Out32(QSPI_ER, 1);
}

static void cs_assert(void)   { u32 cr = Xil_In32(QSPI_CR); Xil_Out32(QSPI_CR, cr & ~CR_SSCTRL); }
static void cs_deassert(void) { u32 cr = Xil_In32(QSPI_CR); Xil_Out32(QSPI_CR, cr |  CR_SSCTRL); }

/* Send N bytes (1..4), receive N bytes synchronously. CS already asserted.
 * Auto-start mode: TX FIFO write triggers transfer. */
static u32 qspi_xfer4(u32 tx_data, int n_bytes)
{
    /* Drain stale RX FIFO entries first */
    while (Xil_In32(QSPI_ISR) & ISR_RX_NEMPTY) {
        (void)Xil_In32(QSPI_RXD);
    }
    Xil_Out32(QSPI_ISR, 0x7FU);   /* clear all ISR */

    u32 txd_reg;
    switch (n_bytes) {
        case 1: txd_reg = QSPI_TXD1; break;
        case 2: txd_reg = QSPI_TXD2; break;
        case 3: txd_reg = QSPI_TXD3; break;
        default: txd_reg = QSPI_TXD0; n_bytes = 4; break;
    }
    Xil_Out32(txd_reg, tx_data);

    /* Wait for RX FIFO not empty */
    int spin = 0;
    while (!(Xil_In32(QSPI_ISR) & ISR_RX_NEMPTY)) {
        if (++spin > 1000000) {
            xil_printf("[qfw] xfer timeout (n=%d) ISR=0x%x CR=0x%x\r\n",
                       n_bytes, (unsigned)Xil_In32(QSPI_ISR),
                       (unsigned)Xil_In32(QSPI_CR));
            return 0;
        }
    }
    return Xil_In32(QSPI_RXD);
}

static int read_jedec(u8 *id3)
{
    cs_assert();
    /* RDID + 3 dummy bytes = 4 byte transfer to TXD0. RX 4 bytes:
     * byte 0 = response to cmd phase (don't care), byte 1-3 = ID. */
    u32 rx = qspi_xfer4(CMD_RDID, 4);   /* tx low byte = cmd */
    cs_deassert();
    /* RX is right-justified per UG585. TXD0 写 instr 是 LSByte first;
     * RXD: bytes received in order, low byte = first received (= response to
     * cmd shift in, == 0 from flash). */
    /* Actually per Xilinx driver: response in RXD bits[31:0] = data1<<24 | data2<<16 | data3<<8 | first */
    id3[0] = (rx >>  8) & 0xFFU;
    id3[1] = (rx >> 16) & 0xFFU;
    id3[2] = (rx >> 24) & 0xFFU;
    (void)rx;
    return 0;
}

static int wait_not_busy(void)
{
    for (int spin = 0; spin < 5000000; spin++) {
        cs_assert();
        u32 rx = qspi_xfer4(CMD_RDSR1, 2);   /* cmd + 1 dummy = 2 byte */
        cs_deassert();
        u8 status = (rx >> 8) & 0xFFU;
        if ((status & 0x01U) == 0) return 0;
    }
    return -1;
}

static void wren(void)
{
    cs_assert();
    qspi_xfer4(CMD_WREN, 1);
    cs_deassert();
}

static int erase_block(u32 addr)
{
    wren();
    cs_assert();
    /* CMD + 4-byte addr = 5 byte. 用 TXD0 (4 byte: cmd + addr[31:24..15:8])
     * 然后 TXD1 (1 byte: addr[7:0]) */
    u32 first4 = (u32)CMD_BE64K_4B
               | (((addr >> 24) & 0xFFU) << 8)
               | (((addr >> 16) & 0xFFU) << 16)
               | (((addr >>  8) & 0xFFU) << 24);
    qspi_xfer4(first4, 4);
    qspi_xfer4(addr & 0xFFU, 1);
    cs_deassert();
    return wait_not_busy();
}

static int program_page(u32 addr, const u8 *data, u32 len)
{
    if (len > PAGE_SIZE) return -1;
    wren();
    cs_assert();
    /* cmd + 4 byte addr (5 byte 头部) + len byte data */
    u32 first4 = (u32)CMD_PP4B
               | (((addr >> 24) & 0xFFU) << 8)
               | (((addr >> 16) & 0xFFU) << 16)
               | (((addr >>  8) & 0xFFU) << 24);
    qspi_xfer4(first4, 4);
    /* addr[7:0] + 起始 3 byte data */
    u32 next4 = (addr & 0xFFU)
              | (len > 0 ? ((u32)data[0] <<  8) : 0)
              | (len > 1 ? ((u32)data[1] << 16) : 0)
              | (len > 2 ? ((u32)data[2] << 24) : 0);
    qspi_xfer4(next4, 4);
    /* 剩余 data 4-byte at a time */
    u32 i = 3;
    while (i + 4 <= len) {
        u32 d = (u32)data[i] | ((u32)data[i+1] << 8) |
                ((u32)data[i+2] << 16) | ((u32)data[i+3] << 24);
        qspi_xfer4(d, 4);
        i += 4;
    }
    while (i < len) {
        qspi_xfer4(data[i], 1);
        i++;
    }
    cs_deassert();
    return wait_not_busy();
}

static int read_byte(u32 addr, u8 *out)
{
    cs_assert();
    /* All-4-byte transfers: cmd+addr[31:24..15:8] | addr[7:0]+3 dummies.
     * RX of 2nd transfer: byte 0 (during addr[7:0] tx) = junk, byte 1 (during
     * dummy[0]) = data byte 0. */
    u32 first4 = (u32)CMD_READ4B
               | (((addr >> 24) & 0xFFU) << 8)
               | (((addr >> 16) & 0xFFU) << 16)
               | (((addr >>  8) & 0xFFU) << 24);
    qspi_xfer4(first4, 4);
    u32 rx = qspi_xfer4((u32)(addr & 0xFFU), 4);   /* TXD0 4-byte: addr[7:0] + 0 + 0 + 0 */
    cs_deassert();
    *out = (rx >> 8) & 0xFFU;   /* byte 1 = data 0 */
    return 0;
}

void qspi_flash_writer_main(void)
{
    xil_printf("[qfw] === QSPI flash writer (W25Q256, raw 4-byte xfer) ===\r\n");
    qspi_pin_init();
    qspi_init();
    xil_printf("[qfw] init done CR=0x%x ER=0x%x\r\n",
               (unsigned)Xil_In32(QSPI_CR), (unsigned)Xil_In32(QSPI_ER));

    /* Internal loopback test: TX→RX 短路, 验证 controller 工作 */
    {
        Xil_Out32(QSPI_LPBK, 0x21U);   /* enable internal loopback (bit 5 + delay nss) */
        cs_assert();
        u32 rx = qspi_xfer4(0xDEADBEEFU, 4);
        cs_deassert();
        Xil_Out32(QSPI_LPBK, 0);
        xil_printf("[qfw] loopback: tx=0xDEADBEEF rx=0x%08x\r\n", (unsigned)rx);
    }

    /* Enter 4-byte address mode (W25Q256 default 3-byte). EN4B 0xB7. */
    cs_assert();
    qspi_xfer4(CMD_EN4B, 1);
    cs_deassert();
    xil_printf("[qfw] EN4B sent\r\n");

    u8 id[3] = { 0 };
    read_jedec(id);
    xil_printf("[qfw] JEDEC ID = %02x %02x %02x", id[0], id[1], id[2]);
    if (id[0] == 0xEF && id[1] == 0x40 && id[2] == 0x19) {
        xil_printf(" (Winbond W25Q256JV) OK\r\n");
    } else if (id[0] == 0xFF || id[0] == 0x00) {
        xil_printf(" (no response, abort)\r\n");
        return;
    } else {
        xil_printf(" (unknown, continue anyway)\r\n");
    }

    u32 boot_size = Xil_In32(MAGIC_SIZE_ADDR);
    if (boot_size == 0 || boot_size > 0x01000000) {
        xil_printf("[qfw] bad size 0x%x\r\n", (unsigned)boot_size);
        return;
    }
    xil_printf("[qfw] BOOT.bin size %u bytes\r\n", (unsigned)boot_size);

    const u8 *src = (const u8 *)BOOT_BIN_DDR_ADDR;

    /* Sanity: read 0x0 BEFORE erase 看 raw flash content (出厂 default) */
    {
        u8 b;
        xil_printf("[qfw] sanity read pre-erase [0..7]:\r\n");
        for (u32 i = 0; i < 8; i++) {
            read_byte(i, &b);
            xil_printf("  %02x", b);
        }
        xil_printf("\r\n");
    }

    u32 n_blocks = (boot_size + BLOCK_SIZE - 1) / BLOCK_SIZE;
    xil_printf("[qfw] erasing %u blocks (64KB each)...\r\n", (unsigned)n_blocks);
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

    /* Sanity 2: read 0x0 after erase. 应该 0xFF (erased default) */
    {
        u8 b;
        xil_printf("[qfw] sanity read post-erase [0..7]:\r\n");
        for (u32 i = 0; i < 8; i++) {
            read_byte(i, &b);
            xil_printf("  %02x", b);
        }
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
        if ((p & 0xFF) == 0xFF || p == n_pages - 1) {
            xil_printf("[qfw]   programmed %u/%u\r\n",
                       (unsigned)(p + 1), (unsigned)n_pages);
        }
    }
    xil_printf("[qfw] program done\r\n");

    /* Hex dump 前 16 byte for debug */
    xil_printf("[qfw] hex dump [0..15]:\r\n");
    for (u32 i = 0; i < 16; i++) {
        u8 got;
        read_byte(i, &got);
        xil_printf("[qfw]   [%02x] got=%02x expect=%02x\r\n",
                   (unsigned)i, got, src[i]);
    }
    /* Spot verify: 5 个采样点 */
    xil_printf("[qfw] spot verify...\r\n");
    int fail = 0;
    u32 spots[5] = { 0, 256, boot_size / 2, boot_size - 256, boot_size - 1 };
    for (int s = 0; s < 5; s++) {
        u32 a = spots[s];
        u8 got;
        if (read_byte(a, &got) < 0 || got != src[a]) {
            xil_printf("[qfw] verify FAIL @ 0x%x got=%02x expect=%02x\r\n",
                       (unsigned)a, got, src[a]);
            fail++;
        }
    }
    if (fail) return;
    xil_printf("[qfw] verify OK\r\n");
    xil_printf("[qfw] === flash write SUCCESS ===\r\n");
}
