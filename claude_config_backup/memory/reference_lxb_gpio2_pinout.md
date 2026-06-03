---
name: 鹿小班 GPIO2 connector site → PACKAGE_PIN 映射 (BANK 35)
description: GPIO2 2×40 排针 BANK 35 site→pin 全表，跟 ETH RGMII **不冲突**（ETH 用的 BANK 35 pin 不在 GPIO2 引脚列表）
type: reference
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
SCH: `/mnt/d/芯片资料/zynq7020-484/01_硬件资料/SCH_Schematic1_2024-10-07.pdf` P7 (BANK 35 site→pin) + P8 (GPIO2 connector site map). 跟 GPIO1 镜像结构, Pin 1-6 电源, Pin 5-38 = 34 IO (BANK 35), VCCO_35 = 3.3V LVCMOS33.

## GPIO2 BANK 35 pin 表

| GPIO2 Pin | Site | PACKAGE_PIN | 备注 |
|---|---|---|---|
| 5 | IO_L4N_T0_35 | G16 | |
| 6 | IO_L4P_T0_35 | G15 | |
| 7 | IO_L1P_T0_AD0P_35 | F16 | XADC AD0P |
| 8 | IO_L1N_T0_AD0N_35 | E16 | XADC AD0N |
| 9 | IO_L12N_T1_MRCC_35 | C19 | MRCC, 可走时钟 |
| 10 | IO_L12P_T1_MRCC_35 | D18 | MRCC, 配对 |
| 11 | IO_L3P_T0_DQS_AD1P_35 | E15 | DQS, XADC AD1P |
| 12 | IO_L3N_T0_DQS_AD1N_35 | D15 | DQS, XADC AD1N |
| 13 | IO_L2P_T0_AD8P_35 | D16 | XADC AD8P |
| 14 | IO_L2N_T0_AD8N_35 | D17 | XADC AD8N |
| 15 | IO_L7P_T1_AD2P_35 | C15 | XADC AD2P |
| 16 | IO_L7N_T1_AD2N_35 | B15 | XADC AD2N |
| 17 | IO_L14N_T2_AD4N_SRCC_35 | C20 | SRCC, XADC AD4N |
| 18 | IO_L14P_T2_AD4P_SRCC_35 | D20 | SRCC, XADC AD4P |
| 19 | IO_L9P_T1_DQS_AD3P_35 | A16 | DQS, XADC AD3P |
| 20 | IO_L9N_T1_DQS_AD3N_35 | A17 | DQS, XADC AD3N |
| 21 | IO_L8P_T1_AD10P_35 | B16 | XADC AD10P |
| 22 | IO_L8N_T1_AD10N_35 | B17 | XADC AD10N |
| 23 | IO_L18P_T2_AD13P_35 | B21 | XADC AD13P |
| 24 | IO_L18N_T2_AD13N_35 | B22 | XADC AD13N |
| 25 | IO_L16N_T2_35 | C22 | |
| 26 | IO_L16P_T2_35 | D22 | |
| 27 | IO_L21P_T3_DQS_AD14P_35 | E19 | DQS, XADC AD14P |
| 28 | IO_L21N_T3_DQS_AD14N_35 | E20 | DQS, XADC AD14N |
| 29 | IO_L20N_T3_AD6N_35 | F19 | XADC AD6N |
| 30 | IO_L20P_T3_AD6P_35 | G19 | XADC AD6P |
| 31 | IO_L11N_T1_SRCC_35 | C18 | SRCC |
| 32 | IO_L6P_T0_35 | G17 | |
| 33 | IO_L6N_T0_VREF_35 | F17 | VREF, 避免当 LVCMOS 用 |
| 34 | IO_L5P_T0_AD9P_35 | F18 | XADC AD9P |
| 35 | IO_L5N_T0_AD9N_35 | E18 | XADC AD9N |
| 36 | IO_L19N_T3_VREF_35 | H20 | VREF, 避免 |
| 37 | IO_L19P_T3_35 | H19 | |
| 38 | (未列出, 推断 IO_L11P_T1_SRCC_35 或 IO_25_35) | 待 SCH 确认 | |

## ETH RGMII 占用 BANK 35 pin (不在 GPIO2 上!)

| Signal | PACKAGE_PIN | Site |
|---|---|---|
| RGMII rd[0..3] | A22 / A18 / A19 / B20 | L15N / L10P / L10N / L13N |
| RGMII rx_ctl | A21 | L15P |
| RGMII rxc | B19 | L13P |
| RGMII td[0..3] | E21 / F21 / F22 / G20 | L17P / L23P / L23N / L22P |
| RGMII tx_ctl | G22 | L24N |
| RGMII txc | D21 | L17N |
| MDIO mdc | G21 | L22N |
| MDIO mdio_io | H22 | L24P |

**关键**: ETH 14 个 pin 都不在 GPIO2 site 表里 → ETH + GPIO2 **同时使用无冲突**, 可保留 ETH 跑 HUB75E 48-SDI 方案.

## 备注

- XADC AD pin 标记的 pair 默认有 anti-alias filter, 当 LVCMOS33 GPIO 用没问题但走差分 ADC 信号会浪费
- DQS/MRCC/SRCC 优先留给时钟信号 (DCLK 等), 别浪费在普通 SDI
- VREF pin (L6N, L19N) 当 LVCMOS33 用 OK 但不能同时用 input reference
