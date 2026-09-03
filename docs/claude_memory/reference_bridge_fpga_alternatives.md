---
name: 桥片 FPGA 五家候选横向对比 (高云/紫光/AMD/Lattice/Efinix) — 候选 + 复核汇总 (2026-09-03)
description: 转子侧串化桥的 FPGA 选型: 五家各出一颗候选并经独立复核, 按"真差分対≥93 / VOCM 1.1~1.3 / 输入≥800Mbps / gearing≥8:1 / LUT6-eq≥10k(18k) / 封装≤19×19"逐条打分; 国产口径推 GW5A-LV60UG324S(110対, 8:1~16:1), 非国产口径推 XC7S50-CSGA324(100対, 本机 Vivado 已装但 0 现货); Lattice 全家因真対≤66 出局; 附核实/未查到清单与候选-复核矛盾原样保留
metadata:
  type: reference
---

# 桥片 FPGA 候选横向对比 — 五家候选 + 复核 (2026-09-03)

**背景**: 见 [[project_pov3d_bridge_architecture]] (架构) 与 [[project_eg4_bridge_verification]] (EG4 实测三条零余量)。
本篇是五个并行查证 (每家一颗候选) 与五份独立复核 (只复核"五个要害数": 真対 / LVDS 出 / VOCM / gearing / LUT) 的汇总。
**汇总规则**: 数值一律以复核确认为准; 复核改过的地方在 §⑤ 原样列出候选原文与复核原文, 不替用户裁决; 价格 / 工具链 / license 类字段复核**没有碰**, 只是候选单方查证。

## 0. 口径 (评分标准, 与任务书一致)

| 项 | 门槛 | 备注 |
|---|---|---|
| 🔴 真差分対 | **≥ 93** (12-bit 口径: 73 出 + 20 入) | 仿真 LVDS (LVCMOS+电阻网) 单独标, 不算真対 |
| LVDS 输出 | ≥ 340 Mbps, **VOCM 落在 1.1~1.3 V** (报 min/typ/max) | 24 颗 ICND2260 mini-LVDS 340 Mbps 双沿 = 170 MHz |
| LVDS 输入 | ≥ 800 Mbps, 源同步, 需 ISERDES/IDELAY | **gearing ≥ 8:1 是加分项** (4:1 ⇒ fabric 200 MHz, EG4 实测只余 2%) |
| 逻辑 | ≥ 10k LUT6 当量 (优化后) / ≥ 18k (现役代码直接放大) | 换算 LUT4 ÷ 2.3, LUT5 ÷ 1.5, ALM ≈ 1.2 LUT6 |
| 块 RAM | ≥ 200 Kb | |
| 封装 | ≤ 19×19 mm, pitch ≥ 0.8 mm | pitch 非硬约束 (屏板已是 HDI) 但要报 |
| 不要 | CPU / DDR / SERDES / PCIe | 有也不加分 |
| 工具链 | Windows 无头 (命令行) 能否跑; license 免费与否 / 价格 | |
| 其它 | 国产与否 / 供货渠道 / 公开价格 | 没有就写没有 |
| 对照物 | **PH1A60GEG324**: 70,848 LUT4 / 100 真対 / 15×15 BGA324 0.8 / ERAM 3,160 Kb / LVDS 1250 / VOCM 0.9/1.25/1.4 / 无 DDR 无 SERDES | 第一行 |

## ① 总表 (复核后数值)

| 型号 | 国产 | 原生逻辑 | LUT6-eq | 真対 | 仿真対 | LVDS 出 / 入 (Mbps) | VOCM min/typ/max (V) | gearing | 封装 | BRAM | 工具链 / license | 价格线索 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **PH1A60GEG324** (对照) | 是 (安路) | 70,848 LUT4 | 30.8k | 100 | — | 1250 / 1250 | 0.9 / 1.25 / 1.4 | (未给, 待问 FAE) | 15×15 BGA324 0.8 | 3,160 Kb | TD, license 按 DR1 拿 | 未知 |
| **GW5A-LV60UG324SC2/I1** (高云 Arora V, 22nm) | 是 | 59,904 LUT4 | 26.0k | **110** (112 差分対, 2 対在 JTAG Bank12 只能输入/ELVDS) | 2 | **2000 / 1600** (OSER8 2000, IDES8 1600; 4:1 只到 800) | **1.125 / 1.25 / 1.375** (表不分 bank, 无 MINILVDS 单独行) | **8:1 ~ 16:1** (IDES 1:2/4/7/8/10/14/16/32/64, OSER 2/4/7/8/10/14/16:1) | UG324S 15×15 0.8 | 2,124 Kb | Gowin EDA `gw_sh.exe x.tcl` 无头; 标准版 license 免费 (MAC 申请, 一年一续); 教育版不含此 PN | **未查到** (Mouser/LCSC 无 GW5A-LV60 条目; 同系 GW5A-25UG324 ~$40@119 仅搜索摘要) |
| **PGL22G-6IMBG324** (紫光同创 Logos, 40nm) | 是 | 17,536 LUT5 | **11.7k** (÷1.5) / 9.1k (按厂家 1 LUT5=1.2 LUT4 再 ÷2.3) | **120** (6 bank × 20 対, 逐球) | 0 | **800 / 800** @-6 (-5 只有 680) | LVDS25 **1.0 / 1.25 / 1.4**; MINI-LVDS 1.0 / 1.2 / 1.4 | **8:1** (IDES4/7/8, ODES 2/4/7/8:1) | MBG324 15×15 0.8 | 864 Kb | PDS Lite 免费无 license 3 年 (Win only); `pds.exe -file x.tcl` 命令行, 是否真无头未确认 | 裸片未查到; 含该片核心板 ¥129~139 (云汉) |
| (紫光备选) PG2L50H-6IMBG324 (Logos2, 28nm) | 是 | 35,800 **LUT6** 原生 | 35.8k | **≤105 未核实** (推算 100~103, 引脚表 PK04006 需登录) | 0 | 1250 / 1250 @-6 (-5 TBD) | LVDS 1.0 / 1.25 / 1.425; MINI 1.0 / 1.2 / 1.4 | 8:1 | MBG324 15×15 0.8 | 3,060 Kb | 不在 PDS Lite 内, 完整版 + 申请 NODE-LOCKED license (是否收费未查到) | 未查到 (嘉立创 PG2L25H 无货) |
| **XC7S50-1CSGA324C** (AMD Spartan-7, 28nm) | 否 | 32,600 LUT6 | 32.6k | **100** (4 bank × 24 + bank16 4; 逐球) | 0 | **950 / 950** (-1); 1250 / 1250 (-2, +$7.5) | LVDS_25 **1.000 / 1.250 / 1.425**; MINI_LVDS_25 1.0 / 1.2 / 1.4 | **8:1** (DDR 4/6/8, 主从 10/14) | CSGA324 15×15 0.8 | 2,700 Kb (+600 Kb 分布) | 本机 Vivado 2024.2 已含 xc7s50 库, `vivado.bat -mode batch` 现用; 免费 (2026.1 起 BASIC $0) | Digikey **$75.77 但 0 现货 / 52 周** (-2 $83.31, I 级 $87.09); 国内未查到 |
| **LFCPNX-100-9BBG484C** (Lattice CertusPro-NX, 28nm) | 否 | ~80,000 LUT4 (96k LC ÷1.2 反算) | 34.8k | **66** (仅底边 HP Bank3/4/5 = 24+24+18; 家族上限) | 83 (LVDS25E, 接口上限 300 Mbps < 340) | 1250 / 1250 | 1.125 / 1.25 / 1.375 | 8:1 / 10:1 (仅底边 bank) | BBG484 19×19 0.8 | 3,744 Kb (+LRAM 3,584) | Radiant **付费订阅** (1 年浮动 $5,236 Digikey); `pnmainc.exe` Tcl 无头 | Digikey $148.34@1, 126 现货 |
| **Ti90G400C4** (Efinix Titanium, 16nm) | 否 | 90,719 XLR (LUT4, 兼作布线) | 39.4k | **100** (9 个 HSIO bank 逐行; 扣 SPI 配置 ≈ 96~97) | 0 (74 HVIO 纯单端) | **1500 / 1500** (half-rate; DPA ≤ 1000) | LVDS **1.125 / 1.2 / 1.375**; mini-LVDS 1.0 / 1.2 / 1.4 | 2~8 及 10 (9 非法), 带 DPA + CDC FIFO | G400 16×16 0.8 | 6,880 Kb | Efinity 免费全功能, `efx_run.bat` 无头 | Digikey $80.51 但 **840 颗整箱起订 / 不备库存 / 71 周** |

**一句话出局的旁系 (候选自查, 未复核)**:
高云 GW5A-25 (10.0k LUT6-eq 刚过 10k 不过 18k, 116 対, 左右 bank 慢) / GW2A-18 (9.0k 不够) / GW2A-55 (Bank0/1/2/7 VOS 1.375/1.5/1.625 出窗, 窗内 bank 只有 43~44 対) / GW2AR-18 (≤45 対);
紫光 PG2L25H-6IMBG325 (72 対) / PGL50G (只有 BANK0/2 能真 LVDS 输出, 対数未核实);
AMD XC7S25-CSGA324 (72 対) / XC7A35T-FTG256 (81 対) / XC7A50T-FGG484 (120 対但 23×23) / XC7A35T·50T-CSG324 (100 対但球图与 S7 不兼容, 贵 25%);
Lattice ECP5 LFE5U-45F/85F-BG381 (真输出対只有 32/33, 仿真対 150 MHz=300 Mbps 不够 340, 顶边无差分输入, 无 8:1, -6 档 624 Mbps 不够) / Certus-NX LFD2NX-40 (37 対);
Efinix Trion T20/T35/T120 (LVDS 硬核方向固定, 全家族 TX 最多 52 対) / Ti35·Ti60 F225/F256 (70/71 対; Ti60 无 F484)。

## ② 按桥片需求逐条打分

✅ 过 / ⚠ 过但压线或有条件 / ❌ 不过 / ➕ 加分 / ❔ 未查到。PG2L50H 因対数未核实单列。

| 判据 | PH1A60 (对照) | GW5A-60 UG324S | PGL22G MBG324 | XC7S50 CSGA324 | LFCPNX-100 BBG484 | Ti90 G400 | PG2L50H MBG324 (待核) |
|---|---|---|---|---|---|---|---|
| 🔴 真対 ≥ 93 | ✅ 100 | ✅ **110** (保留全部 MSPI/JTAG 配置脚仍 99) | ✅ **120** (保留 flash 后 113~117) | ✅ **100** (余 7) | ❌ **66** (20 入后剩 46 真出, 差 27; 家族天花板) | ✅ **100** (扣 SPI 配置 ≈ 96~97) | ❔ ≤105 (推算 100~103) |
| 仿真対单独标 | — | 2 (JTAG bank, 只能输入) | 0 (伪差分是同一対的另一种用法) | 0 (电流模真驱动) | 83 (LVDS25E, 300 Mbps 接口顶, 补不了 340) | 0 (HVIO 纯单端) | 0 |
| LVDS 出 ≥ 340 | ✅ 1250 | ✅ 2000 (5.9×) | ✅ 800 (2.35×) | ✅ 950 (2.8×) | ✅ 1250 (仅 HP bank) | ✅ 1500 | ✅ 1250 |
| VOCM 在 1.1~1.3 | ⚠ 0.9/1.25/1.4 | ⚠ **1.125/1.25/1.375** (max 超 75 mV; 全表最贴窗) | ⚠ 1.0/1.25/1.4 (MINI-LVDS 1.0/1.2/1.4; 驱动 7 档可微调) | ⚠ 1.000/1.250/1.425 (原生 MINI_LVDS_25 1.0/1.2/1.4) | ⚠ 1.125/1.25/1.375 | ⚠ 1.125/1.2/1.375 (mini 1.0/1.2/1.4) | ⚠ 1.0/1.25/1.425 |
| LVDS 入 ≥ 800 | ✅ 1250 | ✅ 1600 (2×) | ⚠ **800 = 800, 零余量** (-5 档 680 不可用) | ✅ 950 (-1 余 19%) / 1250 (-2 余 56%) | ✅ 1250 | ✅ 1500 (DPA 上限 1000) | ✅ 1250 (-6; -5 TBD) |
| gearing ≥ 8:1 ➕ | ❔ 未给 | ➕ **8/10/14/16:1** (IDES8 1600 Mbps 满速) | ➕ 8:1 (IDES8/ODES8; IDDR 单独模式 RCLK 只 266 MHz, 800 必须走 SERDES) | ➕ 8:1 (10/14 主从; CLK 400 / CLKDIV 100 MHz 均在 BUFIO 600 / BUFG 464 内) | ➕ 8:1 / 10:1 (仅底边) | ➕ 8:1 / 10:1 (half-rate 400/100 MHz) | ➕ 8:1 |
| IDELAY | ❔ 待问 FAE | ✅ 每 IO 一个, 256 步 × 10/12.5/15 ps (≈3.2 ns), 静态/动态/自适应; 全 bank 100Ω ODT (需 VCCX ≥ 3 V) | ⚠ 15 步 × 25 ps = **375 ps = 30% UI**, 对中要靠 PLL 移相 | ✅ IDELAYE2 31 tap × 78 ps ≈ 2.5 ns (≈2 UI); HR bank 无 ODELAY | ✅ DELAYA/B 128 挡 × ~12.5 ps (复核补) | ✅ 静态 0~63 × ~25 ps + 动态 12/18/24 ps/步 + DPA + 8 字 CDC FIFO | ❔ 有, 步进未查到 |
| LUT6-eq ≥ 10k / 18k | ✅ 30.8k | ✅ 26.0k (1.4× 18k) | ⚠ **11.7k 过 10k 不过 18k** (另一口径 9.1k 连 10k 也差) | ✅ 32.6k 原生 | ✅ 34.8k (反算) | ✅ 39.4k (XLR 兼布线, 有效数偏低) | ✅ 35.8k 原生 |
| BRAM ≥ 200 Kb | ✅ 3,160 | ✅ 2,124 | ✅ 864 | ✅ 2,700 | ✅ 3,744 | ✅ 6,880 | ✅ 3,060 |
| 封装 ≤ 19×19, pitch ≥ 0.8 | ✅ 15×15 / 0.8 | ✅ 15×15 / 0.8 | ✅ 15×15 / 0.8 | ✅ 15×15 / 0.8 | ✅ 19×19 / 0.8 (擦边) | ✅ 16×16 / 0.8 | ✅ 15×15 / 0.8 |
| 无 CPU/DDR/SERDES | ✅ | ✅ (SERDES 在 GW5AT) | ⚠ 自带 HMEMC DDR3 硬核 + ADC, 闲置 (DDR 脚复用在 DIFFIO 上, 不占対) | ✅ (只有 XADC) | ❌ 带 SerDes/PCIe 白付钱 | ✅ G400 无 LPDDR4/MIPI | ⚠ HSST/PCIe/DDR3 硬核, MBG324 0 lane |
| Windows 无头 | ✅ TD (td_commands_prompt 要补 exit) | ✅ `gw_sh.exe x.tcl` (SUG1220 §2.2.1) | ⚠ `pds.exe -file x.tcl` / `-project -run gen_bit_stream`, 是否弹 GUI 未确认 | ✅ `vivado.bat -mode batch` 本项目现用 | ✅ `pnmainc.exe` Tcl | ✅ `efx_run.bat --flow full` | ⚠ 同 PGL22G |
| license | ✅ 按 DR1 | ✅ 免费 (标准版, 一年一续) | ✅ 免费 (Lite 3 年) | ✅ 免费 | ❌ 付费 ($5,236/年浮动) | ✅ 免费全功能 | ❔ 需申请, 是否收费未查到 |
| 国产 | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| 供货 / 价格 | ❔ 未知 | ❔ **无公开报价, 官网只列 UG324A, UG324S 供货待确认** | ⚠ 裸片无价, 但 ALINX/正点原子/野火 都用它, 货源成熟 | 🔴 $75.77, **0 现货 / 52 周** | ✅ $148@1, 126 现货 (但已出局) | 🔴 $80.5 但 **840 整箱 / 71 周** | ❔ 未查到 |

### Bank 级可行性 (73 出 + 20 入 能不能摆下 — 输出 bank 整 bank 要 2.5 V)

- **GW5A-60 UG324S**: 每 bank TLVDS 対 B1 17 / B2 11 / B3 7 (含配置复用) / B4 8 / B5 16 / B9 28 / B10 11 / B11 12。试算 (本人算术, 非手册): B9+B1+B5+B11 = 73 対全做 2.5 V 输出 bank, B10+B2 = 22 対做输入, 余 B3/B4 15 対备用。TLVDS 输入任意 VCCIO, 输出 bank 2.5 或 3.3 V。⚠ 复核补: DS1103 Table 3-5 注[1] — 片上 ODT 需 VCCX ≥ 3 V, Fmax > 600 Mbps 的 IO 需 VCCX ≥ 2.5 V ⇒ **800 Mbps 输入意味着 VCCX 必须走 2.5/3.3 V 轨**。
- **PGL22G MBG324**: 六个 bank 各 20 対, 全部支持 LVDS25/MINI-LVDS 入与出, 独立供电 ⇒ 任意分配, 无 bank 限制。L0 bank 约 3~7 対复用 SPI 配置脚。
- **XC7S50 CSGA324**: bank14/15/34/35 各 24 対 + bank16 4 対。20 入 + 1 时钟対放同一 bank (余 3), 下行 73 = 3 + 72 (三个整 bank) + 4 (bank16) = 79 可用, **余 6 対**; 若桥片自出 24 対时钟 (116) 则不够, 与 PH1A60 一样要外置 LVDS 时钟扇出。🔴 5 个 bank 全 2.5 V 才凑够 ⇒ bank14 的配置双功能脚 (D00~D09/FCS_B) 跟着 2.5 V ⇒ QSPI flash 要 2.3~3.6 V 级, 或**由主控 JTAG/从串行配置桥片、不放 flash** (哑桥更顺)。LVDS_25 **输入**可放非 2.5 V bank (DIFF_TERM=FALSE, 板上 100Ω)。
- **Ti90 G400**: 9 个 HSIO bank 每対任配 TX/RX/双向, 100 対自由分配; LVDS TX bank VCCIO 必须 1.8 V, 每个 TX bank REF_RES 10 kΩ 接地; SPI flash 挂 BANK4C 要 1.8 V flash。
- **LFCPNX-100**: 真 LVDS 只在底边 3 个 bank 共 66 対, 输入输出共用 ⇒ 无解。

### 淘汰名单与理由

| 型号 | 淘汰? | 理由 |
|---|---|---|
| LFCPNX-100-9BBG484C | **❌ 淘汰** | 真対 66 < 93 (硬性), 且 66 是整个 CertusPro-NX 家族上限 (BFG484/LFG672 同 66, CBG256 42); 仿真対 83 只能 300 Mbps 接口 (< 340); 另 Radiant 付费。其余三条 (输入 1250 / VOCM 部分覆盖 / 8:1·10:1) 都过, 淘汰仅因真対。 |
| GW5A-LV60UG324SC2/I1 | 不淘汰 | 五个要害数全部核实无一需改; 三条淘汰线 (対 110 / VOCM typ 1.25 在窗 / 输入 1600) 均不触发。 |
| PGL22G-6IMBG324 | 不淘汰 (⚠ 两条压线) | 対 120 / VOCM typ 1.25 在窗 / 输入 800 = 800 不低于门槛; 但 (a) 输入零余量, (b) LUT6-eq 11.7k 只过 10k 口径, (c) IDELAY 375 ps 只扫 30% UI。 |
| XC7S50-1CSGA324C | 不淘汰 | 14 条过 12: 不过的是 非国产 与 VOCM min/max 超窗 (与 PH1A60 同病); 差异化风险是供货 (0 现货 / 52 周)。 |
| Ti90G400C4 | 不淘汰 | 参数全过 (対 100 / 1500 / 8:1+DPA / 39k / 6.9 Mb); 风险全在供货 (840 整箱 / 71 周) 与非国产。 |
| PG2L50H-6IMBG324 | **悬置** | 対数未核实 (上界 105, 推算 100~103); 参数上全面优于 PGL22G (35.8k LUT6 原生 / 1250 / 全 bank 可出 LVDS); 需登录官网拿 PK04006 逐球数 + 问 license 是否收费。 |

## ③ 手册核实 vs 未查到 (明确分开)

三级: **【复核确认】** = 候选查过 + 复核独立按官方原文再核过; **【候选单查】** = 只有候选查过 (复核明说没碰: 价格 / 库存 / 工具链 / license / 旁系型号); **【未查到】** = 两边都没拿到出处。

### GW5A-LV60UG324SC2/I1
- 【复核确认】59,904 LUT4 (DS1103-1.0.9E Table 1-1 p.2, Fig 4-2 p.84); 110 真 TLVDS 対 (Table 1-3 p.4 "226(110)"; UG1101 Table 2-5 p.12 逐 bank 17/11/7/8/16/28/11/12; 复核另用 UG1229 引脚表 226 行逐脚重数 = 220 脚 LVDS=True → 110 対, 分 bank 完全一致); 2000/1600 Mbps (Table 3-32 p.67 OSER8~16 2000, IDES8~32 1600, 4:1 800); VOS 1.125/1.25/1.375 (Table 3-25 p.65); gearing 表 (Table 2-8 p.28); IODELAY 256 步 × 10/12.5/15 ps (Table 2-7 p.26); 全 bank 100Ω ODT (UG304 §3.3.2); 命名 C1/I0 最慢, C2/I1 最快 (Fig 4-2)。
- 【候选单查】gw_sh.exe 无头 (SUG1220 §2.2.1); 标准版 license 免费一年一续 (SUG501 §4.1); 教育版 PN 列表 (Sipeed 2025-09-29 截图, 非官方最新); GW5A-25 / GW2A-18 / GW2A-55 / GW2AR-18 旁系数据。
- 【未查到】GW5A-60 任何封装公开单价与现货渠道; 官网只列 UG324A, **UG324S/PG324C 供货状态**; VOS 表不分 bank/IO 类型也无 VCCIO=3.3 V 一列; C2/I1 与 C1/I0 在 LVDS/gearbox 速率上是否有差 (Table 3-32 只一列 "IP-dependent"); GW5A-60 是否全 bank 同速 (手册没像 25K 那样注左右 bank 慢, 也没明说同速); GW2A-55 高 VOS bank 能否调低。

### PGL22G-6IMBG324
- 【复核确认】120 対 (PK02002 V1.6 表2-1 逐球 DIFFIO_[L0..R2]_[0..19]_[P,N] = 240 球无落单; 表3-4 六 bank 全 "Supported"); 800/800 @-6 (DS02001 V3.0 表5-1 p.43); VOCM LVDS25 1/1.25/1.4, MINI-LVDS 1/1.2/1.4 (表3-7 p.29); VICM 0.5~1.9 (表3-6); ISERDES 1:2/4/7/8, OSERDES 2/4/7/8:1 (§1.3.4 p.12; UG020006 表2-53); IDDR/ODDR 单独 RCLK 266 MHz (表4-4/4-5), IO 时钟网 470 MHz @-6 (表4-13); 17,536 LUT5 (表1-1 注1: 1 LUT5 = 1.2 LUT4); IODELAY 15 × 25 ps (UG020006 §2.3.1); 封装 15.0×15.0 / 0.8 / A max 1.36 (PK02002 表2-1)。
- 【候选单查】PDS Lite 免费 3 年覆盖 PGL50H 及以下; `pds.exe -file/-project -run` 命令行 (PDS UG V3.1 第5章); 核心板价 ¥129~139; 渠道 (ALINX/正点原子/野火); Logos2 系列所有数据 (DS04001)。
- 【未查到】**PG2L50H-6IMBG324 真差分対数** (PK04006 需登录); PGL50G MBG324/MBG484 各封装対数 (PK02010/PK02012 需登录); Logos2 IODELAY 步进/量程 (UG040006 需登录); **PDS -file 模式是否真无头**; 完整版 PDS license (Logos2 必需) 是否收费; PGL22G -7 档是否量产 (订购图有, AC 表只有 -5/-6); 同 bank 多少対可同跑 800 Mbps (SSO); 用户提的 "CPG324" 封装名任何紫光文档都没有; PGL22G 裸片单价。

### XC7S50-1CSGA324C
- 【复核确认】100 対 (复核用 AMD 官方 ASCII pinout xc7s50csga324pkg.txt 逐球, 与候选用的 Vivado IBIS pkg 是两份独立文件, 结果一致: bank14/15/34/35 各 24 + bank16 4; 孤儿 N 脚 2 = D11/D10 VREF; UG475 表 1-7 "Differential 202" 是引脚数); 950/1250 (DS189 v1.10 表 15 p.14, 在线 v1.11 未变); VOCM (表 11 p.11 / 表 9 p.10); 8:1 (UG471 表 3-3 p.151, OSERDESE2 p.166); BUFG 464 / BUFIO 600 / BUFR 315 (-1) (表 32/33/34); IDELAY 分辨率 (表 25 p.28); TSAMP (表 48) 与封装偏斜 80 ps (表 49); 32,600 LUT6 (DS180 v2.6.1 表 2: 8,150 slice × 4); 无 GT/PCIe。旁系 XC7S25 72 / FGG484 120 / FTG256 81 / CSG324 100 复核也按 IBIS pkg 重数一致。
- 【候选单查】Digikey 价格与交期 (2026-09-03); Vivado 2026.1 五档分级与 BASIC $0; DS181 Artix 表逐格对比; 本机 2024.2 器件库路径。
- 【未查到】国内渠道 (立创/华强北/安富利) 现货与人民币价; Mouser 报价 (反爬); 桥片 RTL 在 7 系列的真实 LUT 用量 (未跑综合); Vivado 2026.1 BASIC license 文件是否需联网年更、对 2024.2 有无影响; MINI_LVDS_25 的 OSERDES 最高速率单列值; ICND2260 是否接受 LVDS_25 247~600 mV / MINI 300~600 mV VOD 与 1.0~1.425 V VOCM 全范围 (要对屏手册)。

### LFCPNX-100-9BBG484C
- 【复核确认】66 対 (FPGA-DS-02086-2.5 Table 5.2 p.167: Bank3 24 / 4 24 / 5 18; WR 83; §2.13 p.46 底边每対有真 LVDS 驱动; Table 3.13 注4 "Bank 0/1/2/6/7 无差分输入"; BFG484/LFG672 同 66, CBG256 42); 1250 Mbps wire-bond (Table 3.29 p.77-78; BBG 编码 §6.1 p.169); LVDS25E 400 Mbps 缓冲但 GDDRX1 接口 300 Mbps (Table 3.32 p.81); VOCM 1.125/1.25/1.375 (Table 3.19 p.70); gearing X1/X2/X4/X5/X71 与速率表 (p.80-85); 96k LC ÷1.2 = 80k LUT4 (Table 1.1 注1); **复核新增**: DELAYA/DELAYB 128 挡 × ~12.5 ps (TN-02244-1.6 §3.12 p.19); 顶边 Bank 0 连 X1 都没有 (Fig 2.19/2.21 "Left and Right sides only").
- 【候选单查】Radiant 订阅 $5,236 (Digikey); 器件 $148.34@1 / 126 现货; ECP5 全套数据 (FPGA-DS-02012-3.4, TN-02032, TN-02035); Certus-NX LFD2NX-40 37 対; 开源 prjtrellis 流程; pnmainc 用法。
- 【未查到】CertusPro-NX 精确 LUT4 数 (只有 LC); WR bank 仿真 LVDS25E 能否实跑 340 (按手册应判不达标, 未实测); Radiant 节点锁定/续费价; ECP5 BG381 顶边可做仿真 LVDS25E 的 A/B 対数; 国内代理价; Mouser 页面。

### Ti90G400C4
- 【复核确认】90,719 XLR (DSTi90-v3.7 Table 1 p.5; p.7 XLR = LUT4 + 全加器 + SRL8); 100 対 (Table 2 p.5 G400 列; 复核另按 ti90_pinout-v1.4.xlsx sheet Ti90G400 "LVDS and MIPI Pairs" 列独立重数 2A 10 / 2B 12 / 2C 10 / 3A 10 / 3B 15 / 3C 10 / 4A 12 / 4B 12 / 4C 9 = 100; HVIO 74 只单端); 1500 half-rate / 1000 full (Table 70 p.81; DPA ≤1000 Table 76 p.83); VOCM LVDS 1.125/1.2/1.375 (Table 80 p.85), mini 1.0/1.2/1.4 (Table 84 p.86) 逐字相符; 串化 2~8 及 10 (UG-TiINTF-v7.0 Table 63/64 p.122-123; "16" 只属 HSIO2 = Ti95/Ti125); 8:1 @800 = 400/100 MHz (Table 14 p.35); 16×16 0.8 (Table 3); REF_RES 10 kΩ (Table 105); 延迟步长 12/18/24 ps 是 min/typ/max (Table 75)。
- 【候选单查】Efinity 免费全功能 / efx_run.bat (UG-EFN-SOFTWARE-v18.3 p.17, p.36); Digikey $80.51@840 / 71 周; TI60F256C4L $52.02@1190; 中国区渠道 (Efinix HK + 亿灵思 Elitestek); Trion T20/T35/T120 与 Ti35/Ti60 旁系。
- 【未查到】Ti90G400 小批量/单颗价 (Mouser 超时, 官方 shop 与 Elitestek 不公开); XLR 兼布线后的有效 LUT 折减系数; fabric fMAX (手册只给 BRAM/DSP/全局时钟 1000 MHz); mini-LVDS 各 VOD 档实际数值 (只在工具 Block Summary 显示); LVDS TX 対数 SSN 上限与 100 対全用的功耗/热; 精确的配置复用対数 (3~4, 取决于 x1/x4/x8 与 TEST_N/CBSEL); 国内库存/交期/人民币价。

## ④ 推荐 (两个口径) + gearing ≥ 8:1 对本项目的具体价值

### 国产口径
1. **首选 GW5A-LV60UG324SC2/I1 (高云 Arora V)** — 五个要害数全部复核成立且是全表最贴需求的一颗: 110 真対 (≥93 余 17, 保留全部配置脚仍 99) / VOS 1.125/1.25/1.375 (max 只超窗 75 mV, 比 PH1A60 的 0.9~1.4 窄一半) / 输入 1600 (2×) / **8:1~16:1 gearing 且 IDES8 满 1600 Mbps** / IODELAY 256 步 × 12.5 ps ≈ 3.2 ns (2.6 UI) + 全 bank 100Ω ODT / 26k LUT6-eq (现役口径 1.4×) / 2,124 Kb / 15×15 0.8 / 工具免费无头。
   - 与对照 PH1A60GEG324 (同 15×15 BGA324): LUT 59.9k vs 70.8k (少 15%), 対 110 vs 100, BRAM 2,124 vs 3,160, RX 1600 vs 1250, VOS 上限 1.375 vs 1.4, 高云多 8:1~16:1 与 256 步 IODELAY (PH1A 的 gearing/IDELAY 还待问 FAE)。
   - 🔴 **投板前必须先做的**: (a) 向高云/代理确认 **UG324S 封装供货与单价** (官网产品页只列 UG324A; 无任何公开报价); (b) VCCX 轨按 ≥ 2.5 V (>600 Mbps IO) / ≥ 3 V (用片上 ODT) 规划; (c) Bank 分配按 UG304/IPUG 校验 800 Mbps IDES8 能放在哪些 bank (手册没明说 60K 全 bank 同速); (d) 问 ICND2260 能否吃 VOS 1.375 V 上限 (PH1A 是 1.4, 同一个问题)。
2. **次选 PGL22G-6IMBG324 (紫光同创)** — 只在 "桥片 RTL 优化到 ≤ 10k LUT6 当量" 成立时可用: 対数最富裕 (120, 六 bank 任配) + PDS Lite 免费 + 渠道最成熟 (ALINX/正点原子/野火 都在用), 但 **输入 800 = 800 零余量** (与 EG4 的 200 MHz 2% 是同一种"擦线") + IDELAY 只扫 30% UI + BRAM 864 Kb + 11.7k LUT6-eq (另一换算口径 9.1k 连 10k 都不到)。三条压线叠在一起, 比 GW5A-60 差一个档。
3. **待核 PG2L50H-6IMBG324 (紫光 Logos2)** — 参数上 35.8k LUT6 原生 / 1250 / 3,060 Kb / 全 bank 可出 LVDS, 若真対 ≥ 93 (推算 100~103) 则与 GW5A-60 同档; 但要登录官网拿 PK04006 逐球数, 且完整版 PDS license 是否收费未知。**值得花一次登录的功夫**。
4. PH1A60GEG324 (对照物) 仍成立: 100 対 / 30.8k / 1250 / VOCM min 0.9 最差; gearing 与 IDELAY 是它唯一没数的两条 —— 问 FAE 前它排在 GW5A-60 之后。

### 非国产口径
1. **首选 XC7S50-1CSGA324C (AMD Spartan-7)** — 14 条过 12, 只丢 "非国产" 与 "VOCM min/max 超窗 (同病)": 100 対 (与 PH1A60 同封装同対数) / 32.6k LUT6 **原生不用换算** / 950 (-1) 或 1250 (-2, +$7.5) / 8:1 (10/14 主从) / IDELAYE2 2.5 ns ≈ 2 UI / 2,700 Kb / **本机 Vivado 2024.2 已装、`vivado.bat -mode batch` 现用、桥片 RTL 与 icnd2260 现役代码零移植** (DR1 也是 LUT6 同构)。
   - 🔴 **供货是唯一实质风险**: Digikey 0 现货 / 厂标 52 周 (S50/S25/A50T/A35T 四个候选全部 0 现货), 国内渠道未查到 ⇒ 先确认现货再投板。
   - 设计约束: 5 个 bank 全 2.5 V 才凑够 73 出 (余 6 対), bank14 配置脚跟着 2.5 V ⇒ **建议主控 JTAG/从串行配置桥片、不放 flash**; 桥片自出 24 対时钟不够, 与 PH1A60 一样要外置 LVDS 时钟扇出。
   - Spartan-7 在此用途是 Artix-7 的严格子集且更便宜更小; 选 Artix 只在需要 >100 対 (XC7A50T-FGG484 120 対) 时有意义, 代价 23×23。
2. **次选 Ti90G400C4 (Efinix Titanium)** — 纸面最强 (100 対任配 / 1500 + DPA / 8:1·10:1 / 39k / 6.9 Mb / 免费全功能工具), 但 **840 颗整箱起订 + 不备库存 + 71 周**, 16×16 比 15×15 大 1 mm, HSIO 做 LVDS TX 要 1.8 V VCCIO + 每 bank 10 kΩ REF_RES。适合"批量且能等"的情形, 不适合先投一块验证板。
3. Lattice 整家出局 (CertusPro-NX 66 対是家族天花板; ECP5 更差且无 8:1; 唯一优点是 ECP5 有开源工具链)。

### gearing ≥ 8:1 对本项目的具体价值 —— "200 MHz 那 2%" 的来龙去脉
- **来源** ([[project_eg4_bridge_verification]] §③b, 提交 58093e9): 上行 800 Mbps 用 EG4S20 的 iDDRx2 (**4:1**) 解串 ⇒ pclk = 800/4 = **200 MHz**, 5 ns 周期。`uplink_rx` (13 lane iDDRx2 + bitslip 字对齐 + 13-lane deskew + 200→83 MHz 异步 FIFO) 原版 RTL 在 200 MHz **SWNS −1.409 / Fmax 156 / 7 级 LUT** 不过; 加 3 轮流水 (功能不变, 仿真照过) 后 **SWNS +0.102 ns / Fmax 204.2** —— 0.102 / 5 = **2%**; 225 MHz 立刻 −0.725。结论: 55nm 上 5 ns 只装得下 4 级 LUT4, 最差路径布线占 65~70%, **天花板就是 200 整**; 真板若再加回读/CRC 只能退到 175 MHz (700 Mbps, 16 対/面)。
- **8:1 改变了什么**: pclk = 800/8 = **100 MHz, 10 ns 周期** —— 同一条 5 级路径在 10 ns 里余 ~5 ns, 余量从 2% 变成 ~50%, 不必加那 3 轮流水, 也留得下回读/CRC/12-bit 重排的逻辑; 800 Mbps 档从"擦线成立"变成"随便过"。代价是数据通路宽一倍 (每 lane 8 bit 而非 4 bit, bitslip/deskew 的 mux 树相应变宽 — 桥片重排/对齐正是 LUT 系数 2.3~2.7 的那类逻辑), 所以 LUT 预算要按 8-bit lane 重估, 但换来的是时序余量而非速率上限。
- **输出侧同理**: 340 Mbps 双沿 ÷ 8 = 42.5 MHz fabric (4:1 是 85 MHz), 24 链 × 3 対的扇出逻辑在 42.5 MHz 下几乎无时序压力。
- **在候选里的落点**: GW5A-60 (IDES8 满 1600) / PGL22G (IDES8, 800 必须走 SERDES 因为 IDDR 单独只到 266 MHz) / XC7S50 (ISERDESE2 8, CLKDIV 100 MHz) / Ti90 (8:1 half-rate 400/100) / PG2L50H (8:1) 全有 ⇒ **所有留下的候选都把 200 MHz 那条轴直接抹掉**; 只有 EG4 (4:1) 与 ECP5 (7:1 DDR71 顶 756 Mbps 跑不到 800, 只能 4:1) 还困在 200 MHz。PH1A60 的 gearing 未给, 这是它相对本表其它候选唯一悬着的一条。

## ⑤ 汇总时发现的矛盾 (候选 vs 复核 / 文档自相矛盾) — 原样保留, 不裁决

| # | 型号 | 字段 | 候选原文 | 复核原文 / 另一出处 | 备注 |
|---|---|---|---|---|---|
| 1 | PGL22G | HMEMC DDR 引脚 | "HMEMC DDR3 硬核的 [R,L]_A/DQ/DQS 等是独立球, 不在 240 IO 内, 不用 DDR 时空着即可" | "错。HMEMC 的 [R,L]_A/DQ/DQS/CK/BA/CS_N/... 全部复用在 DIFFIO 球上 (PK02002 表2-1 'Memory Byte Group' 列), 例如 DIFFIO_R2_1_N = R_DQ15, DIFFIO_R2_11_P/N = R_CK/R_CK_N; 分布在 L1/L2/R1/R2 约 108 球。MBG324 没有独立 DDR 球" | 复核注明对本需求无影响, 120 対仍成立 |
| 2 | PGL22G | LVDS25 驱动电流 | "LVDS25 1.5~4.5 mA" (引 UG020006 表2-9 p.24) | "LVDS25 1.5 / 2.0 / 2.5 / 3.0 / 3.5 / 4.5 / 6.5 mA (7 档, 上限 6.5 不是 4.5)" (引 UG020006 表2-9 **p.25**) | 页码也差 1 |
| 3 | PGL22G | LUT6 当量 | 候选自报两种换算: 17,536 LUT5 ÷1.5 = **11,691** (过 10k); 或按厂家 1 LUT5 = 1.2 LUT4 → 21,043 ÷2.3 = **9,149** (不过 10k) | 复核只确认 17,536 LUT5 与注1 "1 LUT5 = 1.2 LUT4", 说 "÷1.5 = 11,691, 过 10k 不过 18k, 候选自述正确" | 同一颗片子过不过 10k 取决于换算口径, 两边都没裁 |
| 4 | XC7S50 | 封装引脚数 | "CSGA324 (wire-bond CSP BGA, 324 球, **240 有效引脚**)" | "324 球 = 210 I/O + 51 GND + 63 电源/配置/JTAG/XADC。'240' 是 Vivado IBIS pkg 头部 [Number of Pins] 240 = 210 IO + 30 个非 IO 网络各记 1 条, 不是物理引脚数" (引 AMD 官方 xc7s50csga324pkg.txt) | |
| 5 | XC7S50 | DS189 页码 | "表 48 p.49, 表 49 p.50; 表 32-34 p.37-38" | "DS189 v1.10 印刷页码: 表 48 p.50, 表 49 p.51, 表 32/33/34 均在 p.38 — 数值全部正确" | 仅页码 |
| 6 | XC7S50 | IDELAYE2 出处 | "UG471 **p.?** 'IDELAYE2 is a 31-tap, wraparound'" | 复核同样写 "UG471 p.?" | 页码两边都没填 |
| 7 | LFCPNX-100 | WR bank gearing | "顶/左/右 WR Bank 0/1/2/6/7 只有 X1 (2:1)" | "顶边 Bank 0 连 X1 都没有: Fig 2.19/2.21 注 'IDDRX1 / ODDRX1 supported on Left and Right sides only' (p.39, p.41), 修订记录 Rev 0.81 'remove top side support reference'; 能做 2:1 仿真输出的只有 Bank 1/2/6/7 = 71 対" | 复核同时指出**手册自相矛盾**: Table 3.32 GDDRX1 行仍写 "Bank0, 1, 2, 6, 7" (p.81); GDDRX4 Aligned 标题写 "Left and Right sides Only" (p.84) 与 §2.10 "gearing 仅底边" 冲突; TN-02244 §5.7 又说顶/左/右只能 1× <250 MHz 且 "single-ended interfaces only" |
| 8 | LFCPNX-100 | IDELAY 步长 | "步长/挡位数未在数据手册中给出, 需查 FPGA-TN-02244 (未核实)" | "DELAYB 静态 + DELAYA 动态: 128 挡 × ~12.5 ps, DEL_VALUE 0..127" (TN-02244-1.6 §3.12 p.19) | 复核补上, 非矛盾 |
| 9 | GW5A-60 | VCCIO3 引脚 | 候选 unknowns: "UG1101 Table 2-5 把 UG324S 的 VCCIO3 引脚数写成 0, 而 UG1229 引脚表有 U14/R12 两个 VCCIO3, 文档自相矛盾, 以 UG1229 为准" | 复核未涉及 | 高云两份文档互相矛盾, 未解 |
| 10 | GW5A-60 | 配置复用対数 | 候选: "B3 7 対 (含配置复用脚)" | 复核: "110 対中约 **11 対**是配置复用脚 (B3: IOR5/9/15/17; B4: IOR20/34; B5: IOR41/63/66/70/72; 另 B2 IOT142B/DOUT 单脚), 全部保留仍剩 99 対" | 复核口径更宽 (B3+B4+B5), 候选只标了 B3 |
| 11 | GW5A-60 | VCCX 约束 | 候选只写 "ODT 需 VCCX ≥ 3 V (DS1103 Table 3-5 注[1])" | 复核加: "VCCX=1.8 V 时 IO Fmax 受限, **Fmax > 600 Mbps 的输入输出需 VCCX ≥ 2.5 V**" (同一注) | 补充, 非矛盾; 影响电源树 |
| 12 | GW5A-60 | MLVDS25 | 候选 notes 未提 | 复核: "DS1103 1.0.9E 修订新增 '60K I/O supports MLVDS25' 指 MLVDS **输入** (Table 2-4), 输出仅 MLVDS25E 仿真; 别与 MINILVDS (真 TLVDS 输出) 混淆" | 名字易混 |
| 13 | Ti90 | 延迟步长 | 候选: 静态 "0~63 步 (约 25 ps/步, UG-TiINTF-v7.0 Table 63/64)"; 动态 "12/18/24 ps/步 (DS Table 75)" | 复核: "Table 75 差分延迟步长 12/18/24 ps 是 min/typ/max 且**对静态与动态都适用** (与 UG 的 '~25 ps' 是 Efinix 两份文档自身的小出入, 非候选错误)" | Efinix DS 与 UG 不一致 |
| 14 | Ti90 | SPI 配置占用対 | 候选: "≈3 対 (CCK/CSI/CSO/CDI0/CDI1)" → 约 97 対 | 复核: "CCK/CSO/CSI/CDI0-3 落在 4C 的 01/02/09/10 対, ≈3-4 対" | 差 1 対, 不影响 ≥93 |
| 15 | PGL22G | -file 无头 | 候选: "手册未写 -file 模式是否仍弹 GUI 窗口, 真正'无头'未确认" | 复核: "工具链/license/价格类字段本次未复核" | 仍是未知 |
| 16 | PH1A60 vs 全表 | LUT4→LUT6 系数 | 任务书换算 LUT4 ÷ 2.3 | [[project_eg4_bridge_verification]] 实测 TD 对 EG4 k = 2.31, 对 DR1 2.37, 宽 mux 树 2.7 | 系数是实测均值, 桥片的重排/bitslip 类逻辑偏 2.7, 26.0k/30.8k/34.8k/39.4k 这些 LUT4 折算数都可能高估 10~15% |
| 17 | XC7S50 | 国内价 | 候选: "立创只搜到 XC7S50-2FTGB196I (搜索摘要 ¥336.67/现货 5, 页面未核出价格), CSGA324 未查到" | 复核未涉及价格 | 立创搜索页 203 空返回 |
| 18 | LFCPNX-100 | LUT4 数 | 候选与复核都写 80,000 是 "96k LC ÷ 1.2" 反算 | Lattice 产品页同样只给 96K LC | 两边一致地没有独立出处 |

**关联**: [[project_pov3d_bridge_architecture]] (桥架构与対数账) · [[project_eg4_bridge_verification]] (EG4 三条零余量实测, 2% 出处) · [[reference_anlogic_lineup_pair_counts]] (安路家族対数与 VOCM 通病) · [[reference_vivado_batch_tcl]] (Windows Vivado 无头用法)
