// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
/***************************** Include Files *********************************/
#include "xpov_eta_rd.h"

/************************** Function Implementation *************************/
#ifndef __linux__
int XPov_eta_rd_CfgInitialize(XPov_eta_rd *InstancePtr, XPov_eta_rd_Config *ConfigPtr) {
    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(ConfigPtr != NULL);

    InstancePtr->Control_BaseAddress = ConfigPtr->Control_BaseAddress;
    InstancePtr->IsReady = XIL_COMPONENT_IS_READY;

    return XST_SUCCESS;
}
#endif

void XPov_eta_rd_Set_voxel(XPov_eta_rd *InstancePtr, u64 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XPov_eta_rd_WriteReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_VOXEL_DATA, (u32)(Data));
    XPov_eta_rd_WriteReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_VOXEL_DATA + 4, (u32)(Data >> 32));
}

u64 XPov_eta_rd_Get_voxel(XPov_eta_rd *InstancePtr) {
    u64 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_VOXEL_DATA);
    Data += (u64)XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_VOXEL_DATA + 4) << 32;
    return Data;
}

void XPov_eta_rd_Set_phase(XPov_eta_rd *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XPov_eta_rd_WriteReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_PHASE_DATA, Data);
}

u32 XPov_eta_rd_Get_phase(XPov_eta_rd *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_PHASE_DATA);
    return Data;
}

void XPov_eta_rd_Set_n_slots(XPov_eta_rd *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XPov_eta_rd_WriteReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_N_SLOTS_DATA, Data);
}

u32 XPov_eta_rd_Get_n_slots(XPov_eta_rd *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_N_SLOTS_DATA);
    return Data;
}

void XPov_eta_rd_Set_axis_off_q8(XPov_eta_rd *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XPov_eta_rd_WriteReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_AXIS_OFF_Q8_DATA, Data);
}

u32 XPov_eta_rd_Get_axis_off_q8(XPov_eta_rd *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_AXIS_OFF_Q8_DATA);
    return Data;
}

void XPov_eta_rd_Set_mirror_u(XPov_eta_rd *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XPov_eta_rd_WriteReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_MIRROR_U_DATA, Data);
}

u32 XPov_eta_rd_Get_mirror_u(XPov_eta_rd *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_MIRROR_U_DATA);
    return Data;
}

void XPov_eta_rd_Set_pf_cols(XPov_eta_rd *InstancePtr, u32 Data) {
    Xil_AssertVoid(InstancePtr != NULL);
    Xil_AssertVoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    XPov_eta_rd_WriteReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_PF_COLS_DATA, Data);
}

u32 XPov_eta_rd_Get_pf_cols(XPov_eta_rd *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_PF_COLS_DATA);
    return Data;
}

u64 XPov_eta_rd_Get_xor_out(XPov_eta_rd *InstancePtr) {
    u64 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_XOR_OUT_DATA);
    Data += (u64)XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_XOR_OUT_DATA + 4) << 32;
    return Data;
}

u32 XPov_eta_rd_Get_xor_out_vld(XPov_eta_rd *InstancePtr) {
    u32 Data;

    Xil_AssertNonvoid(InstancePtr != NULL);
    Xil_AssertNonvoid(InstancePtr->IsReady == XIL_COMPONENT_IS_READY);

    Data = XPov_eta_rd_ReadReg(InstancePtr->Control_BaseAddress, XPOV_ETA_RD_CONTROL_ADDR_XOR_OUT_CTRL);
    return Data & 0x1;
}

