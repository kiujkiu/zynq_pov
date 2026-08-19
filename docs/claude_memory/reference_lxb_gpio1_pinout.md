---
name: 鹿小班 GPIO1 排针脚号 → site → PACKAGE_PIN (BANK 33)
description: GPIO1 2×20 排针 34 根 BANK 33 IO 的完整对应表; 2026-08-19 更正了旧版一半的脚号
type: reference
originSessionId: 4a5ca456-0b28-4ae3-b178-c2e4275a5f3c
---

SCH 来源: `/mnt/d/芯片资料/zynq7020-484/01_硬件资料/SCH_Schematic1_2024-10-07.pdf` **P8**
（GPIO1 符号本身就同时画了脚号和 site 名）+ P6 / Vivado 封装表核 PACKAGE_PIN。

**GPIO1 = 2×20 双排排针（不是 2×40）**，共 40 脚：**35~40 是电源**，1~34 是 BANK 33 的 17 对 IO。
VCCO_33 = 3.3V（LVCMOS33）。

| 脚 | site | PACKAGE_PIN | 备注 |
|---|---|---|---|
| 1 | IO_L2N_T0_33 | U22 | |
| 2 | IO_L2P_T0_33 | T22 | |
| 3 | IO_L3N_T0_DQS_33 | W22 | DQS |
| 4 | IO_L3P_T0_DQS_33 | V22 | DQS |
| 5 | IO_L9N_T1_DQS_33 | Y21 | DQS |
| 6 | IO_L9P_T1_DQS_33 | Y20 | DQS |
| 7 | IO_L7N_T1_33 | AB22 | |
| 8 | IO_L7P_T1_33 | AA22 | |
| 9 | IO_L8N_T1_33 | AB21 | |
| 10 | IO_L8P_T1_33 | AA21 | |
| 11 | IO_L10P_T1_33 | AB19 | |
| 12 | IO_L10N_T1_33 | AB20 | |
| 13 | IO_L11N_T1_SRCC_33 | AA19 | SRCC |
| 14 | IO_L11P_T1_SRCC_33 | Y19 | SRCC |
| 15 | IO_L18N_T2_33 | AB16 | |
| 16 | IO_L18P_T2_33 | AA16 | |
| 17 | IO_L12P_T1_MRCC_33 | Y18 | MRCC |
| 18 | IO_L12N_T1_MRCC_33 | AA18 | MRCC |
| 19 | IO_L24P_T3_33 | AB14 | |
| 20 | IO_L24N_T3_33 | AB15 | |
| 21 | IO_L23P_T3_33 | Y13 | |
| 22 | IO_L23N_T3_33 | AA13 | |
| 23 | IO_L20P_T3_33 | V13 | |
| 24 | IO_L20N_T3_33 | W13 | |
| 25 | IO_L13N_T2_MRCC_33 | W18 | MRCC |
| 26 | IO_L13P_T2_MRCC_33 | W17 | MRCC |
| 27 | IO_L17P_T2_33 | AA17 | |
| 28 | IO_L17N_T2_33 | AB17 | |
| 29 | IO_L14P_T2_SRCC_33 | W16 | SRCC |
| 30 | IO_L14N_T2_SRCC_33 | Y16 | SRCC |
| 31 | IO_L22P_T3_33 | Y14 | |
| 32 | IO_L22N_T3_33 | AA14 | |
| 33 | IO_L19N_T3_VREF_33 | V15 | VREF，本 bank 全 LVCMOS 时可当普通 IO |
| 34 | IO_L19P_T3_33 | V14 | |

电源脚（**左右两列对称，不是对角**）：
`35 GND / 36 GND`、`37 VCC3V3 / 38 VCC3V3`、`39 +5V / 40 +5V`。

## 🔴 2026-08-19 更正：旧版这张表一半的脚号是错的

旧版（2026-04 建）把 site 顺序当成了脚号顺序，结果：
- 脚 **19~24、31~38 全错**（把 L19/L22/L23/L24 那组挪了位，还把 L2/L3 放到了 35~38）
- 「Pin 1-6 是电源」也是错的 —— 电源在 **35~40**，1~4 是 L2N/L2P/L3N/L3P
- 脚 5~18、25~30 那些行是对的（所以错得不明显）

**发现经过**：核 ICND2260 转接板 `zynq-lxb_2260_V0.1` 时，板上 P1 的脚号与旧表对不上 6 处。
去翻原理图，**`pdftotext -layout` 抽 P8 出来的脚号是乱的**（两列数字互相穿插，
电源那三条连线被排成对角），差点据此判定「转接板把 +5V 和 GND 接反了、插上就短路」。
把 P8 渲染成图片肉眼看才确认：**转接板完全正确，错的是旧记忆表。**

**How to apply:**
1. 这类「符号图 + 连线」的信息，`pdftotext` 不可信，**渲染成 PNG 看图**
   （`pdftoppm -f <页> -r 600 -png -x -y -W -H` 裁出局部）。
2. 用 site 名做中介、避开脚号：ICND2260 转接板的网表就是直接用 site 名标的
   （`L3P_33` / `L9N_33`…），这样连这张表都不需要。site→ball 查
   [[reference_vivado_ibis_pkg]] 的封装文件，不要靠记忆。

相关：[[project_lxb_icnd2260_bringup]]（用到脚 3~10 / 18 / 20 / 22 / 33 / 34）。
GPIO2 = BANK 35 同结构，但 BANK 35 已被以太网 RGMII 占用（eth_pins.xdc）。
另：板载 **PL_CLK_50M = IO_L13P_T2_MRCC_34 = M19**（P3 有源晶振，P7 引脚矩阵），
纯 PL 设计不用 PS 也能起时钟。
