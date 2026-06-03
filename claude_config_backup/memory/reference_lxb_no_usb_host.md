---
name: 鹿小班板无 USB host 能力
description: LXB-ZYNQ7000 (HELLOFPGA_XC7Z020) MIO 28-39 全悬空 + 无 ULPI PHY + 板上 USB-C 只是 CH340E UART, 想 USB WiFi 必须换板
type: reference
originSessionId: b3c27305-3e71-472d-bb43-6bae56fdaada
---
原始原理图：`/mnt/d/芯片资料/zynq7020-484/01_硬件资料/SCH_Schematic1_2024-10-07.pdf` (8 页)

## 板上 USB-C 是 USB-UART, 不是 USB host

Page 3 "Drivers"：USB-C 座 (USB1) → USB_DP/USB_DN → **CH340E (U18)** → CH340_UART_TX/RX → PS_UART。
就是平时的 console/调试串口，没有 USB host 能力。

## MIO 28-39 全悬空

Page 7 "BACK_2"：以下 MIO 都只出现在 Zynq BGA pin assignment 处，板上没接任何器件：

| MIO | BGA | 状态 |
|-----|-----|------|
| MIO28 | A12 | 悬空 |
| MIO29 | E8  | 悬空 |
| MIO30 | A11 | 悬空 |
| MIO31 | F9  | 悬空 |
| MIO32 | C7  | 悬空 |
| MIO33 | G13 | 悬空 |
| MIO34 | B12 | 悬空 |
| MIO35 | F14 | 悬空 |
| MIO36 | A9  | 悬空 |
| MIO37 | B14 | 悬空 |
| MIO38 | F13 | 悬空 |
| MIO39 | C13 | 悬空 |

板上**没有 ULPI PHY 芯片** (USB3320/3340/370x 都没有)，没有 USB-A 母座，没有 USB host 用电源。

## GPIO1/GPIO2 扩展座 (Page 8) 只走 PL

- GPIO1 = BANK 33 PL 引脚（17 对差分）
- GPIO2 = BANK 35 PL 引脚
- **没有 MIO 引到任何用户连接器**

## EMIO 救不了 USB

Zynq USB 控制器是 PS 硬核，必须走 MIO 28-39 (USB0) 或 40-51 (USB1，但 MIO40-47 是板载 microSD)，**不能走 EMIO**——ULPI 60 MHz 时序 PL 路由满足不了。

## 想要 USB WiFi 的可行路径

1. **换板**（推荐）：ALINX AX7Z020 / 米尔 MYC-Y7Z020 / 正点原子 领航者，都自带 USB3320 ULPI PHY + USB-A 座
2. **保留鹿小班**：继续走 ESP32-C5 SDIO 桥 (已 live, `project_pov3d_wifi_data_path_live.md`) 或 GEM0 RJ45 有线
3. **不可行**：飞线到 MIO 28-39 (BGA 底面无引出点) / PL 模拟 USB host (480 Mbps 不靠谱)

## 推荐的 Linux-friendly USB WiFi 芯片 (换板后用)

mainline kernel 自带 driver，PetaLinux 一键启用：
- **AR9271** (TP-LINK TL-WN722N v1)：`ath9k_htc`，最稳
- **RTL8188EUS** (TL-WN725N)：`r8188eu`
- **RT5370** 各种小 dongle：`rt2800usb`

避免：RTL8821CU/8822BU/8811CU——驱动要 dkms 自编，PetaLinux 集成痛苦。
