---
name: WiFi 吞吐只有 ~20 Mbps — 瓶颈锁定在 mt7921u 的 USB 传输, 已穷尽软件手段
description: 空口协商 432-1200Mbit/s 零重传, 板内回环 1238Mbps, 但过 USB-WiFi 只有 15-26Mbps; SG 不能关(关了卡死)
type: feedback
---

2026-08-04 系统排查。**结论: 不是无线、不是 CPU、不是配置, 是 mt7921u 驱动的 USB
批量传输实现, 且没有可调参数。**

## 🔴 先纠正一个长期错误认知

`povstream` 统计行里的 `链路占用 28% (@28 Mbps)` —— 那个 **28 是硬编码常量**
(`DEFAULT_LINK_MBPS = 28.0`), **不是实测值**。我一度把它当实测并据此写进结论。
真实带宽必须自己测。

## 实测数据 (板子转着, 663 RPM)

| 通路 | 吞吐 |
|---|---|
| **板内 TCP 回环** (不过 USB/无线) | **1238 Mbps** |
| 经 USB-WiFi (pov_rxd 停, 真空载) | **23.1 / 23.7 Mbps** |
| 经 USB-WiFi (网络流解压中) | 25.6 Mbps |
| 经 USB-WiFi (空闲动画解压中) | 15.2 Mbps |
| SG 回滚后复测 | 18.8 Mbps |

⇒ **CPU/TCP 栈差 54 倍余量, 完全不是瓶颈。**
⚠ 测量时必须先 `systemctl stop povrxd` —— 否则空闲动画会持续解压吃掉 ~53% CPU,
"停了推流"**不等于**空载 (我为此测出过自相矛盾的数)。

## 已排除的嫌疑 (都有硬证据)

| 嫌疑 | 排除依据 |
|---|---|
| 2.4G / 频段错 | 实测 **5745-5805 MHz, 80MHz 带宽** |
| 信号弱 | **−45 ~ −57 dBm**, `tx retries: 0`, `tx failed: 0` |
| **转子旋转衰落** | **零重传** —— 空口根本没丢包。⚠ 我之前"天线在转子上=硬件问题"的归因**是错的** |
| CPU / TCP 栈 | 回环 1238 Mbps |
| USB 接口速率 | `/sys/bus/usb/devices/1-1/speed` = **480** (高速), EHCI 正常, 无 USB 错误 |
| **USB scatter-gather** | 见下 |

## USB SG 实验: 假设被干净证否

`mt76_usb` **只暴露一个参数** `disable_usb_sg` (默认 N=启用 SG)。关掉试:

| 配置 | 大流量 | 小包(SSH) |
|---|---|---|
| `disable_usb_sg=N` (默认) | 15–26 Mbps | ✅ |
| `disable_usb_sg=Y` | **完全卡死**(send 阻塞超时) | ✅ 还能通 |

⇒ **SG 是必需的, 不是可选优化。软件可调项到此穷尽。**
(实验脚本带自愈回滚, 40s 内自动恢复; 回滚后复测 18.8 Mbps 确认链路没坏。)

## 换 dongle 这条路的前置障碍

内核 `6.6.0-xilinx-g343f487d6341` 的 `drivers/net/wireless/` **只有 mediatek 一家**
(7 个 mt76 系 .ko)。插 RTL8812BU/8821CU 等**驱动根本不存在**。
⇒ 要验证"是驱动问题还是 ci_hdrc 平台通病", **必须先重编内核加驱动**, 而当初的
内核构建环境在 `~/mlkpai-kernel/` **换机已丢** (见 [[feedback_new_machine_setup_gotchas]])。

## 剩下的路

1. **接受 ~20 Mbps, 从数据侧要空间** ✅ 立刻可做:
   `--delta` 帧间 XOR 实测压缩比 33.7×→38.9× (白捡 15%); 配合降 fps。
   双面 720 片 @10fps 需 21 Mbps —— **刚好够**。
2. **换 SDIO WiFi** (RTL8822CS, 见 [[project_lxb_sdio_wifi_plan]]) —— 绕开 USB, 上限 200 Mbps。硬件改动。
3. 重编内核换 dongle 芯片验证 —— 成本高, 信息量大。
4. ⚠ **空闲动画已经绕过了这个问题** —— 本地播放不走网络, 稳定 8fps 零丢帧。
   只有"PC 实时驱动高帧率"才卡在链路上。

## 排查方法论 (下次省时间)

- **板内回环**是分离"栈/CPU"与"物理通路"的最快手段, 一条 python 就能测。
- **小包 vs 大流量分开测**: SSH banner 秒回但 1MB send 卡死 ⇒ 立刻定位到批量传输层。
- `socket.create_connection(addr, timeout)` 的 timeout **会作用在 send 上** ——
  测吞吐要 `connect` 后 `settimeout(None)`, 否则会把"链路慢"误报成"超时断开"。
- sink 要**循环 accept**, 否则就绪探测会把唯一的 accept 消耗掉。
