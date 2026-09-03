// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
#ifndef XPOV_ETA_RD_H
#define XPOV_ETA_RD_H

#ifdef __cplusplus
extern "C" {
#endif

/***************************** Include Files *********************************/
#ifndef __linux__
#include "xil_types.h"
#include "xil_assert.h"
#include "xstatus.h"
#include "xil_io.h"
#else
#include <stdint.h>
#include <assert.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stddef.h>
#endif
#include "xpov_eta_rd_hw.h"

/**************************** Type Definitions ******************************/
#ifdef __linux__
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
#else
typedef struct {
#ifdef SDT
    char *Name;
#else
    u16 DeviceId;
#endif
    u64 Control_BaseAddress;
} XPov_eta_rd_Config;
#endif

typedef struct {
    u64 Control_BaseAddress;
    u32 IsReady;
} XPov_eta_rd;

typedef u32 word_type;

/***************** Macros (Inline Functions) Definitions *********************/
#ifndef __linux__
#define XPov_eta_rd_WriteReg(BaseAddress, RegOffset, Data) \
    Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))
#define XPov_eta_rd_ReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))
#else
#define XPov_eta_rd_WriteReg(BaseAddress, RegOffset, Data) \
    *(volatile u32*)((BaseAddress) + (RegOffset)) = (u32)(Data)
#define XPov_eta_rd_ReadReg(BaseAddress, RegOffset) \
    *(volatile u32*)((BaseAddress) + (RegOffset))

#define Xil_AssertVoid(expr)    assert(expr)
#define Xil_AssertNonvoid(expr) assert(expr)

#define XST_SUCCESS             0
#define XST_DEVICE_NOT_FOUND    2
#define XST_OPEN_DEVICE_FAILED  3
#define XIL_COMPONENT_IS_READY  1
#endif

/************************** Function Prototypes *****************************/
#ifndef __linux__
#ifdef SDT
int XPov_eta_rd_Initialize(XPov_eta_rd *InstancePtr, UINTPTR BaseAddress);
XPov_eta_rd_Config* XPov_eta_rd_LookupConfig(UINTPTR BaseAddress);
#else
int XPov_eta_rd_Initialize(XPov_eta_rd *InstancePtr, u16 DeviceId);
XPov_eta_rd_Config* XPov_eta_rd_LookupConfig(u16 DeviceId);
#endif
int XPov_eta_rd_CfgInitialize(XPov_eta_rd *InstancePtr, XPov_eta_rd_Config *ConfigPtr);
#else
int XPov_eta_rd_Initialize(XPov_eta_rd *InstancePtr, const char* InstanceName);
int XPov_eta_rd_Release(XPov_eta_rd *InstancePtr);
#endif


void XPov_eta_rd_Set_voxel(XPov_eta_rd *InstancePtr, u64 Data);
u64 XPov_eta_rd_Get_voxel(XPov_eta_rd *InstancePtr);
void XPov_eta_rd_Set_phase(XPov_eta_rd *InstancePtr, u32 Data);
u32 XPov_eta_rd_Get_phase(XPov_eta_rd *InstancePtr);
void XPov_eta_rd_Set_n_slots(XPov_eta_rd *InstancePtr, u32 Data);
u32 XPov_eta_rd_Get_n_slots(XPov_eta_rd *InstancePtr);
void XPov_eta_rd_Set_axis_off_q8(XPov_eta_rd *InstancePtr, u32 Data);
u32 XPov_eta_rd_Get_axis_off_q8(XPov_eta_rd *InstancePtr);
void XPov_eta_rd_Set_mirror_u(XPov_eta_rd *InstancePtr, u32 Data);
u32 XPov_eta_rd_Get_mirror_u(XPov_eta_rd *InstancePtr);
void XPov_eta_rd_Set_pf_cols(XPov_eta_rd *InstancePtr, u32 Data);
u32 XPov_eta_rd_Get_pf_cols(XPov_eta_rd *InstancePtr);
u64 XPov_eta_rd_Get_xor_out(XPov_eta_rd *InstancePtr);
u32 XPov_eta_rd_Get_xor_out_vld(XPov_eta_rd *InstancePtr);

#ifdef __cplusplus
}
#endif

#endif
