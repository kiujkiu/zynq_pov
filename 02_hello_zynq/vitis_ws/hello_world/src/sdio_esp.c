/*
 * sdio_esp.c - Zynq baremetal SDIO host driver for ESP32-C5 SDIO slave.
 *
 * Why a custom driver:
 *   The Xilinx `xsdps` driver in Vitis BSP defaults to detecting SD memory
 *   cards (runs CMD8 SEND_IF_COND, CMD2 ALL_SEND_CID, CMD9 SEND_CSD, ACMD41
 *   SD_SEND_OP_COND, etc.). ESP32 SDIO slave is an IO card — it does NOT
 *   respond to CMD8/2/9. Trying XSdPs_CardInitialize() would error out.
 *
 *   So we use XSdPs ONLY for low-level command/data plumbing (XSdPs_CmdTransfer
 *   + the raw register access) and we drive the SDIO IO-card init sequence
 *   ourselves: CMD0 → CMD5 → CMD3 → CMD7 → CMD52 setup.
 *
 * Init pseudocode:
 *   XSdPs_CfgInitialize(...)
 *   XSdPs_Identify_UhsMode equivalent skipped
 *   power up, 80 dummy clocks (XSdPs_Pow_On)
 *   CMD0 (no resp)
 *   CMD5 OCR=0  → R4 OCR (loop until card-ready bit 31 set, ~100 ms timeout)
 *   CMD3        → R6 RCA (16 high bits)
 *   CMD7 RCA   → R1b (card transition to "cmd" state)
 *   CMD52 read CCCR 0x00 ver-byte for sanity
 *   CMD52 write CCCR 0x10/0x11 = 512   (Func0 block size)
 *   CMD52 write FBR1 0x10/0x11 = 512   (Func1 block size)
 *   CMD52 write CCCR 0x02 = 0x02       (IOE bit1=1: enable Func1)
 *   poll  CMD52 read  CCCR 0x03 bit1=1 (Func1 ready)
 *   CMD52 write CCCR 0x04 = 0x03       (IEN master+Func1)
 *   CMD52 write CCCR 0x07 = 0x02       (4-bit bus)  -- if controller in 4-bit
 *
 * Send (CMD53):
 *   set BLK_SIZE register on host = 512
 *   set BLK_COUNT  = ceil(len/512)
 *   set TRANSFER_MODE = MULTI_BLK | DAT_DIR_HOST_TO_CARD | DMA_ENABLE
 *   issue CMD53 with arg = WR/Func1/BLK_MODE/INC/OP_CODE=4/REG=SDIO_ESP_RX_REG
 *   wait BUFFER_WRITE_READY interrupt, push payload, wait TX_COMPLETE
 *
 * Recv (CMD53 read):
 *   CMD53 read same way, dir = card → host.
 *
 * We keep the read/write paths thin — wrap XSdPs_CmdTransfer where possible.
 * If the deployed BSP's XSdPs has data API that takes a buffer and length
 * (XSdPs_ReadPolled / XSdPs_WritePolled), we call those for the bulk DMA.
 *
 * Logging convention:  "[sdio-esp] ..."  for every state-significant event.
 *
 * Status: code only, NOT hardware verified — user must enable SD0 in BD and
 * connect ESP32 first. See sdio_esp.README.md.
 */

#include "sdio_esp.h"
#include "xil_printf.h"
#include "xstatus.h"
#include "sleep.h"

/* Pull in XSdPs only if we have the BSP. If the BSP doesn't include xsdps
 * (currently the case in this worktree because SD0 not enabled in BD yet),
 * leave the implementation as a stub that returns SDIO_ESP_ERR_INIT — code
 * still compiles, helloworld can keep ENABLE_SDIO_ESP_BRIDGE=0 path.
 *
 * Once BD enables SD0 + Vitis regenerates BSP, the macro
 * XPAR_XSDPS_0_BASEADDR (or XPAR_PS7_SD_0_BASEADDR) is defined; we then
 * compile the real path. */

#include "xparameters.h"

#if defined(XPAR_XSDPS_0_BASEADDR) || defined(XPAR_PS7_SD_0_BASEADDR) || \
    defined(XPAR_PSU_SD_0_BASEADDR)
#  define SDIO_ESP_HAVE_XSDPS 1
#  include "xsdps.h"
#  include "xsdps_hw.h"
#else
#  define SDIO_ESP_HAVE_XSDPS 0
#endif

/* SDIO command opcodes */
#define SD_CMD0_GO_IDLE_STATE        0
#define SD_CMD3_SEND_RCA             3
#define SD_CMD5_IO_SEND_OP_COND      5
#define SD_CMD7_SELECT               7
#define SD_CMD52_IO_RW_DIRECT       52
#define SD_CMD53_IO_RW_EXTENDED     53

/* CMD52 arg layout (SDIO spec Part E1, Figure 5-3):
 *   bit31 = R/W   (0 read, 1 write)
 *   bits30..28 = Function number
 *   bit27 = RAW (read after write)
 *   bit26 = stuff (0)
 *   bits25..9 = Register address (17 bits)
 *   bit8  = stuff (0)
 *   bits7..0 = Write data (read = 0)
 */
#define CMD52_ARG(rw, fn, raw, addr, data) \
    ((((rw) & 1u) << 31) | (((fn) & 7u) << 28) | (((raw) & 1u) << 27) | \
     (((addr) & 0x1FFFFu) << 9) | ((data) & 0xFFu))

/* CMD53 arg layout (block mode):
 *   bit31 = R/W
 *   bits30..28 = Function
 *   bit27 = Block mode (1 = block, 0 = byte)
 *   bit26 = OP code (1 = incrementing addr, 0 = fixed addr / FIFO)
 *   bits25..9 = Register address
 *   bits8..0  = Block count (block mode) or byte count (byte mode)
 */
#define CMD53_ARG(rw, fn, blkmode, incr, addr, count) \
    ((((rw) & 1u) << 31) | (((fn) & 7u) << 28) | (((blkmode) & 1u) << 27) | \
     (((incr) & 1u) << 26) | (((addr) & 0x1FFFFu) << 9) | ((count) & 0x1FFu))

/*---------------------------------------------------------------------------*/

#if SDIO_ESP_HAVE_XSDPS

static XSdPs g_sd;          /* Xilinx SDPS controller instance */
static u32   g_rca = 0;     /* Relative Card Address acquired via CMD3 */
static int   g_initialized = 0;

/* essl_sdio host context: RX byte counter (latest read from PKT_LEN, and
 * how much we've already drained). Wraps modulo ESSL_RX_BYTE_MAX. */
static u32 g_rx_got_bytes = 0;
static u32 g_rx_got_bytes_latest = 0;

/* Init progress marker (so the diagnostic line shows where init died).
 * 0 = not started, increments at each major step. */
static int g_init_step = 0;

/* Capture first CMD-error code so diag can show it after timeout. */
static u32 g_last_err_intr = 0;
static u8  g_last_err_cmd  = 0;

/* Rate-limit timeout/error prints — main loop polls this every iteration,
 * so unfiltered prints flood the UART. */
static u32 g_err_print_skip = 0;
#define ERR_LOG(...) do { \
    if ((g_err_print_skip++ & 0x3FF) == 0) { xil_printf(__VA_ARGS__); } \
} while (0)

/* Init-time spin count: handles 400 kHz init clock where CMD takes ~100µs.
 * 500k * 3 cycles @ 666 MHz ≈ 2.25 ms — generous for init only. */
#define CMD_POLL_ITERS_INIT  500000

/* Runtime spin count: at 25 MHz CMD < 2µs. 10k iters ≈ 45 µs — generous
 * with margin for occasional slow responses, won't slow main loop. */
#define CMD_POLL_ITERS_RUN   10000

/* Active value — flipped to RUN after init completes. */
static u32 g_cmd_poll = CMD_POLL_ITERS_INIT;
#define CMD_POLL_ITERS  (g_cmd_poll)

/* Forward declarations */
static int essl_update_rx_len(u32 *latest);

/* Run a raw SDIO command via XSdPs primitive register write. We bypass the
 * XSdPs high-level SD-memory state machine. Builds the CMD register manually
 * and waits for command-complete.
 *
 * Returns response in *resp (low 32b). For CMD0 no resp, pass NULL. */
static int sdio_raw_cmd(u8 cmd, u32 arg, u32 resp_type, u32 *resp)
{
    UINTPTR base = g_sd.Config.BaseAddress;

    XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0xFFFF);
    XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
    XSdPs_WriteReg(base, XSDPS_ARGMT_OFFSET, arg);

    u16 cmd_reg = (u16)cmd << 8;
    switch (resp_type) {
        case 0:        cmd_reg |= 0x0;            break;  /* no resp */
        case 48:       cmd_reg |= 0x1A;           break;
        case 48136:    cmd_reg |= 0x09;           break;  /* R136 + CRC */
        case 481:      cmd_reg |= 0x1A;           break;  /* R1 */
        case 4801:     cmd_reg |= 0x1B;           break;  /* R1b (busy) */
        case 4804:     cmd_reg |= 0x02;           break;  /* R4 (CMD5: no CRC) */
        case 4806:     cmd_reg |= 0x1A;           break;  /* R6 */
        default:       cmd_reg |= 0x1A;           break;
    }

    XSdPs_WriteReg16(base, XSDPS_CMD_OFFSET, cmd_reg);

    int done = 0;
    for (u32 i = 0; i < CMD_POLL_ITERS; i++) {
        u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
        u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
        if (e) {
            if (g_last_err_intr == 0) { g_last_err_intr = e; g_last_err_cmd = cmd; }
            ERR_LOG("[sdio-esp] CMD%d err=0x%x\r\n", cmd, e);
            XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
            return SDIO_ESP_ERR_CMD;
        }
        if (s & 0x1) {
            XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x1);
            done = 1;
            break;
        }
    }
    if (!done) {
        if (g_last_err_intr == 0) { g_last_err_intr = 0xFFFF; g_last_err_cmd = cmd; }
        ERR_LOG("[sdio-esp] CMD%d timeout\r\n", cmd);
        /* Recover controller via SW reset of CMD+DAT lines; without this the
         * stuck state propagates to every subsequent command. */
        XSdPs_WriteReg8(base, XSDPS_SW_RST_OFFSET, 0x06);
        for (u32 i = 0; i < 100000; i++) {
            if (!(XSdPs_ReadReg8(base, XSDPS_SW_RST_OFFSET) & 0x06)) break;
        }
        XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0xFFFF);
        XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
        return SDIO_ESP_ERR_TIMEOUT;
    }

    if (resp) {
        *resp = XSdPs_ReadReg(base, XSDPS_RESP0_OFFSET);
    }
    return SDIO_ESP_OK;
}

/* Convenience: CMD52 direct write */
static int sdio_cmd52_write(u8 fn, u32 addr, u8 data)
{
    u32 r = 0;
    u32 arg = CMD52_ARG(1, fn, 0, addr, data);
    return sdio_raw_cmd(SD_CMD52_IO_RW_DIRECT, arg, 481, &r);
}

/* Convenience: CMD52 direct read */
static int sdio_cmd52_read(u8 fn, u32 addr, u8 *out)
{
    u32 r = 0;
    u32 arg = CMD52_ARG(0, fn, 0, addr, 0);
    int rc = sdio_raw_cmd(SD_CMD52_IO_RW_DIRECT, arg, 481, &r);
    if (rc) return rc;
    if (out) *out = (u8)(r & 0xFF);
    return SDIO_ESP_OK;
}

/* CMD53 multi-block transfer; uses XSdPs polled DMA path if available.
 *
 * For now we use a generic register-driven polled path: set block size /
 * block count / transfer mode, issue CMD53, then poll PRESENT_STATE for
 * BUFFER_READ_READY / BUFFER_WRITE_READY and shuffle 32b at a time. SDMA
 * could be wired later (XSdPs_WritePolled equivalent) — keeping the polled
 * PIO path here since ESP32 traffic is modest. */
static int sdio_cmd53_xfer(int is_write, u8 fn, u32 addr, u32 incr,
                           u8 *buf, u32 n_blocks)
{
    UINTPTR base = g_sd.Config.BaseAddress;
    u32 byte_count = n_blocks * SDIO_ESP_BLOCK_SIZE;

    /* Block size + block count regs */
    XSdPs_WriteReg16(base, XSDPS_BLK_SIZE_OFFSET, SDIO_ESP_BLOCK_SIZE);
    XSdPs_WriteReg16(base, XSDPS_BLK_CNT_OFFSET, (u16)n_blocks);

    /* Transfer mode: bit0 = DMA, bit1 = block-count enable,
     * bit4 = DAT direction (1 = read), bit5 = multi-block.
     * For single block n_blocks=1: don't set MULTI_BLK or BLK_CNT_EN. */
    u16 mode = 0;
    if (n_blocks > 1) mode = 0x22;        /* MULTI_BLK | BLK_CNT_EN */
    if (!is_write) mode |= 0x10;          /* read = card → host */
    /* DMA off → host CPU PIO via BUFFER_DATA_PORT */
    XSdPs_WriteReg16(base, XSDPS_XFER_MODE_OFFSET, mode);

    /* Clear all intr status before issue */
    XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0xFFFF);
    XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);

    /* Argument + CMD53 with data-present bit */
    u32 arg = CMD53_ARG(is_write ? 1 : 0, fn, 1 /*blk*/, incr & 1, addr,
                        n_blocks & 0x1FF);
    XSdPs_WriteReg(base, XSDPS_ARGMT_OFFSET, arg);

    u16 cmd_reg = ((u16)SD_CMD53_IO_RW_EXTENDED << 8) | (1u << 5) | 0x1A;
    XSdPs_WriteReg16(base, XSDPS_CMD_OFFSET, cmd_reg);

    /* Wait CMD_COMPLETE */
    {
        int done = 0;
        for (u32 i = 0; i < CMD_POLL_ITERS; i++) {
            u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
            u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
            if (e) { ERR_LOG("[sdio-esp] CMD53 cmd err=0x%x\r\n", e);
                     XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
                     return SDIO_ESP_ERR_CMD; }
            if (s & 0x1) { XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x1);
                           done = 1; break; }
        }
        if (!done) return SDIO_ESP_ERR_TIMEOUT;
    }

    /* Shuffle data 32b at a time, polling BUFFER_READ_READY (bit5) /
     * BUFFER_WRITE_READY (bit4). */
    u32 *p = (u32 *)buf;
    u32 words = byte_count / 4;
    u32 ready_mask = is_write ? 0x10 : 0x20;
    for (u32 i = 0; i < words; ) {
        int got = 0;
        /* Per-block timeout must accommodate larger payloads + slow clock. */
        for (u32 j = 0; j < 200000; j++) {
            u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
            if (s & ready_mask) {
                XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, ready_mask);
                got = 1; break;
            }
            u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
            if (e) { ERR_LOG("[sdio-esp] CMD53 data err=0x%x\r\n", e);
                     XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
                     return SDIO_ESP_ERR_CMD; }
        }
        if (!got) return SDIO_ESP_ERR_TIMEOUT;
        u32 burst = SDIO_ESP_BLOCK_SIZE / 4;
        for (u32 k = 0; k < burst && i < words; k++, i++) {
            if (is_write)
                XSdPs_WriteReg(base, XSDPS_BUF_DAT_PORT_OFFSET, p[i]);
            else
                p[i] = XSdPs_ReadReg(base, XSDPS_BUF_DAT_PORT_OFFSET);
        }
    }

    /* Wait TRANSFER_COMPLETE (bit1) */
    {
        int done = 0;
        for (u32 i = 0; i < 500000; i++) {
            u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
            if (s & 0x2) { XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x2);
                           done = 1; break; }
            u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
            if (e) { ERR_LOG("[sdio-esp] CMD53 xfer err=0x%x\r\n", e);
                     XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
                     return SDIO_ESP_ERR_CMD; }
        }
        if (!done) return SDIO_ESP_ERR_TIMEOUT;
    }

    return SDIO_ESP_OK;
}

int sdio_esp_init(void)
{
    XSdPs_Config *cfg = XSdPs_LookupConfig(0);
    if (!cfg) {
        xil_printf("[sdio-esp] LookupConfig(0) FAILED — SD0 not in BSP?\r\n");
        return SDIO_ESP_ERR_INIT;
    }
    int rc = XSdPs_CfgInitialize(&g_sd, cfg, cfg->BaseAddress);
    if (rc != XST_SUCCESS) {
        xil_printf("[sdio-esp] CfgInitialize rc=%d\r\n", rc);
        return SDIO_ESP_ERR_INIT;
    }

    /* Bring up clock / power without running SD memory probe. We mimic the
     * lower half of XSdPs_HostStart. Set 400 kHz init clock first. */
    UINTPTR base = g_sd.Config.BaseAddress;
    /* SW reset */
    g_init_step = 1;
    XSdPs_WriteReg8(base, XSDPS_SW_RST_OFFSET, XSDPS_SWRST_ALL_MASK);
    {
        int done = 0;
        for (u32 i = 0; i < 1000000; i++) {
            if (!(XSdPs_ReadReg8(base, XSDPS_SW_RST_OFFSET) & XSDPS_SWRST_ALL_MASK)) {
                done = 1; break;
            }
        }
        if (!done) {
            xil_printf("[sdio-esp] SW reset hang\r\n");
            return SDIO_ESP_ERR_INIT;
        }
    }
    /* SD clock init: BSP PS clock to SD0 is 50 MHz (from BD PCW_SDIO_PERIPHERAL_FREQMHZ).
     * SDHCI v2 divisor field (bits 8-15) divides by 2N. N=64 -> clock = 50e6/128 = ~390 kHz.
     * Sequence (SDHCI 2.1.2):
     *   1) Internal clock enable (bit 0 = 1), divisor set
     *   2) Wait Internal Clock Stable (bit 1 = 1)
     *   3) SD Clock Enable (bit 2 = 1)
     */
    g_init_step = 2;
    {
        u16 clk_ctrl = (0x40 << 8) | 0x0001;  /* divisor=64 + ICE=1 */
        XSdPs_WriteReg16(base, XSDPS_CLK_CTRL_OFFSET, clk_ctrl);
        int stable = 0;
        for (u32 i = 0; i < 1000000; i++) {
            if (XSdPs_ReadReg16(base, XSDPS_CLK_CTRL_OFFSET) & 0x0002) {
                stable = 1; break;
            }
        }
        if (!stable) {
            xil_printf("[sdio-esp] internal clock not stable\r\n");
            return SDIO_ESP_ERR_INIT;
        }
        /* Enable SD clock to card */
        clk_ctrl = XSdPs_ReadReg16(base, XSDPS_CLK_CTRL_OFFSET) | 0x0004;
        XSdPs_WriteReg16(base, XSDPS_CLK_CTRL_OFFSET, clk_ctrl);
        xil_printf("[sdio-esp] SD clock ~400 kHz ON (CLK_CTRL=0x%04x)\r\n",
                   (unsigned)clk_ctrl);
    }
    g_init_step = 3;

    /* Power on bus */
    XSdPs_WriteReg8(base, XSDPS_POWER_CTRL_OFFSET, 0x0F);  /* 3.3V + PWR */

    /* Enable NORM/ERR interrupt-status latching. Without this, STATUS regs
     * stay 0 forever and CMD_COMPLETE/TRANSFER_COMPLETE are never observable.
     * Signal-enable left at 0 so no IRQ line is asserted — we poll only. */
    XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_EN_OFFSET, 0xFFFF);
    XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_EN_OFFSET,  0xFFFF);

    /* Override card-detect: LXB-ZYNQ7000 board MIO46 wired to microSD CD pin.
     * With microSD removed (ESP32 connected to MIO40-45 instead), CD reports
     * "no card", and SD controller refuses to issue CMD. Set Host Control 1
     * bit 7 (CD signal selection = test level) + bit 6 (CD test level = 1)
     * to force the controller to think card is always present. */
    {
        u8 hc1 = XSdPs_ReadReg8(base, XSDPS_HOST_CTRL1_OFFSET);
        hc1 |= (1U << 7) | (1U << 6);  /* CD test source + force "inserted" */
        XSdPs_WriteReg8(base, XSDPS_HOST_CTRL1_OFFSET, hc1);
        xil_printf("[sdio-esp] CD override set: HC1=0x%02x\r\n", (unsigned)hc1);
    }

    /* 80 dummy clocks: small udelay enough — controller auto-clocks once on */
    usleep(2000);

    u32 resp = 0;

    /* CMD0 GO_IDLE */
    g_init_step = 10;
    rc = sdio_raw_cmd(SD_CMD0_GO_IDLE_STATE, 0, 0, NULL);
    if (rc) return rc;
    usleep(1000);

    /* CMD5: send op-cond. Arg=0 first to probe OCR, then re-send with OCR
     * to commit voltage. We treat ESP slave as 3.3V-only — accept whatever. */
    g_init_step = 20;
    rc = sdio_raw_cmd(SD_CMD5_IO_SEND_OP_COND, 0, 4804, &resp);
    if (rc) {
        xil_printf("[sdio-esp] CMD5 probe failed — is ESP32 on bus?\r\n");
        return rc;
    }
    /* Re-issue CMD5 with OCR until card-ready bit31 = 1 */
    g_init_step = 21;
    u32 ocr = resp & 0x00FFFFFF;   /* mask voltage window */
    u32 spin = 50;
    while (spin--) {
        rc = sdio_raw_cmd(SD_CMD5_IO_SEND_OP_COND, ocr, 4804, &resp);
        if (rc) return rc;
        if (resp & 0x80000000) break;
        usleep(2000);
    }
    if (!(resp & 0x80000000)) {
        xil_printf("[sdio-esp] CMD5 card-not-ready, OCR=0x%x\r\n",
                   (unsigned)resp);
        return SDIO_ESP_ERR_TIMEOUT;
    }

    /* CMD3 ask for RCA */
    g_init_step = 30;
    rc = sdio_raw_cmd(SD_CMD3_SEND_RCA, 0, 4806, &resp);
    if (rc) return rc;
    g_rca = (resp >> 16) & 0xFFFF;
    xil_printf("[sdio-esp] RCA=0x%x\r\n", (unsigned)g_rca);

    /* CMD7 select RCA */
    g_init_step = 40;
    rc = sdio_raw_cmd(SD_CMD7_SELECT, g_rca << 16, 4801, &resp);
    if (rc) return rc;

    /* CMD52 sanity: read CCCR 0x00 (CCCR/SDIO revision byte) */
    g_init_step = 50;
    u8 ver = 0;
    rc = sdio_cmd52_read(0, 0x00, &ver);
    if (rc) return rc;
    xil_printf("[sdio-esp] CCCR ver=0x%02x\r\n", ver);

    /* CMD52 set Func0 block size = 512 */
    g_init_step = 60;
    if ((rc = sdio_cmd52_write(0, SDIO_CCCR_BLK_SIZE_LO, 0x00))) return rc;
    if ((rc = sdio_cmd52_write(0, SDIO_CCCR_BLK_SIZE_HI, 0x02))) return rc;

    /* CMD52 set Func1 block size = 512 */
    g_init_step = 70;
    if ((rc = sdio_cmd52_write(0, SDIO_FBR_BLK_SIZE_LO(1), 0x00))) return rc;
    if ((rc = sdio_cmd52_write(0, SDIO_FBR_BLK_SIZE_HI(1), 0x02))) return rc;

    /* Enable Func1 (CCCR IOEnable bit 1 = 1) */
    g_init_step = 80;
    if ((rc = sdio_cmd52_write(0, SDIO_CCCR_IO_ENABLE, 0x02))) return rc;
    /* Poll IOReady bit1 */
    {
        int ready = 0;
        for (int s = 0; s < 50; s++) {
            u8 ior = 0;
            rc = sdio_cmd52_read(0, SDIO_CCCR_IO_READY, &ior);
            if (rc) return rc;
            if (ior & 0x02) { ready = 1; break; }
            usleep(2000);
        }
        if (!ready) {
            xil_printf("[sdio-esp] Func1 not ready\r\n");
            return SDIO_ESP_ERR_TIMEOUT;
        }
    }

    /* Enable host int master + Func1 int (bit0 master, bit1 Func1) */
    if ((rc = sdio_cmd52_write(0, SDIO_CCCR_INT_ENABLE, 0x03))) return rc;

    /* 1-bit mode (4-bit attempt 2026-05-11: even with external pull-ups
     * added on DAT1-3, runtime CMD53 data fails and CMD52 follow-up timeouts
     * — likely pull-up contact not solid or flying-wire signal integrity
     * still insufficient. Stay 1-bit for production. */

    /* Bump SD clock to ~25 MHz. */
    {
        u16 clk = XSdPs_ReadReg16(base, XSDPS_CLK_CTRL_OFFSET);
        clk &= ~0x0004;
        XSdPs_WriteReg16(base, XSDPS_CLK_CTRL_OFFSET, clk);
        clk = (clk & 0x00FF) & ~0xFF00;
        clk |= (0x01 << 8) | 0x0001;
        XSdPs_WriteReg16(base, XSDPS_CLK_CTRL_OFFSET, clk);
        for (u32 i = 0; i < 100000; i++) {
            if (XSdPs_ReadReg16(base, XSDPS_CLK_CTRL_OFFSET) & 0x0002) break;
        }
        clk |= 0x0004;
        XSdPs_WriteReg16(base, XSDPS_CLK_CTRL_OFFSET, clk);
        xil_printf("[sdio-esp] 1-bit @ 25MHz (CLK=0x%04x)\r\n", (unsigned)clk);
    }

    /* Set host controller block size = 512 (it stays per-CMD53 too). */
    XSdPs_WriteReg16(base, XSDPS_BLK_SIZE_OFFSET, SDIO_ESP_BLOCK_SIZE);

    g_init_step = 90;
    g_initialized = 1;

    /* Sync essl rx counter to slave's current PKT_LEN so we don't try to
     * drain stale phantom data. Latest reading defines our zero point. */
    g_init_step = 95;
    u32 latest = 0;
    int sync_rc = essl_update_rx_len(&latest);
    if (sync_rc == SDIO_ESP_OK) {
        g_rx_got_bytes = latest;
        g_rx_got_bytes_latest = latest;
    }

    g_init_step = 99;
    g_cmd_poll = CMD_POLL_ITERS_RUN;  /* fast-fail runtime polling */
    xil_printf("[sdio-esp] INIT DONE: RCA=0x%x sync_rc=%d latest=%u err_intr=0x%x\r\n",
               (unsigned)g_rca, sync_rc, (unsigned)latest, (unsigned)g_last_err_intr);
    return SDIO_ESP_OK;
}

/* CMD53 byte-mode short read: 1..511 bytes from a register-mapped address.
 * Used for atomic multi-byte reads of SLCHOST 32-bit registers (PKT_LEN,
 * INT_RAW, etc.). Slave hardware updates these atomically; 4× CMD52 risks
 * racing on the counter latch. */
static int sdio_cmd53_short_read(u32 addr, u8 *buf, u32 n_bytes)
{
    if (n_bytes == 0 || n_bytes > 511) return SDIO_ESP_ERR_PARAM;
    UINTPTR base = g_sd.Config.BaseAddress;

    /* Round up to multiple of 4 (SDHCI buffer port is 32-bit). */
    u32 padded = (n_bytes + 3u) & ~3u;

    /* BLK_SIZE = byte count for byte mode (small int <= 512). */
    XSdPs_WriteReg16(base, XSDPS_BLK_SIZE_OFFSET, (u16)padded);
    XSdPs_WriteReg16(base, XSDPS_BLK_CNT_OFFSET, 0);

    /* Transfer mode: single block (no MULTI_BLK), no BLK_CNT_EN, read dir. */
    XSdPs_WriteReg16(base, XSDPS_XFER_MODE_OFFSET, 0x0010);

    XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0xFFFF);
    XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);

    /* CMD53 arg: byte-mode (bit27=0), OP_CODE=1 incrementing addr,
     * count field = byte count (0 means 512). */
    u32 count_arg = (n_bytes == 512) ? 0 : n_bytes;
    u32 arg = (0u << 31)            /* read */
            | (((u32)SDIO_ESP_FUNC & 7u) << 28)
            | (0u << 27)            /* byte mode */
            | (1u << 26)            /* incrementing addr */
            | (((addr) & 0x1FFFFu) << 9)
            | (count_arg & 0x1FFu);
    XSdPs_WriteReg(base, XSDPS_ARGMT_OFFSET, arg);

    u16 cmd_reg = ((u16)SD_CMD53_IO_RW_EXTENDED << 8) | (1u << 5) | 0x1A;
    XSdPs_WriteReg16(base, XSDPS_CMD_OFFSET, cmd_reg);

    /* Wait CMD_COMPLETE */
    int done = 0;
    for (u32 i = 0; i < CMD_POLL_ITERS; i++) {
        u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
        u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
        if (e) { ERR_LOG("[sdio-esp] CMD53s cmd err=0x%x\r\n", e);
                 XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
                 return SDIO_ESP_ERR_CMD; }
        if (s & 0x1) { XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x1);
                       done = 1; break; }
    }
    if (!done) return SDIO_ESP_ERR_TIMEOUT;

    /* Wait BUFFER_READ_READY then drain padded/4 words. */
    done = 0;
    for (u32 i = 0; i < CMD_POLL_ITERS; i++) {
        u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
        if (s & 0x20) { XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x20);
                        done = 1; break; }
        u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
        if (e) { ERR_LOG("[sdio-esp] CMD53s data err=0x%x\r\n", e);
                 XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
                 return SDIO_ESP_ERR_CMD; }
    }
    if (!done) return SDIO_ESP_ERR_TIMEOUT;

    /* Drain padded bytes through 32-bit buffer port. */
    u32 words = padded / 4;
    for (u32 i = 0; i < words; i++) {
        u32 w = XSdPs_ReadReg(base, XSDPS_BUF_DAT_PORT_OFFSET);
        for (int k = 0; k < 4; k++) {
            u32 off = i * 4 + k;
            if (off < n_bytes) buf[off] = (u8)(w >> (k * 8));
        }
    }

    /* Wait TRANSFER_COMPLETE */
    done = 0;
    for (u32 i = 0; i < CMD_POLL_ITERS; i++) {
        u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
        if (s & 0x2) { XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x2);
                       done = 1; break; }
    }
    if (!done) return SDIO_ESP_ERR_TIMEOUT;

    /* Restore block size for subsequent 512B transfers. */
    XSdPs_WriteReg16(base, XSDPS_BLK_SIZE_OFFSET, SDIO_ESP_BLOCK_SIZE);
    return SDIO_ESP_OK;
}

/* essl_sdio host: read 4-byte PKT_LEN_REG via 4× CMD52. While essl_sdio.c
 * uses CMD53 byte-mode, ESP-IDF's sdio_slave hardware doesn't latch on
 * byte-mode short reads consistently — using CMD52 is slower (4 round-trips)
 * but reliable. PKT_LEN is monotonic-modulo-2^20 so torn read = stale but OK.
 * Returns the masked 20-bit packet byte counter in *latest. */
static int essl_update_rx_len(u32 *latest)
{
    u8 b0 = 0, b1 = 0, b2 = 0, b3 = 0;
    int rc;
    if ((rc = sdio_cmd52_read(SDIO_ESP_FUNC, ESSL_PKT_LEN_REG + 0, &b0))) return rc;
    if ((rc = sdio_cmd52_read(SDIO_ESP_FUNC, ESSL_PKT_LEN_REG + 1, &b1))) return rc;
    if ((rc = sdio_cmd52_read(SDIO_ESP_FUNC, ESSL_PKT_LEN_REG + 2, &b2))) return rc;
    if ((rc = sdio_cmd52_read(SDIO_ESP_FUNC, ESSL_PKT_LEN_REG + 3, &b3))) return rc;
    u32 v = (u32)b0 | ((u32)b1 << 8) | ((u32)b2 << 16) | ((u32)b3 << 24);
    *latest = v & ESSL_RX_BYTE_MASK;
    return SDIO_ESP_OK;
}

/* SW reset CMD+DAT lines after data error: SDHCI spec mandates clearing
 * both paths or controller can stay locked (subsequent CMD52 timeouts). */
static void sdio_reset_dat(void)
{
    UINTPTR base = g_sd.Config.BaseAddress;
    XSdPs_WriteReg8(base, XSDPS_SW_RST_OFFSET, 0x06);  /* SWRST_CMD | SWRST_DAT */
    for (u32 i = 0; i < 100000; i++) {
        if (!(XSdPs_ReadReg8(base, XSDPS_SW_RST_OFFSET) & 0x06)) break;
    }
    /* Clear any leftover interrupt status */
    XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0xFFFF);
    XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
}

/* essl_sdio: copy `nblk` blocks (= 512B each) from slave TX queue. The slave
 * decodes byte count from the address: arg addr = ESSL_CMD53_END_ADDR - len.
 * Op-code = 1 (incrementing) per essl spec — slave hw ignores increments
 * once it has the length but the protocol mandates incr=1. */
static int essl_read_blocks(u8 *buf, u32 nblk)
{
    u32 byte_count = nblk * SDIO_ESP_BLOCK_SIZE;
    u32 addr = ESSL_CMD53_END_ADDR - byte_count;
    int rc = sdio_cmd53_xfer(/*is_write*/ 0, SDIO_ESP_FUNC,
                             addr, /*incr*/ 1, buf, nblk);
    if (rc) sdio_reset_dat();  /* recover from CRC/timeout error */
    return rc;
}

int sdio_esp_send(const u8 *data, u32 len)
{
    if (!g_initialized) return SDIO_ESP_ERR_INIT;
    if (!data || !len)  return SDIO_ESP_ERR_PARAM;

    u32 nblk = (len + SDIO_ESP_BLOCK_SIZE - 1) / SDIO_ESP_BLOCK_SIZE;
    if (nblk == 0 || nblk > 0x1FF) return SDIO_ESP_ERR_PARAM;
    if (len & (SDIO_ESP_BLOCK_SIZE - 1)) return SDIO_ESP_ERR_PARAM;

    /* host→slave: same address-encoding trick. The Zynq side doesn't manage
     * the buffer token here (TX path is optional for this bridge); slave will
     * either accept or NAK via CMD err if no buffers are loaded. */
    u32 addr = ESSL_CMD53_END_ADDR - (nblk * SDIO_ESP_BLOCK_SIZE);
    return sdio_cmd53_xfer(/*is_write*/ 1, SDIO_ESP_FUNC,
                           addr, /*incr*/ 1, (u8 *)data, nblk);
}

int sdio_esp_recv(u8 *buf, u32 max_len, u32 *actual)
{
    if (actual) *actual = 0;
    if (!g_initialized) return SDIO_ESP_ERR_INIT;
    if (!buf || !max_len) return SDIO_ESP_ERR_PARAM;

    /* Read slave's current PKT_LEN counter. The diff (mod 2^20) is how many
     * bytes have been queued since last drain. */
    u32 latest = 0;
    int rc = essl_update_rx_len(&latest);
    if (rc) {
        /* Surface error rarely — main-loop polls every iter so flood-protect. */
        ERR_LOG("[sdio-esp] essl_update_rx_len rc=%d\r\n", rc);
        return rc;
    }
    /* Debug: print only on change to avoid UART flood. */
    if (latest != g_rx_got_bytes_latest) {
        xil_printf("[sdio-esp] PKT_LEN latest=%u got=%u\r\n",
                   (unsigned)latest, (unsigned)g_rx_got_bytes);
    }
    g_rx_got_bytes_latest = latest;

    u32 available = (latest + ESSL_RX_BYTE_MAX - g_rx_got_bytes) & ESSL_RX_BYTE_MASK;
    if (available == 0) return SDIO_ESP_ERR_NO_DATA;

    /* Cap by caller buffer. Slave pads last partial block to 512; we must
     * read ceil(avail/512) blocks but only count `avail` bytes as valid —
     * the padding bytes after `avail` are garbage and the caller must not
     * consume them (we report actual = avail, not padded size). */
    u32 want = available;
    if (want > max_len) {
        /* Caller buf small — drain a whole block multiple instead so we
         * don't leave partial data straddling buffer boundaries. */
        want = (max_len / SDIO_ESP_BLOCK_SIZE) * SDIO_ESP_BLOCK_SIZE;
        if (want == 0) return SDIO_ESP_ERR_NO_DATA;
    }
    u32 nblk = (want + SDIO_ESP_BLOCK_SIZE - 1) / SDIO_ESP_BLOCK_SIZE;
    if (nblk == 0) return SDIO_ESP_ERR_NO_DATA;
    if (nblk > 0x1FF) {
        nblk = 0x1FF;
        want = nblk * SDIO_ESP_BLOCK_SIZE;
    }
    /* Buf must accommodate padded read; caller already provides 4 KB. */
    if (nblk * SDIO_ESP_BLOCK_SIZE > max_len) return SDIO_ESP_ERR_PARAM;

    rc = essl_read_blocks(buf, nblk);
    if (rc) return rc;

    g_rx_got_bytes = (g_rx_got_bytes + want) & ESSL_RX_BYTE_MASK;
    if (actual) *actual = want;  /* real bytes; padding ignored */
    return SDIO_ESP_OK;
}

int sdio_esp_get_status(void)
{
    if (!g_initialized) return SDIO_ESP_ERR_INIT;
    /* Read SLC0HOST_INT_RAW low byte via CMD52 — bit23 (new-packet) lives
     * in byte index 2 of the 4-byte register. */
    u8 st = 0;
    int rc = sdio_cmd52_read(SDIO_ESP_FUNC, ESSL_INT_RAW_REG + 2, &st);
    if (rc) return rc;
    return (int)st;
}

u32 sdio_esp_dbg_rx_got(void)     { return g_rx_got_bytes; }
u32 sdio_esp_dbg_rx_latest(void)  { return g_rx_got_bytes_latest; }
int sdio_esp_dbg_initialized(void) { return g_initialized; }
int sdio_esp_dbg_init_step(void)   { return g_init_step; }
u32 sdio_esp_dbg_present_state(void) {
    if (!g_sd.Config.BaseAddress) return 0xDEAD0000;
    return XSdPs_ReadReg(g_sd.Config.BaseAddress, XSDPS_PRES_STATE_OFFSET);
}
u32 sdio_esp_dbg_clk_ctrl(void) {
    if (!g_sd.Config.BaseAddress) return 0xDEAD0000;
    return XSdPs_ReadReg16(g_sd.Config.BaseAddress, XSDPS_CLK_CTRL_OFFSET);
}
u32 sdio_esp_dbg_hc1(void) {
    if (!g_sd.Config.BaseAddress) return 0xDEAD0000;
    return XSdPs_ReadReg8(g_sd.Config.BaseAddress, XSDPS_HOST_CTRL1_OFFSET);
}
u32 sdio_esp_dbg_err_intr(void) { return g_last_err_intr; }
u32 sdio_esp_dbg_err_cmd(void)  { return g_last_err_cmd; }

#else /* SDIO_ESP_HAVE_XSDPS == 0  — BSP doesn't include xsdps (SD0 disabled) */

int sdio_esp_init(void)
{
    xil_printf("[sdio-esp] xsdps not in BSP — enable SD0 in BD first\r\n");
    return SDIO_ESP_ERR_INIT;
}
int sdio_esp_send(const u8 *data, u32 len)        { (void)data; (void)len; return SDIO_ESP_ERR_INIT; }
int sdio_esp_recv(u8 *buf, u32 max_len, u32 *act) { (void)buf; (void)max_len; if (act) *act = 0; return SDIO_ESP_ERR_INIT; }
int sdio_esp_get_status(void)                     { return SDIO_ESP_ERR_INIT; }

#endif /* SDIO_ESP_HAVE_XSDPS */
