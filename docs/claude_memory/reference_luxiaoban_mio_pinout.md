---
name: 鹿小班核心板 MIO 物理引脚分配
description: 鹿小班 LXB-ZYNQ7000 核心板上每个 MIO 实际焊到了什么外设；扩展连接器只走 PL 引脚
type: reference
originSessionId: 424767a4-a574-44de-ba47-dbe4a060ea3f
---
来源：`/mnt/d/芯片资料/zynq7020-484/01_硬件资料/SCH_Schematic1_2024-10-07.pdf`（核心板原理图，8 页）

## 核心板已用 MIO（焊死，不可复用）

- **MIO 1-6**：QSPI Flash `W25Q256JVEIQ`（256Mb / 32MB）— 启动 flash
  - MIO1=CSN, MIO2=IO0, MIO3=IO1, MIO4=IO2, MIO5=IO3, MIO6=CLK
- **MIO 40-45, 47**：microSD 卡座（焊在核心板上！）
  - MIO40=CLK, MIO41=CMD, MIO42-45=DAT0-3, MIO47=CD（卡检测）
- **MIO 28-39**：原理图 Page 7 列出 BGA pin 但**板上全悬空**（无 PHY、无连接器、无测试点）→ 见 `reference_lxb_no_usb_host.md`
- 其他 MIO（0, 7-13, 46, 48-53）：核心板原理图未展示具体连接；扩展连接器（GPIO1/GPIO2）只走 PL 引脚（BANK 33/35），**没有 MIO 引到用户连接器**

## 用户扩展连接器（GPIO1 + GPIO2，2×40 pin）

- GPIO1：BANK 33 PL 引脚
- GPIO2：BANK 35 PL 引脚
- 已使用 PL 引脚（在现有 hellozynq.xdc 中约束的）：
  - HDMI TMDS：BANK 34（M21/M22, L21/L22, J21/J22, N22/P22）
  - PL LED：BANK 34（P20, P21）
  - 以太网 RGMII + MDIO：BANK 35（A18-22, B19-22, D21, E21, F21-22, G20-22, H17, H22）
  - PL UART（USB-CP2102）：BANK 34（M17 RX, L17 TX）

## 用法

- 想加 SDIO Slave 设备（如 ESP32 协处理器）：**只能用 SD1 走 EMIO 出 PL 引脚** 到 GPIO1/2 连接器，不能复用 SD0 MIO（被板载 microSD 占用）
- SD1 EMIO 限速 ~25-50 MHz（受 PL 路由延迟），实测吞吐 10-15 MB/s
- 想做高速 PS 外设（USB/SPI/I2C）也都得走 EMIO
- QSPI 启动模式下，BootROM 读 W25Q256，启动后 SSBL 不必启用 QSPI peripheral 也能跑
