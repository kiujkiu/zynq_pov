---
name: project-m90-wifi-p2p-1012
description: "2026-10-12 ARM 主控 DR1M90 点对点 WiFi 实测: TCP 推流方向 ≥160 Mbit/s (台架封顶, 板子 CPU 未满), 真实推流 CPU 路径 45 fps/68 Mbit, PL lz4 13.8 fps; 对显示带宽已不是瓶颈"
metadata:
  node_type: memory
  type: project
  originSessionId: 8546d15b-e447-401c-ad29-dcf7e23adf7b
  modified: 2026-10-12T08:09:22.632Z
---

台架: WSL 点对点 (第二块 MT7921AU 当 AP, ch48 80 MHz HE), 板 −40~−44 dBm, PHY 720/960 Mbit, MTU 1500, 空口重传 0。数据 ~/pov_work/wifibw/2026-10-12_p2p/。

- **TCP PC→板 (推流方向) 159/159/160 Mbit/s**, -P 2/4 合计仍 158 ⇒ 卡在台架, **不是板子上限; 板子 ≥160**。此时 CPU0 70% (USB IRQ 22 ~18k/s + TASKLET 全在 CPU0), CPU1 60%。
- 记忆里"台架封顶 145"已过时: 这次台架 UDP 实发 171–174 Mbit/s。UDP 180 档板 wlan0 收全 305k 包, 丢包全是 iperf3 的 RcvbufErrors ⇒ 驱动+协议栈 ≥171。
- TCP 反向 (板→PC) 109, CPU 未满, 原因未查。
- RPS (rps_cpus=2) 把 NET_RX 搬到 CPU1; TCP 看不出差别 (台架封顶), UDP 收 133→146 (+10%)。已恢复 0。
- 真实推流 (helix 3-bit 双面 ~187 KB/帧, 不限速, 假转 16.15 rps): CPU 解码 **45.6 fps / 68 Mbit**, CPU0 97.5%; PL lz4 **13.8 fps / 20.9 Mbit** (PL 串行 71.7 ms/帧); 只收包 102.5 fps / 153–156 Mbit。屏上翻页受转速限 (每转一次) ≈ 14–16 次/s。
- 对照 RISC-V DR1V90: 原版 91.7 / 优化 136, CPU 打满 ⇒ **ARM 板明显更强**。

**结论**: 目标板走"传体素表"只需 31–62 Mbit/s (见 [[project-target-35hz-budget-recheck]]), ARM 板 ≥160 ⇒ **WiFi 带宽对显示已不是瓶颈**。200 未实测坐实 (按 CPU 余量粗推约 200), 要坐实需更快发送端 (原生 Linux 或有线+AP)。真实推流的瓶颈是 CPU 解码 / PL lz4 串行 / 转速。

**Why:** 用户问"换 ARM 芯片后 WiFi 能不能到 200"。
**How to apply:** 再讨论 WiFi 时以本条为准; WSL 点对点台架换 IP-guard 内核后失效 ([[project-ipg-wsl-kernel-switch]]); 推流结束后 pov_rxd 会留下 pov_en=1/fake_en=1, 要手动写 0x80000010=0x008E0004 关掉。
