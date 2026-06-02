---
name: 鹿小班 GPIO1 connector site → PACKAGE_PIN 映射 (BANK 33)
description: GPIO1 2×40 排针所有 17 对 BANK 33 site 跟 XC7Z020-CLG484 PACKAGE_PIN 的对应表，来自 SCH P6 + P8 抽取
type: reference
originSessionId: 4a5ca456-0b28-4ae3-b178-c2e4275a5f3c
---
SCH 来源: `/mnt/d/芯片资料/zynq7020-484/01_硬件资料/SCH_Schematic1_2024-10-07.pdf` P6 (BANK 33 site → package pin) + P8 (GPIO1 connector site map)

GPIO1 = 2×40 pin 双排排针, Pin 1-6 电源 (+5V / VCC3V3 / GND ×2), Pin 7-40 = 17 对 BANK 33 IO, VCCO_33 = 3.3V (LVCMOS33)。Site 顺序 P8 列出, package pin 在 P6 抽出。

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
| 13 | IO_L11N_T1_SRCC_33 | AA19 | SRCC, 可走时钟 |
| 14 | IO_L11P_T1_SRCC_33 | Y19 | SRCC, 可走时钟 |
| 15 | IO_L18N_T2_33 | AB16 | |
| 16 | IO_L18P_T2_33 | AA16 | |
| 17 | IO_L12P_T1_MRCC_33 | Y18 | MRCC, 主时钟首选 |
| 18 | IO_L12N_T1_MRCC_33 | AA18 | MRCC, 配对 |
| 25 | IO_L13N_T2_MRCC_33 | W18 | MRCC (BANK 33 T2) |
| 26 | IO_L13P_T2_MRCC_33 | W17 | MRCC (BANK 33 T2) |
| 27 | IO_L17P_T2_33 | AA17 | |
| 28 | IO_L17N_T2_33 | AB17 | |
| 29 | IO_L14P_T2_SRCC_33 | W16 | SRCC |
| 30 | IO_L14N_T2_SRCC_33 | Y16 | SRCC |
| 19 | IO_L19P_T3_33 | V14 | T3 |
| 20 | IO_L19N_T3_VREF_33 | V15 | VREF, 避免当 LVCMOS 用 |
| 21 | IO_L22N_T3_33 | AA14 | |
| 22 | IO_L22P_T3_33 | Y14 | |
| 23 | IO_L20N_T3_33 | W13 | |
| 24 | IO_L20P_T3_33 | V13 | |
| 31 | IO_L23N_T3_33 | AA13 | |
| 32 | IO_L23P_T3_33 | Y13 | |
| 33 | IO_L24N_T3_33 | AB15 | |
| 34 | IO_L24P_T3_33 | AB14 | |
| 35 | IO_L3P_T0_DQS_33 | V22 | DQS T0 |
| 36 | IO_L3N_T0_DQS_33 | W22 | DQS T0 |
| 37 | IO_L2P_T0_33 | T22 | |
| 38 | IO_L2N_T0_33 | U22 | |

电源 pin 1-4: +5V / VCC3V3 / GND ×2 (各两根, 加冗余)。

GPIO2 = BANK 35 同结构, 但 BANK 35 现已用于以太网 RGMII (eth_pins.xdc 占用)。新外设走 GPIO1。
