---
name: XC7Z020 没有 PCIe，无线只能走 USB2.0 / SDIO / SPI
description: 7Z010/7Z020 无 PCIe 硬核也无 GTP 收发器 ⇒ PCIe WiFi 模块物理上接不了, 软核也救不了; USB2.0 480 标称但本项目实测 ~125 Mbps 已到顶
type: reference
---

2026-08-04 问"7020 能不能用 PCIe 的 WiFi 模块" ⇒ **不能，永久排除这条路。**

## 硬事实

XC7Z020 **既没有 PCIe 硬核，也没有任何高速串行收发器 (GTP/GTX)**。

| 型号 | GTP/GTX | PCIe Gen2 硬核 |
|---|---|---|
| 7Z007S / 7Z010 / **7Z020** | ❌ 无 | ❌ 无 |
| 7Z012S / 7Z015 / 7Z030 | 4× GTP | ✅ |
| 7Z035 / 7Z045 / 7Z100 | GTX | ✅ |

7Z010/7Z020 是纯 Artix-7 fabric，只有 HR/HP 普通 IO。

⚠ **软核 PCIe IP 也不行** —— PCIe 物理层必须靠串行收发器，普通 IO 顶不了。别在这上面花时间找"PL 实现 PCIe"的方案。

## 因此 7020 上的无线接口只有三条

| 接口 | 上限 | 本项目状态 |
|---|---|---|
| **USB 2.0 OTG** (PS，需外挂 ULPI PHY) | 标称 480 Mbps；Zynq 实用 25-35 MB/s | ✅ FS03 在用 (MT7921AU)，**实测 ~125 Mbps 到顶**，见 [[feedback_wifi_throughput_bottleneck_isolated]] |
| **SDIO** (PS SD0/SD1) | ~200 Mbps | 方案已写未做，见 [[project_lxb_sdio_wifi_plan]] |
| **SPI/UART 协处理器** | 1-20 Mbps | ESP32-C5 桥，见 [[project_pov3d_wifi_data_path_live]] |

另：**GEM 千兆有线实测 700-900 Mbps，硬件 DMA，CPU 占用远低于 USB** —— 能拉线的场合差一个数量级。

## How to apply

- 再被问"能不能上 PCIe/USB3/更快的无线"：7020 上答案是**换 SoC**（Zynq UltraScale+ ZU2CG/ZU3EG 才有 USB 3.0 + PCIe），不是换模块、不是改 PL。
- 鹿小班板还额外没有 ULPI PHY，连 USB 这条都走不了，见 [[reference_lxb_no_usb_host]]。
- 选 USB WiFi 芯片前先看现有链路余量：[[feedback_wifi_bandwidth_first_question_demand]] —— 现在卡帧率的是 ARM 解码不是链路。
