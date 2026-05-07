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
#include "xil_mmu.h"   /* Xil_SetTlbAttributes for ring buffer non-cacheable */
#include "xil_io.h"
#include "xiltimer.h"

#define USE_PL 0
/* Address-cache defeat experiment kept off — PL IP bug deferred. */
#define DEFEAT_ADDR_CACHE 0

/* Keep 720p60 for stable HDMI preview. 1080p upgrade needs rgb2dvi verification. */
/* HDMI resolution: define USE_1080P30 to switch to 1920×1080 @ 30Hz.
 * Both modes use same 74.25 MHz pixel clock. 720p60 is the demo default
 * (USB capture cards often only accept 720p input). 1080p30 verified
 * working on real 1080p monitor; capture chain limit on 720p cards. */
/* #define USE_1080P30 1 */
#ifdef USE_1080P30
#define WIDTH   1920
#define HEIGHT  1080
#else
#define WIDTH   1280
#define HEIGHT  720
#endif
#define BPP     3
#define STRIDE  (WIDTH * BPP)
#define FRAME_BYTES (STRIDE * HEIGHT)
/* Double buffer: VDMA reads one while ARM/IP writes the other.
 * 2.76 MB each + spacing; kept well away from model (0x11000000). */
#define FB_A_ADDR 0x10000000UL
#define FB_B_ADDR 0x14000000UL
#define FRAMEBUF_ADDR FB_A_ADDR  /* kept for any legacy refs */

/* Ring buffer for LED driver consumption (Phase 5a).
 * N_SLOTS of tightly-packed slice images, each SLICE_W × SLICE_H × 3 bytes.
 * LED driver IP will eventually pick a slot by angle and blast it to the
 * serial RGB chains. For now ARM writes, nobody reads except debug dumps. */
#define N_SLOTS          72
#define SLOT_BYTES       (SLICE_W * SLICE_H * 3)   /* 106×120×3 = 38160 */
#define RING_BUFFER_ADDR 0x12000000UL              /* separate from model, fb */
#define RING_BUFFER_END  (RING_BUFFER_ADDR + N_SLOTS * SLOT_BYTES)
/* = 0x12000000 + 2.62MB = 0x1229E200, well before FB_B_ADDR=0x14000000 */

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

/* Model lives at a fixed high DDR address, away from framebuffer + voxel grid.
 * DDR ends at 0x20000000 (512MB). Voxel grid 0x18-0x1A. Model after. */
#define MODEL_ADDR      0x1A000000UL    /* 1M points × 16B = 16 MB */
#define MAX_POINTS      1048576          /* 1M */
static PovPoint * const model = (PovPoint *)MODEL_ADDR;
static volatile int model_n = 0;   /* volatile: hybrid mode main loop 实时切换需要 */

/* Helper: force ARM cache + register flush, return current model_n. compiler
 * 不能 hoist 因为 it's a non-inline function with side effects. */
__attribute__((noinline)) static int read_model_n(void) {
    __asm__ __volatile__("dsb sy" ::: "memory");
    return model_n;
}

/* ---------------------------------------------------------------------- */
/* Voxel grid                                                             */
/* ---------------------------------------------------------------------- */
/* Voxelize model[] into a 3D grid in DDR. Each voxel = RGB565 (16 bit).
 * Slot for grid: 0x11800000 (between MODEL_ADDR_B 0x11400000 + 4MB
 * and RING_BUFFER_ADDR 0x12000000). Size 64^3 * 2 = 512 KB.
 *
 * Why voxels: original point-cloud render leaves "thin profile" at 90°
 * rotation when model has small z extent. Voxel representation gives
 * each cell intrinsic 3D extent (2 model units cubed), so slabs at any
 * rotation always sample some non-empty cells. */
#define VOXEL_RES        256
#define VOXEL_HALF       (VOXEL_RES / 2)
#define WORLD_HALF       128                   /* model coords [-127, 127] all fit */
#define VOXEL_CELL_SIZE  1                     /* = 2*WORLD_HALF/VOXEL_RES */
#define VOXEL_GRID_ADDR  0x18000000UL          /* 32 MB grid moved past FB_B */
#define VOXEL_BYTES      (VOXEL_RES * VOXEL_RES * VOXEL_RES * 2)   /* 32 MB */
static u16 * const voxel_grid = (u16 *)VOXEL_GRID_ADDR;
static volatile int voxel_n_occupied = 0;
/* 主循环 / uart_poll_frame 共享: 收到新点云后置 1, 让主循环重画右侧 grid.
 * volatile: uart_poll_frame 在 cpu_render 内部被嵌套调用, 不希望编译器优化. */
static volatile int right_dirty_g = 1;

/* Compact list of occupied voxels for fast render iteration (vs scanning
 * 256K cells). Each entry packs (vx, vy, vz, rgb565). MAX_OCCUPIED chosen
 * generously: 5000 points × 1 voxel-each-best-case = 5000 max. */
#define MAX_OCCUPIED       262144  /* 256K — covers up to 256K unique voxels */
typedef struct {
    uint8_t vx, vy, vz;   /* 0..255 (VOXEL_RES=256) needs unsigned */
    uint8_t _pad;
    u16     rgb565;
} VoxOcc;
static VoxOcc occupied_list[MAX_OCCUPIED];   /* 256K * 6 = 1.5 MB BSS */

/* Painter's algorithm bucket sort: 每帧按 rz 排序, 远到近绘制. */
static int painter_count[256];
static int painter_offset[256];
static u32 painter_sorted[MAX_OCCUPIED];   /* 256K * 4 = 1 MB BSS */

static inline u16 pack_rgb565(u8 r, u8 g, u8 b) {
    return ((u16)(r >> 3) << 11) | ((u16)(g >> 2) << 5) | (u16)(b >> 3);
}

static void voxelize_model(void) {
    /* Pass 1: write each model point to its primary voxel cell. */
    memset(voxel_grid, 0, VOXEL_BYTES);
    int occ = 0;
    for (int i = 0; i < model_n; i++) {
        int vx = (model[i].x + WORLD_HALF) / VOXEL_CELL_SIZE;
        int vy = (model[i].y + WORLD_HALF) / VOXEL_CELL_SIZE;
        int vz = (model[i].z + WORLD_HALF) / VOXEL_CELL_SIZE;
        if (vx < 0 || vx >= VOXEL_RES) continue;
        if (vy < 0 || vy >= VOXEL_RES) continue;
        if (vz < 0 || vz >= VOXEL_RES) continue;
        int idx = (vz * VOXEL_RES + vy) * VOXEL_RES + vx;
        u16 prev = voxel_grid[idx];
        u16 col = pack_rgb565(model[i].r, model[i].g, model[i].b);
        voxel_grid[idx] = col;
        if (prev == 0 && occ < MAX_OCCUPIED) {
            occupied_list[occ].vx = (uint8_t)vx;
            occupied_list[occ].vy = (uint8_t)vy;
            occupied_list[occ].vz = (uint8_t)vz;
            occupied_list[occ].rgb565 = col;
            occ++;
        }
    }

    /* Halo disabled to keep render fast. With 12000 raw points the
     * voxelized density (~10K cells) is enough for visible figure
     * without 4-5x render cost from halo cells. */
    voxel_n_occupied = occ;
    Xil_DCacheFlushRange(VOXEL_GRID_ADDR, VOXEL_BYTES);
}

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
 *   8   4  num_points  (u32: supports >65535 for high-detail one-shots)
 *   12  2  flags
 *   14  2  reserved
 *   16  N*16  point_t array
 */
#define PC_MAGIC  0x4C435050U
#define MESH_MAGIC 0x48534D50U   /* 'PMSH' little-endian — 三角面 mesh 协议 */

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t frame_id;
    uint32_t num_points;
    uint16_t flags;
    uint16_t reserved;
} pc_hdr_t;

/* Mesh 协议: header + verts(6B each) + tris(6B each).
 * 见 host/mesh_proto.py. */
typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t frame_id;
    uint32_t n_verts;
    uint32_t n_tris;
    uint16_t flags;
    uint16_t reserved;
} mesh_hdr_t;

typedef struct __attribute__((packed)) {
    int16_t  x, y, z;       /* Q8.4 fix-point: model unit = x / 16 */
    uint8_t  r, g, b;
} mesh_vert_t;   /* 9 bytes */

typedef struct __attribute__((packed)) {
    uint16_t i0, i1, i2;
} mesh_tri_t;

#define MAX_MESH_VERTS  16384
#define MAX_MESH_TRIS   8192
/* DDR layout: 借用 RING_BUFFER 段(0x12000000), 当前未使用 (USE_PL=0 走 ARM render) */
#define MESH_VERTS_ADDR  0x12000000UL    /* 24 KB */
#define MESH_TRIS_ADDR   0x12010000UL    /* 24 KB */
#define ZBUFFER_ADDR     0x12100000UL    /* 720*640 = 460 KB, allow pad */

static mesh_vert_t * const mesh_verts = (mesh_vert_t *)MESH_VERTS_ADDR;
static mesh_tri_t  * const mesh_tris  = (mesh_tri_t  *)MESH_TRIS_ADDR;
static int8_t      * const mesh_zbuf  = (int8_t      *)ZBUFFER_ADDR;

static volatile int  mesh_ready = 0;
static volatile u32  mesh_n_verts = 0;
static volatile u32  mesh_n_tris  = 0;

/* model_n: volatile 让 main loop 看到 uart_poll_frame 内部的更新 (hybrid mode 切换) */
/* (defined in build_model area but forward-declare volatile here for use_pl path) */

/* Receiver state machine: keep pulling bytes until a full valid frame lands,
 * or no more bytes available. On success, copies into `model[]`, sets
 * model_n, and returns 1. Returns 0 if still waiting / nothing arrived.
 *
 * Protocol supports raw (16B/point) and compressed (5B/point RGB565) formats,
 * selected by flags bit 0. Compressed points are decoded into 16-byte model[]
 * on the fly so the IP sees a consistent 16-byte array regardless of wire format. */
#define PC_FLAG_COMPRESSED    0x0001u
#define PC_FLAG_SPARSE_VOXEL  0x0002u  /* body = (idx24 + rgb16) * N, 5 byte/cell */
#define PC_POINT_LEN_RAW      16
#define PC_POINT_LEN_COMP     5
typedef enum { RX_HDR, RX_PTS, RX_MESH_VERTS, RX_MESH_TRIS } rx_state_t;
static rx_state_t rx_state = RX_HDR;
static u8          rx_hdr_buf[sizeof(mesh_hdr_t)]; /* 20 B; PC 只用前 16 */
static u32         rx_hdr_got = 0;
static u32         rx_expected_pts = 0;
static u32         rx_pts_got = 0;         /* bytes received so far in current point */
static u32         rx_pts_done = 0;        /* points fully decoded */
static u32         rx_magic_sync = 0;
static u32         rx_flags = 0;
static u32         rx_pt_len = PC_POINT_LEN_RAW;
static u8          rx_pt_buf[PC_POINT_LEN_RAW];
/* Mesh 接收状态 */
static int         rx_is_mesh = 0;
static u32         rx_hdr_size = sizeof(pc_hdr_t);
static u32         rx_mesh_n_verts_target = 0;
static u32         rx_mesh_n_tris_target = 0;
static u32         rx_mesh_bytes = 0;

static int uart_poll_frame(void)
{
    /* Drain as much as is available without blocking render loop.
     * Safety: cap at 256 bytes per call so we never hang here. */
    int frame_ready = 0;
    int guard = 256;
    while (guard-- > 0 && uart_rx_has()) {
        u8 b = uart_rx_byte();
        if (rx_state == RX_HDR) {
            /* Sync on magic — slide a 4-byte window. 接受 PC_MAGIC 或 MESH_MAGIC. */
            rx_magic_sync = (rx_magic_sync >> 8) | ((u32)b << 24);
            if (rx_hdr_got < 4) {
                rx_hdr_buf[rx_hdr_got++] = b;
                if (rx_hdr_got == 4) {
                    if (rx_magic_sync == PC_MAGIC) {
                        rx_is_mesh = 0;
                        rx_hdr_size = sizeof(pc_hdr_t);
                    } else if (rx_magic_sync == MESH_MAGIC) {
                        rx_is_mesh = 1;
                        rx_hdr_size = sizeof(mesh_hdr_t);
                    } else {
                        /* Not matched - rewind one position */
                        rx_hdr_got--;
                        memmove(rx_hdr_buf, rx_hdr_buf + 1, 3);
                    }
                }
            } else {
                rx_hdr_buf[rx_hdr_got++] = b;
                if (rx_hdr_got == rx_hdr_size) {
                    if (rx_is_mesh) {
                        mesh_hdr_t *mh = (mesh_hdr_t *)rx_hdr_buf;
                        if (mh->n_verts > MAX_MESH_VERTS || mh->n_tris > MAX_MESH_TRIS) {
                            xil_printf("[mesh-rx] bad sizes verts=%u tris=%u\r\n",
                                       (unsigned)mh->n_verts, (unsigned)mh->n_tris);
                            rx_hdr_got = 0;
                            rx_magic_sync = 0;
                        } else {
                            rx_mesh_n_verts_target = mh->n_verts;
                            rx_mesh_n_tris_target = mh->n_tris;
                            rx_mesh_bytes = 0;
                            rx_state = RX_MESH_VERTS;
                            xil_printf("[mesh-rx] verts=%u tris=%u\r\n",
                                       (unsigned)mh->n_verts, (unsigned)mh->n_tris);
                        }
                        continue;
                    }
                    pc_hdr_t *h = (pc_hdr_t *)rx_hdr_buf;
                    if (h->num_points > MAX_POINTS) {
                        xil_printf("[rx] bad num_points=%u, resync\r\n",
                                   (unsigned)h->num_points);
                        rx_hdr_got = 0;
                        rx_magic_sync = 0;
                    } else {
                        rx_expected_pts = h->num_points;
                        rx_flags = h->flags;
                        if (rx_flags & PC_FLAG_SPARSE_VOXEL) {
                            /* Sparse voxel: 5 bytes per cell (idx24 + rgb16).
                             * No model[] involvement — write straight to grid. */
                            rx_pt_len = 5;
                            /* Clear voxel grid + occupied count for fresh load. */
                            memset(voxel_grid, 0, VOXEL_BYTES);
                            voxel_n_occupied = 0;
                        } else {
                            rx_pt_len = (rx_flags & PC_FLAG_COMPRESSED)
                                            ? PC_POINT_LEN_COMP : PC_POINT_LEN_RAW;
                        }
                        rx_pts_got = 0;
                        rx_pts_done = 0;
                        rx_state = RX_PTS;
                        if (rx_expected_pts == 0) {
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
        } else if (rx_state == RX_PTS) {
            rx_pt_buf[rx_pts_got++] = b;
            if (rx_pts_got == rx_pt_len) {
                /* One point fully received; decode into model[rx_pts_done] */
                if (rx_flags & PC_FLAG_SPARSE_VOXEL) {
                    /* idx24 + rgb16 directly into voxel_grid + occupied_list */
                    u32 idx = (u32)rx_pt_buf[0] |
                              ((u32)rx_pt_buf[1] << 8) |
                              ((u32)rx_pt_buf[2] << 16);
                    u16 rgb = rx_pt_buf[3] | (rx_pt_buf[4] << 8);
                    if (idx < (u32)(VOXEL_RES * VOXEL_RES * VOXEL_RES)) {
                        voxel_grid[idx] = rgb;
                        if (voxel_n_occupied < MAX_OCCUPIED) {
                            u32 vx = idx % VOXEL_RES;
                            u32 vy = (idx / VOXEL_RES) % VOXEL_RES;
                            u32 vz = idx / (VOXEL_RES * VOXEL_RES);
                            occupied_list[voxel_n_occupied].vx = (uint8_t)vx;
                            occupied_list[voxel_n_occupied].vy = (uint8_t)vy;
                            occupied_list[voxel_n_occupied].vz = (uint8_t)vz;
                            occupied_list[voxel_n_occupied].rgb565 = rgb;
                            voxel_n_occupied++;
                        }
                    }
                } else if (rx_flags & PC_FLAG_COMPRESSED) {
                    /* 5B: int8 x, y, z; u16 rgb565 little-endian */
                    int8_t xs = (int8_t)rx_pt_buf[0];
                    int8_t ys = (int8_t)rx_pt_buf[1];
                    int8_t zs = (int8_t)rx_pt_buf[2];
                    u16 rgb = rx_pt_buf[3] | (rx_pt_buf[4] << 8);
                    /* One-time dump of first decoded point for verification */
                    static int rgb_dumped = 0;
                    if (!rgb_dumped && rx_pts_done == 0) {
                        rgb_dumped = 1;
                        xil_printf("[comp] wire bytes[3,4]=0x%02x 0x%02x rgb=0x%04x\r\n",
                                   rx_pt_buf[3], rx_pt_buf[4], (unsigned)rgb);
                    }
                    /* expand RGB565 → RGB888 */
                    u8 r5 = (rgb >> 11) & 0x1F;
                    u8 g6 = (rgb >> 5)  & 0x3F;
                    u8 b5 = rgb         & 0x1F;
                    u8 r = (r5 << 3) | (r5 >> 2);
                    u8 g = (g6 << 2) | (g6 >> 4);
                    u8 b = (b5 << 3) | (b5 >> 2);
                    model[rx_pts_done].x = xs;
                    model[rx_pts_done].y = ys;
                    model[rx_pts_done].z = zs;
                    model[rx_pts_done]._pad0 = 0;
                    model[rx_pts_done].r = r;
                    model[rx_pts_done].g = g;
                    model[rx_pts_done].b = b;
                    model[rx_pts_done]._pad1 = 0;
                    model[rx_pts_done]._pad2 = 0;
                } else {
                    /* 16B raw: direct memcpy from buffer into PovPoint struct */
                    memcpy(&model[rx_pts_done], rx_pt_buf, PC_POINT_LEN_RAW);
                }
                rx_pts_done++;
                rx_pts_got = 0;
                if (rx_pts_done == rx_expected_pts) {
                    if (rx_flags & PC_FLAG_SPARSE_VOXEL) {
                        /* Sparse voxel cells: voxel_grid + occupied_list filled
                         * directly per-byte above. Just flush cache. */
                        Xil_DCacheFlushRange(VOXEL_GRID_ADDR, VOXEL_BYTES);
                    } else {
                        model_n = rx_expected_pts;
                        __asm__ __volatile__("dsb sy" ::: "memory");
                        xil_printf("[rxdone] model_n set to %d\r\n", model_n);
                        Xil_DCacheFlushRange(MODEL_ADDR, model_n * sizeof(PovPoint));
#if !USE_PL
                        /* USE_PL=1 时 PL IP 直接用 model[], 不需 voxel_grid.
                         * 跳过 voxelize_model 避免 32MB memset 阻塞 UART. */
                        voxelize_model();
#endif
                    }
                    rx_state = RX_HDR;
                    rx_hdr_got = 0;
                    rx_magic_sync = 0;
                    frame_ready = 1;
                    right_dirty_g = 1;   /* 触发主循环重画右侧 grid */
                    /* First-frame dump to compare with Host */
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
        } else if (rx_state == RX_MESH_VERTS) {
            /* 把字节直接写到 mesh_verts buffer 里 (UART 顺序 = struct 布局) */
            ((u8 *)mesh_verts)[rx_mesh_bytes++] = b;
            if (rx_mesh_bytes == rx_mesh_n_verts_target * sizeof(mesh_vert_t)) {
                rx_mesh_bytes = 0;
                rx_state = RX_MESH_TRIS;
            }
        } else if (rx_state == RX_MESH_TRIS) {
            ((u8 *)mesh_tris)[rx_mesh_bytes++] = b;
            if (rx_mesh_bytes == rx_mesh_n_tris_target * sizeof(mesh_tri_t)) {
                /* Mesh 收完, flush cache + 标 ready */
                mesh_n_verts = rx_mesh_n_verts_target;
                mesh_n_tris  = rx_mesh_n_tris_target;
                Xil_DCacheFlushRange(MESH_VERTS_ADDR,
                                     mesh_n_verts * sizeof(mesh_vert_t));
                Xil_DCacheFlushRange(MESH_TRIS_ADDR,
                                     mesh_n_tris * sizeof(mesh_tri_t));
                __asm__ __volatile__("dsb sy" ::: "memory");
                mesh_ready = 1;
                right_dirty_g = 1;
                xil_printf("[mesh-rxdone] verts=%u tris=%u\r\n",
                           (unsigned)mesh_n_verts, (unsigned)mesh_n_tris);
                /* dump first vert + first tri */
                xil_printf("[mesh-dump] v0=(%d,%d,%d  r=%u g=%u b=%u)\r\n",
                           (int)mesh_verts[0].x, (int)mesh_verts[0].y, (int)mesh_verts[0].z,
                           (unsigned)mesh_verts[0].r, (unsigned)mesh_verts[0].g,
                           (unsigned)mesh_verts[0].b);
                xil_printf("[mesh-dump] tri0=(%u,%u,%u)\r\n",
                           (unsigned)mesh_tris[0].i0, (unsigned)mesh_tris[0].i1,
                           (unsigned)mesh_tris[0].i2);
                rx_state = RX_HDR;
                rx_hdr_got = 0;
                rx_magic_sync = 0;
                frame_ready = 1;
            }
        }
    }
    return frame_ready;
}

/* 360 entry tables for 1° resolution (used by slice panel).
 * Full table to avoid runtime sin/cos. */
static const int16_t cos360_table[360] = {
     256,256,256,256,255,255,255,254,254,253, 252,251,250,249,248,247,246,245,243,242,
     241,239,237,236,234,232,230,228,226,224, 222,219,217,215,212,210,207,204,202,199,
     196,193,190,187,184,181,178,175,171,168, 165,161,158,154,150,147,143,139,136,132,
     128,124,120,116,112,108,104,100, 96, 92,  88, 83, 79, 75, 71, 66, 62, 58, 53, 49,
      44, 40, 36, 31, 27, 22, 18, 13,  9,  4,   0, -4, -9,-13,-18,-22,-27,-31,-36,-40,
     -44,-49,-53,-58,-62,-66,-71,-75,-79,-83, -88,-92,-96,-100,-104,-108,-112,-116,-120,-124,
    -128,-132,-136,-139,-143,-147,-150,-154,-158,-161, -165,-168,-171,-175,-178,-181,-184,-187,-190,-193,
    -196,-199,-202,-204,-207,-210,-212,-215,-217,-219, -222,-224,-226,-228,-230,-232,-234,-236,-237,-239,
    -241,-242,-243,-245,-246,-247,-248,-249,-250,-251, -252,-253,-254,-254,-255,-255,-255,-256,-256,-256,
    -256,-256,-256,-256,-255,-255,-255,-254,-254,-253, -252,-251,-250,-249,-248,-247,-246,-245,-243,-242,
    -241,-239,-237,-236,-234,-232,-230,-228,-226,-224, -222,-219,-217,-215,-212,-210,-207,-204,-202,-199,
    -196,-193,-190,-187,-184,-181,-178,-175,-171,-168, -165,-161,-158,-154,-150,-147,-143,-139,-136,-132,
    -128,-124,-120,-116,-112,-108,-104,-100,-96,-92, -88,-83,-79,-75,-71,-66,-62,-58,-53,-49,
     -44,-40,-36,-31,-27,-22,-18,-13, -9, -4,   0,  4,  9, 13, 18, 22, 27, 31, 36, 40,
      44, 49, 53, 58, 62, 66, 71, 75, 79, 83,  88, 92, 96,100,104,108,112,116,120,124,
     128,132,136,139,143,147,150,154,158,161, 165,168,171,175,178,181,184,187,190,193,
     196,199,202,204,207,210,212,215,217,219, 222,224,226,228,230,232,234,236,237,239,
     241,242,243,245,246,247,248,249,250,251, 252,253,254,254,255,255,255,256,256,256,
};
static const int16_t sin360_table[360] = {
       0,  4,  9, 13, 18, 22, 27, 31, 36, 40,  44, 49, 53, 58, 62, 66, 71, 75, 79, 83,
      88, 92, 96,100,104,108,112,116,120,124, 128,132,136,139,143,147,150,154,158,161,
     165,168,171,175,178,181,184,187,190,193, 196,199,202,204,207,210,212,215,217,219,
     222,224,226,228,230,232,234,236,237,239, 241,242,243,245,246,247,248,249,250,251,
     252,253,254,254,255,255,255,256,256,256, 256,256,256,256,255,255,255,254,254,253,
     252,251,250,249,248,247,246,245,243,242, 241,239,237,236,234,232,230,228,226,224,
     222,219,217,215,212,210,207,204,202,199, 196,193,190,187,184,181,178,175,171,168,
     165,161,158,154,150,147,143,139,136,132, 128,124,120,116,112,108,104,100, 96, 92,
      88, 83, 79, 75, 71, 66, 62, 58, 53, 49,  44, 40, 36, 31, 27, 22, 18, 13,  9,  4,
       0, -4, -9,-13,-18,-22,-27,-31,-36,-40, -44,-49,-53,-58,-62,-66,-71,-75,-79,-83,
     -88,-92,-96,-100,-104,-108,-112,-116,-120,-124, -128,-132,-136,-139,-143,-147,-150,-154,-158,-161,
    -165,-168,-171,-175,-178,-181,-184,-187,-190,-193, -196,-199,-202,-204,-207,-210,-212,-215,-217,-219,
    -222,-224,-226,-228,-230,-232,-234,-236,-237,-239, -241,-242,-243,-245,-246,-247,-248,-249,-250,-251,
    -252,-253,-254,-254,-255,-255,-255,-256,-256,-256, -256,-256,-256,-256,-255,-255,-255,-254,-254,-253,
    -252,-251,-250,-249,-248,-247,-246,-245,-243,-242, -241,-239,-237,-236,-234,-232,-230,-228,-226,-224,
    -222,-219,-217,-215,-212,-210,-207,-204,-202,-199, -196,-193,-190,-187,-184,-181,-178,-175,-171,-168,
    -165,-161,-158,-154,-150,-147,-143,-139,-136,-132, -128,-124,-120,-116,-112,-108,-104,-100,-96,-92,
     -88,-83,-79,-75,-71,-66,-62,-58,-53,-49, -44,-40,-36,-31,-27,-22,-18,-13, -9, -4,
};

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
    /* POV 物理坐标: X 水平左右, Y 水平前后(深度), Z 垂直上下 (LED 板旋转轴).
     * 板内部 my 是屏幕垂直, mz 是深度旋转. 把 Y(深度)→GREEN, Z(垂直)→BLUE 让
     * BLUE 沿屏幕垂直显示, 与 POV 物理意义对齐. */
    add_line(-50, 0, 0, 50, 0, 0, 40, 255, 0, 0);   /* X: RED, 水平 */
    add_line(0, 0, -50, 0, 0, 50, 40, 0, 255, 0);   /* Y: GREEN, 深度(旋转中) */
    add_line(0, -50, 0, 0, 50, 0, 40, 0, 0, 255);   /* Z: BLUE, 垂直 */

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

/* Single pov IP only (BD reverted to remove pov_project_1/2/3).
 * Dispatcher code kept for future re-enable when 4-IP doesn't break HDMI. */
#define N_POV_IPS  1
static const u32 pov_bases[4] = {
    0x43C20000UL, 0x43C30000UL, 0x43C40000UL, 0x43C50000UL
};
#define POV_BASE          0x43C20000UL
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

/* Ring buffer render via BATCH IP: one ap_start renders all 72 slices.
 * IP reads model once into internal BRAM, loops internally.
 *
 * Register map (pov_project_batch HLS-generated):
 *   0x00 AP_CTRL
 *   0x10 model[31:0]
 *   0x14 model[63:32]
 *   0x1c num_points
 *   0x24 ring_base[31:0]
 *   0x28 ring_base[63:32]
 *   0x30 slot_bytes
 *   0x38 slot_stride
 *   0x40 phase
 *   0x48 n_slots
 */
#define BATCH_MODEL_LO     0x10
#define BATCH_MODEL_HI     0x14
#define BATCH_NUM_POINTS   0x1c
#define BATCH_RING_LO      0x24
#define BATCH_RING_HI      0x28
#define BATCH_SLOT_BYTES   0x30
#define BATCH_SLOT_STRIDE  0x38
#define BATCH_PHASE        0x40
#define BATCH_N_SLOTS      0x48

/* Alternate model copy address — to test if HP/smc has read-cache stale issue */
#define MODEL_ADDR_B  0x11400000UL   /* 4 MB after primary, well aligned */

static void pov_render_frame_to_ring(u32 phase)
{
    /* Force phase to heavy test values so different output must occur. */
    u32 test_phase = phase & 0x3F;   /* 0..63 */

#if DEFEAT_ADDR_CACHE
    /* Each call: copy MODEL_ADDR → MODEL_ADDR_B (alternating each frame),
     * point IP at the copied address. Forces IP to read from a different
     * DDR location each ap_start, defeating any address-keyed stale cache. */
    static int alt = 0;
    UINTPTR src = MODEL_ADDR;
    UINTPTR dst = alt ? MODEL_ADDR_B : MODEL_ADDR;
    if (alt) {
        memcpy((void *)MODEL_ADDR_B, (void *)MODEL_ADDR, model_n * sizeof(PovPoint));
        Xil_DCacheFlushRange(MODEL_ADDR_B, model_n * sizeof(PovPoint));
    }
    alt ^= 1;
    pov_w(BATCH_MODEL_LO,    (u32)dst);
#else
    pov_w(BATCH_MODEL_LO,    (u32)MODEL_ADDR);
#endif
    pov_w(BATCH_MODEL_HI,    0);
    pov_w(BATCH_NUM_POINTS,  model_n);
    pov_w(BATCH_RING_LO,     (u32)RING_BUFFER_ADDR);
    pov_w(BATCH_RING_HI,     0);
    pov_w(BATCH_SLOT_BYTES,  SLOT_BYTES);
    pov_w(BATCH_SLOT_STRIDE, SLICE_W * 3);
    pov_w(BATCH_PHASE,       test_phase);
    pov_w(BATCH_N_SLOTS,     N_SLOTS);

    /* Diagnostic every 128 frames: print what IP actually sees */
    static u32 dbg = 0;
    if ((dbg++ & 0x7F) == 0) {
        xil_printf("batch fire phase=%u rb_phase=%u rb_np=%u model_addr=0x%x\r\n",
                   (unsigned)test_phase,
                   (unsigned)pov_r(BATCH_PHASE),
                   (unsigned)pov_r(BATCH_NUM_POINTS),
                   (unsigned)pov_r(BATCH_MODEL_LO));
    }

    pov_w(POV_AP_CTRL, 0x1);
    u32 to = 0;
    while (!(pov_r(POV_AP_CTRL) & 0x2)) {
        if (++to > 0x10000000) { xil_printf("batch timeout\r\n"); return; }
        uart_poll_frame();
    }
}

/* Dump center pixel + a few sample locations of slot 0, and nonzero count.
 * If model changes cause slot content change, center pixel or nonzero count will shift. */
static void ring_verify(void)
{
    for (int s = 0; s <= 36; s += 18) {
        const u8 *p = (const u8 *)(RING_BUFFER_ADDR + s * SLOT_BYTES);
        Xil_DCacheInvalidateRange((UINTPTR)p, SLOT_BYTES);
        u32 nonzero = 0;
        for (u32 b = 0; b < SLOT_BYTES; b++) if (p[b]) nonzero++;
        int cx = SLICE_W / 2, cy = SLICE_H / 2;
        const u8 *cen = p + cy * (SLICE_W * 3) + cx * 3;
        xil_printf("slot %2d  nonzero=%u  cen_px=%02x%02x%02x  near=%02x%02x%02x\r\n",
                   s, (unsigned)nonzero,
                   cen[0], cen[1], cen[2],
                   p[4000], p[4001], p[4002]);
    }
}

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
/* CPU path (for A/B comparison + hybrid mode boot rendering) */

#if 1   /* always-compile for hybrid: boot ARM render even with USE_PL=1 */
static inline void put_pixel_fb(u32 x, u32 y, u8 r, u8 g, u8 b)
{
    if (x >= WIDTH || y >= HEIGHT) return;
    u8 *p = (u8 *)FRAMEBUF_ADDR + y * STRIDE + x * 3;
    /* HDMI VDMA reads bytes as (G,B,R) — verified by anime test 2026-04-27. */
    p[0] = g; p[1] = b; p[2] = r;
}

/* Slice thickness: points whose rotated-Z is within ±SLICE_HALF_THICK are in-slice.
 * Thicker slices = more points per slice, better visual continuity. */
#define SLICE_HALF_THICK  8

/* Render one slice cell. If `slice_mode` is 0, do full projection (old, for
 * left half of screen); if 1, do real z-slice (clip by rotated-Z).          */
static void cpu_render_slice_mode(int angle_idx, int col, int row, int slice_mode)
{
    int16_t c = cos8_table[angle_idx];
    int16_t s = sin8_table[angle_idx];
    u8 *fb = (u8 *)FRAMEBUF_ADDR;
    u32 x0 = col * SLICE_W;
    u32 y0 = row * SLICE_H;

    for (int yy = 0; yy < SLICE_H; yy++) {
        memset(fb + (y0 + yy) * STRIDE + x0 * 3, 0, SLICE_W * 3);
    }
    /* Border: left half = gray, right half = cyan (visual split marker) */
    u8 bR = slice_mode ? 0 : 30;
    u8 bG = slice_mode ? 80 : 30;
    u8 bB = slice_mode ? 80 : 30;
    for (int xx = 0; xx < SLICE_W; xx++) {
        put_pixel_fb(x0 + xx, y0, bR, bG, bB);
        put_pixel_fb(x0 + xx, y0 + SLICE_H - 1, bR, bG, bB);
    }
    for (int yy = 0; yy < SLICE_H; yy++) {
        put_pixel_fb(x0, y0 + yy, bR, bG, bB);
        put_pixel_fb(x0 + SLICE_W - 1, y0 + yy, bR, bG, bB);
    }

    int cx = SLICE_W / 2;
    int cy = SLICE_H / 2;
    for (int i = 0; i < model_n; i++) {
        int16_t px = model[i].x;
        int16_t py = model[i].y;
        int16_t pz = model[i].z;
        /* rotated coords */
        int32_t rx = ((int32_t)px * c + (int32_t)pz * s) >> 8;
        int32_t rz = ((int32_t)-px * s + (int32_t)pz * c) >> 8;

        if (slice_mode) {
            /* true slice: keep only points within thin z band */
            if (rz > SLICE_HALF_THICK || rz < -SLICE_HALF_THICK) continue;
        }

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

/* Legacy helper: used by main loop. Decides mode per-column. */
static void cpu_render_slice(int angle_idx, int col, int row)
{
    int slice_mode = (col >= GRID_COLS / 2) ? 1 : 0;
    cpu_render_slice_mode(angle_idx, col, row, slice_mode);
}

/* Big-panel render: panel_w × panel_h region at (origin_x, origin_y).
 * `angle_deg` is 0..359; uses 360-entry LUT for 1° resolution.
 * slice_mode 0 = full 3D projection; 1 = z-slice cut. */
static void cpu_render_panel(UINTPTR fb_base, int angle_deg,
                             int origin_x, int origin_y,
                             int panel_w, int panel_h,
                             int slice_mode, int scale_pct)
{
    if (angle_deg < 0) angle_deg = 0;
    if (angle_deg >= 360) angle_deg %= 360;
    int16_t c = cos360_table[angle_deg];
    int16_t s = sin360_table[angle_deg];
    u8 *fb = (u8 *)fb_base;

    /* Clear panel */
    for (int yy = 0; yy < panel_h; yy++) {
        memset(fb + (origin_y + yy) * STRIDE + origin_x * 3, 0, panel_w * 3);
    }
    /* Colored border to label the mode */
    u8 bR = slice_mode ? 0  : 80;
    u8 bG = slice_mode ? 80 : 80;
    u8 bB = slice_mode ? 80 : 80;
    for (int xx = 0; xx < panel_w; xx++) {
        u8 *p = fb + origin_y * STRIDE + (origin_x + xx) * 3;
        p[0]=bG; p[1]=bB; p[2]=bR;
        p = fb + (origin_y + panel_h - 1) * STRIDE + (origin_x + xx) * 3;
        p[0]=bG; p[1]=bB; p[2]=bR;
    }
    for (int yy = 0; yy < panel_h; yy++) {
        u8 *p = fb + (origin_y + yy) * STRIDE + origin_x * 3;
        p[0]=bG; p[1]=bB; p[2]=bR;
        p = fb + (origin_y + yy) * STRIDE + (origin_x + panel_w - 1) * 3;
        p[0]=bG; p[1]=bB; p[2]=bR;
    }

    int cx = panel_w / 2;
    int cy = panel_h / 2;
    /* scale_pct = 100 means 1:1 (model ±60 fits in ±300 panel space). Use
     * larger scale for the big panel so model fills it. 500 ~= 5x. */
    for (int i = 0; i < model_n; i++) {
        /* Drain UART RX every 100 points to prevent FIFO overflow during long
         * renders. FIFO is only 64 bytes @ 11.5 KB/s = ~5ms drain budget. */
        if ((i & 0x7F) == 0) uart_poll_frame();
        int16_t px = model[i].x;
        int16_t py = model[i].y;
        int16_t pz = model[i].z;
        int32_t rx = ((int32_t)px * c + (int32_t)pz * s) >> 8;
        int32_t rz = ((int32_t)-px * s + (int32_t)pz * c) >> 8;
        if (slice_mode) {
            if (rz > SLICE_HALF_THICK || rz < -SLICE_HALF_THICK) continue;
        }
        int sx = cx + (rx * scale_pct) / 100;
        int sy = cy - (py * scale_pct) / 100;
        if (sx >= 0 && sx < panel_w - 1 && sy >= 0 && sy < panel_h - 1) {
            u8 r_ = model[i].r, g_ = model[i].g, b_ = model[i].b;
            for (int dy = 0; dy < 2; dy++) {
                for (int dx = 0; dx < 2; dx++) {
                    u8 *p = fb + (origin_y + sy + dy) * STRIDE + (origin_x + sx + dx) * 3;
                    p[0] = g_; p[1] = b_; p[2] = r_;
                }
            }
        }
    }
}

/* Voxel-grid renderer. Iterates the occupied-voxel list and projects each
 * voxel as a small filled rectangle on the panel. Voxel cells are 2 model
 * units cubed so they intrinsically have 3D extent — even at 90°/270°
 * rotation a flat anime model still shows visible body width because the
 * voxel grid's z-axis cells span 2 units regardless of input z range.
 *
 * slice_mode: 0 = full projection (all voxels)
 *             1 = thin radial slab (only voxels with |rotated_z| <= half) */
static void cpu_render_voxel_panel(UINTPTR fb_base, int angle_deg,
                                    int origin_x, int origin_y,
                                    int panel_w, int panel_h,
                                    int slice_mode, int scale_pct)
{
    if (angle_deg < 0) angle_deg = 0;
    if (angle_deg >= 360) angle_deg %= 360;
    int16_t c = cos360_table[angle_deg];
    int16_t s = sin360_table[angle_deg];
    u8 *fb = (u8 *)fb_base;

    /* Clear panel 用中性灰 80 替代纯黑: HDMI YCbCr 限制范围 (16-235) 让 30 看起来
     * 跟黑底无差; 80 足够亮显灰. 黑色 voxel (黑发卡/内衣/靴) 跟黑底融合的问题靠
     * 灰底反差解决. */
    for (int yy = 0; yy < panel_h; yy++) {
        memset(fb + (origin_y + yy) * STRIDE + origin_x * 3, 80, panel_w * 3);
        if ((yy & 0x0F) == 0) uart_poll_frame();
    }
    int cx = panel_w / 2;
    int cy = panel_h / 2;

    /* Slab thickness for slice_mode=1: ±4 model units ≈ 8% 模型厚度.
     * 之前 12 太厚, 几乎所有 voxel 都进切片, 视觉等同全身投影 — 不像 POV 切片.
     * 4 是接近 LED panel 真实薄片的下限, 仍能看到主要 voxel 轮廓. */
    const int SLAB_HALF = 4;

    uart_poll_frame();

    /* Each voxel renders as a `block_size`-pixel block, sized to roughly
     * match the cell's true panel footprint at scale_pct. cell = 2 model
     * units; panel pixels per model unit = scale_pct/100; so block size =
     * 2 * scale_pct / 100. Min 1 to ensure something gets drawn. */
    int block = (VOXEL_CELL_SIZE * scale_pct) / 100;
    if (block < 1) block = 1;
    if (block > 4) block = 4;

    /* Painter's algorithm: bucket-sort voxels by rz (rotated z), draw far-to-near.
     * 消除 last-write-wins 的帧间抖动闪烁 (相同 (sx,sy) 处永远是最近的 voxel 赢). */
    int painter_n = 0;
    if (!slice_mode) {
        memset(painter_count, 0, sizeof(painter_count));
        /* Pass 1: count per bucket */
        for (int i = 0; i < voxel_n_occupied; i++) {
            VoxOcc v = occupied_list[i];
            int mx = (int)v.vx * VOXEL_CELL_SIZE - WORLD_HALF + VOXEL_CELL_SIZE / 2;
            int mz = (int)v.vz * VOXEL_CELL_SIZE - WORLD_HALF + VOXEL_CELL_SIZE / 2;
            int rz = (-(int)mx * s + (int)mz * c) >> 8;
            if (rz < -127) rz = -127;
            if (rz > 127) rz = 127;
            painter_count[rz + 128]++;
        }
        /* Prefix sum → bucket start offsets */
        int total = 0;
        for (int b = 0; b < 256; b++) {
            painter_offset[b] = total;
            total += painter_count[b];
            painter_count[b] = 0;   /* reset for scatter */
        }
        /* Pass 2: scatter indices into sorted array */
        for (int i = 0; i < voxel_n_occupied; i++) {
            VoxOcc v = occupied_list[i];
            int mx = (int)v.vx * VOXEL_CELL_SIZE - WORLD_HALF + VOXEL_CELL_SIZE / 2;
            int mz = (int)v.vz * VOXEL_CELL_SIZE - WORLD_HALF + VOXEL_CELL_SIZE / 2;
            int rz = (-(int)mx * s + (int)mz * c) >> 8;
            if (rz < -127) rz = -127;
            if (rz > 127) rz = 127;
            int bk = rz + 128;
            painter_sorted[painter_offset[bk] + painter_count[bk]++] = i;
            if ((i & 0x7F) == 0) uart_poll_frame();
        }
        painter_n = total;
    }

    for (int rs = 0; rs < (slice_mode ? voxel_n_occupied : painter_n); rs++) {
        int i = slice_mode ? rs : (int)painter_sorted[rs];
        VoxOcc v = occupied_list[i];
        /* Voxel center in model coords: voxel index → cell center */
        int mx = (int)v.vx * VOXEL_CELL_SIZE - WORLD_HALF + VOXEL_CELL_SIZE / 2;
        int my = (int)v.vy * VOXEL_CELL_SIZE - WORLD_HALF + VOXEL_CELL_SIZE / 2;
        int mz = (int)v.vz * VOXEL_CELL_SIZE - WORLD_HALF + VOXEL_CELL_SIZE / 2;

        /* Y-axis rotation: rx = mx*c + mz*s,  rz = -mx*s + mz*c  (Q8.8 → div 256) */
        int rx = ((int)mx * c + (int)mz * s) >> 8;
        int rz = (-(int)mx * s + (int)mz * c) >> 8;
        if (slice_mode && (rz > SLAB_HALF || rz < -SLAB_HALF)) continue;

        /* Camera tilt 15° down (only for full projection — slice_mode keeps top-down).
         * Breaks bilateral symmetry: 0°/180° look different even for symmetric models.
         * Q8.8: cos(15°)≈247, sin(15°)≈66 */
        int tilt_y;
        if (!slice_mode) {
            tilt_y = ((int)my * 247 - (int)rz * 66) >> 8;
        } else {
            tilt_y = my;
        }

        int sx = cx + (rx * scale_pct) / 100;
        int sy = cy - (tilt_y * scale_pct) / 100;
        if (sx < 0 || sx + block > panel_w) continue;
        if (sy < 0 || sy + block > panel_h) continue;

        u8 r5 = (v.rgb565 >> 11) & 0x1F;
        u8 g6 = (v.rgb565 >> 5)  & 0x3F;
        u8 b5 =  v.rgb565        & 0x1F;
        u8 r = (r5 << 3) | (r5 >> 2);
        u8 g = (g6 << 2) | (g6 >> 4);
        u8 b = (b5 << 3) | (b5 >> 2);
        for (int dy = 0; dy < block; dy++) {
            u8 *p = fb + (origin_y + sy + dy) * STRIDE + (origin_x + sx) * 3;
            for (int dx = 0; dx < block; dx++) {
                p[0] = g; p[1] = b; p[2] = r;
                p += 3;
            }
        }
        /* Drain UART every 128 voxels — same cadence as point cloud render */
        if ((rs & 0x7F) == 0) uart_poll_frame();
    }
}
#endif

/* ============================================================
 * Mesh software triangle rasterizer
 * 三角面 mesh 路径: 每帧 rotate verts 后用 edge function 光栅化, z-buffer
 * 处理遮挡, 重心插值 r/g/b. 取代 voxel point-cloud render.
 * ============================================================ */
typedef struct {
    int16_t sx, sy;
    int8_t  sz;
    uint8_t r, g, b;
    uint8_t _pad;
} screen_vert_t;

static screen_vert_t mesh_screen_verts[MAX_MESH_VERTS];

static inline int sat_int8(int v) { return v < -127 ? -127 : (v > 127 ? 127 : v); }

static void rasterize_tri(u8 *fb, int origin_x, int origin_y,
                          int panel_w, int panel_h,
                          screen_vert_t *v0, screen_vert_t *v1, screen_vert_t *v2,
                          int8_t *zbuf)
{
    int x0 = v0->sx, y0 = v0->sy, z0 = v0->sz;
    int x1 = v1->sx, y1 = v1->sy, z1 = v1->sz;
    int x2 = v2->sx, y2 = v2->sy, z2 = v2->sz;

    /* 面积负数 = 顶点 CW 顺序; swap v1<->v2 让 area>0, 内层循环不再乘 sign */
    int area2 = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0);
    if (area2 == 0) return;
    screen_vert_t *vv0 = v0, *vv1 = v1, *vv2 = v2;
    if (area2 < 0) {
        screen_vert_t *tmp = vv1; vv1 = vv2; vv2 = tmp;
        int tx = x1, ty = y1, tz = z1;
        x1 = x2; y1 = y2; z1 = z2;
        x2 = tx; y2 = ty; z2 = tz;
        area2 = -area2;
    }

    /* 2D bounding box clipped to panel */
    int minx = x0; if (x1 < minx) minx = x1; if (x2 < minx) minx = x2;
    int miny = y0; if (y1 < miny) miny = y1; if (y2 < miny) miny = y2;
    int maxx = x0; if (x1 > maxx) maxx = x1; if (x2 > maxx) maxx = x2;
    int maxy = y0; if (y1 > maxy) maxy = y1; if (y2 > maxy) maxy = y2;
    if (minx < 0) minx = 0;
    if (miny < 0) miny = 0;
    if (maxx > panel_w - 1) maxx = panel_w - 1;
    if (maxy > panel_h - 1) maxy = panel_h - 1;
    if (minx > maxx || miny > maxy) return;

    /* 预存 1/area2 为 Q24: inv = (1<<24) / area2.
     * 之后 b0 = s0 * inv >> 16 给 Q8.8. 替代每像素 sdiv (~12 cyc → 1 mul). */
    const int inv_q24 = (int)((1u << 24) / (unsigned)area2);

    int A12 = -(y2 - y1), B12 = (x2 - x1);
    int A20 = -(y0 - y2), B20 = (x0 - x2);
    int A01 = -(y1 - y0), B01 = (x1 - x0);

    int e0_row = (x2 - x1) * (miny - y1) - (y2 - y1) * (minx - x1);
    int e1_row = (x0 - x2) * (miny - y2) - (y0 - y2) * (minx - x2);
    int e2_row = (x1 - x0) * (miny - y0) - (y1 - y0) * (minx - x0);

    int v0r = vv0->r, v0g = vv0->g, v0b = vv0->b;
    int v1r = vv1->r, v1g = vv1->g, v1b = vv1->b;
    int v2r = vv2->r, v2g = vv2->g, v2b = vv2->b;

    for (int y = miny; y <= maxy; y++) {
        int e0 = e0_row, e1 = e1_row, e2 = e2_row;
        u8 *row = fb + (origin_y + y) * STRIDE + origin_x * 3;
        int8_t *zrow = zbuf + y * panel_w;
        for (int x = minx; x <= maxx; x++) {
            /* area2 已正, 无需再乘 sign */
            if ((e0 | e1 | e2) >= 0) {
                /* Q8.8 barycentric: b = e * inv_q24 >> 16. e 最大 ~640*640 ≤ 19 bits;
                 * inv_q24 ≤ 24 bits → 乘积 43 bits, 32-bit signed 会溢出.
                 * 用 long long 一次. */
                int b0 = (int)(((long long)e0 * inv_q24) >> 16);
                int b1 = (int)(((long long)e1 * inv_q24) >> 16);
                int b2 = 256 - b0 - b1;
                int z = (b0 * z0 + b1 * z1 + b2 * z2) >> 8;
                int8_t zv = (int8_t)sat_int8(z);
                if (zv > zrow[x]) {
                    zrow[x] = zv;
                    int r  = (b0 * v0r + b1 * v1r + b2 * v2r) >> 8;
                    int g_ = (b0 * v0g + b1 * v1g + b2 * v2g) >> 8;
                    int b_ = (b0 * v0b + b1 * v1b + b2 * v2b) >> 8;
                    if (r > 255) r = 255; else if (r < 0) r = 0;
                    if (g_ > 255) g_ = 255; else if (g_ < 0) g_ = 0;
                    if (b_ > 255) b_ = 255; else if (b_ < 0) b_ = 0;
                    u8 *p = row + x * 3;
                    /* GBR byte order on this BD */
                    p[0] = (u8)g_;
                    p[1] = (u8)b_;
                    p[2] = (u8)r;
                }
            }
            e0 += A12;
            e1 += A20;
            e2 += A01;
        }
        e0_row += B12;
        e1_row += B20;
        e2_row += B01;
    }
}

static void cpu_render_mesh(UINTPTR fb_base, int angle_deg,
                            int origin_x, int origin_y,
                            int panel_w, int panel_h, int scale_pct)
{
    if (angle_deg < 0) angle_deg = 0;
    if (angle_deg >= 360) angle_deg %= 360;
    int16_t c = cos360_table[angle_deg];
    int16_t s = sin360_table[angle_deg];
    int cx = panel_w / 2;
    int cy = panel_h / 2;
    u8 *fb = (u8 *)fb_base;

    /* 1) clear panel 灰底 80 + zbuf -127 */
    for (int yy = 0; yy < panel_h; yy++) {
        memset(fb + (origin_y + yy) * STRIDE + origin_x * 3, 80, panel_w * 3);
        memset(mesh_zbuf + yy * panel_w, -127, panel_w);
        if ((yy & 0x0F) == 0) uart_poll_frame();
    }

    /* 2) rotate + project all verts.
     * Vertex Q8.4 (mx = host coord * 16). Cos/sin Q8.8 (c ≈ 256).
     * rx_q4 = (mx * c + mz * s) >> 8 → 仍是 Q8.4. */
    for (u32 i = 0; i < mesh_n_verts; i++) {
        int mx = mesh_verts[i].x;   /* Q8.4 */
        int my = mesh_verts[i].y;
        int mz = mesh_verts[i].z;
        int rx = (mx * c + mz * s) >> 8;     /* Q8.4 */
        int rz = (-mx * s + mz * c) >> 8;
        /* Camera tilt 15° down (Q8.8: cos≈247, sin≈66) */
        int tilt_y = (my * 247 - rz * 66) >> 8;  /* Q8.4 */
        /* Project: sx = cx + rx * scale_pct / 100. rx 是 Q8.4 (即 model*16),
         * 我们想要 sx = cx + (rx_model * scale_pct / 100) px. 转换:
         *   sx = cx + (rx_q4 * scale_pct) / (100*16) = cx + (rx_q4*scale_pct)>>4 / 100 */
        int sx = cx + (rx * scale_pct) / (100 * 16);
        int sy = cy - (tilt_y * scale_pct) / (100 * 16);
        /* z 保持 model unit (用 Q8.4 / 16 → int 范围 ±2047, 缩到 int8 ±127 用 /16) */
        rz = rz >> 4;
        mesh_screen_verts[i].sx = (int16_t)sx;
        mesh_screen_verts[i].sy = (int16_t)sy;
        mesh_screen_verts[i].sz = (int8_t)sat_int8(rz);
        mesh_screen_verts[i].r  = mesh_verts[i].r;
        mesh_screen_verts[i].g  = mesh_verts[i].g;
        mesh_screen_verts[i].b  = mesh_verts[i].b;
    }

    /* 3) rasterize each triangle */
    for (u32 t = 0; t < mesh_n_tris; t++) {
        u16 i0 = mesh_tris[t].i0;
        u16 i1 = mesh_tris[t].i1;
        u16 i2 = mesh_tris[t].i2;
        if (i0 >= mesh_n_verts || i1 >= mesh_n_verts || i2 >= mesh_n_verts) continue;
        rasterize_tri(fb, origin_x, origin_y, panel_w, panel_h,
                      &mesh_screen_verts[i0],
                      &mesh_screen_verts[i1],
                      &mesh_screen_verts[i2],
                      mesh_zbuf);
        if ((t & 0x3F) == 0) uart_poll_frame();
    }
}

int main(void)
{
    init_platform();
    /* PS UART0 baud is set by tools/dl_helloworld.tcl post-ps7_init mwr
     * (BAUDGEN=0x1B=27 BAUDDIV=3 → 921600 @ 100 MHz UART_REF_CLK, 0.5% err). */
    xil_printf("\r\n=== POV-3D Render Phase 4b (USE_PL=%d) baud=921600 ===\r\n", USE_PL);

    XGpio Led;
    XGpio_Initialize(&Led, XPAR_AXI_GPIO_0_BASEADDR);
    XGpio_SetDataDirection(&Led, 1, 0x0);
    XGpio_DiscreteWrite(&Led, 1, 0x3);

    XVtc Vtc;
    XVtc_Config *vtcCfg = XVtc_LookupConfig(XPAR_V_TC_0_BASEADDR);
    XVtc_CfgInitialize(&Vtc, vtcCfg, vtcCfg->BaseAddress);
#ifdef USE_1080P30
    /* 1080p30 timing (CTA-861, 74.25 MHz pixel clock — same as 720p60).
     * 2200 × 1125 = 2,475,000 pixels/frame × 30 = 74.25 MHz ✓ */
    XVtc_Timing t = {
        .HActiveVideo  = 1920, .HFrontPorch   = 88,
        .HSyncWidth    = 44,   .HBackPorch    = 148,
        .HSyncPolarity = 1,
        .VActiveVideo  = 1080,
        .V0FrontPorch  = 4,    .V0SyncWidth   = 5,    .V0BackPorch  = 36,
        .V1FrontPorch  = 4,    .V1SyncWidth   = 5,    .V1BackPorch  = 36,
        .VSyncPolarity = 1,    .Interlaced    = 0,
    };
    XVtc_SetGeneratorTiming(&Vtc, &t);
#else
    XVtc_SetGeneratorVideoMode(&Vtc, XVTC_VMODE_720P);
#endif
    XVtc_EnableGenerator(&Vtc);
    XVtc_Enable(&Vtc);

    XAxiVdma Vdma;
    XAxiVdma_Config *vdmaCfg = XAxiVdma_LookupConfig(XPAR_AXI_VDMA_0_BASEADDR);
    XAxiVdma_CfgInitialize(&Vdma, vdmaCfg, vdmaCfg->BaseAddress);
    /* VDMA init per Digilent Zybo-Z7-HDMI reference (display_ctrl.c):
     *   1) EnableCircularBuf = 1
     *   2) XAxiVdma_DmaConfig
     *   3) XAxiVdma_DmaSetBufferAddr (all N framestores)
     *   4) XAxiVdma_DmaStart  — start FIRST
     *   5) XAxiVdma_StartParking on initial frame — park SECOND
     * Swap is another call to StartParking with the new index.
     * Wrong order (park before start) causes HDMI black (seen 2026-04-23). */
    XAxiVdma_DmaSetup setup = {0};
    setup.VertSizeInput = HEIGHT;
    setup.HoriSizeInput = STRIDE;
    setup.Stride        = STRIDE;
    setup.EnableCircularBuf = 1;
    setup.FixedFrameStoreAddr = 0;
    XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_READ, &setup);
    UINTPTR fbs[2] = { FB_A_ADDR, FB_B_ADDR };
    XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_READ, fbs);
    XAxiVdma_DmaStart(&Vdma, XAXIVDMA_READ);
    /* Stay in circular mode (no StartParking). VDMA auto-cycles through
     * fbs[0]→fbs[1]→fbs[0]... at vsync. ARM polls curR to vsync-lock writes. */
    xil_printf("VDMA DMACR=0x%x PARK_PTR=0x%x (pure circular)\r\n",
               (unsigned)vdma_dmacr(),
               (unsigned)Xil_In32(VDMA_BASE + VDMA_PARK_PTR_OFF));

    /* Clear BOTH framebuffers at boot so VDMA starts on known black. */
    memset((void *)FB_A_ADDR, 0, FRAME_BYTES);
    memset((void *)FB_B_ADDR, 0, FRAME_BYTES);
    Xil_DCacheFlush();

    /* DEBUG: 移除 MMU non-cacheable 配置, 验证 PL m_axi 是否还工作 */

    build_model();
    /* Model lives in DDR; flush once so IP sees it via HP1 (not cache-coherent) */
    Xil_DCacheFlushRange(MODEL_ADDR, MAX_POINTS * sizeof(PovPoint));
    /* Voxelize boot-time cube model so render path has valid data before
     * any PPCL frame arrives. */
    voxelize_model();
    xil_printf("Voxel grid: %d/%d cells occupied\r\n",
               voxel_n_occupied, VOXEL_RES*VOXEL_RES*VOXEL_RES);

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
    /* gt_anchor: 旋转角的起点参考, 只设一次. gt0 每 32 帧会被
     * 重置为最新时间用于 FPS 计算, 不能拿来当旋转参考. */
    u64 gt_anchor = gt0;
    XTime t0, t1;
    XTime_GetTime(&t0);
    xil_printf("Global Timer initial: 0x%08x%08x (after enable)\r\n",
               (u32)(gt0 >> 32), (u32)gt0);
    u32 frame = 0;
    u32 phase = 0;

    u32 stream_frames = 0;
    UINTPTR fb_bufs[2] = { FB_A_ADDR, FB_B_ADDR };
    u32 write_idx = 1;   /* VDMA reads 0 first, we write to 1 */
    /* right_dirty_g 是全局 volatile, 由 uart_poll_frame 内部置 1 (避免嵌套调用丢事件) */
    /* 渲染耗时统计 (256 帧窗口): max + sum→avg. >16.6ms 意味着撕裂不可避免 (circular VDMA). */
    u32 render_us_max  = 0;
    u64 render_us_sum  = 0;
    u32 render_count   = 0;

    while (1) {
        int got_frame = uart_poll_frame();
        if (got_frame) {
            stream_frames++;
            /* Verify ARM wrote the new model to DDR + first byte reads back */
            Xil_DCacheInvalidateRange(MODEL_ADDR, 16);
            volatile u8 *mbyte = (volatile u8 *)MODEL_ADDR;
            xil_printf("[rx] stream_frame=%u model_n=%d p0={x=%d y=%d z=%d rgb=%u,%u,%u}\r\n",
                       (unsigned)stream_frames, model_n,
                       (int16_t)((mbyte[1] << 8) | mbyte[0]),
                       (int16_t)((mbyte[3] << 8) | mbyte[2]),
                       (int16_t)((mbyte[5] << 8) | mbyte[4]),
                       mbyte[8], mbyte[9], mbyte[10]);
        }

        UINTPTR fb_write = fb_bufs[write_idx];

#if USE_PL
        /* No pre-clear needed: we full-blit from ring buffer below, covers entire grid. */
#endif
#if USE_PL
        /* PL render 只在收到大数据集后启动. boot 时 model_n=315 (cube),
         * anime 是 30K → 用 model_n > 1000 区分. 持续 PL render 会
         * 干扰 UART (RX FIFO 64B, 32MB voxelize_model memset 阻塞 200ms),
         * 让 ARM boot 阶段全心处理 UART, anime 接收完成 model_n 跳到
         * 30K 后 PL 启动. */
        /* Plain USE_PL=1: always PL render (regression test 看 PL m_axi 是否还工作) */
        pov_render_frame_to_ring(phase);
        if ((frame % 3) == 0) {
            Xil_DCacheInvalidateRange(RING_BUFFER_ADDR, N_SLOTS * SLOT_BYTES);
            for (int s = 0; s < N_SLOTS; s++) {
                u32 col = s % GRID_COLS;
                u32 row = s / GRID_COLS;
                u32 x0 = col * SLICE_W;
                u32 y0 = row * SLICE_H;
                const u8 *src = (const u8 *)(RING_BUFFER_ADDR + s * SLOT_BYTES);
                u8 *dst = (u8 *)fb_write + y0 * STRIDE + x0 * 3;
                for (int yy = 0; yy < SLICE_H; yy++) {
                    memcpy(dst + yy * STRIDE, src + yy * (SLICE_W * 3), SLICE_W * 3);
                }
            }
            Xil_DCacheFlushRange(fb_write, FRAME_BYTES);
            /* DEBUG: ring nonzero */
            static u32 vd = 0;
            if ((vd++ & 0x3F) == 0) {
                volatile u8 *r = (volatile u8 *)RING_BUFFER_ADDR;
                u32 nz = 0;
                for (u32 b = 0; b < 100000; b++) if (r[b]) nz++;
                xil_printf("[ringV] nz=%u/100K [0..3]=%02x%02x%02x%02x\r\n",
                           (unsigned)nz, r[0],r[1],r[2],r[3]);
            }
        }
#else
        /* Layout:
         *   LEFT 640×720: full 3D projection rotating 10s/cycle (每帧重画).
         *   RIGHT 640×720: 2×2 = 4 切片 cell, 静态 (only on new pointcloud).
         * Right grid 按需渲染: 收到新点云时同时写 fb_A + fb_B 一次, 平时
         * 主循环只画 LEFT, 让 ARM 跑到 60 FPS 不与 VDMA vsync 冲突. */
        {
            const int PW = WIDTH / 2;
            const int PH = HEIGHT;
            const int LEFT_SCALE = 400;

            /* (1) 右侧 grid: 仅 dirty 时一次性写两个 fb. 4×6 = 24 cells,
             * 每 15°/cell 覆盖 360° (POV 切片预览, cell 大小适中能看细节). */
            if (right_dirty_g) {
                right_dirty_g = 0;
                u64 rt0 = gt_read();
                const int GCOLS = 4;
                const int GROWS = 6;
                const int CW = PW / GCOLS;        /* 160 */
                const int CH = PH / GROWS;        /* 120 */
                const int CELL_SCALE = 130;       /* 模型 ±54 → 屏幕 ±70 px, 占 cell 一半多 */
                for (int fbi = 0; fbi < 2; fbi++) {
                    UINTPTR addr = fb_bufs[fbi];
                    for (int gi = 0; gi < GCOLS * GROWS; gi++) {
                        int gc = gi % GCOLS;
                        int gr = gi / GCOLS;
                        int ox = PW + gc * CW;
                        int oy = gr * CH;
                        int ang = (gi * 15) % 360;
                        cpu_render_voxel_panel(addr, ang, ox, oy, CW, CH, 1, CELL_SCALE);
                    }
                    /* flush 右半侧 cache */
                    for (int yy = 0; yy < HEIGHT; yy++) {
                        Xil_DCacheFlushRange(addr + yy * STRIDE + PW * BPP, PW * BPP);
                        if ((yy & 0x1F) == 0) uart_poll_frame();
                    }
                    /* 同时清 LEFT 半屏到灰底, 杜绝 boot cube wireframe 残留在
                     * 非当前 write_idx 的 fb 上, VDMA 交替读两块 fb 看到 cube/anime 闪烁. */
                    for (int yy = 0; yy < HEIGHT; yy++) {
                        memset((u8 *)addr + yy * STRIDE, 80, PW * BPP);
                        if ((yy & 0x1F) == 0) uart_poll_frame();
                    }
                    for (int yy = 0; yy < HEIGHT; yy++) {
                        Xil_DCacheFlushRange(addr + yy * STRIDE, PW * BPP);
                        if ((yy & 0x1F) == 0) uart_poll_frame();
                    }
                }
                u64 rt1 = gt_read();
                u32 rt_us = (u32)((rt1 - rt0) / GT_TICKS_PER_US);
                xil_printf("[right] 24 cells x 2 fb done, voxel_n=%d, dt=%u us (%u ms)\r\n",
                           voxel_n_occupied, rt_us, rt_us / 1000);
            }

            /* (2) LEFT 全投影旋转, 每帧重画 */
            u64 now = gt_read();
            u64 us  = (now - gt_anchor) / GT_TICKS_PER_US;
            /* 72°/sec → 5 秒一圈完整 360° (旋转更明显) */
            int left_angle = (int)((us * 72ULL / 1000000ULL) % 360ULL);
            uart_poll_frame();
            u64 rt0 = gt_read();
            if (mesh_ready) {
                /* mesh path: software triangle rasterizer + z-buffer */
                cpu_render_mesh(fb_write, left_angle, 0, 0, PW, PH, LEFT_SCALE);
            } else {
                cpu_render_voxel_panel(fb_write, left_angle, 0, 0, PW, PH, 0, LEFT_SCALE);
            }
#if !USE_PL
            /* Cache flush 仅 LEFT 半屏 (右侧由 dirty 路径自管). 1.38 MB / 帧. */
            {
                const u32 LEFT_W_BYTES = (WIDTH / 2) * BPP;
                for (int yy = 0; yy < HEIGHT; yy++) {
                    Xil_DCacheFlushRange(fb_write + yy * STRIDE, LEFT_W_BYTES);
                    if ((yy & 0x1F) == 0) uart_poll_frame();
                }
            }
#endif
            u64 rt1 = gt_read();
            u32 rt_us = (u32)((rt1 - rt0) / GT_TICKS_PER_US);
            if (rt_us > render_us_max) render_us_max = rt_us;
            render_us_sum += rt_us;
            render_count++;
        }
#endif

        /* Pure circular VDMA: auto-cycles fbs[0] ↔ fbs[1] at vsync.
         * 撕裂修复: 等 VDMA 翻到我们刚写的 buffer (write_idx), 然后下一轮
         * 写另一块. 这样保证 ARM 永远写的是 VDMA "不在读" 的 buffer.
         * 当 render <16.6ms 时与原 ^=1 等价; render >16.6ms 时仍可能撕裂
         * (单帧内 vsync 翻到我们半成品 fb), 但避免了 race 后选错 buffer. */
        u32 target = write_idx;
        for (u32 wait = 0; wait < 600000; wait++) {
            if (vdma_current_read_idx() == target) break;
            if ((wait & 0xFF) == 0) uart_poll_frame();
        }
        /* 直接按当前 cur 选下一块: 1 - cur 永远是 VDMA 不在读的那块.
         * 即使 wait 超时 cur 卡住, 1-cur 仍是合法选择 (写入未被读的 buffer). */
        write_idx = 1 - vdma_current_read_idx();

        frame++;
        /* Slow rotation: advance phase only every 3 frames. */
        if ((frame % 3) == 0) phase++;

        /* Telemetry every 32 frames (was prior cadence) created sustained
         * UART TX bursts that block the CPU in xil_printf, causing RX FIFO
         * overflow during host stream upload. Throttle to every 256 frames
         * (~2.8 sec at 91 FPS) and skip the VDMA + ring_verify lines unless
         * specifically debugging. */
        if ((frame & 0xFF) == 0) {
            XTime_GetTime(&t1);
            gt1 = gt_read();
            u64 gt_dt = gt1 - gt0;
            u32 us = (u32)(gt_dt / GT_TICKS_PER_US);
            u32 ms = us / 1000;
            u32 fps100 = ms ? (u32)((256ULL * 100 * 1000) / ms) : 0;
            u32 r_avg = render_count ? (u32)(render_us_sum / render_count) : 0;
            xil_printf("frame=%u dT=%u us (%u.%02u FPS)  render avg=%u us max=%u us\r\n",
                       (unsigned)frame, us,
                       fps100 / 100, fps100 % 100,
                       r_avg, render_us_max);
            render_us_max = 0;
            render_us_sum = 0;
            render_count  = 0;
            gt0 = gt1;
            t0 = t1;
            XGpio_DiscreteWrite(&Led, 1, (frame >> 5) & 1 ? 0x1 : 0x2);
        }
    }
    return 0;
}
