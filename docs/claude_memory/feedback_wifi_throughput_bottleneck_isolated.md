---
name: 🔴 已推翻 — "WiFi 只有 20 Mbps" 的真因是我自己写的看门狗, 不是 USB
description: 看门狗拿 ping 网关当判据, 办公网网关不回 ICMP ⇒ 6 小时 3582 次重连; 停掉后 23→58 Mbps, 8 分钟零掉线
type: feedback
---

# 🔴 2026-08-04 晚 — 本文原结论被推翻, 先读这一节

**真因: 我自己 2026-08-01 写的 `wifi_watchdog.sh` 把链路每 15 秒拆一次。**

```sh
# /home/uisrc/wifi_watchdog.sh:49
[ -n "$GW" ] && ! ping -c2 -W2 "$GW" >/dev/null 2>&1 && reconnect "GW_DEAD($GW)"
```
拿 **ping 网关**当链路健康判据。**办公网网关不回 ICMP 是常态** ⇒ 每次都判"链路死了"
⇒ 重启 wpa_supplicant。日志坐实: 6 小时 **3,582 次 reconnect vs 3,566 次 OK**, 日志 647 KB。
dmesg 侧每 15-16 秒一次 `deauthenticating ... **by local choice**` —— **是板子自己断的,
不是 AP 踢的、不是信号差、不是转子遮挡。**

⚠ 而且**装了两个看门狗在打架**: `povwifi.timer`(15s, 我加的) + `wifi-watchdog.timer`(30s, 7/28 的)。
`povwifi.service` 长期停在 `activating (start)` —— 跟之前端口冲突那次一样, **状态不是 `failed` 所以不查就发现不了**。

## 停掉看门狗后的实测 (2026-08-04 12:13-12:16, 板子刚重启, povrxd 已停)

| 方向 | 结果 |
|---|---|
| PC→板 50 MB | **51.6 Mbps** |
| PC→板 100 MB ×2 | **62.9 / 58.5 Mbps** |
| 板→PC 100 MB | **46.9 Mbps** |
| **掉线事件** | **0** (8 分钟内只有开机那 2 次 USB 枚举 reset) |
| 传输时板子 CPU | **两核各约 50% idle** ⇒ 板端不是瓶颈 |

⇒ **23 → ~58 Mbps, 2.5×。仅仅是停掉看门狗。**

## 🔴 因此下面原文的核心结论作废

原文写"瓶颈是 mt7921u 驱动的 USB 批量传输实现"。**那次测出的 23.1/23.7 Mbps 是在
看门狗每 15 秒拆一次链路的情况下测的**(看门狗 8/1 部署, 测量 8/4)。TCP 拥塞窗口
根本长不起来, 且链路有一半时间是断的。**结论建立在被污染的测量上。**

⚠ 用户当时的质疑是对的: "USB 本该比 SDIO 快, 这应该是 bug" —— 确实是 bug, 而且是软件的。
**差点据此去买 SDIO 硬件(200 Mbps), 去替换一条本该 280-320 Mbps 的 USB 通路。**

## 🔴 看门狗的升级路径会把板子弄成不可远程恢复
```sh
if [ $n -ge 3 ]; then    # 连续 3 次修不好 → 重挂 USB PHY
    echo ci_hdrc.0 > /sys/bus/platform/drivers/ci_hdrc/unbind
```
unbind 后若没 rebind 回来, **WiFi 网卡整个消失, 只能物理重启**。2026-08-04 实际发生过一次。

## 处置 (已做)
`povwifi.timer/service` 与 `wifi-watchdog.timer/service` **全部 `disable --now`**。
⚠ 重做看门狗的话三条都得改:
1. 判据**不能用 ping 网关** —— 用 carrier + associated + 有 IP, 或探一个**确认可达**的 TCP 端口
2. 触发要**连续失败数分钟**, 不是 15 秒
3. **删掉 USB unbind 那条升级路径**

## 还没定的事 (别再overclaim)
~58 Mbps **是不是天花板、卡在哪一层, 仍未确定**。候选: mt76/USB、空口/AP 拥塞、
我这侧 WSL2 NAT。USB 2.0 高速实用值 280-320 Mbps, 所以 58 仍只有 ~20%, **可能还有空间**。
决定性实验(同口插 U 盘测裸吞吐)**仍未做** —— 板上当时没插 U 盘。

## 对项目的实际影响
- 现 PVS1 **720 片双面 @30fps 需 63 Mbps** ⇒ 58 Mbps 已接近, 帧率上限从 13 fps 抬到 **~27 fps**
- 🔴 **但解码接棒成为新瓶颈**: 双核并行 `dec_avg≈78-88ms/帧` ⇒ 只有 **11-12 fps**。
  见 [[project_pov3d_v31_dualface_geometry_solved]]。**下一步该打解码, 不是链路。**

## 顺带
- **静态 IP 10.10.21.250 又被 dhcpcd 推翻**, 板子实际在 `10.10.20.239` (dynamic)。
- 排查方法: plink 里 `nohup ... &` **起不来后台进程**(会话一退就没), 用
  `systemd-run --unit=xxx` 才可靠; 该板 `journalctl` 需要 sudo。

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
