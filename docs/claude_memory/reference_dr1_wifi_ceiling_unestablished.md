---
name: reference_dr1_wifi_ceiling_unestablished
description: ✅ 2026-09-14 已实测确立 — DR1 WiFi iperf3 正向中位 64 / 反向 57 Mbps, 单核 CPU 88-100% 打满而空口 tx retries/failed=0 ⇒ 天花板在 CPU(内核 dwc2+mt76+TCP 路径)不在空口; 需求 D_typ 22(2×=44 ✅) / D_heavy 70(连 1× 都不够 ❌); 旧的 26.7/28.4 是坏测法
metadata:
  type: reference
---

# ✅ 2026-09-14 实测确立 (先读这一节, 下面 08-26 的内容是历史)

**装置**: 板 dr1a(wlan0 `90:de:80:47:b4:16`, ch149 80MHz HE, signal −34 dBm)跑 iperf3 服务端;
PC(Intel AX211, 同 AP 同信道, 链路 1201 Mbps)经 WSL 当客户端。⚠ **服务端没走有线**(用户选择) ⇒ 按 RUN.md 口径是"下限"。
板上 CPU 用后台脚本每 2 s 采 `/proc/stat` 写文件 —— 🔴 **跑流量时串口会被饿死**, 串口采样会拖到流量结束后才执行, 采到的是假空闲。
原始数据与脚本: `dr1v90/measure/03_wifibw/results/2026-09-14/`

| 方向 | 有效次数 | 分布 (Mbps) | 中位 | 板上 CPU busy |
|---|---|---|---|---|
| 正向 PC→板 (推流方向) | 10 | 24.9 / 55.8 / 59.3 / 62.7 / 64.1 / 64.5 / 67.0 / 70.3 / 72.8 / 73.2 | **64.3** | **88-98%** (sys 70-84%, softirq 13-21%) |
| 反向 板→PC | 8 | 45.1 / 53.7 / 57.2 / 57.4 / 57.5 / 57.8 / 58.2 / 58.4 | **57.5** | **96-100%** |

- 24.9 那次 CPU 只有 20-30% ⇒ 空口/环境停顿, 不是 CPU。
- 空口 `tx retries 0 / tx failed 0`, rx 1200.9 Mbps HE-MCS11 ⇒ **空口远没到顶**。
- 板内回环(同一 iperf3, 收发挤一个核)**333 Mbps**。
- 第一轮反向第 4 次时用户拔了充电头 ⇒ 板子重启, 那 2 次作废(日志 `iperf_run1_reboot_at_rev4.log`)。

🔴 **结论: DR1 WiFi 天花板 ≈ 60-65 Mbps, 卡在单核 CPU(sys 占大头 = 内核 dwc2+mt76+TCP 路径), 不是空口, 也不是 USB2.0 带宽。**
反向 57.4-58.2 极平 + 100% busy = 典型 CPU 墙 ⇒ **换有线服务端大概率涨不了多少**。
对比 Zynq 110-125 Mbps 且两核各 50% idle ⇒ **DR1 约为 Zynq 的一半**。

### 对照需求 (口径: `05_rxcap/RUN.md` §2, 2× 是因为一圈一帧的突发投递)
| 需求 | 1× | 2× 目标 | DR1 实测 64 |
|---|---|---|---|
| rgbhelix 空闲动画 @11fps | 12.5 | 25 | ✅ |
| **D_typ** = bonsai_h @12fps | 22 | 44 | ✅ 2.9× |
| **D_heavy** = cyl2 @12fps | 70 | 140 | ❌ 连 1× 都不够(@11fps 要 64.1 = 零余量) |

⚠ **iperf3 是只收不干活的理想负载**。真推流时同一个核还要跑 pov_rxd(收包 + 压缩流回写 + PL 调度)
⇒ **实际推流上限会低于 64**; 重内容必须降档, 验收标准写清用哪个内容。
🔴 更正(同日): 内核**不是** PREEMPT_RT —— SDK `.config` 是 `CONFIG_PREEMPT=y`(HZ=100), `-rt42` 只是 localversion 的名字 ⇒ 之前写的"换非 RT 内核"那条**作废**。
另查实: dwc2 硬件 `arch=2`(内部 DMA)且运行在 `host_dma=1`、`GAHBCFG=0x23`(DMAEn, HBstLen=INCR) ⇒ **不是 PIO 模式**。

本次顺带挖出的两个坑: 供电 [[feedback_dr1_wifi_dongle_brownout_reboot_loop]] / 量具 [[feedback_musl_static_pie_cjson_hooks_null]]

## 🎯 同日晚: CPU 瓶颈归因 (详细数据 `dr1v90/measure/03_wifibw/results/2026-09-14/ceiling_cpu_analysis.md`)

- **干净上限**(测量期间板上什么都不跑, 只读前后计数器): UDP 收包 **~11.3k pps ≈ 130 Mbps @100% CPU**; TCP PC→板 **65-73 Mbps @87-94%**。
- **成本按包不按字节**: MSS 1448 vs 536 每包 112 vs 125 µs ⇒ memcpy/校验/加密都不是大头; 纯收包路径 ~88 µs/包, TCP 再加 ~60 µs/包。
- **软件 CCMP 已排除**: 内核 aes-generic 用户态移植上板实测 **867 µs/包**(5.4 MB/s), 若真走软件只能收 ~1.1k pps; 硬件在解密。
- **运行时旋钮全无效**(3×20 s, ±10% 噪声内): power_save off / tcp_timestamps / rmem 8M 无变化; mt76 线程改 SCHED_OTHER **反而 −20%**。
- 🎯 **每 URB 恰好 1 次 dwc2 中断、每 URB 只有 1 帧; rx worker 每次唤醒已批处理 ~50 URB; ACK 仅 0.19/包; TX-status 控制读轮询只多 ~60 次/s(限速价值 ~2%)**。
- 🎯🎯 **MT7921AU 固件支持 USB RX 聚合**: debugfs regval 写 `WLCFG_1=0x10040002 / WLCFG_0=0x00f40202` ⇒ bulk-IN 平均长 1491→**2831 B**(max 3048=2×1524), dwc2 中断 **−43%**; 原版驱动每 URB 只解析第 1 帧所以包数减半; 写回 `0x00f40000/0x10040000` 完全恢复。⇒ **驱动解析多帧即可成倍摊薄每 URB 开销**, 这是最大的软件杠杆; 另一个是 mt76-usb 无 NAPI/GRO(`napi=NULL`)。
- 🎯 **USB RX 帧布局**(原版驱动 usbmon): 每帧占 **round_up(RXD0 len, 8) + 4** 字节 —— 🔴 **09-15 更正**: 我先写成 round_up(len,4)+8, 因为测的大帧(1513-1516→1524)两种算法恰好相同; 离线回放全部 1400 个样本, 新规律 1400/1400、旧规律 1389/1400, 所谓"+4 异常帧"正是 len%8∈{0,5,6,7} 的帧。**按错规律设的 rx_agg_tail=8 直接导致了板子卡死**, 见 [[feedback_dr1_experimental_module_hard_hang]]。⇒ 教训: **只用一种帧长测出来的规律不能外推, 要覆盖 len%8 全部余数**。
- 🔧 **已编好未上板的驱动补丁**(均只换 mt76-usb.ko, vermagic/CRC 全核过, 部署脚本失败自动回退原版, 重启即完全恢复): GRO(复用闲置 napi 字段)/ TX-status 轮询限速(价值 ~2%)/ 多帧解析 rx_agg(审查挑出 2 个 major 已修: 先校验整条帧链再投递+信任闸+分片重同步, 缓冲默认 8 KB)/ hrtimer PC 采样器 pcprof.ko。🔴 **上板加载内核模块被权限分类器拦下, 需用户明确同意**。
- ✅ **09-15 下午 rx_agg v3 + GRO + mt7921u disconnect 修复 按 RUNBOOK 上板: 功能/安全全过(step 1-6)**, 芯片寄存器仍是原版值(单帧/URB)。
  gro_fixB 与 gro_rxaggv3_fixB 都能在板上内核加载; v3 在 ~8.6 万 URB 流量里 errors/splits/resync 全 0、frames==urbs; 运行时开 multi_en 也无错。
  🔴 **吞吐收益仍未测出**: 当天 PC 那一跳 WiFi 拥挤(PC→网关 ping 均 17-59 ms), 各次 11-19 Mbit 且板子 CPU 只忙 18-38% ⇒ 路径受限, GRO/v3 与原版无法比较。
  下一步: 空口安静 + PC 与板同一 AP 时做 原版/GRO/v3 吞吐 A/B(busy≥85% 才算数), 再做 step 7(写芯片聚合寄存器, 需先改 aggctl.sh、测帧间距)。
  证据与产物: `dr1v90/measure/03_wifibw/results/2026-09-15/rxagg_v3_retest/`(README.md 为总结)。
- 🎯🎯 **09-15 晚 点对点实测真实上限**(PC 上插第二块 MT7921AU → usbipd 进 WSL → 自编 6.6.87.2 mt76 模块 + hostapd, 5 GHz ch48 80 MHz HE WPA2,
  板 STA −36~−42 dBm, PHY 960-1200 Mbit, ping 2.5 ms; 每组 3×20 s TCP PC→板, 板 CPU 全部 98-100% ⇒ 全是 CPU 受限的有效数):
  原版 **91.7** / GRO(gro_fixB) **95.5**(+4%) / v3 单帧(寄存器原版) **87.3**(−5%, 多一次拷贝) / **v3 + 芯片聚合 2帧 110.7**(+21%, 1.98 帧/URB); 板→PC 各组都 ~49。
  ⇒ 之前办公网测的 65-73 其实有空口限制。聚合时 v3 遇到"帧总长恰为 512 整数倍 + 4 字节零填充"(MT_WL_RX_MPSZ_PAD0)判坏链、丢帧致重传 85-126, 修复版 v3p1 在做。
  聚合 4帧/6KB(WLCFG_1=0x10040004, WLCFG_0=0x00f40602, AGG_LMT 单位是 KB): TCP **123.3**(+34%, 3.82 帧/URB, 但重传 350-507、CPU 92-96% ⇒ 被填充 bug 丢包限住);
  UDP 按数据报算板子接住 ~140 Mbit @97%。🔴 **这套直连台架 PC 端发送封顶 ~145 Mbit**(USB/IP 每帧一个 URB 经 Hyper-V vEthernet 往返, WSL CPU 不忙), >140 的板子能力测不了。
  板上 iperf3 3.10 服务端 UDP 字节统计是错的, 要按数据报数算。
  ✅ **修复版 v3p1**(解析器接受"帧链止于 maxp 整数倍 + 4 字节零"= MT_WL_RX_MPSZ_PAD0; 新计数 rx_agg_mpsz_pad; 主机测试 8/8、对抗审查 minor)
  + 聚合 4帧/6KB: **TCP 131.3 Mbit/s(130/132/132), CPU 100%, 0 重传, errors 0, +43% vs 原版**;
  + 聚合 5帧/7KB(WLCFG_1=0x10040005, WLCFG_0=0x00f40702): **TCP 136.0(136×3), CPU 100%, 0 重传, 4.72 帧/URB, +48%** —— DR1V90 单核直挂 USB 网卡目前实测最高值, 再加帧数收益递减。
  ⇒ 距 200M 还差 1.47×; 剩下的每包开销在 TCP 栈/拷贝/mac80211, 聚合摊不掉。汇总 `results/2026-09-15/tput_ab/README.md`。
- 🎯 **真实 pov_rxd 只收包(`--diag-rxonly`, 不解码不翻页, cyl2 284 片 ~981 KB/帧, 点对点)**: 原版驱动顶在 **~11.8 帧/s ≈ 95-98 Mbit/s(wlan0 链路层)** CPU 99%(与 iperf3 同水平);
  **v3p1 + 聚合 5帧: 12/14/16/18 帧/s 全跟上, 18 帧 = 147 Mbit/s CPU 95%**, 0 丢包 0 聚合错误; 每 Mbit CPU 10.2 → 6.5 ms ⇒ 推算顶 ~150-155(再高被台架 145 发送上限挡住)。
  完整路径(PL lz4 解码)被 PL 引擎 37 帧后失效挡住, 见 [[project_dr1_pl_decode_parity]]。数据 `results/2026-09-15/rxd_p2p/FINDINGS.md`。
- 🔎 **09-15 调研(源码 + 网上案例, `results/2026-09-15/opt_research/SYNTHESIS.md`)**:
  - 网传"DWC2 调 FIFO / 开 DMA 描述符 / 调中断亲和性"对 DR1 **基本无用**: `snps,fifo-size`、`CONFIG_USB_DWC2_DMA_DESC`、`snps,dma-desc-enable` 在 6.1 里**都不存在**; g-*-fifo-size 只在 gadget 模式读; host FIFO 已是硬件最大; 单核无亲和性可调; USB host 侧合计仅 ~12% CPU。DR1 dwc2 用通用 `snps,dwc2` 默认参数(INCR 突发, buffer DMA)。
  - 按预期收益排的软件杠杆(均推算, 未测): ① **wlan0 MTU 2304**(mac80211 上限, 包数 ÷1.55, 估 +25-35%) ② v3p1 **零拷贝**投递(现在每帧 memcpy 进新 skb, 估 +7-12%) ③ 信任 MT7921 硬件 RX 校验和(USB 路径上游被 mmio 判断关掉, 估 +3-5%, 有数据完整性风险, 需先做坏校验和实验) ④ 每 URB 更多帧(16 KB 缓冲, 估 +4-8%, 先读 dwc2 max_transfer_size) ⑤ TCP backlog ACK 延迟回移(0-5%) ⑥ pov_rxd 直收 CMA / 长期 UDP ⑦ 省 DMA cache sync(1-2%) ⑧ pollrl(2%) ⑨ hardened_usercopy=off 等(1-3%)。叠加纸面估 pov_rxd 只收包 200-235(增益不独立, 低置信)。
  - 外部: MediaTek 2026-06 上游已发 "mt76: add USB RX aggregation support"(仅 mt7927u, 无数据) = v3p1 的官方对应物; mt76u threaded NAPI 补丁的大收益来自多核; Douglas Anderson 2015-16 dwc2 提速已在 6.1 内。
  产物 `results/2026-09-15/rxagg_v3_retest/v3p1/` 与 `deploy/gro_rxaggv3p1_fixB/`(mt76-usb.ko 6e82fa99...)。
  结果目录 `results/2026-09-15/tput_ab/p2p_*`。WSL 侧坑: 内核直读固件走 VM 根目录, 要把固件放 /mnt/wsl/fw 并写 /sys/module/firmware_class/parameters/path; 自带 cfg80211/mac80211 与源码 CRC 不符, 整套无线栈要自编。
- 🎯 **T1(pov_rxd 型负载下的 TCP 上限)量法**: CPU 小偷(rxcap spin)无效 —— FIFO 网络线程会饿死普通进程, 链路不降速、小偷拿不到 CPU; 改用每收 1 MB 固定耗 CPU 的 TCP sink(ksink)。原版驱动: 额外 0/5/10/20 ms/MB ⇒ 83/73/73/51 Mbps ⇒ pov_rxd 估 16-25 ms/MB ⇒ **T1≈70-73, 正压在决策规则 70 Mbps 边界上**。
- 🔴 量具坑: 板上采样脚本(每 2 s fork)会把同一 12k pps 的收包从 ~11k 压到 7-8k; musl `sched_setscheduler` 是桩(SCHED_IDLE 静默退成 nice 19); Windows `Get-NetAdapterStatistics` 发包数比板子收到的还少(不可用); 跑流量时串口被 FIFO 网络线程饿死, 采样必须脱机写文件。
- 内核事实: `CONFIG_PREEMPT` 非 RT、HZ=100、-O2、无 FTRACE/KPROBES/PERF; dwc2 已是 DMA 模式; 板子原始 `tcp_rmem` = `4096 131072 3698272`; 主频 DT 实读 800 MHz。

---

# (历史) DR1 的 WiFi 天花板从未确立, 而载荷正好压在那个数上 (2026-08-26)

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
