/* Phase 4b: PL HLS pov_project IP accelerated rendering
 *
 * ARM:
 *   1) build 3D model in DDR (aligned point_t array)
 *   2) flush model cache once
 *   3) each frame: for each of 72 slices, kick off pov_project IP, poll done
 *   4) measure FPS
 *
 * PL (HLS IP @ FCLK_CLK1 = 75 MHz, Fmax 205 MHz at 150 MHz target):
 *   - reads model via m_axi_gmem0 (128b) -> HP1 -> DDR
 *   - writes slice cell to fb via m_axi_gmem1 (32b) -> HP1 -> DDR
 *
 * Framebuffer stays VDMA-read (HP0) -> video pipeline -> HDMI.
 *
 * Set USE_PL=0 to fall back to ARM software rendering (old Phase 4a path)
 * for A/B comparison.
 */
#include <stdio.h>
#include <string.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xvtc.h"
#include "xaxivdma.h"
#include "xgpio.h"
#include "sleep.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xiltimer.h"

#define USE_PL 1

/* 1080p30 HDMI: pixel clock stays 74.25 MHz (same as 720p60). */
#define WIDTH   1920
#define HEIGHT  1080
#define BPP     3
#define STRIDE  (WIDTH * BPP)
#define FRAME_BYTES (STRIDE * HEIGHT)
/* Double buffer: VDMA reads one while ARM/IP writes the other.
 * 2.76 MB each + spacing; kept well away from model (0x11000000). */
#define FB_A_ADDR 0x10000000UL
#define FB_B_ADDR 0x14000000UL
#define FRAMEBUF_ADDR FB_A_ADDR  /* kept for any legacy refs */

/* VDMA MM2S PARK_PTR register: bits [4:0] = MM2S park frame index.
 * When DMACR.Circular_Park=0 (park mode), VDMA reads from this framestore.
 * Writing it takes effect at the NEXT VDMA frame boundary (seamless). */
#define VDMA_BASE         XPAR_AXI_VDMA_0_BASEADDR
#define VDMA_PARK_PTR_OFF 0x28

static inline void vdma_park(u32 idx)
{
    u32 v = Xil_In32(VDMA_BASE + VDMA_PARK_PTR_OFF);
    v = (v & ~0x1Fu) | (idx & 0x1Fu);
    Xil_Out32(VDMA_BASE + VDMA_PARK_PTR_OFF, v);
    /* Verify first few writes actually latch */
    static u32 dbg = 0;
    if (dbg < 4) {
        u32 rb = Xil_In32(VDMA_BASE + VDMA_PARK_PTR_OFF);
        xil_printf("[park] wrote idx=%u full=0x%x readback=0x%x\r\n",
                   (unsigned)idx, (unsigned)v, (unsigned)rb);
        dbg++;
    }
}

/* Read-only: current MM2S read frame store index (bits [20:16]). */
static inline u32 vdma_current_read_idx(void)
{
    return (Xil_In32(VDMA_BASE + VDMA_PARK_PTR_OFF) >> 16) & 0x1F;
}
/* DMACR bit 1 is Circular_Park: 0=park mode, 1=circular. Must be 0 here. */
static inline u32 vdma_dmacr(void)
{
    return Xil_In32(VDMA_BASE + 0x00);
}

#define SLICE_W    106
#define SLICE_H    120
#define GRID_COLS  12
#define GRID_ROWS  6
#define NUM_SLICES (GRID_COLS * GRID_ROWS)  /* 72 */

/* Matches HLS pov_project.h exactly: 16 bytes, natural alignment */
typedef struct __attribute__((aligned(16))) {
    int16_t  x;
    int16_t  y;
    int16_t  z;
    int16_t  _pad0;
    uint8_t  r;
    uint8_t  g;
    uint8_t  b;
    uint8_t  _pad1;
    int32_t  _pad2;
} PovPoint;

/* Model lives at a fixed high DDR address, away from framebuffer. */
#define MODEL_ADDR      0x11000000UL
#define MAX_POINTS      1024
static PovPoint * const model = (PovPoint *)MODEL_ADDR;
static int model_n = 0;

/* ---------------------------------------------------------------------- */
/* UART point-cloud receiver                                              */

/* PS UART0 = console (STDOUT_BASEADDRESS = 0xE0000000 on this BSP).
 * Share TX with xil_printf; use RX side for incoming point-cloud stream. */
#define UART0_BASE   0xE0000000UL
#define UART_SR      0x2C   /* Channel Status Register */
#define UART_FIFO    0x30   /* RX/TX FIFO */
#define UART_SR_REMPTY  (1u << 1)

static inline int uart_rx_has(void) {
    return !(Xil_In32(UART0_BASE + UART_SR) & UART_SR_REMPTY);
}
static inline u8 uart_rx_byte(void) {
    return (u8)(Xil_In32(UART0_BASE + UART_FIFO) & 0xFF);
}

/* Wire protocol (little-endian, matches host/pointcloud_proto.py):
 *   0   4  magic 0x4C435050 ("PPCL")
 *   4   4  frame_id
 *   8   2  num_points
 *   10  2  flags
 *   12  4  reserved
 *   16  N*16  point_t array
 */
#define PC_MAGIC  0x4C435050U

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t frame_id;
    uint16_t num_points;
    uint16_t flags;
    uint32_t reserved;
} pc_hdr_t;

/* Receiver state machine: keep pulling bytes until a full valid frame lands,
 * or no more bytes available. On success, copies into `model[]`, sets
 * model_n, and returns 1. Returns 0 if still waiting / nothing arrived. */
typedef enum { RX_HDR, RX_PTS } rx_state_t;
static rx_state_t rx_state = RX_HDR;
static u8          rx_hdr_buf[sizeof(pc_hdr_t)];
static u32         rx_hdr_got = 0;
static u32         rx_expected_pts = 0;
static u32         rx_pts_got = 0;
static u32         rx_magic_sync = 0;   /* rolling 4-byte window hunting magic */

static int uart_poll_frame(void)
{
    /* Drain as much as is available without blocking render loop.
     * Safety: cap at 256 bytes per call so we never hang here. */
    int frame_ready = 0;
    int guard = 256;
    while (guard-- > 0 && uart_rx_has()) {
        u8 b = uart_rx_byte();
        if (rx_state == RX_HDR) {
            /* Sync on magic — slide a 4-byte window until it matches. */
            rx_magic_sync = (rx_magic_sync >> 8) | ((u32)b << 24);
            if (rx_hdr_got < 4) {
                rx_hdr_buf[rx_hdr_got++] = b;
                if (rx_hdr_got == 4 && rx_magic_sync != PC_MAGIC) {
                    /* Not magic yet - rewind one position */
                    rx_hdr_got--;
                    memmove(rx_hdr_buf, rx_hdr_buf + 1, 3);
                }
            } else {
                rx_hdr_buf[rx_hdr_got++] = b;
                if (rx_hdr_got == sizeof(pc_hdr_t)) {
                    pc_hdr_t *h = (pc_hdr_t *)rx_hdr_buf;
                    if (h->num_points > MAX_POINTS) {
                        /* invalid — resync */
                        xil_printf("[rx] bad num_points=%u, resync\r\n",
                                   (unsigned)h->num_points);
                        rx_hdr_got = 0;
                        rx_magic_sync = 0;
                    } else {
                        rx_expected_pts = h->num_points;
                        rx_pts_got = 0;
                        rx_state = RX_PTS;
                        if (rx_expected_pts == 0) {
                            /* Empty frame — accept immediately */
                            model_n = 0;
                            rx_state = RX_HDR;
                            rx_hdr_got = 0;
                            rx_magic_sync = 0;
                            frame_ready = 1;
                            break;
                        }
                    }
                }
            }
        } else { /* RX_PTS */
            ((u8 *)model)[rx_pts_got++] = b;
            if (rx_pts_got == rx_expected_pts * sizeof(PovPoint)) {
                model_n = rx_expected_pts;
                Xil_DCacheFlushRange(MODEL_ADDR, model_n * sizeof(PovPoint));
                rx_state = RX_HDR;
                rx_hdr_got = 0;
                rx_magic_sync = 0;
                frame_ready = 1;
                /* On first received frame, dump the header + first 3 points
                 * so we can compare against what Host sent. */
                static int dumped = 0;
                if (!dumped) {
                    dumped = 1;
                    pc_hdr_t *h = (pc_hdr_t *)rx_hdr_buf;
                    xil_printf("[rx-dump] magic=0x%08x fid=%u N=%u flags=0x%x\r\n",
                               (unsigned)h->magic, (unsigned)h->frame_id,
                               (unsigned)h->num_points, (unsigned)h->flags);
                    for (int i = 0; i < 3 && i < model_n; i++) {
                        xil_printf("[rx-dump] p%d  x=%d y=%d z=%d  r=%u g=%u b=%u\r\n",
                                   i,
                                   (int)model[i].x, (int)model[i].y, (int)model[i].z,
                                   (unsigned)model[i].r, (unsigned)model[i].g,
                                   (unsigned)model[i].b);
                    }
                }
                break;
            }
        }
    }
    return frame_ready;
}

static const int16_t cos8_table[72] = {
    256, 255, 252, 247, 241, 232, 222, 210,
    196, 181, 165, 147, 128, 108,  88,  66,
     44,  22,   0, -22, -44, -66, -88,-108,
   -128,-147,-165,-181,-196,-210,-222,-232,
   -241,-247,-252,-255,-256,-255,-252,-247,
   -241,-232,-222,-210,-196,-181,-165,-147,
   -128,-108, -88, -66, -44, -22,   0,  22,
     44,  66,  88, 108, 128, 147, 165, 181,
    196, 210, 222, 232, 241, 247, 252, 255,
};
static const int16_t sin8_table[72] = {
      0,  22,  44,  66,  88, 108, 128, 147,
    165, 181, 196, 210, 222, 232, 241, 247,
    252, 255, 256, 255, 252, 247, 241, 232,
    222, 210, 196, 181, 165, 147, 128, 108,
     88,  66,  44,  22,   0, -22, -44, -66,
    -88,-108,-128,-147,-165,-181,-196,-210,
   -222,-232,-241,-247,-252,-255,-256,-255,
   -252,-247,-241,-232,-222,-210,-196,-181,
   -165,-147,-128,-108, -88, -66, -44, -22,
};

static void add_line(int16_t x0, int16_t y0, int16_t z0,
                     int16_t x1, int16_t y1, int16_t z1,
                     int n, uint8_t r, uint8_t g, uint8_t b)
{
    for (int i = 0; i <= n && model_n < MAX_POINTS; i++) {
        model[model_n].x = (int16_t)(x0 + (x1 - x0) * i / n);
        model[model_n].y = (int16_t)(y0 + (y1 - y0) * i / n);
        model[model_n].z = (int16_t)(z0 + (z1 - z0) * i / n);
        model[model_n]._pad0 = 0;
        model[model_n].r = r;
        model[model_n].g = g;
        model[model_n].b = b;
        model[model_n]._pad1 = 0;
        model[model_n]._pad2 = 0;
        model_n++;
    }
}

static void build_model(void)
{
    model_n = 0;
    add_line(-50, 0, 0, 50, 0, 0, 40, 255, 0, 0);
    add_line(0, -50, 0, 0, 50, 0, 40, 0, 255, 0);
    add_line(0, 0, -50, 0, 0, 50, 40, 0, 0, 255);

    const int16_t S = 30;
    add_line(-S, -S, -S,  S, -S, -S, 15, 200, 200, 255);
    add_line( S, -S, -S,  S, -S,  S, 15, 200, 200, 255);
    add_line( S, -S,  S, -S, -S,  S, 15, 200, 200, 255);
    add_line(-S, -S,  S, -S, -S, -S, 15, 200, 200, 255);
    add_line(-S,  S, -S,  S,  S, -S, 15, 200, 200, 255);
    add_line( S,  S, -S,  S,  S,  S, 15, 200, 200, 255);
    add_line( S,  S,  S, -S,  S,  S, 15, 200, 200, 255);
    add_line(-S,  S,  S, -S,  S, -S, 15, 200, 200, 255);
    add_line(-S, -S, -S, -S,  S, -S, 15, 255, 100,   0);
    add_line( S, -S, -S,  S,  S, -S, 15, 255, 100,   0);
    add_line( S, -S,  S,  S,  S,  S, 15, 255, 100,   0);
    add_line(-S, -S,  S, -S,  S,  S, 15, 255, 100,   0);

    xil_printf("Model built: %d points @ 0x%08lx\r\n",
               model_n, (unsigned long)MODEL_ADDR);
}

/* ---------------------------------------------------------------------- */
/* PL path: direct register bang on pov_project HLS IP */

/* 4 parallel pov IP instances; base addrs set by bd_4pov_and_1080p.tcl */
#define N_POV_IPS  4
static const u32 pov_bases[N_POV_IPS] = {
    0x43C20000UL, 0x43C30000UL, 0x43C40000UL, 0x43C50000UL
};
#define POV_BASE          0x43C20000UL   /* legacy single-IP refs */
#define POV_AP_CTRL       0x00
#define POV_GIE           0x04
#define POV_IER           0x08
#define POV_ISR           0x0c
#define POV_MODEL_LO      0x10
#define POV_MODEL_HI      0x14
#define POV_NUM_POINTS    0x1c
#define POV_ANGLE_IDX     0x24
#define POV_FB_LO         0x2c
#define POV_FB_HI         0x30
#define POV_FB_STRIDE     0x38
#define POV_DST_X         0x40
#define POV_DST_Y         0x48

static inline void pov_w(u32 off, u32 v) { Xil_Out32(POV_BASE + off, v); }
static inline u32  pov_r(u32 off)        { return Xil_In32(POV_BASE + off); }

/* Indexed accessors for 4-IP dispatch */
static inline void povi_w(int ip, u32 off, u32 v) { Xil_Out32(pov_bases[ip] + off, v); }
static inline u32  povi_r(int ip, u32 off)        { return Xil_In32(pov_bases[ip] + off); }

/* A9 Cortex-A9 MPCore Global Timer (64-bit, shared, ticks @ CPU_3x2x = 333 MHz).
 * Use as fallback when XTime_GetTime() misbehaves. */
#define GT_CNT_LO   0xF8F00200U
#define GT_CNT_HI   0xF8F00204U
#define GT_CTRL     0xF8F00208U  /* bit 0 = Timer Enable */

static inline void gt_enable(void) {
    /* Safe to set enable bit; if already enabled this is a no-op. */
    u32 c = Xil_In32(GT_CTRL);
    Xil_Out32(GT_CTRL, c | 0x1);
}
static inline u64 gt_read(void) {
    u32 hi1, lo, hi2;
    do {
        hi1 = Xil_In32(GT_CNT_HI);
        lo  = Xil_In32(GT_CNT_LO);
        hi2 = Xil_In32(GT_CNT_HI);
    } while (hi1 != hi2);
    return ((u64)hi2 << 32) | lo;
}
/* Global Timer ticks @ half the CPU clock = 333 MHz → 1 us = 333 ticks */
#define GT_TICKS_PER_US 333U

/* Set one IP's parameters and fire it. Caller waits elsewhere. */
static void povi_fire(int ip, UINTPTR fb_base, int angle_idx, int col, int row)
{
    u32 dst_x = col * SLICE_W;
    u32 dst_y = row * SLICE_H;
    povi_w(ip, POV_MODEL_LO,   (u32)MODEL_ADDR);
    povi_w(ip, POV_MODEL_HI,   0);
    povi_w(ip, POV_NUM_POINTS, model_n);
    povi_w(ip, POV_ANGLE_IDX,  angle_idx);
    povi_w(ip, POV_FB_LO,      (u32)fb_base);
    povi_w(ip, POV_FB_HI,      0);
    povi_w(ip, POV_FB_STRIDE,  STRIDE);
    povi_w(ip, POV_DST_X,      dst_x);
    povi_w(ip, POV_DST_Y,      dst_y);
    povi_w(ip, POV_AP_CTRL,    0x1);
}

/* Spin until IP reports ap_done (bit 1). Shared AXI-Lite polling logic. */
static void povi_wait(int ip)
{
    u32 to = 0;
    while (!(povi_r(ip, POV_AP_CTRL) & 0x2)) {
        if (++to > 0x10000000) {
            xil_printf("pov%d timeout\r\n", ip);
            return;
        }
    }
}

/* Render NUM_SLICES slices by round-robin dispatching to 4 IPs in parallel.
 * Each iteration fires 4 IPs, polls UART while they run, then waits all 4.
 * Total time ~ (NUM_SLICES/N_POV_IPS) * max(slice_time, overhead). */
static void pov_render_frame_parallel(UINTPTR fb_base, u32 phase)
{
    /* How many batches: 72 / 4 = 18 */
    int n_batches = (NUM_SLICES + N_POV_IPS - 1) / N_POV_IPS;
    int slice_idx = 0;
    for (int b = 0; b < n_batches; b++) {
        /* Fire up to N_POV_IPS IPs */
        int fired = 0;
        for (int i = 0; i < N_POV_IPS; i++) {
            if (slice_idx >= NUM_SLICES) break;
            int col = slice_idx % GRID_COLS;
            int row = slice_idx / GRID_COLS;
            int ang = (slice_idx + phase) % NUM_SLICES;
            povi_fire(i, fb_base, ang, col, row);
            fired++;
            slice_idx++;
        }
        /* While IPs compute, drain UART (saves latency). */
        uart_poll_frame();
        /* Wait all fired IPs done. */
        for (int i = 0; i < fired; i++) povi_wait(i);
    }
}

static void pov_render_slice(UINTPTR fb_base, int angle_idx, int col, int row)
{
    u32 dst_x = col * SLICE_W;
    u32 dst_y = row * SLICE_H;

    pov_w(POV_MODEL_LO,   (u32)MODEL_ADDR);
    pov_w(POV_MODEL_HI,   0);
    pov_w(POV_NUM_POINTS, model_n);
    pov_w(POV_ANGLE_IDX,  angle_idx);
    pov_w(POV_FB_LO,      (u32)fb_base);
    pov_w(POV_FB_HI,      0);
    pov_w(POV_FB_STRIDE,  STRIDE);
    pov_w(POV_DST_X,      dst_x);
    pov_w(POV_DST_Y,      dst_y);

    pov_w(POV_AP_CTRL, 0x1);
    u32 timeout = 0;
    while (!(pov_r(POV_AP_CTRL) & 0x2)) {
        if (++timeout > 0x10000000) {
            xil_printf("pov IP timeout at angle=%d col=%d row=%d\r\n",
                       angle_idx, col, row);
            return;
        }
    }
}

/* ARM-side helpers: clear the 12x6 grid region and draw static gray borders.
 * MUCH faster than IP doing it via m_axi (A9 + L1/L2 + DDR controller has
 * higher memset throughput than HLS m_axi bursts). */
#define GRID_W_PX  (GRID_COLS * SLICE_W)   /* 1272 */
#define GRID_H_PX  (GRID_ROWS * SLICE_H)   /* 720 */

/* Dynamic base so caller picks FB_A or FB_B (double-buffer). */
static void arm_clear_grid(UINTPTR fb_base)
{
    for (u32 y = 0; y < GRID_H_PX; y++) {
        memset((u8 *)fb_base + y * STRIDE, 0, GRID_W_PX * 3);
    }
}

static void arm_draw_borders(UINTPTR fb_base)
{
    for (int r = 0; r < GRID_ROWS; r++) {
        for (int c = 0; c < GRID_COLS; c++) {
            u32 x0 = c * SLICE_W;
            u32 y0 = r * SLICE_H;
            u8 *fb = (u8 *)fb_base;
            memset(fb + y0 * STRIDE + x0 * 3, 30, SLICE_W * 3);
            memset(fb + (y0 + SLICE_H - 1) * STRIDE + x0 * 3, 30, SLICE_W * 3);
            for (u32 yy = 1; yy < SLICE_H - 1; yy++) {
                u8 *p = fb + (y0 + yy) * STRIDE + x0 * 3;
                p[0] = p[1] = p[2] = 30;
                p = fb + (y0 + yy) * STRIDE + (x0 + SLICE_W - 1) * 3;
                p[0] = p[1] = p[2] = 30;
            }
        }
    }
}

/* ---------------------------------------------------------------------- */
/* CPU path (for A/B comparison) */

#if !USE_PL
static inline void put_pixel_fb(u32 x, u32 y, u8 r, u8 g, u8 b)
{
    if (x >= WIDTH || y >= HEIGHT) return;
    u8 *p = (u8 *)FRAMEBUF_ADDR + y * STRIDE + x * 3;
    p[0] = b; p[1] = g; p[2] = r;
}

static void cpu_render_slice(int angle_idx, int col, int row)
{
    int16_t c = cos8_table[angle_idx];
    int16_t s = sin8_table[angle_idx];
    u8 *fb = (u8 *)FRAMEBUF_ADDR;
    u32 x0 = col * SLICE_W;
    u32 y0 = row * SLICE_H;

    for (int yy = 0; yy < SLICE_H; yy++) {
        memset(fb + (y0 + yy) * STRIDE + x0 * 3, 0, SLICE_W * 3);
    }
    for (int xx = 0; xx < SLICE_W; xx++) {
        put_pixel_fb(x0 + xx, y0, 30, 30, 30);
        put_pixel_fb(x0 + xx, y0 + SLICE_H - 1, 30, 30, 30);
    }
    for (int yy = 0; yy < SLICE_H; yy++) {
        put_pixel_fb(x0, y0 + yy, 30, 30, 30);
        put_pixel_fb(x0 + SLICE_W - 1, y0 + yy, 30, 30, 30);
    }

    int cx = SLICE_W / 2;
    int cy = SLICE_H / 2;
    for (int i = 0; i < model_n; i++) {
        int16_t px = model[i].x;
        int16_t py = model[i].y;
        int16_t pz = model[i].z;
        int32_t rx = ((int32_t)px * c + (int32_t)pz * s) >> 8;
        int sx = cx + rx;
        int sy = cy - py;
        if (sx >= 0 && sx < SLICE_W && sy >= 0 && sy < SLICE_H) {
            u8 r_ = model[i].r, g_ = model[i].g, b_ = model[i].b;
            put_pixel_fb(x0 + sx,     y0 + sy,     r_, g_, b_);
            put_pixel_fb(x0 + sx + 1, y0 + sy,     r_, g_, b_);
            put_pixel_fb(x0 + sx,     y0 + sy + 1, r_, g_, b_);
            put_pixel_fb(x0 + sx + 1, y0 + sy + 1, r_, g_, b_);
        }
    }
}
#endif

int main(void)
{
    init_platform();
    xil_printf("\r\n=== POV-3D Render Phase 4b (USE_PL=%d) ===\r\n", USE_PL);

    XGpio Led;
    XGpio_Initialize(&Led, XPAR_AXI_GPIO_0_BASEADDR);
    XGpio_SetDataDirection(&Led, 1, 0x0);
    XGpio_DiscreteWrite(&Led, 1, 0x3);

    XVtc Vtc;
    XVtc_Config *vtcCfg = XVtc_LookupConfig(XPAR_V_TC_0_BASEADDR);
    XVtc_CfgInitialize(&Vtc, vtcCfg, vtcCfg->BaseAddress);
    XVtc_SetGeneratorVideoMode(&Vtc, XVTC_VMODE_720P);
    XVtc_EnableGenerator(&Vtc);
    XVtc_Enable(&Vtc);

    XAxiVdma Vdma;
    XAxiVdma_Config *vdmaCfg = XAxiVdma_LookupConfig(XPAR_AXI_VDMA_0_BASEADDR);
    XAxiVdma_CfgInitialize(&Vdma, vdmaCfg, vdmaCfg->BaseAddress);
    XAxiVdma_DmaSetup setup = {0};
    setup.VertSizeInput = HEIGHT;
    setup.HoriSizeInput = STRIDE;
    setup.Stride        = STRIDE;
    /* Park mode from the start: EnableCircularBuf=0 means VDMA keeps
     * reading ONE framestore (selected by PARK_PTR register).
     * ARM renders into the OTHER one then writes PARK_PTR to swap. */
    setup.EnableCircularBuf = 0;
    XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_READ, &setup);
    UINTPTR fbs[2] = { FB_A_ADDR, FB_B_ADDR };
    XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_READ, fbs);
    /* StartParking BEFORE DmaStart: driver sets DMACR.Circular_Park=0,
     * PARK_PTR to our index, and only then starts the pixel pump. */
    XAxiVdma_StartParking(&Vdma, 0, XAXIVDMA_READ);
    XAxiVdma_DmaStart(&Vdma, XAXIVDMA_READ);
    xil_printf("VDMA DMACR=0x%x PARK_PTR=0x%x\r\n",
               (unsigned)vdma_dmacr(),
               (unsigned)Xil_In32(VDMA_BASE + VDMA_PARK_PTR_OFF));

    /* Clear BOTH framebuffers at boot so VDMA starts on known black. */
    memset((void *)FB_A_ADDR, 0, FRAME_BYTES);
    memset((void *)FB_B_ADDR, 0, FRAME_BYTES);
    Xil_DCacheFlushRange(FB_A_ADDR, FRAME_BYTES);
    Xil_DCacheFlushRange(FB_B_ADDR, FRAME_BYTES);

    build_model();
    /* Model lives in DDR; flush once so IP sees it via HP1 (not cache-coherent) */
    Xil_DCacheFlushRange(MODEL_ADDR, MAX_POINTS * sizeof(PovPoint));

#if USE_PL
    xil_printf("PL IP path: pov_project @ 0x%x, FCLK_CLK1\r\n",
               (unsigned)POV_BASE);
    /* Sanity: write-readback control regs. If axi-lite broken, mismatch. */
    pov_w(POV_NUM_POINTS, 0xDEADBEEF);
    pov_w(POV_DST_X,      0x12345678);
    u32 rb1 = pov_r(POV_NUM_POINTS);
    u32 rb2 = pov_r(POV_DST_X);
    xil_printf("AXI-Lite WR/RD: num_points=0x%x dst_x=0x%x (expect deadbeef/12345678)\r\n",
               (unsigned)rb1, (unsigned)rb2);
    xil_printf("IP initial AP_CTRL=0x%x  Ready=%u Done=%u Idle=%u\r\n",
               (unsigned)pov_r(POV_AP_CTRL),
               (unsigned)(pov_r(POV_AP_CTRL) >> 0 & 1),
               (unsigned)(pov_r(POV_AP_CTRL) >> 1 & 1),
               (unsigned)(pov_r(POV_AP_CTRL) >> 2 & 1));

    /* Fine-grained timing: setup, start, poll-wait, and 1000-read overhead */
    gt_enable();
    /* (a) 1000 reads of POV_AP_CTRL in tight loop - measures pure poll overhead */
    u64 tr0 = gt_read();
    volatile u32 junk = 0;
    for (int i = 0; i < 1000; i++) junk += pov_r(POV_AP_CTRL);
    u64 tr1 = gt_read();
    u32 per_read_ns = (u32)(((tr1 - tr0) * 3) / 1000);
    xil_printf("1000 pov_r(AP_CTRL) -> %u us total, %u ns/read\r\n",
               (u32)((tr1 - tr0) / GT_TICKS_PER_US), per_read_ns);

    /* (b) Scale test: time with num_points = 0, 1, 10, 100, model_n */
    u8 *fbtest = (u8 *)FRAMEBUF_ADDR;
    memset(fbtest, 0xAA, 512);
    Xil_DCacheFlushRange(FRAMEBUF_ADDR, 512);

    int test_np[5] = {0, 1, 10, 100, model_n};
    for (int k = 0; k < 5; k++) {
        pov_w(POV_MODEL_LO,   (u32)MODEL_ADDR);
        pov_w(POV_MODEL_HI,   0);
        pov_w(POV_NUM_POINTS, test_np[k]);
        pov_w(POV_ANGLE_IDX,  0);
        pov_w(POV_FB_LO,      (u32)FRAMEBUF_ADDR);
        pov_w(POV_FB_HI,      0);
        pov_w(POV_FB_STRIDE,  STRIDE);
        pov_w(POV_DST_X,      0);
        pov_w(POV_DST_Y,      0);
        u64 t_a = gt_read();
        pov_w(POV_AP_CTRL, 0x1);
        u32 polls = 0;
        while (!(pov_r(POV_AP_CTRL) & 0x2)) polls++;
        u64 t_b = gt_read();
        xil_printf("N=%u : %u us (%u polls)\r\n",
                   test_np[k], (u32)((t_b - t_a) / GT_TICKS_PER_US), polls);
    }
#endif

    xil_printf("Rendering 72 slices/frame. Reporting FPS every 32 frames.\r\n");

    gt_enable();
    u64 gt0 = gt_read();
    u64 gt1;
    XTime t0, t1;
    XTime_GetTime(&t0);
    xil_printf("Global Timer initial: 0x%08x%08x (after enable)\r\n",
               (u32)(gt0 >> 32), (u32)gt0);
    u32 frame = 0;
    u32 phase = 0;

    u32 stream_frames = 0;
    UINTPTR fb_bufs[2] = { FB_A_ADDR, FB_B_ADDR };
    u32 write_idx = 1;    /* VDMA parked on 0, we write to 1 first */

    while (1) {
        if (uart_poll_frame()) {
            stream_frames++;
            xil_printf("[rx] stream_frame=%u model_n=%d\r\n",
                       (unsigned)stream_frames, model_n);
        }

        UINTPTR fb_write = fb_bufs[write_idx];

#if USE_PL
        arm_clear_grid(fb_write);
        arm_draw_borders(fb_write);
        Xil_DCacheFlushRange(fb_write, FRAME_BYTES);
#endif
#if USE_PL
        /* Parallel dispatch: 4 IPs render simultaneously, each on different slice. */
        pov_render_frame_parallel(fb_write, phase);
#else
        for (int n = 0; n < NUM_SLICES; n++) {
            uart_poll_frame();
            int col = n % GRID_COLS;
            int row = n / GRID_COLS;
            int angle_idx = (n + phase) % NUM_SLICES;
            (void)fb_write;
            cpu_render_slice(angle_idx, col, row);
        }
#endif

#if !USE_PL
        Xil_DCacheFlushRange(fb_write, FRAME_BYTES);
#endif

        /* Seamless swap: write PARK_PTR directly (no stop/restart).
         * VDMA picks up the new index at its next frame boundary. */
        vdma_park(write_idx);
        write_idx ^= 1;

        frame++;
        phase++;

        if ((frame & 0x1F) == 0) {
            XTime_GetTime(&t1);
            gt1 = gt_read();
            /* Sanity: DMACR should have Circular_Park=0 and park ptr cycling. */
            xil_printf("  VDMA DMACR=0x%x parkW=%u curR=%u\r\n",
                       (unsigned)vdma_dmacr(),
                       (unsigned)(Xil_In32(VDMA_BASE + VDMA_PARK_PTR_OFF) & 0x1F),
                       (unsigned)vdma_current_read_idx());
            /* Primary: global timer direct read */
            u64 gt_dt = gt1 - gt0;
            u32 us = (u32)(gt_dt / GT_TICKS_PER_US);
            u32 ms = us / 1000;
            u32 fps100 = ms ? (u32)((32ULL * 100 * 1000) / ms) : 0;
            /* Secondary: XTime for comparison */
            u64 xt = t1 - t0;
            xil_printf("frame=%u  GT dT=%u us (%u.%02u FPS)  XT dT=%u ticks\r\n",
                       (unsigned)frame, us,
                       fps100 / 100, fps100 % 100,
                       (unsigned)xt);
            gt0 = gt1;
            t0 = t1;
            XGpio_DiscreteWrite(&Led, 1, (frame >> 5) & 1 ? 0x1 : 0x2);
        }
    }
    return 0;
}
