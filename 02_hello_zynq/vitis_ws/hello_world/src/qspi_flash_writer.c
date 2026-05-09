/* QSPI flash writer for W25Q256JV using XQspiPs driver from BSP.
 * BD now has QSPI peripheral enabled, ps7_init configures MIO+clock,
 * BSP includes XQspiPs driver. Standard PolledTransfer 应该 work.
 */
#include <stdint.h>
#include <string.h>
#include "xil_printf.h"
#include "xil_io.h"
#include "xparameters.h"
#include "xqspips.h"

#define BOOT_BIN_DDR_ADDR    0x10000000UL
#define MAGIC_SIZE_ADDR      0x18000004UL

#define CMD_WREN     0x06
#define CMD_RDSR1    0x05
#define CMD_RDID     0x9F
#define CMD_PP       0x02
#define CMD_READ     0x03
#define CMD_BE64K    0xD8
#define CMD_EX4B     0xE9

#define PAGE_SIZE     256
#define BLOCK_SIZE    65536

static XQspiPs Qspi;

static void qspi_pin_init(void)
{
    Xil_Out32(0xF8000008, 0xDF0DU);                 /* SLCR_UNLOCK */
    Xil_Out32(0xF8000168, 0x00000901U);             /* QSPI clk */
    {
        u32 aper = Xil_In32(0xF800012CU);
        Xil_Out32(0xF800012CU, aper | (1U << 23));  /* LQSPI_CPU_1XCLKACT */
    }
    Xil_Out32(0xF8000704, 0x00001602U);   /* MIO1 QSPI_CSN PULLUP */
    Xil_Out32(0xF8000708, 0x00000602U);   /* MIO2 QSPI_IO0 */
    Xil_Out32(0xF800070C, 0x00000602U);
    Xil_Out32(0xF8000710, 0x00000602U);
    Xil_Out32(0xF8000714, 0x00000602U);
    Xil_Out32(0xF8000718, 0x00000602U);
    Xil_Out32(0xF8000004, 0x767BU);                 /* SLCR_LOCK */
}

static int qspi_init(void)
{
    qspi_pin_init();
#ifdef SDT
    XQspiPs_Config *cfg = XQspiPs_LookupConfig(XPAR_QSPI_BASEADDR);
#else
    XQspiPs_Config *cfg = XQspiPs_LookupConfig(0);
#endif
    if (!cfg) { xil_printf("[qfw] LookupConfig fail\r\n"); return -1; }
    if (XQspiPs_CfgInitialize(&Qspi, cfg, cfg->BaseAddress) != XST_SUCCESS) {
        xil_printf("[qfw] CfgInitialize fail\r\n");
        return -1;
    }
    XQspiPs_SetClkPrescaler(&Qspi, XQSPIPS_CLK_PRESCALE_8);
    u32 opts = XQSPIPS_FORCE_SSELECT_OPTION |
               XQSPIPS_MANUAL_START_OPTION |
               XQSPIPS_HOLD_B_DRIVE_OPTION;
    XQspiPs_SetOptions(&Qspi, opts);
    XQspiPs_SetSlaveSelect(&Qspi);
    XQspiPs_Enable(&Qspi);
    /* Re-apply MIO config (CfgInit/Enable may have reset peripheral state) */
    qspi_pin_init();
    return 0;
}

static int read_jedec(u8 *id3)
{
    u8 tx[4] = { CMD_RDID, 0, 0, 0 };
    u8 rx[4] = { 0 };
    if (XQspiPs_PolledTransfer(&Qspi, tx, rx, 4) != XST_SUCCESS) return -1;
    id3[0] = rx[1]; id3[1] = rx[2]; id3[2] = rx[3];
    return 0;
}

static int wait_not_busy(void)
{
    for (int spin = 0; spin < 5000000; spin++) {
        u8 tx[2] = { CMD_RDSR1, 0 };
        u8 rx[2] = { 0 };
        if (XQspiPs_PolledTransfer(&Qspi, tx, rx, 2) != XST_SUCCESS) return -1;
        if ((rx[1] & 0x01U) == 0) return 0;
    }
    return -1;
}

static int wren(void)
{
    /* Write-only command: pass RecvBufPtr=NULL so driver does not switch
     * to dummy-TX mode (which would corrupt any data beyond the first word).
     * See xqspips.c PolledTransfer: when RecvBufferPtr != NULL and offset > 4
     * the driver writes XQSPIPS_DUMMY_TX_DATA (0xFFFFFFFF) instead of SendBuf. */
    u8 tx = CMD_WREN;
    return XQspiPs_PolledTransfer(&Qspi, &tx, NULL, 1) == XST_SUCCESS ? 0 : -1;
}

static int erase_block(u32 addr)
{
    if (wren() < 0) return -1;
    u8 tx[4] = { CMD_BE64K,
                 (u8)((addr >> 16) & 0xFF),
                 (u8)((addr >>  8) & 0xFF),
                 (u8) (addr        & 0xFF) };
    /* Pure write — no RX buffer */
    if (XQspiPs_PolledTransfer(&Qspi, tx, NULL, 4) != XST_SUCCESS) return -1;
    return wait_not_busy();
}

static int program_page(u32 addr, const u8 *data, u32 len)
{
    if (len > PAGE_SIZE) return -1;
    if (wren() < 0) return -1;
    static u8 tx[4 + PAGE_SIZE];
    tx[0] = CMD_PP;
    tx[1] = (u8)((addr >> 16) & 0xFF);
    tx[2] = (u8)((addr >>  8) & 0xFF);
    tx[3] = (u8) (addr        & 0xFF);
    memcpy(tx + 4, data, len);
    /* CRITICAL: RecvBufPtr MUST be NULL for page-program. If non-NULL the
     * Xilinx driver assumes a READ flow and replaces every TX word past
     * offset 4 with XQSPIPS_DUMMY_TX_DATA (0xFFFFFFFF), so the flash only
     * sees cmd+addr followed by 256 bytes of 0xFF (a no-op on erased flash).
     * This was the root cause of "first 4 bytes program, rest stays 0xFF". */
    if (XQspiPs_PolledTransfer(&Qspi, tx, NULL, 4 + len) != XST_SUCCESS) return -1;
    return wait_not_busy();
}

static int read_bytes(u32 addr, u8 *out, u32 n)
{
    if (n == 0) return 0;
    if (n > 256) return -1;
    static u8 tx[4 + 256];
    static u8 rx[4 + 256];
    tx[0] = CMD_READ;
    tx[1] = (u8)((addr >> 16) & 0xFF);
    tx[2] = (u8)((addr >>  8) & 0xFF);
    tx[3] = (u8) (addr        & 0xFF);
    memset(tx + 4, 0, n);
    if (XQspiPs_PolledTransfer(&Qspi, tx, rx, 4 + n) != XST_SUCCESS) return -1;
    memcpy(out, rx + 4, n);
    return 0;
}

void qspi_flash_writer_main(void)
{
    xil_printf("[qfw] === QSPI flash writer (BSP XQspiPs driver) ===\r\n");
    if (qspi_init() < 0) return;
    xil_printf("[qfw] init done\r\n");

    /* Force 3-byte addr mode (write-only command, no RX) */
    {
        u8 tx = CMD_EX4B;
        XQspiPs_PolledTransfer(&Qspi, &tx, NULL, 1);
    }
    xil_printf("[qfw] EX4B sent\r\n");

    u8 id[3] = { 0 };
    read_jedec(id);
    xil_printf("[qfw] JEDEC ID = %02x %02x %02x", id[0], id[1], id[2]);
    if (id[0] == 0xEF && id[1] == 0x40 && id[2] == 0x19) {
        xil_printf(" (Winbond W25Q256JV) OK\r\n");
    } else {
        xil_printf(" (unexpected)\r\n");
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
    xil_printf("[qfw] BOOT.bin %u bytes\r\n", (unsigned)boot_size);

    const u8 *src = (const u8 *)BOOT_BIN_DDR_ADDR;

    u32 n_blocks = (boot_size + BLOCK_SIZE - 1) / BLOCK_SIZE;
    xil_printf("[qfw] erasing %u blocks...\r\n", (unsigned)n_blocks);
    for (u32 b = 0; b < n_blocks; b++) {
        if (erase_block(b * BLOCK_SIZE) < 0) {
            xil_printf("[qfw] erase fail %u\r\n", (unsigned)b);
            return;
        }
        if ((b & 0x07) == 7 || b == n_blocks - 1)
            xil_printf("[qfw]   erased %u/%u\r\n", (unsigned)(b+1), (unsigned)n_blocks);
    }

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
            xil_printf("[qfw] prog fail %u\r\n", (unsigned)p);
            return;
        }
        if ((p & 0x3FF) == 0x3FF || p == n_pages - 1)
            xil_printf("[qfw]   prog %u/%u\r\n", (unsigned)(p+1), (unsigned)n_pages);
    }

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
    xil_printf("[qfw] === flash write SUCCESS ===\r\n");
}
