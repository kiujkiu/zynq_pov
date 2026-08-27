---
name: reference_dr1_wifi_ceiling_unestablished
description: DR1 那个 26.7/28.4 Mbps 是共享空口的坏测法(同法把 Zynq 也卡在 18/47); 载荷实测是一条 2.7-64.1 Mbps 的阶梯(跨内容差 24 倍), 正好压在未知数上 ⇒ 应该第一个复测
metadata:
  type: reference
---

# DR1 的 WiFi 天花板从未确立, 而载荷正好压在那个数上 (2026-08-26)

## 三个数字, 只有一个可信

| | 数字 | 口径 |
|---|---|---|
| DR1V90 | **26.7 / 28.4 Mbps** (CPU 仅 40-47%, 未饱和) | ⚠ **不作数** |
| Zynq-7020 **同一测法** | 18 / 47 Mbps | ⚠ 同上 |
| ~~Zynq 现役真实收包~~ | ~~24.7 MB/s ≈ 198 Mbps~~ | 🔴 **2026-08-27 更正: 那是突发窗口速率, 不是持续吞吐** |
| **Zynq 持续吞吐(改用这个做预算)** | **110-125 Mbps** | 500/300 MB 单流实测; 1/2/4/8/16 并发聚合 128/121/86/101/107 ⇒ **多流不涨** |

**为什么前两行不作数**: 那是 Windows 上单线程无 sendfile 的 Python `http.server`
+ **两端都在 WiFi 上共享空口**, 把两块板**同样**卡在 20-50 Mbps。
[[project_dr1_wifi_modules]] 自己就写了 "绝对吞吐数字仍未确立 —— 要可信的数必须用
iperf + 有线服务端 + 多次取分布"。**两块板用的是同一颗 MT7921AU**, ch149 HE-MCS9。

⚠ 别拿 Zynq 那个 198 Mbps 当 DR1 的预期 —— 它只证明"这颗 dongle + 这个 AP 能到那么快",
不证明 DR1 的单核 + dwc2 USB 控制器能喂饱它。

## 载荷要多少 —— ⚠ **口径已于 2026-08-26 晚重测, 下面这版作废**

~~WSL `python3-lz4` 单流实测 12.3× / 35.5× / 100.5×, 推出 7.85MB @ 11fps 需 **19-56 Mbps**~~
—— 那三个素材不是生产口径(其中一个是合成图案), 且**用的是 HC9 而生产早就是 HC12**。

**现行口径**: `dr1v90/measure/tools/measure_payload.py`, 真实渲染帧 + 生产配置
(3-bit + fold_a 213 片 + lz4-**HC12** + `--stream-split even --stream-workers 3`),
详见 [[project_dr1_measure_bench]]:

| 内容 | 压缩后/帧 | 压缩比 | @11 fps |
|---|---|---|---|
| colors8 / solidtop | 31 KB | 254× | 2.7 Mbps |
| **rgbhelix**(上电固化的空闲动画) | 142 KB | 55× | **12.5 Mbps** |
| bonsai_h | 227 KB | 34× | 20.0 Mbps |
| **cyl2** | **729 KB** | **10.8×** | **64.1 Mbps** ← 实测最重 |

🔴 **需求不是一个数, 是一条跨 24 倍的阶梯**(2.7 → 64.1 Mbps)。
另: 流传的 **22.8×/33.7×** 是 **1-bit 720 片 `frames_robot`** 的数, 3-bit 把位平面分开后
重复度高得多(实测 34-255×) —— **拿旧比例推链路需求会失真**。

## 🔴 结论

**DR1 那个未确立的 26.7/28.4 正好落在这条阶梯中间** ——
够 rgbhelix 和 bonsai_h, 不够 cyl2。
⇒ 用 **iperf + 有线服务端 + 多次取分布**复测 DR1 WiFi,
是 [[project_dr1_parity_plan]] 里**第一个该做的事**(`measure/03_wifibw/`, 15 分钟, 不用新 bit)。
判读: ≥130 后面照原计划 / 64-130 重内容降规格 / 25-64 **内容分档**(验收标准要写清用哪个内容) /
<25 🔴 链路成为新的第一瓶颈, 得先修链路再谈解码, 否则 B 线做完发现 fps 没涨。

⚠ 同时要防的老坑: **看 fps 永远看板端 DIAG 的 `flip`, 不是 PC 报的数**。
DR1 上撞过一次(PC 报 6.47 / 板上 `flip=5.00/s` 且 drop 持续累积, 差 29%),
Zynq 上也撞过([[project_pov3d_nslices_match_panel]]: RX 收到就 ACK, 与上不上屏无关)。
另注 WiFi 每 20-40 s 有 1-3 次 300-840 ms 的环境性停顿 ⇒ **每个配置只跑一次的数不可信**。

相关: [[project_dr1_wifi_modules]] [[project_dr1_parity_plan]] [[feedback_recv_setsockopt_rcvbuf_lock]]
[[feedback_wifi_throughput_bottleneck_isolated]] [[feedback_office_ap_blocks_esp32c5_tcp]]

---

## 🔴 2026-08-27 更正: 198 Mbps 不能拿来做预算

那个 24.7 MB/s 是**突发窗口速率**。**持续吞吐实测只有 110-125 Mbps**,
用 198 做链路预算会**乐观 1.6×**。本文之前(以及依赖本文的多处推算)都用错了口径。

🔴 **而且换更强的 PS 一分钱都买不到带宽**: 天花板在 **USB2.0 + mt76 驱动**, 不在 CPU ——
124 Mbps 传输时两个核**各 50% idle**, 而板内回环能到 1123-1238 Mbps。
XC7Z020 无 PCIe 无 GTP, 无线只剩 USB2.0(实用上限 280-320 Mbps)。
⇒ 链路不够时, **该换的是链路架构(传什么), 不是 PS 档次**。
