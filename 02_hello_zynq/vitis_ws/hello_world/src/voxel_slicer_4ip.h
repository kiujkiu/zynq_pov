/* voxel_slicer_4ip.h — coordinate 4× pov_voxel_slice_batch HLS IPs in parallel.
 *
 * Use after Vivado integrates 4 IPs (see tools/bd_4ip_voxel_slicer.tcl).
 *
 * Each IP renders 18 of 72 slots (slot_start = 0/18/36/54). All 4 IPs share
 * voxel grid via HP1 Smartconnect, all write to ring buffer via HP2.
 *
 * Usage in main render loop:
 *   pov4ip_fire_all(voxel_grid, ring_base, phase);
 *   pov4ip_wait_all();    // blocks until all 4 ap_done = 1
 */
#ifndef VOXEL_SLICER_4IP_H
#define VOXEL_SLICER_4IP_H

#include "xil_io.h"
#include "xparameters.h"

/* Replace these with actual XPAR_*_BASEADDR values from regenerated xparameters.h */
#define POV4IP_BASE_0  XPAR_POV_VOXEL_SLICE_BATCH_0_S_AXI_CONTROL_BASEADDR
#define POV4IP_BASE_1  XPAR_POV_VOXEL_SLICE_BATCH_1_S_AXI_CONTROL_BASEADDR
#define POV4IP_BASE_2  XPAR_POV_VOXEL_SLICE_BATCH_2_S_AXI_CONTROL_BASEADDR
#define POV4IP_BASE_3  XPAR_POV_VOXEL_SLICE_BATCH_3_S_AXI_CONTROL_BASEADDR

/* HLS-generated control register offsets (from xpov_voxel_slice_batch_hw.h).
 * Confirm post-synth — these are typical Vitis HLS layout. */
#define POV4IP_AP_CTRL          0x00  /* bit 0: ap_start, bit 1: ap_done, bit 2: ap_idle, bit 4: auto_restart */
#define POV4IP_VOXEL_GRID_LO    0x10
#define POV4IP_VOXEL_GRID_HI    0x14
#define POV4IP_RING_BASE_LO     0x1C
#define POV4IP_RING_BASE_HI     0x20
#define POV4IP_SLOT_BYTES       0x28
#define POV4IP_SLOT_STRIDE      0x30
#define POV4IP_PHASE            0x38
#define POV4IP_SLOT_START       0x40
#define POV4IP_N_SLOTS          0x48

#define POV4IP_AP_START_BIT     0x01
#define POV4IP_AP_DONE_BIT      0x02

static const u32 pov4ip_bases[4] = {
    POV4IP_BASE_0, POV4IP_BASE_1, POV4IP_BASE_2, POV4IP_BASE_3
};

static inline void pov4ip_set_args(int ip, u32 voxel_grid, u32 ring_base,
                                    u32 slot_bytes, u32 slot_stride,
                                    u32 phase, u32 slot_start, u32 n_slots)
{
    u32 b = pov4ip_bases[ip];
    Xil_Out32(b + POV4IP_VOXEL_GRID_LO, voxel_grid);
    Xil_Out32(b + POV4IP_VOXEL_GRID_HI, 0);
    Xil_Out32(b + POV4IP_RING_BASE_LO, ring_base);
    Xil_Out32(b + POV4IP_RING_BASE_HI, 0);
    Xil_Out32(b + POV4IP_SLOT_BYTES, slot_bytes);
    Xil_Out32(b + POV4IP_SLOT_STRIDE, slot_stride);
    Xil_Out32(b + POV4IP_PHASE, phase);
    Xil_Out32(b + POV4IP_SLOT_START, slot_start);
    Xil_Out32(b + POV4IP_N_SLOTS, n_slots);
}

static inline void pov4ip_start(int ip)
{
    u32 b = pov4ip_bases[ip];
    u32 v = Xil_In32(b + POV4IP_AP_CTRL);
    Xil_Out32(b + POV4IP_AP_CTRL, v | POV4IP_AP_START_BIT);
}

static inline u32 pov4ip_done(int ip)
{
    return Xil_In32(pov4ip_bases[ip] + POV4IP_AP_CTRL) & POV4IP_AP_DONE_BIT;
}

/* Fire all 4 IPs to render 72 slots (18 each). voxel_grid + ring_base in DDR. */
static inline void pov4ip_fire_all(u32 voxel_grid, u32 ring_base,
                                    u32 slot_bytes, u32 slot_stride, u32 phase)
{
    for (int ip = 0; ip < 4; ip++) {
        pov4ip_set_args(ip, voxel_grid, ring_base,
                        slot_bytes, slot_stride, phase,
                        ip * 18 /*slot_start*/, 18 /*n_slots*/);
        pov4ip_start(ip);
    }
}

/* Wait for all 4 IPs to finish. Returns 0 = ok, 1 = timeout. */
static inline int pov4ip_wait_all(u32 timeout_iters)
{
    for (u32 t = 0; t < timeout_iters; t++) {
        u32 done = 0;
        for (int ip = 0; ip < 4; ip++) {
            if (pov4ip_done(ip)) done++;
        }
        if (done == 4) return 0;
    }
    return 1;  /* timeout */
}

#endif
