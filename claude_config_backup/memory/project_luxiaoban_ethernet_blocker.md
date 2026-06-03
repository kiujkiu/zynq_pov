---
name: 鹿小班 ETH 裸机 lwIP 硬件层阻塞问题
description: 2026-04-22 调试到的以太网硬件/PHY 阻塞问题，软件怎么改都不通，卡在这里
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**状态**：Task #7 (lwIP 裸机以太网) **软件都跑通但 ARP 回不来**，卡在硬件层。

## 可以验证 work 的部分
- Vivado BD: PS ETH0 EMIO + gmii_to_rgmii_0 + FCLK_CLK2=200MHz 配置正确（照抄 vendor）
- PHY 芯片识别为 RTL8211E (Realtek ID=0x001c)
- PHY autoneg 完成，link up (1000 / 100 / 10 Mbps 都能)
- lwIP 初始化成功，TCP echo server 监听在 port 7
- GEM0 RX 侧完美：`BROADCAST_RX` 计数器会增长（收到 PC 发的 ARP 广播 43、91 次）
- 所有 RX 错误计数器 = 0 (FCS、symbol、alignment、overrun 都 0)

## 验证不 work 的部分  
- PC ping 板子 → 100% timeout（不管 1000/100/10Mbps）
- GEM0 TX 侧：`FRAMES_TX` 计数会增（板子发了 4~9 帧，应该是 ARP reply）
- PC 的 ARP 表里从来没有板子的 MAC 条目 → **说明板子发出的帧根本没到 PC 网卡**

## 结论（推测）
TX 路径在物理层坏了，但不是经典的 RGMII timing 错配（时序错配会导致 FCS 错误，counter 应 > 0）。推测：
1. PHY 的 TX 模拟驱动有问题（PCB 设计 / 磁变 / RJ45）
2. 或 RXD[1]/TXDLY strap 被 5.1K 上拉导致 100M 下 delay 不合适

## 试过的方案（都不行）
- 改 `xemacpsif_physpeed.c` 的 `get_Realtek_phy_speed()` 里 advertise register：只广播 100M / 10M
- 给 PHY page 0xd08 / page 0x07 写 TX delay / RX delay enable bit 
- 给 PHY page 0xd08 写 TX delay = 0（清除硬件 strap 默认值）
- 强制 10Mbps（最宽松 MII 时序）
- 所有改动都让 TX frame counter 增加，但 PC 收不到

## 未试过的方案
- 添加 FPGA 侧 IODELAY2 primitive 手工延迟 RGMII_0_txc 2ns (需要改 BD 或 custom RTL)
- 用 Wireshark 抓 PC 那边的包看有没有到达 & 内容
- 跑 vendor Linux BOOT.BIN 验证硬件 PHY TX 工作（Linux 能不能走 ETH）
- 换网线 / 换 PC Ethernet 口

## 下一步建议
Task #7 暂停。继续 POV 主流程（Task #7b "HDMI 帧缓冲"）用 UART 替代 ETH 做数据源，因为 POV 本质只需要主机→板子的单向数据链路。等以后硬件问题明朗再回来。
