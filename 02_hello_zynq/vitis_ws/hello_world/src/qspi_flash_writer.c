/* QSPI flash writer for W25Q256JV on 鹿小班 Zynq, raw register access.
 * 不依赖 XQspiPs driver, 直接写 PS QSPI controller 寄存器 (UG585 §12).
 *
 * Workflow: BOOT.bin 在 DDR @ 0x10000000, size at 0x18000004.
 * 4-byte address commands (W25Q256 默认 3-byte address mode, 但 0x12/0x13/0xDC
 * 都是 4-byte address opcode 不需要 enter 4-byte mode).
 *
 * Algorithm: erase 64KB blocks → page program 256B → verify.
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
#define QSPI_MOD_ID      (QSPI_BASE + 0xFCU)

/* CR bits */
#define CR_IFMODE      (1U << 31)  /* 0=normal SPI, 1=I/O mode */
#define CR_HOLDB_DR    (1U << 19)
#define CR_MAN_START   (1U << 16)
#define CR_MAN_START_EN (1U << 15)
#define CR_MAN_CS      (1U << 14)
#define CR_PCS         (1U << 10)  /* Manual PCS state, 0=assert, 1=deassert */
#define CR_FCK_DIV_4   (0x1U << 3) /* divide by 4: clk/4 */
#define CR_FCK_DIV_8   (0x2U << 3)
#define CR_MODEFAIL_GEN_EN (1U << 17)
#define CR_MSTR        (1U << 0)
#define CR_CPOL        (1U << 1)
#define CR_CPHA        (1U << 2)

/* ISR bits */
#define ISR_TX_FIFO_NOT_FULL (1U << 2)
#define ISR_TX_FIFO_FULL  (1U << 3)
#define ISR_RX_FIFO_NOT_EMPTY (1U << 4)
#define ISR_TX_FIFO_UNDERFLOW (1U << 6)

#define BOOT_BIN_DDR_ADDR    0x10000000UL
#define MAGIC_SIZE_ADDR      0x18000004UL

#define CMD_WREN              0x06
#define CMD_RDSR1             0x05
#define CMD_RDID              0x9F
#define CMD_PP4B              0x12
#define CMD_READ4B            0x13
#define CMD_BE64K_4B          0xDC

#define PAGE_SIZE             256
#define BLOCK_SIZE            65536

static void qspi_pin_init(void)
{
    Xil_Out32(0xF8000008, 0xDF0DU);                    /* SLCR_UNLOCK */
    Xil_Out32(0xF8000168, 0x00000901U);                /* QSPI clk: IO_PLL/9 */
    /* APER_CLK_CTRL: enable LQSPI peripheral AHB clock (bit 23 in Zynq 7000).
     * 实际 Zynq 7000 0xF800_012C: bit[23] = LQSPI_CPU_1XCLKACT.
     * 不 set 则 QSPI register write 全部丢失 (peripheral clock gated). */
    {
        u32 aper = Xil_In32(0xF800012CU);
        Xil_Out32(0xF800012CU, aper | (1U << 23));
    }
    Xil_Out32(0xF8000704, 0x00001602U);   /* MIO1 QSPI_CSN PULLUP */
    Xil_Out32(0xF8000708, 0x00000602U);   /* MIO2 QSPI_IO0 */
    Xil_Out32(0xF800070C, 0x00000602U);   /* MIO3 QSPI_IO1 */
    Xil_Out32(0xF8000710, 0x00000602U);   /* MIO4 QSPI_IO2 */
    Xil_Out32(0xF8000714, 0x00000602U);   /* MIO5 QSPI_IO3 */
    Xil_Out32(0xF8000718, 0x00000602U);   /* MIO6 QSPI_CLK */
    Xil_Out32(0xF8000004, 0x767BU);                    /* SLCR_LOCK */
}

static void qspi_init(void)
{
    /* Disable + reset QSPI controller */
    Xil_Out32(QSPI_ER, 0);
    Xil_Out32(QSPI_IDR, 0x7FU);
    Xil_Out32(QSPI_ISR, 0x7FU);   /* clear pending */

    /* CR: master, manual CS + manual start, /4 prescaler, holdb_dr, normal SPI mode */
    u32 cr = CR_HOLDB_DR | CR_MAN_START_EN | CR_MAN_CS | CR_PCS |
             CR_FCK_DIV_4 | CR_MODEFAIL_GEN_EN | CR_MSTR;
    Xil_Out32(QSPI_CR, cr);
    Xil_Out32(QSPI_LPBK, 0);
    Xil_Out32(QSPI_LQSPI_CFG, 0);
    Xil_Out32(QSPI_GPIO, 1);              /* WP_N = high (release write protect) */
    Xil_Out32(QSPI_ER, 1);                /* enable */

    /* Debug: print register state */
    xil_printf("[qfw]   CR  = 0x%08x\r\n", (unsigned)Xil_In32(QSPI_CR));
    xil_printf("[qfw]   ER  = 0x%08x\r\n", (unsigned)Xil_In32(QSPI_ER));
    xil_printf("[qfw]   ISR = 0x%08x\r\n", (unsigned)Xil_In32(QSPI_ISR));
    xil_printf("[qfw]   GPIO= 0x%08x\r\n", (unsigned)Xil_In32(QSPI_GPIO));
}

static void cs_assert(void)   { u32 cr = Xil_In32(QSPI_CR); Xil_Out32(QSPI_CR, cr & ~CR_PCS); }
static void cs_deassert(void) { u32 cr = Xil_In32(QSPI_CR); Xil_Out32(QSPI_CR, cr |  CR_PCS); }

/* 单字节传输, 同时收发. 返回收到字节. */
static u8 qspi_txrx_byte(u8 tx)
{
    /* Wait TX FIFO not full (ISR bit 2) */
    int spin = 0;
    while (!(Xil_In32(QSPI_ISR) & ISR_TX_FIFO_NOT_FULL)) {
        if (++spin > 100000) { xil_printf("[qfw] TX_NOT_FULL stuck ISR=0x%x\r\n",
                                          (unsigned)Xil_In32(QSPI_ISR)); return 0xFF; }
    }
    Xil_Out32(QSPI_TXD1, tx);   /* TXD1 = 1-byte transfer */
    /* trigger manual start */
    u32 cr = Xil_In32(QSPI_CR);
    Xil_Out32(QSPI_CR, cr | CR_MAN_START);
    /* wait for RX */
    spin = 0;
    while (!(Xil_In32(QSPI_ISR) & ISR_RX_FIFO_NOT_EMPTY)) {
        if (++spin > 100000) {
            static int rep = 0;
            if (rep++ < 3)
                xil_printf("[qfw] RX_NOT_EMPTY stuck ISR=0x%x CR=0x%x\r\n",
                           (unsigned)Xil_In32(QSPI_ISR),
                           (unsigned)Xil_In32(QSPI_CR));
            return 0xFF;
        }
    }
    u32 rxd = Xil_In32(QSPI_RXD);
    return (u8)(rxd & 0xFFU);
}

static int wait_not_busy(void)
{
    for (int spin = 0; spin < 5000000; spin++) {
        cs_assert();
        qspi_txrx_byte(CMD_RDSR1);
        u8 status = qspi_txrx_byte(0);
        cs_deassert();
        if ((status & 0x01U) == 0) return 0;
    }
    xil_printf("[qfw] busy timeout\r\n");
    return -1;
}

static void wren(void)
{
    cs_assert();
    qspi_txrx_byte(CMD_WREN);
    cs_deassert();
}

static int read_jedec(u8 *id3)
{
    cs_assert();
    qspi_txrx_byte(CMD_RDID);
    id3[0] = qspi_txrx_byte(0);
    id3[1] = qspi_txrx_byte(0);
    id3[2] = qspi_txrx_byte(0);
    cs_deassert();
    return 0;
}

static int erase_block(u32 addr)
{
    wren();
    cs_assert();
    qspi_txrx_byte(CMD_BE64K_4B);
    qspi_txrx_byte((addr >> 24) & 0xFF);
    qspi_txrx_byte((addr >> 16) & 0xFF);
    qspi_txrx_byte((addr >>  8) & 0xFF);
    qspi_txrx_byte( addr        & 0xFF);
    cs_deassert();
    return wait_not_busy();
}

static int program_page(u32 addr, const u8 *data, u32 len)
{
    if (len > PAGE_SIZE) return -1;
    wren();
    cs_assert();
    qspi_txrx_byte(CMD_PP4B);
    qspi_txrx_byte((addr >> 24) & 0xFF);
    qspi_txrx_byte((addr >> 16) & 0xFF);
    qspi_txrx_byte((addr >>  8) & 0xFF);
    qspi_txrx_byte( addr        & 0xFF);
    for (u32 i = 0; i < len; i++) qspi_txrx_byte(data[i]);
    cs_deassert();
    return wait_not_busy();
}

static int verify_byte(u32 addr, u8 expect)
{
    cs_assert();
    qspi_txrx_byte(CMD_READ4B);
    qspi_txrx_byte((addr >> 24) & 0xFF);
    qspi_txrx_byte((addr >> 16) & 0xFF);
    qspi_txrx_byte((addr >>  8) & 0xFF);
    qspi_txrx_byte( addr        & 0xFF);
    u8 got = qspi_txrx_byte(0);
    cs_deassert();
    return (got == expect) ? 0 : -1;
}

void qspi_flash_writer_main(void)
{
    xil_printf("[qfw] === QSPI flash writer (W25Q256, raw reg) ===\r\n");
    qspi_pin_init();
    xil_printf("[qfw] MIO + clock init done\r\n");
    qspi_init();
    xil_printf("[qfw] QSPI controller init done\r\n");

    /* JEDEC ID check */
    u8 id[3] = { 0 };
    read_jedec(id);
    xil_printf("[qfw] JEDEC ID = %02x %02x %02x", id[0], id[1], id[2]);
    if (id[0] == 0xEF && id[1] == 0x40 && id[2] == 0x19) {
        xil_printf(" (Winbond W25Q256JV) OK\r\n");
    } else if (id[0] == 0x00 || id[0] == 0xFF) {
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

    u32 n_blocks = (boot_size + BLOCK_SIZE - 1) / BLOCK_SIZE;
    xil_printf("[qfw] erasing %u blocks (64KB each)...\r\n", (unsigned)n_blocks);
    for (u32 b = 0; b < n_blocks; b++) {
        if (erase_block(b * BLOCK_SIZE) < 0) return;
        if ((b & 0x07) == 7 || b == n_blocks - 1) {
            xil_printf("[qfw]   erased %u/%u\r\n", (unsigned)(b + 1), (unsigned)n_blocks);
        }
    }
    xil_printf("[qfw] erase done\r\n");

    u32 n_pages = (boot_size + PAGE_SIZE - 1) / PAGE_SIZE;
    xil_printf("[qfw] programming %u pages (256B each)...\r\n", (unsigned)n_pages);
    for (u32 p = 0; p < n_pages; p++) {
        u32 addr = p * PAGE_SIZE;
        u32 chunk = (boot_size - addr > PAGE_SIZE) ? PAGE_SIZE : (boot_size - addr);
        if (program_page(addr, src + addr, chunk) < 0) return;
        if ((p & 0xFF) == 0xFF || p == n_pages - 1) {
            xil_printf("[qfw]   programmed %u/%u\r\n", (unsigned)(p + 1), (unsigned)n_pages);
        }
    }
    xil_printf("[qfw] program done\r\n");

    /* spot-check verify (前 16 byte + 中间 16 byte + 末 16 byte) */
    xil_printf("[qfw] spot verify...\r\n");
    int fail = 0;
    for (u32 i = 0; i < 16; i++) if (verify_byte(i, src[i]) < 0) { fail++; break; }
    u32 mid = boot_size / 2;
    for (u32 i = 0; i < 16; i++) if (verify_byte(mid + i, src[mid + i]) < 0) { fail++; break; }
    u32 endo = boot_size - 16;
    for (u32 i = 0; i < 16; i++) if (verify_byte(endo + i, src[endo + i]) < 0) { fail++; break; }
    if (fail) {
        xil_printf("[qfw] VERIFY FAIL\r\n");
        return;
    }
    xil_printf("[qfw] verify OK\r\n");
    xil_printf("[qfw] === flash write SUCCESS ===\r\n");
}
