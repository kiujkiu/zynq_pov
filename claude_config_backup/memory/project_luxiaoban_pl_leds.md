---
name: 鹿小班板载 PL LED 引脚与极性
description: 鹿小班 LXB-ZYNQ7000 核心板上两颗 PL 侧板载 LED 的 FPGA 引脚分配和电气极性
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
板载 PL 侧有 2 颗用户 LED，直连到 PL 的 Bank 34：

| 信号 | FPGA 引脚 | I/O 名称 | 电阻 |
|------|----------|----------|------|
| PL_LED1 | **P20** | IO_L18P_T2_34 | R57 1K 串联后到 GND |
| PL_LED2 | **P21** | IO_L18N_T2_34 | R56 1K 串联后到 GND |

**极性：高电平点亮**（PL 输出 1 → LED 亮；输出 0 → LED 灭）。Bank 34 的 VCCO 走 3.3V，XDC 电平用 `LVCMOS33`。

**Why:** 后续 POV 项目所有裸机/Linux 程序做板级自检时这两颗 LED 是最快的"活着没"指示灯；AXI GPIO 或普通 PL 管脚都可以驱动，极性错会导致"程序跑了 LED 不亮"误判。

**How to apply:** 任何需要板载 LED 指示的 Vivado 工程，XDC 直接写：
```
set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 } [get_ports { led[0] }];
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS33 } [get_ports { led[1] }];
```
来源：`01_硬件资料/SCH_Schematic1_2024-10-07.pdf` 第 3 页（LED 电路）+ 第 7 页（FPGA 引脚矩阵）。
