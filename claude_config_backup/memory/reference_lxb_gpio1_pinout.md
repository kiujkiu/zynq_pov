---
name: 鹿小班 GPIO1 connector site → PACKAGE_PIN 映射 (BANK 33) **已纠正 2026-06-08**
description: GPIO1 2×40 排针所有 17 对 BANK 33 site 跟 XC7Z020-CLG484 PACKAGE_PIN 的对应表。原表 2026-05 抽错, 2026-06-08 panel 2 wiring 调试时从 SCH P8 重新提取
created_at: 2026-05-18 CST
updated_at: 2026-06-12 00:20 CST
type: reference
originSessionId: c65586d5-1bd7-42fb-bf7e-7a8b7f63582c
---
SCH 来源: `/mnt/d/芯片资料/zynq7020-484/01_硬件资料/SCH_Schematic1_2024-10-07.pdf` page 8 (GPIO1 connector + BANK 33 site)

GPIO1 = 2×40 pin 双排排针. **电源在高编号端 (2026-06-12 SCH P8 渲染实锤): GND=35/36, VCC3V3=37/38, +5V=39/40**. 信号 = pin 1-34 (17 对 BANK 33 IO), VCCO_33 = 3.3V (LVCMOS33).
**2026-06-12 二次纠正**: 原表两端全错 (写成电源 1-4 + L3/L2@35-38). 实际: **pin 1=L2N(U22), 2=L2P(T22), 3=L3N(W22), 4=L3P(V22)**, 电源 35-40. 中段 5-34 原表正确. 当前 XDC 的 C'/D' (T22/U22) 物理在板 pin 2/1, XDC 注释 "J1.37/38" 是错标 (引脚本身对).

**重要 (2026-06-08 panel 2 bring-up 踩坑)**: 之前抽表把 pin 7-22 和 pin 23-38 上下"竖列"读法搞反, 导致 panel 2 wiring 设计跟实际 board 全错位 (除 pin 13 / pin 30 正好对). PDF 上 GPIO1 connector 是双排, pin 编号从顶 (33/34) 到底 (7/8), 偶数列在左 / 奇数列在右. 用 PyMuPDF 提取坐标 + Y 行匹配重新抽:

| GPIO1 Pin | Site | PACKAGE_PIN | 备注 |
|---|---|---|---|
| 5 | IO_L9N_T1_DQS_33 | Y21 | DQS, 当 GPIO 用 |
| 6 | IO_L9P_T1_DQS_33 | Y20 | DQS, 当 GPIO 用 |
| 7 | IO_L7N_T1_33 | AB22 | |
| 8 | IO_L7P_T1_33 | AA22 | |
| 9 | IO_L8N_T1_33 | AB21 | |
| 10 | IO_L8P_T1_33 | AA21 | |
| 11 | IO_L10P_T1_33 | AB19 | |
| 12 | IO_L10N_T1_33 | AB20 | |
| **13** | **IO_L11N_T1_SRCC_33** | **AA19** | SRCC, 可走时钟 |
| 14 | IO_L11P_T1_SRCC_33 | Y19 | SRCC, 可走时钟 |
| 15 | IO_L18N_T2_33 | AB16 | |
| 16 | IO_L18P_T2_33 | AA16 | |
| 17 | IO_L12P_T1_MRCC_33 | Y18 | MRCC, 主时钟首选 |
| 18 | IO_L12N_T1_MRCC_33 | AA18 | MRCC, 配对 |
| **19** | **IO_L24P_T3_33** | **AB14** | |
| **20** | **IO_L24N_T3_33** | **AB15** | |
| **21** | **IO_L23P_T3_33** | **Y13**  | |
| **22** | **IO_L23N_T3_33** | **AA13** | |
| 23 | IO_L20P_T3_33 | V13 | |
| 24 | IO_L20N_T3_33 | W13 | |
| 25 | IO_L13N_T2_MRCC_33 | W18 | MRCC (BANK 33 T2) |
| 26 | IO_L13P_T2_MRCC_33 | W17 | MRCC (BANK 33 T2) |
| 27 | IO_L17P_T2_33 | AA17 | |
| 28 | IO_L17N_T2_33 | AB17 | |
| 29 | IO_L14P_T2_SRCC_33 | W16 | SRCC |
| **30** | **IO_L14N_T2_SRCC_33** | **Y16** | SRCC |
| 31 | IO_L22P_T3_33 | Y14 | |
| 32 | IO_L22N_T3_33 | AA14 | |
| 33 | IO_L19N_T3_VREF_33 | V15 | VREF, 避免当 LVCMOS 用 |
| 34 | IO_L19P_T3_33 | V14 | T3 |
| **4** | IO_L3P_T0_DQS_33 | V22 | DQS T0 (二次纠正: 原误标 35) |
| **3** | IO_L3N_T0_DQS_33 | W22 | DQS T0 (原误标 36) |
| **2** | IO_L2P_T0_33 | T22 | (原误标 37) |
| **1** | IO_L2N_T0_33 | U22 | (原误标 38) |
| 35/36 | GND | - | 电源端 |
| 37/38 | VCC3V3 | - | 电源端 |
| 39/40 | +5V | - | 电源端 |

(电源行已并入上表)

GPIO2 = BANK 35 同结构, 但 BANK 35 现已用于以太网 RGMII (eth_pins.xdc 占用). 新外设走 GPIO1.

**验证方法**: 用 `tools/_extract_sch4.py` 读 PDF page 8 提取 site<->pin 对应, 然后从 Xilinx CLG484 datasheet 查 IO_L<N><PN>_T<X>_<bank> → PACKAGE_PIN. PyMuPDF 提取脚本在 tools/ 目录.

**踩坑教训**: 抽 PDF schematic pin map 一定要看 PDF 渲染 (`pdftoppm`) 或者用 PyMuPDF 提取坐标 + Y 行对齐, 不能只靠 raw text dump.
