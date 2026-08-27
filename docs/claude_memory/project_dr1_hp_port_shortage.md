---
name: project_dr1_hp_port_shortage
description: 移植 DR1 的头号架构问题 — Zynq 现役 4 个 HP 口全占满(面板1+lz4引擎3各独占), DR1 只有 2 个; 且 TD 没有 SmartConnect 对等 IP, N:1 汇聚要手写
metadata:
  type: project
---

# DR1 只有 2 个 HP, 而 Zynq 现役用满了 4 个 (2026-08-26 盘出)

> ✅ **本文是问题陈述; 解法已于 2026-08-26 当天定案, 见 [[project_dr1_hp_topology_decision]]**
> (方案 A: 面板独占 HP0@50M + 2 个 lz4 引擎 @100MHz 经 2:1 仲裁打 HP1)。
> 🔴 那份文档翻掉了本文下表里的一个 ❓: **DR1 的两个 HP 口在 DDRC 之前就合流成单条 `HP_BUS`**
> ⇒ "口分开"在 DR1 上买不到 DDRC 级隔离, 只买到 AXI 通道级隔离(而那才是当年 HDMI 变噪点的真病根)。
> 另外查实 **HP1 在当前 PS IP 里根本没生成出来**, 要用 TD 重新生成 PS IP 才有第二个口。
> 本文以下内容保留供追溯, **带 ❓ 的两行已被上述文档取代**。

这是 [[project_dr1_parity_plan]] v2 的头号问题。**v1 时代不存在** —— 那时 Zynq 也只用 1 个 HP。
是 2026-08-25 Zynq 上 PL lz4 三引擎落地之后才出现的新约束。

## 现状对照

| | Zynq-7020 现役 (2026-08-25) | DR1V90 |
|---|---|---|
| HP slave 口 | **4 个** | **2 个** (64-bit) |
| 面板 `ddr_slice_fetch256` | HP0 独占, **纯读** 110.8 MB/s, 32-bit | 占 1 个 |
| lz4 引擎 | HP1 / HP2 / HP3 **各独占一口** | 三个引擎的读+写要挤进**剩下那 1 个** |
| 出处 | `mlkpai_fs03/vivado/create_panel_proj_v6.tcl:73-105`; `set NENG 4` / `HP_ORDER {3 1 2 3}` | [[reference_anlogic_dr1_fs03_eval]] §3 (厂商文档: 2×GP master + 2×GP slave + **2×HP slave 64bit**) |

## 🔴 "每引擎独占一口" 是设计理由, 不是随手分的

`create_panel_proj_v6.tcl:65-67` 明确写着前车之鉴: **NUM_SI=8 挤在一个 axi_smc 上打 HP1,
单独跑每个都对, 一起跑 HDMI 变噪点** —— [[feedback_pov_4x_ip_breaks_hdmi]]。
⇒ DR1 上被迫回到的, 正是那个在 Zynq 上被否决过的拓扑。

## Zynq 为什么没炸, 以及这些理由在 DR1 上还剩几分

2026-08-25 上板实测 (commit `7efe755`): 三引擎全速打 DDR 后 **`pair_miss` 仍是 0.0/s**。
当时的风险推断被实测站住了:

| Zynq 成立的理由 | DR1 上还成立吗 |
|---|---|
| 面板在 **HP0 独占口**, 且纯读 | ❌ 面板仍纯读, 但只剩 2 个口, 拓扑余地小得多 |
| DDRC 入口有 3 个 {HP0}/{HP1,HP2}/{HP3} ⇒ 写流量能 2:2 摊开 (AMD 文档: "HP1 and HP2 shares one DDR input port") | ❓ DR1 的 DDRC 入口拓扑**没查过** |
| DDRC 拥塞时**读优先于写** ⇒ 面板是被偏袒的一方 | ❓ 安路 DDRC 仲裁策略**没查过** |

## 带宽账【推算】

三引擎 @50 MHz × 0.95 B/clk ≈ **142 MB/s 写** + 面板 **110.8 MB/s 读** ≈ **253 MB/s**,
全压在 2 个 64-bit 口上。
🔴 **DR1 的 HP 实际可用带宽零实测** —— 这条论证整个悬在一个没有的数上。

## 工具链缺口

**TD 没有 `smartconnect` / `axi_protocol_converter` 的对等 IP**(未查证安路自家有没有替代)。
Zynq 上白拿的 N:1 汇聚 + 位宽转换, DR1 上要手写。
现有 `dr1v90/rtl/axi4_to_axi3_hp.v`(231 行, 过了 11 档仿真回归)**是只读的** ——
lz4 的**写**通路要新写一份。

> ✅ **已做**: `dr1v90/rtl/axi_hp_arb.v`(约 390 行, N:1 + 位宽适配, 仿真 7/7 + 变异 7/7)。
> 🎯 **且"新写一个 AXI4→AXI3 写桥"这件事查下来不用做** —— Zynq 的 `lz4_engine_axi.v` 壳
> 已经是 64-bit 且已把写攒成 ≤16 拍 INCR 突发(`WPACK_N=16`, 就是因为 AXI3 的 AWLEN 只有 4 bit),
> 剩下只是位宽裁剪, 已并进仲裁器。工作量从"新写一个桥"降成"接上去"。

⚠ Zynq 侧还有一条相关实测值得知道: 把独占口的 SmartConnect 换成 `axi_protocol_converter`
(1:1 直通不需要交叉开关), **LUT 12432→8010, WHS 0.010→0.020**。
但 4 引擎版时钟网 fanout 8726→17092 而 **WHS 纹丝不动** ⇒
"fanout↑ ⇒ 偏斜↑ ⇒ WHS↓"这个因果**至少不完整, 别当定律用**(commit `970edce`)。

## 三条出路 (按代价排序, 都没验证过)

1. 降 `n_slices` / 继续用 fold_a ⇒ 载荷小了, 引擎数可从 3 降到 2 甚至 1
2. 引擎输出不落 DDR, 改由面板直接从 PL 片上取 ⇒ 架构改动大, 但把写流量整个干掉
3. 接受更低 fps

## 判据

上板后 **`pair_miss`(读 `0x1C`) 必须保持 0**。
🔴 但注意 [[feedback_pair_miss_sentinel_was_broken]]: 那是 **16 位计数器且只有 PL 复位能清**
⇒ **只能冷启动后测增长率**, 读绝对值会被饱和值骗。

相关: [[project_dr1_parity_plan]] [[project_lz4_pl_decoder]] [[project_dr1_pl_decode_removes_both_walls]]
[[reference_anlogic_dr1_fs03_eval]] [[project_dr1_soc_step1_done]]
