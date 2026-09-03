// ==============================================================
// Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
// Tool Version Limit: 2024.11
// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
// 
// ==============================================================
#ifndef __linux__

#include "xstatus.h"
#ifdef SDT
#include "xparameters.h"
#endif
#include "xpov_eta_rd.h"

extern XPov_eta_rd_Config XPov_eta_rd_ConfigTable[];

#ifdef SDT
XPov_eta_rd_Config *XPov_eta_rd_LookupConfig(UINTPTR BaseAddress) {
	XPov_eta_rd_Config *ConfigPtr = NULL;

	int Index;

	for (Index = (u32)0x0; XPov_eta_rd_ConfigTable[Index].Name != NULL; Index++) {
		if (!BaseAddress || XPov_eta_rd_ConfigTable[Index].Control_BaseAddress == BaseAddress) {
			ConfigPtr = &XPov_eta_rd_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XPov_eta_rd_Initialize(XPov_eta_rd *InstancePtr, UINTPTR BaseAddress) {
	XPov_eta_rd_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XPov_eta_rd_LookupConfig(BaseAddress);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XPov_eta_rd_CfgInitialize(InstancePtr, ConfigPtr);
}
#else
XPov_eta_rd_Config *XPov_eta_rd_LookupConfig(u16 DeviceId) {
	XPov_eta_rd_Config *ConfigPtr = NULL;

	int Index;

	for (Index = 0; Index < XPAR_XPOV_ETA_RD_NUM_INSTANCES; Index++) {
		if (XPov_eta_rd_ConfigTable[Index].DeviceId == DeviceId) {
			ConfigPtr = &XPov_eta_rd_ConfigTable[Index];
			break;
		}
	}

	return ConfigPtr;
}

int XPov_eta_rd_Initialize(XPov_eta_rd *InstancePtr, u16 DeviceId) {
	XPov_eta_rd_Config *ConfigPtr;

	Xil_AssertNonvoid(InstancePtr != NULL);

	ConfigPtr = XPov_eta_rd_LookupConfig(DeviceId);
	if (ConfigPtr == NULL) {
		InstancePtr->IsReady = 0;
		return (XST_DEVICE_NOT_FOUND);
	}

	return XPov_eta_rd_CfgInitialize(InstancePtr, ConfigPtr);
}
#endif

#endif

