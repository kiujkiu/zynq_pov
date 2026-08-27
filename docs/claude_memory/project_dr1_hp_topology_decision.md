---
name: project_dr1_hp_topology_decision
description: DR1 HP 拓扑定案(方案A) — 面板独占 HP0@50M + 2 个 lz4 引擎 @100MHz 经 2:1 仲裁打 HP1; 关键发现是两个 HP 口在 DDRC 前就合流成单条 HP_BUS; 08-27 仲裁器过 TD + HP1/p2f_clk1 已接出, 但 PS 侧寄存器那一半还没上板
metadata:
  type: project
---

# DR1 HP 拓扑定案 (2026-08-26, commit `70c0dde`)

[[project_dr1_hp_port_shortage]] 提的问题在这里收口。完整论证 `dr1v90/docs/hp_topology.md`。
每个数字都标了出处: `[厂商]` / `[推算]` / `[仿真]` / `[实测]`。
🔴 **文档里没有一个数字来自 DR1 板上** —— 厂商 DS1200 表 3-34 的 HP 带宽栏自己写 **TBD**。

## 🔴 最关键的发现: 两个 HP 口在 DDRC 之前就合流了

厂商架构图 (DS1200 图 2-2) 画的是 `Slave AXI HP ──→ HP_BUS ──→ DDR Controller`,
**只有一条 HP_BUS**。而 Zynq 的 4 个 HP 对应 DDRC 的 **3 个独立入口**
`{HP0}/{HP1,HP2}/{HP3}` —— 那正是现役 `create_panel_proj_v6.tcl` 挑口的依据。

⇒ **在 DR1 上"给每个主一个独立口"买不到 Zynq 那种 DDRC 级隔离。**
口分开仍然值钱, 但值钱的地方换成 **AXI 通道级隔离**(各自的 AR/R/AW/W/B 与各自的 ready 反压) ——
而这恰恰才是 [[feedback_pov_4x_ip_breaks_hdmi]] 那次"8 个主挤一个 SmartConnect ⇒ 画面变噪点"
真正的病根: **头阻塞, 不是 DDRC 入口**。所以口分开依然对, 只是**理由要换一个**。

⚠ 效力边界: 这是**框图级**证据不是寄存器手册级的, HP_BUS 内部可能仍是多通道。
但它足以说明**不能按 Zynq 的类比假设 DR1 的口是隔离的**, 而那个假设是整套设计理由的基础。
这条如果错了, 方案 A 只会更好不会更差(按最坏假设设计的)。

## 方案

**✅ A (定)**: 面板 `ddr_slice_fetch256` 独占 **HP0@50MHz**; **2 个 lz4 引擎 @100MHz** 经
2:1 仲裁打 **HP1@100MHz**。

- 2 个够的支点: 需求 7.85 MB ÷ 62 ms = **126.6 MB/s**`[推算,输入实测]`;
  引擎 @100M = 0.95 B/clk × 100M = **95 MB/s** 每个 ⇒ 2 个 = 190, 余量 **50%**。
  @50M 要 3 个才够(142.5, 余量仅 13%)。
- 🎯 **100 MHz 几乎不要 CDC 代价**: `slave_hp1_axi_aclk` 是**每口独立的时钟输入**`[厂商]`
  ⇒ lz4 子系统与 HP1 **一起**放 100M 域, **数据通路上一个跨时钟都不需要**,
  只有 AXI-Lite 控制寄存器要跨。`P2F_CLK1_DIV` 已透到硬核, 源约 399.96 MHz ÷4 = **99.99 MHz**。
- 代价: ERAM 2×28 + 36 = **92/280 = 33%**; lz4 核 @100M Fmax **113 MHz**`[实测]` 只剩 13% 余量,
  🔴 那是**核单独综合**的数, 集成后必降, **别拿 113 当承诺**。

**🔶 C (退路)**: 3 引擎 @50M, 3:1 打 HP1@50M。与 A **只差两个参数**
(`P2F_CLK1_DIV` 8 而非 4, `N` 3 而非 2), **RTL 一行不用改**。lz4 在 100M 收敛不了就退这里。

**❌ B (否决)**: 4 个主挤 HP0。正面重演头阻塞结构, 收益只是省一次 wrapper 编辑, 占用 65%。
**❌ 用 GP slave 分流**: GP 是 **32-bit**`[厂商]`, 带宽减半且与 CPU 同路。

**📌 降 `n_slices`**: 不作主方案, 但留作上板降级档 —— 213→160 ⇒ 2 个引擎 @50M 就够。
**先用这档把屏点亮把通路跑通, 再提频加引擎**, 可以把"接屏"和"提性能"解耦。

## 🔴 HP1 在当前工程里根本没生成出来

`RISCV_Processor_System_*.v` 里 HP1 每根线都硬接常量(`:229` aclk 接 `1'b0`,
`:252` wdata 还是 **32 位**而 HP0 是 64), 外层 wrapper 里 `slave_hp1` 一个字都没有。
~~⇒ 必须用 TD **重新生成 PS IP**, 光改 wrapper 不够。~~
🔴 **2026-08-27 证伪**: 手改那两个 `.v` 就够了(`tools/ps_enable_hp1.py`), TD 综合到 bitgen
全过、`GEN_PL_HP1` 时钟域已出现。见下面「HP1 与 p2f_clk1 已接出」。排期 +2~3 天那条取消。
⇒ "DR1 有 2 个 HP 口"在**芯片层面**成立, 在**改之前的工程层面**只有 1 个 —— 现在两个都有了。

⚠ 好消息: 硬核 `DR1_PHY_PROCESSOR_SYSTEM` 的参数表里**没有任何 HP 使能参数**
⇒ `Slave_AXI_HP1_Interface` 只是 GUI 生成器的开关, 不是硬核门控。

## 交付的 RTL: `dr1v90/rtl/axi_hp_arb.v` (约 390 行)

两个让它变简单的设计决策:

1. **一主一个固定 AXI ID**(HP 口 id 6 bit`[厂商]`)。AXI 保证**同 ID 按序返回**
   ⇒ 不要重排序缓冲、不要 ID 映射表; 不同 ID 允许乱序 ⇒ 慢的主堵不住快的主。
   R/B 退化成按 id 的纯组合 demux。
2. **W 通道由 AW 授权顺序 FIFO 驱动**, 不是"谁 wvalid 先到转发谁" ——
   DR1 的 HP 口**没有 WID**`[厂商]` ⇒ 写数据必须严格按 AW 顺序。最容易写错的地方。

位宽适配(`len` 8→4 / `size` 3→2 / `addr` 32→33)也在本模块吃掉 ⇒ **N=1 时退化成纯位宽适配器**,
单引擎调试与多引擎生产同一份代码。契约违反走粘滞标志不静默算错; 另有 `r_stall_cnt`/`w_stall_cnt`。

🎯 **写通路桥比原计划小得多**: Zynq 的 `lz4_engine_axi.v` 壳已经是 64-bit 且已把写攒成
≤16 拍 INCR 突发(`WPACK_N=16`, 注释写明就是因为 AXI3 的 AWLEN 只有 4 bit)
⇒ **不用新写 AXI4→AXI3 写桥**, 只剩位宽裁剪。工作量从"新写一个桥"降成"接上去"。

## 回归 (`make -f Makefile.arb`, 2026-08-27 复跑一致)

功能 7 档(ideal/r33/w/slow/hell/ooo/lat) + N=1/2/3/4 **全 PASS**;
变异注入 **7 个 bug 全被抓到**。
🔴 **bug3(`m_rready` 恒取主 0) 在恒 ready 下是 PASS**, 只有 33% 反压才炸 ——
又一次印证 [[feedback_always_ready_tb_hides_handshake_bugs]]。

判据不是"没挂死": 每主读数据逐拍等于**它自己区间的地址** / 写数据收尾**回读比对** /
每主 **B 数恰好等于 AW 数** / 拍数一个不多不少 / `rlast` 落在正确的拍。

带宽`[仿真]`: N=3 时读/写各 **210.9 MB/s** 且**对 DDR 首拍延迟完全不敏感**
(一个主等 AR 往返时别的主在填空) ⇒ **仲裁器本身不是瓶颈**。
模型可信度的独立佐证: N=1 时复现了 `axi4_to_axi3_hp` **板上量过的**曲线形状
(MAXO=1 在 ARLAT=25 掉到 95.4, MAXO=2 几乎不掉 —— 实测是 176→106 / 185→170, 同形状同量级)。

## ✅ 2026-08-27 落地: 仲裁器过了 TD, HP1 也接出来了

### axi_hp_arb 综合表征 (`td_arb/build.sh`, DR1V90GEG484 -2, **100 MHz 约束**)

| N | SWNS @10ns | HWNS | Fmax | lut6 | reg | slice | eram |
|---|---|---|---|---|---|---|---|
| 1 | +6.135 | +0.021 | 258.7 | 130 | 253 | 162 | 0 |
| **2 (方案A)** | **+4.291** | +0.034 | 175.2 | 161 | 272 | 182 | 0 |
| 3 (方案C) | +4.455 | +0.088 | 180.3 | 193 | 289 | 203 | 0 |
| 4 | +4.967 | +0.021 | 198.7 | 188 | 296 | 204 | 0 |

🎯 **方案 A 的 100 MHz 假设成立**, N=2 余量 **43%**, 仲裁器不是瓶颈; 资源约 0.35% slice / 0 eram。
⚠ 含 harness(128 reg + XOR 树), 是上界。⚠ **Fmax 随 N 上升是布局噪声不是趋势**(才 200 slice)。
⚠ 单独综合的 Fmax 集成后必降 —— lz4 核那个 113 MHz 是前车之鉴。
⚠ 本文 §7 原写"模块里用了 `$clog2`" —— **是错的**, 代码里根本没用。

🔴 过程中撞到只有综合能抓的真 bug(`len_err` 多驱动), 见 [[feedback_only_synthesis_catches_it]]。

### HP1 与 p2f_clk1 已接出 —— 但「纯 wrapper 编辑」只是一半

**不用重新生成 PS IP。** `tools/ps_enable_hp1.py` 从同一文件里的 HP0 段做 `hp0→hp1`
文本变换生成 HP1 段, 再与 `td_pov/ref_hp1_2025.1/`(2025.1 生成器开着 HP1 真跑出来的产物,
**全世界没有第二份**) 逐根对账。
🔴 **只能逐根当对照, 不能整份替换**: 去掉 HP1 后两边 76 根端口逐字一致, 差异恰好三条 ——
只在本工程的 `.CPU_Dot_Actual_IO_Frequency(799.92)` 与 `.p2f_clk0_1st_Divisor(P2F_CLK0_DIV)`
【**屏的 50 MHz 靠它**】, 只在参考版的 `.Slave_AXI_HP1_DATA_WIDTH(64)`;
且参考版例化硬核**一个参数都不传**。整份换 = 屏的时钟当场变。

**五条判据全过** (`measure/01_hpbw/build.sh 1`): HP0/HP1 归一化后逐字相同 / 信号名集合与
厂商产物逐个相同(38) / iverilog 连硬核 elaborate 零输出 / 综合日志里 HP1 警告集合与 HP0
逐条相同 / **area 报告出现 `GEN_PL_HP1`(74 LUT, HP0 是 71)**。
`GEN_PL_HP1` 这个名字原先是构词法猜的(TD 全安装目录 grep 零命中), 现在实证。
生产工程 `td_pov` 加 HP1 整口 tie-off 后重建, **每项数字与 A 线那次逐字相同, 零回归**。

🔴 **PS 侧还必须写寄存器, 不写的话综合全过、上板 HP1 静默不应答**:

| 寄存器 | 位 | 作用 |
|---|---|---|
| `0xF8801078` | `[1]=1` | 释放 HP1 复位 (`nic_hp1_srst_n`) |
| `0xF8800084` | `[1]=0` | 选 64 位 (`wmode_hp1`) |
| `0xF880103C` | `[13:8]=div−1` | `p2f_clk1` 分频 🔴 **只改这 6 位**! 整字写会带走 `[5:0]` 的 `div_fclk0` = 屏在用的 `p2f_clk0` |
| `0xF8806330` | `[7:4]` | 四路 `p2f_rst_n` 闸门 ⚠ 只有二手出处, 且 **`hpf_config.json` 里 grep 零命中 ⇒ `BOOT.bin` 永远不写它, 必须软件自己写** |

⚠ **这四个寄存器一个都没在板上写过。** 上面全部验证都在 PL 侧。

🔴 五条判据全过之后另跑的独立审计**逮到四个真缺陷**(其中一个"会烧板/挂死"级) ——
见 [[feedback_differential_criterion_blind_to_common_mode]]。**判据全绿不等于没问题。**

---

## 诚实的空白

1. 🔴 **DR1 的 HP 口实际带宽零实测** —— 见 [[project_dr1_measure_bench]] 的 `01_hpbw`
   (阶段 2 双口并发已经能跑了, `hpbw dual`)。
2. `HP_BUS` 单入口只有框图级证据。
3. **QoS 语义未知**: 手册只说"支持", 没说数值怎么解释。`axi_hp_arb` 已把 QoS 参数化,
   上板真出 `pair_miss` 时第一件要试的就是把面板的 `arqos` 拉高 —— **当旋钮试, 别当保证**。
4. **DDR 到底 1066 还是 1333**: 芯片手册 vs 板卡资料冲突(同类前科: dts 写 600MHz 实为 800),
   上板读回再定稿。按 1066 算是保守的。
5. ~~`axi_hp_arb` 没过 TD 综合~~ ✅ 已补, 见上; `$clog2` 那条是错的(没用过)。

相关: [[project_dr1_hp_port_shortage]] [[project_dr1_parity_plan]] [[project_lz4_pl_decoder]]
[[project_dr1_measure_bench]] [[feedback_pov_4x_ip_breaks_hdmi]]
[[feedback_always_ready_tb_hides_handshake_bugs]] [[feedback_verdict_design_before_blaming_dut]]
[[feedback_pair_miss_sentinel_was_broken]]
