/* pov_project_batch_4x.h — 4× pov_project_batch IP 并行渲染 driver
 *
 * IP: povlab:user:pov_project_batch:1.0 (Phase 4b 综合, BD 现 1× 实例)
 * 4× 集成: tools/bd_4x_pov_project_batch.tcl (待 LED 到再跑 Vivado)
 *
 * 寄存器映射跟 helloworld.c 现有 BATCH_* 对齐 (从 xpov_project_batch_hw.h 反推).
 * pov_project_batch IP 接口:
 *   model (gmem0) + num_points + ring_base (gmem1) + slot_bytes + slot_stride
 *   + phase + n_slots + slice_mode + slice_half_thick
 *
 * 4-IP 任务划分: 各 IP 跑 18/72 slot, 通过 phase 偏移 + ring_base 偏移
 *   IP0: phase=p+0,  ring_base=R + 0*18*SB, n_slots=18
 *   IP1: phase=p+18, ring_base=R + 1*18*SB, n_slots=18
 *   IP2: phase=p+36, ring_base=R + 2*18*SB, n_slots=18
 *   IP3: phase=p+54, ring_base=R + 3*18*SB, n_slots=18
 * (pov_project_batch 没 slot_start, 所以靠 phase + ring_base 偏移分工)
 */
#ifndef POV_PROJECT_BATCH_4X_H
#define POV_PROJECT_BATCH_4X_H

#include "xil_io.h"

/* PS GP0 地址映射, 各 IP 64KB 控制窗口. 实际值待 BD 跑完 assign_bd_address
 * 后从 xparameters.h XPAR_POV_PROJECT_BATCH_*_S_AXI_CONTROL_BASEADDR 取代. */
#define P4X_BASE_0  0x43C20000UL  /* XPAR_POV_PROJECT_BATCH_0_BASEADDR */
#define P4X_BASE_1  0x40000000UL  /* XPAR_POV_PROJECT_BATCH_1_BASEADDR */
#define P4X_BASE_2  0x40010000UL  /* XPAR_POV_PROJECT_BATCH_2_BASEADDR */
#define P4X_BASE_3  0x40020000UL  /* XPAR_POV_PROJECT_BATCH_3_BASEADDR */

/* HLS 寄存器布局 (跟 pov_project.cpp 中 #pragma s_axilite 顺序对齐) */
#define P4X_AP_CTRL          0x00
#define P4X_GIE              0x04
#define P4X_IER              0x08
#define P4X_ISR              0x0c
#define P4X_MODEL_LO         0x10
#define P4X_MODEL_HI         0x14
#define P4X_NUM_POINTS       0x1c
#define P4X_RING_LO          0x24
#define P4X_RING_HI          0x28
#define P4X_SLOT_BYTES       0x30
#define P4X_SLOT_STRIDE      0x38
#define P4X_PHASE            0x40
#define P4X_N_SLOTS          0x48
#define P4X_SLICE_MODE       0x50
#define P4X_SLICE_HALF       0x58

#define P4X_AP_START_BIT     0x01
#define P4X_AP_DONE_BIT      0x02
#define P4X_AP_IDLE_BIT      0x04

static const u32 p4x_bases[4] = { P4X_BASE_0, P4X_BASE_1, P4X_BASE_2, P4X_BASE_3 };

static inline void p4x_w(int ip, u32 off, u32 v) {
    Xil_Out32(p4x_bases[ip] + off, v);
}
static inline u32 p4x_r(int ip, u32 off) {
    return Xil_In32(p4x_bases[ip] + off);
}

/* Set 4 IPs to render NUM_SLICES slots, 18 each. Caller dcache-flushed model + ring. */
static inline void p4x_fire_all(u32 model, u32 num_points, u32 ring_base,
                                 u32 slot_bytes, u32 slot_stride, u32 phase,
                                 u32 n_total /* 72 */,
                                 u32 slice_mode, u32 slice_half_thick)
{
    u32 per_ip = n_total >> 2;            /* 72 / 4 = 18 */
    for (int ip = 0; ip < 4; ip++) {
        p4x_w(ip, P4X_MODEL_LO,    model);
        p4x_w(ip, P4X_MODEL_HI,    0);
        p4x_w(ip, P4X_NUM_POINTS,  num_points);
        p4x_w(ip, P4X_RING_LO,     ring_base + ip * per_ip * slot_bytes);
        p4x_w(ip, P4X_RING_HI,     0);
        p4x_w(ip, P4X_SLOT_BYTES,  slot_bytes);
        p4x_w(ip, P4X_SLOT_STRIDE, slot_stride);
        p4x_w(ip, P4X_PHASE,       phase + ip * per_ip);
        p4x_w(ip, P4X_N_SLOTS,     per_ip);
        p4x_w(ip, P4X_SLICE_MODE,  slice_mode);
        p4x_w(ip, P4X_SLICE_HALF,  slice_half_thick);
    }
    for (int ip = 0; ip < 4; ip++) {
        u32 v = p4x_r(ip, P4X_AP_CTRL);
        p4x_w(ip, P4X_AP_CTRL, v | P4X_AP_START_BIT);
    }
}

/* Block until all 4 IPs report ap_done. Returns 0=ok, ip+1 if that IP timed out. */
static inline int p4x_wait_all(u32 timeout_iters)
{
    for (u32 t = 0; t < timeout_iters; t++) {
        int done = 0;
        for (int ip = 0; ip < 4; ip++) {
            if (p4x_r(ip, P4X_AP_CTRL) & P4X_AP_DONE_BIT) done++;
        }
        if (done == 4) return 0;
    }
    return -1;
}

#endif
