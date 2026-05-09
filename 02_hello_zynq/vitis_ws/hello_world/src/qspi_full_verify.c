/* qspi_full_verify.c — 完整 readback QSPI flash 跟 DDR BOOT.bin 对比.
 * 触发: xsdb 写 magic 0xFA571101 @ 0x18000000 + size @ 0x18000004.
 * helloworld.c main() 检测到调用 qspi_full_verify_main(). */
#include <stdint.h>
#include <string.h>
#include "xil_printf.h"
#include "xil_io.h"
#include "xqspips.h"

#define BOOT_BIN_DDR_ADDR  0x10000000UL
#define MAGIC_SIZE_ADDR    0x18000004UL

#define CMD_READ   0x03
#define CMD_RDID   0x9F
#define CMD_EX4B   0xE9

extern XQspiPs *qfw_get_qspi(void);

static int qspi_init_local(XQspiPs *q)
{
    /* MIO + clk re-init (same as qspi_flash_writer.c) */
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

#ifdef SDT
    XQspiPs_Config *cfg = XQspiPs_LookupConfig(XPAR_QSPI_BASEADDR);
#else
    XQspiPs_Config *cfg = XQspiPs_LookupConfig(0);
#endif
    if (!cfg) return -1;
    if (XQspiPs_CfgInitialize(q, cfg, cfg->BaseAddress) != XST_SUCCESS) return -1;
    XQspiPs_SetClkPrescaler(q, XQSPIPS_CLK_PRESCALE_8);
    XQspiPs_SetOptions(q,
        XQSPIPS_FORCE_SSELECT_OPTION |
        XQSPIPS_MANUAL_START_OPTION |
        XQSPIPS_HOLD_B_DRIVE_OPTION);
    XQspiPs_SetSlaveSelect(q);
    XQspiPs_Enable(q);

    /* Re-apply MIO config */
    Xil_Out32(0xF8000008, 0xDF0DU);
    Xil_Out32(0xF8000704, 0x00001602U);
    Xil_Out32(0xF8000708, 0x00000602U);
    Xil_Out32(0xF800070C, 0x00000602U);
    Xil_Out32(0xF8000710, 0x00000602U);
    Xil_Out32(0xF8000714, 0x00000602U);
    Xil_Out32(0xF8000718, 0x00000602U);
    Xil_Out32(0xF8000004, 0x767BU);

    /* Force 3-byte addr mode */
    u8 tx = CMD_EX4B;
    XQspiPs_PolledTransfer(q, &tx, NULL, 1);

    return 0;
}

static int read_chunk(XQspiPs *q, u32 addr, u8 *out, u32 n)
{
    static u8 tx[4 + 256];
    static u8 rx[4 + 256];
    if (n > 256) return -1;
    tx[0] = CMD_READ;
    tx[1] = (u8)((addr >> 16) & 0xFF);
    tx[2] = (u8)((addr >>  8) & 0xFF);
    tx[3] = (u8) (addr        & 0xFF);
    memset(tx + 4, 0, n);
    if (XQspiPs_PolledTransfer(q, tx, rx, 4 + n) != XST_SUCCESS) return -1;
    memcpy(out, rx + 4, n);
    return 0;
}

void qspi_full_verify_main(void)
{
    static XQspiPs Qspi;
    xil_printf("[verify] === QSPI full readback verify ===\r\n");
    if (qspi_init_local(&Qspi) < 0) {
        xil_printf("[verify] init fail\r\n");
        return;
    }

    u32 boot_size = Xil_In32(MAGIC_SIZE_ADDR);
    if (boot_size == 0 || boot_size > 0x01000000) {
        xil_printf("[verify] bad size 0x%x\r\n", (unsigned)boot_size);
        return;
    }
    xil_printf("[verify] reading %u bytes from QSPI...\r\n", (unsigned)boot_size);

    const u8 *expect = (const u8 *)BOOT_BIN_DDR_ADDR;
    u8 buf[256];
    /* SPOT-CHECK MODE: only read 8 chunks (256B each) at strategic offsets to
     * see if the program flow itself works before full readback. */
    static const u32 spot_offsets[] = {
        0x000000, 0x000100, 0x000200, 0x010000,
        0x100000, 0x200000, 0x300000, 0x400000
    };
    for (u32 i = 0; i < sizeof(spot_offsets)/sizeof(u32); i++) {
        u32 addr = spot_offsets[i];
        if (addr >= boot_size) break;
        xil_printf("[verify] read @0x%06x ... ", (unsigned)addr);
        if (read_chunk(&Qspi, addr, buf, 256) < 0) {
            xil_printf("FAIL\r\n");
            return;
        }
        u32 mm = 0;
        for (u32 j = 0; j < 256; j++) if (buf[j] != expect[addr + j]) mm++;
        xil_printf("mismatch %u/256, first 8B flash:", (unsigned)mm);
        for (u32 j = 0; j < 8; j++) xil_printf(" %02x", buf[j]);
        xil_printf(" expect:");
        for (u32 j = 0; j < 8; j++) xil_printf(" %02x", expect[addr+j]);
        xil_printf("\r\n");
    }
    xil_printf("[verify] spot-check done. exiting.\r\n");
    return;
}
