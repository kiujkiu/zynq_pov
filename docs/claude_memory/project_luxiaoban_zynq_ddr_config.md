---
name: 鹿小班 LXB-ZYNQ7020 核心板 PS/DDR 关键配置
description: 本项目所用 Zynq-7020 开发板(鹿小班 LXB-ZYNQ7000)的已验证 Vivado PS 与 DDR 参数，照抄即可跑通 FSBL/裸机
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
开发板型号：鹿小班 LXB-ZYNQ7000（XC7Z020CLG484）。已经通过 Hello World 裸机测试的 Vivado PS 配置，任何新 Vivado 工程直接照抄这套参数即可（否则 DDR 初始化失败，Vitis 报 `DAP status 0xF0000021 / Memory write error at 0x100000`）。

**Part (Device Selection)**
- `xc7z020clg484-2`（**速度等级 -2**，不是默认的 -1；板子实际颗粒是 -2 速度等级）

**DDR Configuration（ZYNQ7 PS → DDR Configuration）**
- Memory Type: `DDR 3`（**不是** DDR 3 Low Voltage；板子 VCCO 走的是 1.5V DDR3）
- Memory Part: `MT41J256M16 RE-125`（注意是 **J** 不是 K，即使丝印显示 D9SHG 这种 FBGA 码）
- **Effective DRAM Bus Width: `16 Bit`**（**板子只有单颗 DDR 颗粒**，不是双颗 32-bit 并联；这是最容易踩错的参数）
- ECC: Disabled
- Burst Length: 8
- DDR clock: 533.333333 MHz
- Speed Bin: `DDR3_1066F`
- DRAM Device Capacity: `4096 MBits`

**PS-PL Configuration**
- 勾选 M_AXI_GP0 interface（后续 PL 外设要用）
- **必须连 `FCLK_CLK0` → `M_AXI_GP0_ACLK`**，否则 Validate/HDL Generation 报 BD 41-758 错

**Why:** 之前把 Bus Width 设成 32 Bit + Memory Type = DDR 3L 导致 DDR 反复初始化失败，用鹿小班官方 `04_apply-code/HelloZynqPS_Linux_ETH/` 里的参考工程参数对比后才发现真正原因是 Bus Width 和速度等级，不是 DDR 电压类型。

**How to apply:** 新建 Vivado 工程时，Part 选 xc7z020clg484-**2**；Block Design 加 ZYNQ7 PS 后，点 Run Block Automation 先应用板级预设，再进 DDR Configuration 手工校对上面每一项。Export Hardware 前务必 F6 Validate 通过。
