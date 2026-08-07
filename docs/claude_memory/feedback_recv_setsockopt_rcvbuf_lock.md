---
name: 🎯 15 fps 达成 — 收包慢的元凶是 setsockopt(SO_RCVBUF) 自己 (2026-08-06)
description: 板端设 SO_RCVBUF 会置 SOCK_RCVBUF_LOCK 关掉内核接收窗自动放大, 窗口钉死 32844B; 删掉后收包 2.83→24.7 MB/s, 上屏 flip 中位 15.00/s
type: feedback
---

2026-08-06, 分支 `feature/recv-gap` commit `7e7773e`(已合入 `feature/icnd2260-dualface`)。
上位: [[project_pov3d_link_budget_status]](余量表) / [[feedback_lz4_onboard_reality_check]](上一轮实测)。

## 🔴 根因: 调 setsockopt(SO_RCVBUF) 这个**动作本身**

`pov_rxd` 为了"一帧 272 KB 得装得下"去 `SO_RCVBUFFORCE` 768 KB。副作用:
内核给 socket 置 **`SOCK_RCVBUF_LOCK`** ⇒ 接收窗自动放大 (DRS, `tcp_rcv_space_adjust`)
**整个关掉**, 窗口永远钉在握手时算出的 `window_clamp` 上。吞吐 = 在途窗口 / RTT。

板上 `ss -tim` 直接量到 (netem 造 30 ms RTT, 同一个 povstream, 交错跑):

| | `rcv_ssthresh` | 8 s 收到 |
|---|---|---|
| 设 768 KB | **恒 32844 B** (t=8/16/24 s 一模一样) | 8.06 MB |
| 不设 | 657886 B (`rcv_space` 557792) | **58.57 MB (7.3×)** |

`32844 B / 30 ms ≈ 1 MB/s` —— 这就是长期那个"3 MB/s / 收一帧 96 ms"的出处。
⇒ **默认不再设 SO_RCVBUF**, 交给内核 DRS。`--rcvbuf N` 只留作 A/B 复现老行为。

## ✅ 定稿实测 (5×20 s, 900 RPM = 15 rev/s, fold540 + lz4-HC9 + 3 流)

```
上屏 flip  中位 15.00/s   p5 11.14  p95 15.00  σ 1.36   ← 15 fps 目标达成, rx==flip 一帧不浪费
body 20.95 ms (13.3 MB/s)      fps=40 时 11.30 ms (24.7 MB/s)
dec 24.90 ms   cpy 26.10 ms   hdr 19.65 ms(发送端按 15 fps 主动空转)
```
收包余量 **0.4× → 3.5×**。下一个瓶颈是 flip 线程的 **cpy + wait**。

## 🔴 两条被推翻的旧经验 (代码注释里写错过)

1. **"抬 `net.core.rmem_max` 是最大收益"** —— 错。出厂 176 KB 确实小于一帧 272 KB,
   但抬完交错 A/B **帧率没有可复现的提升**。真问题是上面那个 lock。
2. **"`--fps` 设高于转速, 让逐帧 ACK 自己贴住翻页率"** —— 链路修好后**反了**。
   发 40 板端能解 22 帧/s, 但**每圈只翻得动 1 帧 ⇒ 上限 = 转速 15**, 多解的 7 帧
   白解还要和 flip 线程抢 DDR。交错 A/B 4×20 s: **fps=40 → 12.99 / fps=17 → 13.99 /
   fps=15 → 15.00**(效应量 1.43)。⇒ **`--fps` 就设成转速。**

## 归因阶梯的方法本身值得复用 (`tools/host/rxgap_*.py`)

一样一样加回去 + **交错跑** + 全取中位数, 逐个排除:
- 不是 CPU: 板上跑满 2 核 6.99 vs 空闲 6.78 MB/s
- 不是 PL 抢 DDR: 引擎 15 rev/s 6.93 vs 引擎停 7.13 MB/s
- 不是频段: 2.4G ch6 (PHY 286) 与 5G ch149 (PHY 1200/80MHz) 交错上屏**都是 13.00 帧/s**
- 不是发送端: povstream 是预压缩的, HC9/HC6/HC3 上屏 8/8/7 帧/s
- **就是接收端**: 同一 povstream 同一链路交错喂两个 sink —— Python 最小 PVS sink
  7.75/6.59/4.44 MB/s, C 写的 `pov_rxd` 只有 2.76/2.12/1.73 MB/s。
  **C 比 Python 慢 3 倍, 差别只在那一行 setsockopt** ⇒ 一步锁定。

⚠ 单次 20 s 窗口在这条 WiFi 上能在 8.0 与 12.0 帧/s 之间跳, **同配置**。
所以一律用 `tools/phase_ab.py` 交错 A/B/C + 报中位数/p5/p95/σ, 见 [[feedback_phase_lock_premise_wrong]]。

## 新增工具
`tools/phase_ab.py`(交错 A/B/C 测量台) / `tools/phase_bench.py`(同配置 N 次报分布) /
`tools/host/rxgap_{sink,send,ladder}.py` / `tools/host/wifi_band.sh`(板端切频段, 带无条件解钉定时器) /
`pov_rxd --diag-rxonly`(收完立刻 ACK, 不解码不翻页) / `pov_rxd --rcvbuf N`(生产别用)。
