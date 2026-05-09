/* dual_core.h — Phase 9.5 task I: Zynq AMP, CPU1 takes LEFT panel render.
 *
 * Layout:
 *   - CPU0 main loop: VDMA / UART / RIGHT panel mesh_slice (24 cell, dirty)
 *   - CPU1 worker loop: LEFT panel mesh render (cpu_render_mesh)
 *
 * Synchronization (single-producer/single-consumer):
 *   CPU0 writes core1_left_cmd (angle + fb_addr) → DMB → core1_left_busy=1
 *   CPU1 polls core1_left_busy → renders LEFT half → flushes dcache range
 *   CPU1 sets core1_left_busy=0 → DSB
 *   CPU0 polls core1_left_busy → continues
 *
 * Sync region lives at SHARED_FLAG_BASE in DDR, marked NORM_NONCACHE on CPU0
 * (CPU1 inherits same MMU table → same attributes after CPU1 invalidates TLB).
 *
 * CPU1 boot: see dual_core.c → core1_start(). Path is XAPP1078:
 *   1) Place jump address at 0xFFFFFFF0 (OCM trampoline target)
 *   2) Release CPU1 reset via SLCR.A9_CPU_RST_CTRL (0xF8000244 bit 1)
 *   3) SEV to wake from WFE
 *
 * Hardware: Zynq 7020 dual-A9. EFUSE indicates dual-core.
 */
#ifndef DUAL_CORE_H
#define DUAL_CORE_H

#include "xil_types.h"
#include "xil_io.h"

#ifdef __cplusplus
extern "C" {
#endif

/* SLCR (System-Level Control) registers */
#define SLCR_BASE              0xF8000000UL
#define SLCR_UNLOCK            (SLCR_BASE + 0x008)  /* key 0xDF0D */
#define SLCR_LOCK              (SLCR_BASE + 0x004)  /* key 0x767B */
#define SLCR_A9_CPU_RST_CTRL   (SLCR_BASE + 0x244)  /* CPU reset bits */
#define SLCR_UNLOCK_KEY        0xDF0DUL
#define SLCR_LOCK_KEY          0x767BUL

/* CPU1 boot trampoline address (Zynq-specific OCM cell) */
#define CPU1_BOOT_TRAMPOLINE_ADDR  0xFFFFFFF0UL

/* Shared flag region in DDR (1 MB section, made non-cacheable on CPU0).
 * Lives outside model/fb/ring layout. Sits at high DDR end safely. */
#define SHARED_FLAG_BASE       0x1FF00000UL  /* last 1MB before DDR end @0x20000000 */

/* Layout of shared region (offsets from SHARED_FLAG_BASE) */
#define OFF_LEFT_BUSY          0x00   /* u32: 1=cmd posted, 0=cpu1 done */
#define OFF_LEFT_FB            0x04   /* u32: framebuffer base address */
#define OFF_LEFT_ANGLE         0x08   /* u32: angle_deg [0..359] */
#define OFF_LEFT_PW            0x0C   /* u32: panel width  (640) */
#define OFF_LEFT_PH            0x10   /* u32: panel height (720) */
#define OFF_LEFT_SCALE         0x14   /* u32: scale_pct */
#define OFF_LEFT_USE_MESH      0x18   /* u32: 1=mesh path, 0=voxel path */
#define OFF_CORE1_ALIVE        0x20   /* u32: heartbeat counter (cpu1 increments) */
#define OFF_CORE1_FRAME_COUNT  0x24   /* u32: frames rendered by cpu1 */
#define OFF_CORE1_LAST_US      0x28   /* u32: last render duration */
#define OFF_CORE1_BOOT_OK      0x2C   /* u32: 0xC0DE_AB1E once cpu1 reaches loop */
#define OFF_KICK_REQ_ID        0x30   /* u32: producer (cpu0) increments */
#define OFF_KICK_DONE_ID       0x34   /* u32: consumer (cpu1) sets = req id */

#define CORE1_BOOT_OK_MAGIC    0xC0DEAB1EUL

/* Accessors — always go through Xil_In32/Xil_Out32 to avoid compiler caching */
static inline u32 dc_load(u32 off)
{
    return Xil_In32(SHARED_FLAG_BASE + off);
}
static inline void dc_store(u32 off, u32 v)
{
    Xil_Out32(SHARED_FLAG_BASE + off, v);
}

/* Public API */

/* CPU0: bring up CPU1. Returns 0 if OK, -1 if CPU1 didn't reach main within
 * timeout (~50ms). After return, CPU1 is in idle wait loop. */
int core1_start(void);

/* CPU0: post LEFT-render command, returns immediately.
 * fb_addr / angle / etc. + atomic kick. */
void core1_kick_left(u32 fb_addr, u32 angle, u32 panel_w, u32 panel_h,
                     u32 scale_pct, u32 use_mesh);

/* CPU0: spin until CPU1 reports done. Returns wait time in us (approx). */
u32 core1_wait_left(void);

/* CPU0: query if CPU1 reports it has booted */
int core1_is_alive(void);

/* CPU1 entry point — implemented in dual_core.c, called from boot stub */
void core1_main(void) __attribute__((noreturn));

#ifdef __cplusplus
}
#endif
#endif /* DUAL_CORE_H */
