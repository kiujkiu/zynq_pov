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

/* Run a raw SDIO command via XSdPs primitive register write. We bypass the
 * XSdPs high-level SD-memory state machine. Builds the CMD register manually
 * and waits for command-complete.
 *
 * Returns response in *resp (low 32b). For CMD0 no resp, pass NULL. */
static int sdio_raw_cmd(u8 cmd, u32 arg, u32 resp_type, u32 *resp)
{
    /* XSdPs base */
    UINTPTR base = g_sd.Config.BaseAddress;

    /* 1) clear normal/error interrupt status (write 1 to clear) */
    XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0xFFFF);
    XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);

    /* 2) write argument */
    XSdPs_WriteReg(base, XSDPS_ARGMT_OFFSET, arg);

    /* 3) build CMD register value:
     *    bits15..8 = CMD index
     *    bits7..6  = command type (00 = normal)
     *    bit5      = data present (0 for cmd-only)
     *    bit4      = command index check
     *    bit3      = command CRC check
     *    bits1..0  = response type (00=none, 10=R136, 01=R48, 11=R48 busy)
     */
    u16 cmd_reg = (u16)cmd << 8;
    switch (resp_type) {
        case 0:        cmd_reg |= 0x0;            break;  /* no resp */
        case 48:       cmd_reg |= 0x1A;           break;  /* R48 + CRC+IDX chk */
        case 48136:    cmd_reg |= 0x09;           break;  /* R136 + CRC */
        case 481:      cmd_reg |= 0x1A;           break;  /* R1 */
        case 4801:     cmd_reg |= 0x1B;           break;  /* R1b (busy) */
        case 4804:     cmd_reg |= 0x02;           break;  /* R4 (CMD5: no CRC) */
        case 4806:     cmd_reg |= 0x1A;           break;  /* R6 */
        default:       cmd_reg |= 0x1A;           break;
    }

    XSdPs_WriteReg16(base, XSDPS_CMD_OFFSET, cmd_reg);

    /* 4) wait for command-complete (bit0 of normal-intr) or error */
    u32 to = 1000000;
    while (to--) {
        u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
        u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
        if (e) {
            xil_printf("[sdio-esp] CMD%d err=0x%x\r\n", cmd, e);
            XSdPs_WriteReg16(base, XSDPS_ERR_INTR_STS_OFFSET, 0xFFFF);
            return SDIO_ESP_ERR_CMD;
        }
        if (s & 0x1) {  /* CMD_COMPLETE */
            XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x1);
            break;
        }
    }
    if (to == 0) {
        xil_printf("[sdio-esp] CMD%d timeout\r\n", cmd);
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
     * bit4 = DAT direction (1 = read), bit5 = multi-block */
    u16 mode = 0x22;                      /* MULTI_BLK | BLK_CNT_EN */
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
    u32 to = 1000000;
    while (to--) {
        u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
        u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
        if (e) { xil_printf("[sdio-esp] CMD53 cmd err=0x%x\r\n", e);
                 return SDIO_ESP_ERR_CMD; }
        if (s & 0x1) { XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x1);
                       break; }
    }
    if (to == 0) return SDIO_ESP_ERR_TIMEOUT;

    /* Shuffle data 32b at a time, polling BUFFER_READ_READY (bit5) /
     * BUFFER_WRITE_READY (bit4). */
    u32 *p = (u32 *)buf;
    u32 words = byte_count / 4;
    u32 ready_mask = is_write ? 0x10 : 0x20;
    for (u32 i = 0; i < words; ) {
        to = 1000000;
        while (to--) {
            u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
            if (s & ready_mask) {
                XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, ready_mask);
                break;
            }
        }
        if (to == 0) return SDIO_ESP_ERR_TIMEOUT;
        /* One buffer = up to 512 bytes = 128 words; we drain block-size words */
        u32 burst = SDIO_ESP_BLOCK_SIZE / 4;
        for (u32 k = 0; k < burst && i < words; k++, i++) {
            if (is_write)
                XSdPs_WriteReg(base, XSDPS_BUF_DAT_PORT_OFFSET, p[i]);
            else
                p[i] = XSdPs_ReadReg(base, XSDPS_BUF_DAT_PORT_OFFSET);
        }
    }

    /* Wait TRANSFER_COMPLETE (bit1) */
    to = 5000000;
    while (to--) {
        u16 s = XSdPs_ReadReg16(base, XSDPS_NORM_INTR_STS_OFFSET);
        if (s & 0x2) { XSdPs_WriteReg16(base, XSDPS_NORM_INTR_STS_OFFSET, 0x2);
                       break; }
        u16 e = XSdPs_ReadReg16(base, XSDPS_ERR_INTR_STS_OFFSET);
        if (e) { xil_printf("[sdio-esp] CMD53 xfer err=0x%x\r\n", e);
                 return SDIO_ESP_ERR_CMD; }
    }
    if (to == 0) return SDIO_ESP_ERR_TIMEOUT;

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
    XSdPs_WriteReg8(base, XSDPS_SW_RST_OFFSET, XSDPS_SWRST_ALL_MASK);
    {
        u32 to = 100000;
        while (to-- && (XSdPs_ReadReg8(base, XSDPS_SW_RST_OFFSET) &
                        XSDPS_SWRST_ALL_MASK)) {}
        if (to == 0) {
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
    {
        u16 clk_ctrl = (0x40 << 8) | 0x0001;  /* divisor=64 + ICE=1 */
        XSdPs_WriteReg16(base, XSDPS_CLK_CTRL_OFFSET, clk_ctrl);
        u32 to = 100000;
        while (to-- &&
               !(XSdPs_ReadReg16(base, XSDPS_CLK_CTRL_OFFSET) & 0x0002)) {}
        if (to == 0) {
            xil_printf("[sdio-esp] internal clock not stable\r\n");
            return SDIO_ESP_ERR_INIT;
        }
        /* Enable SD clock to card */
        clk_ctrl = XSdPs_ReadReg16(base, XSDPS_CLK_CTRL_OFFSET) | 0x0004;
        XSdPs_WriteReg16(base, XSDPS_CLK_CTRL_OFFSET, clk_ctrl);
        xil_printf("[sdio-esp] SD clock ~400 kHz ON (CLK_CTRL=0x%04x)\r\n",
                   (unsigned)clk_ctrl);
    }

    /* Power on bus */
    XSdPs_WriteReg8(base, XSDPS_POWER_CTRL_OFFSET, 0x0F);  /* 3.3V + PWR */

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
    rc = sdio_raw_cmd(SD_CMD0_GO_IDLE_STATE, 0, 0, NULL);
    if (rc) return rc;
    usleep(1000);

    /* CMD5: send op-cond. Arg=0 first to probe OCR, then re-send with OCR
     * to commit voltage. We treat ESP slave as 3.3V-only — accept whatever. */
    rc = sdio_raw_cmd(SD_CMD5_IO_SEND_OP_COND, 0, 4804, &resp);
    if (rc) {
        xil_printf("[sdio-esp] CMD5 probe failed — is ESP32 on bus?\r\n");
        return rc;
    }
    /* Re-issue CMD5 with OCR until card-ready bit31 = 1 */
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
    rc = sdio_raw_cmd(SD_CMD3_SEND_RCA, 0, 4806, &resp);
    if (rc) return rc;
    g_rca = (resp >> 16) & 0xFFFF;
    xil_printf("[sdio-esp] RCA=0x%x\r\n", (unsigned)g_rca);

    /* CMD7 select RCA */
    rc = sdio_raw_cmd(SD_CMD7_SELECT, g_rca << 16, 4801, &resp);
    if (rc) return rc;

    /* CMD52 sanity: read CCCR 0x00 (CCCR/SDIO revision byte) */
    u8 ver = 0;
    rc = sdio_cmd52_read(0, 0x00, &ver);
    if (rc) return rc;
    xil_printf("[sdio-esp] CCCR ver=0x%02x\r\n", ver);

    /* CMD52 set Func0 block size = 512 */
    if ((rc = sdio_cmd52_write(0, SDIO_CCCR_BLK_SIZE_LO, 0x00))) return rc;
    if ((rc = sdio_cmd52_write(0, SDIO_CCCR_BLK_SIZE_HI, 0x02))) return rc;

    /* CMD52 set Func1 block size = 512 */
    if ((rc = sdio_cmd52_write(0, SDIO_FBR_BLK_SIZE_LO(1), 0x00))) return rc;
    if ((rc = sdio_cmd52_write(0, SDIO_FBR_BLK_SIZE_HI(1), 0x02))) return rc;

    /* Enable Func1 (CCCR IOEnable bit 1 = 1) */
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

    /* Switch to 4-bit bus (CCCR 0x07 = 0x02). ESP32 default supports 4-bit. */
    if ((rc = sdio_cmd52_write(0, SDIO_CCCR_BUS_INTERFACE, 0x02))) return rc;

    /* Set host controller block size = 512 (it stays per-CMD53 too). */
    XSdPs_WriteReg16(base, XSDPS_BLK_SIZE_OFFSET, SDIO_ESP_BLOCK_SIZE);

    g_initialized = 1;
    xil_printf("[sdio-esp] CMD5 OP_COND OK, RCA=0x%x, ready\r\n",
               (unsigned)g_rca);
    return SDIO_ESP_OK;
}

int sdio_esp_send(const u8 *data, u32 len)
{
    if (!g_initialized) return SDIO_ESP_ERR_INIT;
    if (!data || !len)  return SDIO_ESP_ERR_PARAM;

    u32 nblk = (len + SDIO_ESP_BLOCK_SIZE - 1) / SDIO_ESP_BLOCK_SIZE;
    if (nblk == 0 || nblk > 0x1FF) return SDIO_ESP_ERR_PARAM;

    /* If `len` isn't 512-aligned, pad zeros via a small stack copy of last
     * block. Skip if exactly aligned. */
    if (len & (SDIO_ESP_BLOCK_SIZE - 1)) {
        /* Caller responsibility: pad buffer ahead of time in protocol layer.
         * For now, just refuse to be safe — payload sender controls layout. */
        return SDIO_ESP_ERR_PARAM;
    }

    /* OP code = 0 (fixed addr / FIFO mode — ESP32 RX is a FIFO window) */
    return sdio_cmd53_xfer(/*is_write*/ 1, SDIO_ESP_FUNC,
                           SDIO_ESP_RX_REG, /*incr*/ 0,
                           (u8 *)data, nblk);
}

int sdio_esp_recv(u8 *buf, u32 max_len, u32 *actual)
{
    if (actual) *actual = 0;
    if (!g_initialized) return SDIO_ESP_ERR_INIT;
    if (!buf || !max_len) return SDIO_ESP_ERR_PARAM;

    /* Check host-int pending: bit1 (Func1) tells us slave queued TX bytes. */
    u8 pend = 0;
    int rc = sdio_cmd52_read(0, SDIO_CCCR_INT_PENDING, &pend);
    if (rc) return rc;
    if (!(pend & 0x02)) return SDIO_ESP_ERR_NO_DATA;

    /* Read 4-byte queued-length register (ESP-Hosted convention) one byte
     * at a time via CMD52. Could also CMD53-byte but CMD52 is simpler. */
    u8 b0 = 0, b1 = 0, b2 = 0, b3 = 0;
    if ((rc = sdio_cmd52_read(1, SDIO_ESP_PKT_LEN_REG + 0, &b0))) return rc;
    if ((rc = sdio_cmd52_read(1, SDIO_ESP_PKT_LEN_REG + 1, &b1))) return rc;
    if ((rc = sdio_cmd52_read(1, SDIO_ESP_PKT_LEN_REG + 2, &b2))) return rc;
    if ((rc = sdio_cmd52_read(1, SDIO_ESP_PKT_LEN_REG + 3, &b3))) return rc;
    u32 queued = (u32)b0 | ((u32)b1 << 8) | ((u32)b2 << 16) | ((u32)b3 << 24);
    if (queued == 0) return SDIO_ESP_ERR_NO_DATA;

    u32 want = queued;
    if (want > max_len) want = max_len;
    /* Round down to whole blocks */
    u32 nblk = want / SDIO_ESP_BLOCK_SIZE;
    if (nblk == 0) return SDIO_ESP_ERR_NO_DATA;
    if (nblk > 0x1FF) nblk = 0x1FF;

    rc = sdio_cmd53_xfer(/*is_write*/ 0, SDIO_ESP_FUNC,
                         SDIO_ESP_TX_REG, /*incr*/ 0,
                         buf, nblk);
    if (rc) return rc;

    if (actual) *actual = nblk * SDIO_ESP_BLOCK_SIZE;
    return SDIO_ESP_OK;
}

int sdio_esp_get_status(void)
{
    if (!g_initialized) return SDIO_ESP_ERR_INIT;
    u8 st = 0;
    int rc = sdio_cmd52_read(1, SDIO_ESP_INTR_ST, &st);
    if (rc) return rc;
    return (int)st;
}

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
