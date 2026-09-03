// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
// control
// 0x00 : reserved
// 0x04 : reserved
// 0x08 : reserved
// 0x0c : reserved
// 0x10 : Data signal of voxel
//        bit 31~0 - voxel[31:0] (Read/Write)
// 0x14 : Data signal of voxel
//        bit 31~0 - voxel[63:32] (Read/Write)
// 0x18 : reserved
// 0x1c : Data signal of slot_base
//        bit 31~0 - slot_base[31:0] (Read/Write)
// 0x20 : Data signal of slot_base
//        bit 31~0 - slot_base[63:32] (Read/Write)
// 0x24 : reserved
// 0x28 : Data signal of phase
//        bit 31~0 - phase[31:0] (Read/Write)
// 0x2c : reserved
// 0x30 : Data signal of slot_start
//        bit 31~0 - slot_start[31:0] (Read/Write)
// 0x34 : reserved
// 0x38 : Data signal of n_slots
//        bit 31~0 - n_slots[31:0] (Read/Write)
// 0x3c : reserved
// 0x40 : Data signal of axis_off_q8
//        bit 31~0 - axis_off_q8[31:0] (Read/Write)
// 0x44 : reserved
// 0x48 : Data signal of mirror_u
//        bit 31~0 - mirror_u[31:0] (Read/Write)
// 0x4c : reserved
// (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)

#define XPOV_ETA_WR_CONTROL_ADDR_VOXEL_DATA       0x10
#define XPOV_ETA_WR_CONTROL_BITS_VOXEL_DATA       64
#define XPOV_ETA_WR_CONTROL_ADDR_SLOT_BASE_DATA   0x1c
#define XPOV_ETA_WR_CONTROL_BITS_SLOT_BASE_DATA   64
#define XPOV_ETA_WR_CONTROL_ADDR_PHASE_DATA       0x28
#define XPOV_ETA_WR_CONTROL_BITS_PHASE_DATA       32
#define XPOV_ETA_WR_CONTROL_ADDR_SLOT_START_DATA  0x30
#define XPOV_ETA_WR_CONTROL_BITS_SLOT_START_DATA  32
#define XPOV_ETA_WR_CONTROL_ADDR_N_SLOTS_DATA     0x38
#define XPOV_ETA_WR_CONTROL_BITS_N_SLOTS_DATA     32
#define XPOV_ETA_WR_CONTROL_ADDR_AXIS_OFF_Q8_DATA 0x40
#define XPOV_ETA_WR_CONTROL_BITS_AXIS_OFF_Q8_DATA 32
#define XPOV_ETA_WR_CONTROL_ADDR_MIRROR_U_DATA    0x48
#define XPOV_ETA_WR_CONTROL_BITS_MIRROR_U_DATA    32

