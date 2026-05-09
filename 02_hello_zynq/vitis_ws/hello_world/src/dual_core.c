/* dual_core.c — Phase 9.5 task I.
 *
 * CPU0 helpers + CPU1 worker loop. See dual_core.h for design notes.
 */
#include "dual_core.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xil_mmu.h"
#include "xil_printf.h"
#include "xpseudo_asm.h"
#include "sleep.h"

extern void core1_asm_entry(void);

/* ----- Forward declarations of host-render helpers from helloworld.c ----- */
extern volatile int  mesh_ready;
extern void cpu_render_mesh(UINTPTR fb_base, int angle_deg,
                            int origin_x, int origin_y,
                            int panel_w, int panel_h, int scale_pct);
extern void cpu_render_voxel_panel(UINTPTR fb_base, int angle_deg,
                                   int origin_x, int origin_y,
                                   int panel_w, int panel_h,
                                   int slice_mode, int scale_pct);

/* WIDTH/STRIDE/BPP from helloworld.c — re-declare locally to avoid full include */
#ifndef BPP
#define BPP    3
#endif
#ifndef WIDTH
#define WIDTH  1280
#endif
#ifndef HEIGHT
#define HEIGHT 720
#endif
#define STRIDE_LOCAL  (WIDTH * BPP)

/* ----- Global Timer (shared between cores) -----
 * GT @ 0xF8F00200 is shared (same physical block). Both cores read the
 * same counter. CPU1 doesn't need to enable — CPU0 already did. */
#define GT_BASE         0xF8F00200UL
#define GT_TICKS_PER_US_LOCAL  333  /* 333.33 MHz → 333 ticks/us approximate */

static u64 dc_gt_read(void)
{
    u32 lo, hi, hi2;
    do {
        hi  = Xil_In32(GT_BASE + 0x04);
        lo  = Xil_In32(GT_BASE + 0x00);
        hi2 = Xil_In32(GT_BASE + 0x04);
    } while (hi != hi2);
    return ((u64)hi << 32) | lo;
}

/* ============================================================
 *                        CPU0 SIDE
 * ============================================================ */

/* Mark the SHARED_FLAG_BASE 1MB section as Normal Non-cacheable on CPU0
 * MMU table.  CPU1 inherits the same MMU table — but we invalidate its
 * TLBs in core1_asm_entry, so it'll re-fetch this entry. */
static void core0_setup_shared_region(void)
{
    /* Xil_SetTlbAttributes operates on 1MB sections; address must be 1MB-aligned.
     * SHARED_FLAG_BASE = 0x1FF00000 — already aligned. */
    Xil_SetTlbAttributes(SHARED_FLAG_BASE, NORM_NONCACHE);
    /* Ensure visibility */
    dsb();
    isb();
}

/* Sanity check: read EFUSE to confirm dual-core part. */
static int core0_efuse_is_dual_core(void)
{
    u32 efuse = Xil_In32(0xF800D010);
    /* bit 7 set => single-core variant */
    return ((efuse & 0x80) == 0) ? 1 : 0;
}

int core1_start(void)
{
    if (!core0_efuse_is_dual_core()) {
        xil_printf("[dual_core] EFUSE: single-core part, abort.\r\n");
        return -1;
    }

    /* Zero shared region */
    for (u32 off = 0; off < 0x100; off += 4) dc_store(off, 0);

    /* Mark non-cacheable so flag updates are visible without explicit flush */
    core0_setup_shared_region();

    xil_printf("[dual_core] cpu1 entry = 0x%x\r\n",
               (unsigned)(uintptr_t)&core1_asm_entry);

    /* Step 1: write CPU1 entry into BootROM trampoline cell. */
    Xil_Out32(CPU1_BOOT_TRAMPOLINE_ADDR, (u32)(uintptr_t)&core1_asm_entry);
    /* Force the value out of cache (OCM normally uncached, but be safe). */
    Xil_DCacheFlushRange(CPU1_BOOT_TRAMPOLINE_ADDR & ~0x3FUL, 64);
    dsb();

    /* Step 2: release CPU1 reset via SLCR.A9_CPU_RST_CTRL.
     * Layout (UG585 Table B.32):
     *   bit 0: A9_RST0       (CPU0 reset, leave alone!)
     *   bit 1: A9_RST1       (CPU1 reset — clear to release)
     *   bit 4: A9_CLKSTOP0
     *   bit 5: A9_CLKSTOP1   (clear to start clock to CPU1)
     *   bit 8: PERI_RST      (peripheral reset)
     */
    Xil_Out32(SLCR_UNLOCK, SLCR_UNLOCK_KEY);

    u32 rst = Xil_In32(SLCR_A9_CPU_RST_CTRL);
    xil_printf("[dual_core] SLCR.A9_CPU_RST_CTRL pre  = 0x%08x\r\n", (unsigned)rst);

    /* First de-assert clock-stop (bit 5) */
    rst &= ~(1u << 5);
    Xil_Out32(SLCR_A9_CPU_RST_CTRL, rst);
    /* Then de-assert reset (bit 1) */
    rst &= ~(1u << 1);
    Xil_Out32(SLCR_A9_CPU_RST_CTRL, rst);

    rst = Xil_In32(SLCR_A9_CPU_RST_CTRL);
    xil_printf("[dual_core] SLCR.A9_CPU_RST_CTRL post = 0x%08x\r\n", (unsigned)rst);

    Xil_Out32(SLCR_LOCK, SLCR_LOCK_KEY);

    /* Step 3: SEV — wake CPU1 from any WFE state (and act as memory barrier
     * for the BootROM polling loop on 0xFFFFFFF0). */
    dsb();
    __asm__ __volatile__("sev");

    /* Step 4: poll CORE1_BOOT_OK_MAGIC with timeout (~50ms). */
    u64 t0 = dc_gt_read();
    while (1) {
        u32 v = dc_load(OFF_CORE1_BOOT_OK);
        if (v == CORE1_BOOT_OK_MAGIC) break;
        u64 t1 = dc_gt_read();
        u32 us = (u32)((t1 - t0) / GT_TICKS_PER_US_LOCAL);
        if (us > 50000) {
            xil_printf("[dual_core] cpu1 boot TIMEOUT (us=%u, OK=0x%x)\r\n",
                       (unsigned)us, (unsigned)v);
            return -1;
        }
    }

    u32 us = (u32)((dc_gt_read() - t0) / GT_TICKS_PER_US_LOCAL);
    xil_printf("[dual_core] cpu1 boot OK in %u us, alive=%u\r\n",
               (unsigned)us, (unsigned)dc_load(OFF_CORE1_ALIVE));
    return 0;
}

void core1_kick_left(u32 fb_addr, u32 angle, u32 panel_w, u32 panel_h,
                     u32 scale_pct, u32 use_mesh)
{
    /* Write parameters first, then the kick id last.  Use store ordering
     * via dmb between params and id. */
    dc_store(OFF_LEFT_FB,       fb_addr);
    dc_store(OFF_LEFT_ANGLE,    angle);
    dc_store(OFF_LEFT_PW,       panel_w);
    dc_store(OFF_LEFT_PH,       panel_h);
    dc_store(OFF_LEFT_SCALE,    scale_pct);
    dc_store(OFF_LEFT_USE_MESH, use_mesh);
    dmb();

    u32 req = dc_load(OFF_KICK_REQ_ID) + 1;
    dc_store(OFF_LEFT_BUSY, 1);
    dc_store(OFF_KICK_REQ_ID, req);
    dsb();
    /* SEV in case CPU1 is in WFE */
    __asm__ __volatile__("sev");
}

u32 core1_wait_left(void)
{
    u64 t0 = dc_gt_read();
    while (dc_load(OFF_LEFT_BUSY) != 0) {
        /* tight poll — could WFE here but CPU0 already busy */
    }
    u64 t1 = dc_gt_read();
    return (u32)((t1 - t0) / GT_TICKS_PER_US_LOCAL);
}

int core1_is_alive(void)
{
    return (dc_load(OFF_CORE1_BOOT_OK) == CORE1_BOOT_OK_MAGIC);
}

/* ============================================================
 *                        CPU1 SIDE
 * ============================================================ */

/* Note: CPU1 cannot safely call xil_printf — UART driver state is owned by
 * CPU0 and not multi-thread-safe.  We only signal status via shared flags. */

void core1_main(void)
{
    /* Announce we're alive */
    dc_store(OFF_CORE1_ALIVE, 1);
    dc_store(OFF_CORE1_BOOT_OK, CORE1_BOOT_OK_MAGIC);
    dsb();

    u32 last_req = 0;
    u32 frames = 0;

    while (1) {
        /* Spin until kick id changes */
        u32 req = dc_load(OFF_KICK_REQ_ID);
        while (req == last_req) {
            /* WFE — but harmless if no event arrives, then poll again */
            __asm__ __volatile__("wfe");
            req = dc_load(OFF_KICK_REQ_ID);
        }
        last_req = req;
        dmb();

        /* Read parameters */
        UINTPTR fb_addr  = (UINTPTR)dc_load(OFF_LEFT_FB);
        int angle        = (int)   dc_load(OFF_LEFT_ANGLE);
        int panel_w      = (int)   dc_load(OFF_LEFT_PW);
        int panel_h      = (int)   dc_load(OFF_LEFT_PH);
        int scale_pct    = (int)   dc_load(OFF_LEFT_SCALE);
        int use_mesh     = (int)   dc_load(OFF_LEFT_USE_MESH);

        u64 t0 = dc_gt_read();

        if (use_mesh && mesh_ready) {
            cpu_render_mesh(fb_addr, angle, 0, 0, panel_w, panel_h, scale_pct);
        } else {
            cpu_render_voxel_panel(fb_addr, angle, 0, 0,
                                   panel_w, panel_h, 0, scale_pct);
        }

        /* Flush LEFT half so VDMA reads our writes (DDR not coherent). */
        const u32 LEFT_W_BYTES = (u32)(panel_w * BPP);
        for (int yy = 0; yy < panel_h; yy++) {
            Xil_DCacheFlushRange(fb_addr + (UINTPTR)yy * STRIDE_LOCAL,
                                 LEFT_W_BYTES);
        }
        dsb();

        u64 t1 = dc_gt_read();
        u32 us = (u32)((t1 - t0) / GT_TICKS_PER_US_LOCAL);
        dc_store(OFF_CORE1_LAST_US, us);
        frames++;
        dc_store(OFF_CORE1_FRAME_COUNT, frames);
        dc_store(OFF_CORE1_ALIVE, dc_load(OFF_CORE1_ALIVE) + 1);

        /* Mark done */
        dsb();
        dc_store(OFF_LEFT_BUSY, 0);
        dc_store(OFF_KICK_DONE_ID, req);
        dsb();
        __asm__ __volatile__("sev");
    }
}
