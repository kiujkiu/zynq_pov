---
name: EG4 桥片三条生死项的实测进度 (2026-09-03)
description: 通用版 TD_Release_2026.1_SP2 装好后在 EG4S20CG324 上实跑: ① 仿真 LVDS 可绑 ODDR/ODDRx2l 全流程到 bit ✅; ② pclk 供给用 BUFIO(clko→sclk, clkdivx→BUFG→pclk) 13 种组合实测定案 ✅; ③ LUT 与接收侧 200MHz 在跑; 附 TD 2026.1 三个坑
metadata:
  type: project
---

# EG4 桥片三条生死项 — 实测进度 (2026-09-03)

前提: 通用版 **`C:\Anlogic\TD_Release_2026.1_SP2.200.067`** 装好(与 DR1 专版 5.9.1 并存),
license `FEATURE TD Anlogic 2027-03-31 HOST_ID=ANY` 拷入即可用, **实测能综合 EG4**。
`sim_release/eg4`、`arch/eagle_s20.db`、`template/.../EG4` 全在。
分支 `dr1v90` 的 `feature/uplink-tx-probe`。

## ✅ ① 仿真 LVDS 能绑 oDDR —— 生死题过了 (`eg4_lvdse_oddr/`, 提交 3bae0d5)

EG4S20CG324 上三路同放, 三道 DRC 零报错, **bitstream 生成**:

| 信号 | IOSTANDARD | 原语 | PackReg |
|---|---|---|---|
| `tx_e1` | `LVDS25_E`(仿真, Bank0 底边 `IO_BE1P_0`) | `EG_LOGIC_ODDR` | **DDRX1** ✅ |
| `tx_e2` | `LVDS25_E`(仿真, `IO_BE15P_0`) | `EG_LOGIC_ODDRx2l` | **DDRX2L** ✅ |
| `tx_t2` | `LVDS25`(真, Bank1 左边 `IO_L15P_1`) | `EG_LOGIC_ODDRx2l` | **DDRX2L** ✅ |

⇒ 桥片那 **54 対仿真対可以用 4:1 DDR 跑 332 Mbps**。

## ✅ ② EG4 上 pclk/sclk 怎么给 —— 13 种组合实测定案 (`eg4_clknet/`, 提交 832790c)

🔴 **裸 `EG_PHY_CLKDIV` 布不上线**(`PHY-8023 Failed to route net` + `PHY-8096 Unconnected pin *.opclk`),
真対仿真対一起断 ⇒ 与 LVDS_E 无关; **真因是 CLKDIV 前面没接 IOCLK**(DS300 §2.3.2 CLKDIV 输入必须来自同 bank IOCLK)。

**推荐接法 F (唯一有文档背书的)**:
```
EG_PHY_PLL C0 = 400 MHz (sclk)
  → EG_LOGIC_BUFIO:  .clko    → IOL 的 sclk
                      .clkdivx → EG_LOGIC_BUFG → pclk (喂 IOL 的 pclk + 全部 fabric)
```
UG301 §4.1: "clko 只能供 IO 使用, clkdiv1/clkdivx 可以供全局时钟网"。
这是 DR1 "PLL→sclk, LCLK÷2→pclk" 的 EG4 对应物。**用 BUFIO 别手拆成 IOCLK→CLKDIV→GCLK**(方案 H 多 TMR-6022 警告)。

| 方案 | 接法 | 布线 |
|---|---|---|
| A/B | PLL 出两路 C0=200(pclk)/C1=400(sclk), 过/不过 BUFG | ✅ 都过 —— **DR1 的 PHY-8033 教训不迁移到 EG4** |
| C/E | 裸 CLKDIV ÷2 → GCLK, clki 过/不过 BUFG | 🔴 PHY-8023/8096 |
| D | 裸 CLKDIV → IOCLK | 🔴 `PHY-9124 IOCLK should drive Pad or CLKDIV only` |
| **F/K** | **PLL→BUFIO(clko=sclk, clkdivx→BUFG=pclk)** | ✅ **推荐**; K 加 SDC 后 pclk 200 MHz **SWNS +1.99**(小设计) |
| L/M | 双 IOCLK / sclk 走 IOCLK + pclk 走 BUFG | ✅ |

**SDC 必须手写** `create_generated_clock -divide_by 2`(`derive_clocks` 不推 ÷2), pin 名用综合后的
`u_bufio_syn_2.clkdivx`(带 `_syn_N` 后缀, 从第一趟 .area 抄)。

🔴 **相位与 DR1 同款状况**: DS300 图 2-6-16 要求 PCLK 边沿对齐 SCLK 下降沿, **正文一字没提**;
TD 的 STA **不检查** IOL 内部 pclk→sclk 交接(CC-From/To = no, IOCLK 网在报告里 `unrouted 0.000`)。
F 里 pclk 经 BUFG 到 IOL 有 **1.5~1.9 ns 插入延迟**而 sclk 走 IOCLK 建模为 0
⇒ **400 MHz 档余量只有零点几 ns, 只能上板量**; 166 MHz 档(屏侧 332 Mbps)余量充裕。
备选 A(两路 GCLK)可用 PLL `CLKCx_CPHASE` 调相(需 ±90°, 符号要 TD GUI 确认)。
⇒ **桥片先按 F 做, 上板用 IDDRx2 环回量字边界; 400 MHz 不稳退 A 调相, IOL 侧 RTL 不用改。**

## ✅🔄 ③a-2 LUT 优化正式汇总 (2026-09-03 深夜, `td_eg4_port/OPT_SUMMARY.md`, 提交 5a28a7f)

🔴 **取代了本文早先"约 20-24%"那版协调者手拼汇总** —— 那版漏了 8→16 位宽扩展 + 13→72 分发块
(~1,000 LUT, 桥架构里真实存在但当时没算), 也没做 (a)/(b) 两口径对照。汇总 agent 补齐后正式版:

三模块实测(gate 口径, 均用**桥片工作参数** `READ_PROBE_FR=0/QUIET_CYCLES=0`):

| 模块 | 改前 | **改后** | 每链增量 |
|---|---|---|---|
| u_ack | 1,143 | **72**(−94%) | 0(全桥只 1 份) |
| u_seq | **344**(桥片参数) | **133**(+1 bram9k) | 0(只 1 份) |
| u_tx | 426(N=1) | **125+54×N**(N=1/2/4 实测 178/232/339 验证线性) | **54** |

**桥片组成(24 链, 独立测量与估算之和, 不是一次综合)**:

| 组成项 | (a) 现役直放大 | (b) 优化后 |
|---|---|---|
| u_tx ×24 | 10,224 | 1,421 |
| u_seq ×1 | 344 | 133 |
| u_ack ×1 | 1,143 | 72 |
| 上行 RX(已单独综合, 200MHz 0 违例) | 2,290 | 2,290 |
| 8→16 扩展+13→72 分发+24 链弹性FIFO(**估算**, 前提="按链序发,只做demux不重排") | ~1,000 | ~1,000 |
| 顶层胶合(估算) | ~75 | ~125 |
| **合计** | **≈ 15,076** | **≈ 5,041** |

**占比(区间 = gate 直加 ~ 按最坏观察 gate→phy 膨胀 +37% 折算)**:

| | EG4S20(19,600) | PH1A60(70,848) |
|---|---|---|
| (a) 现役直接放大 | 🔴 **77%~99%**(零余量, 实际不可行) | ✅ 21%~27% |
| (b) 优化后 | ✅ **26%~29%** | ✅ 7%~8% |

**⇒ LUT 轴从"明确不够"翻盘成"明确够用", 但排序不变**: ③b(200MHz 余量 2%) / ④(Bank1/3 锁 3.3V) /
⑤(IOL 相位只能上板量) 三条硬轴不受影响, **EG4S20 仍排在 `reference_bridge_fpga_alternatives.md`
推荐的 GW5A-LV60UG324S 与 PH1A60GEG324 之后**。

🔴 **下一个该拿真 RTL 顶掉估算的是分发块(~1,000, ±0.35k, 对总占比影响 <2 个百分点)** ——
它现在是"架构原则推出来的数", 不是实测; RTL 尚不存在。

三种优化手法(变址读→串行化 / 常量表→BRAM / 共享控制器+逐 lane 数据通路)与器件无关, 通用。

## 🔴 ③a-1 LUT 真数首测(未优化) —— **EG4S20 装不下** (`td_eg4_port/`, 提交 0b184a1, 已被上面的正式汇总取代)## 🔴 ③a-1 LUT 真数首测(未优化) —— **EG4S20 装不下** (`td_eg4_port/`, 提交 0b184a1, 已被上面的优化结果部分推翻)

icnd2260 屏驱 RTL(1 链 3 通道, CASCADE=1, 帧缓存进 BRAM) 在 **EG4S20CG324** 上跑到 bit:

| 字段 | 值 |
|---|---|
| `#lut` | **2,277** / 19,600 (11.6%) |
| `#Total_luts` = lut4+lut5+lut6 | 998 = 712 + 257 + 29 |
| `#le` (lut only / reg only / lut&reg) | 2,294 (1,792 / 17 / 485) |
| `#reg` / `#bram9k` | 502 / 12 |
| **Fmax** | **120.2 MHz, 150 MHz 收不住**(SWNS −1.66 ns, 227 端点) |

**换算系数 k = 2,277 ÷ 988 (Xilinx LUT6) = 2.31**; 同 TD 对 DR1V90(960 lut6) = **2.37** ⇒ 取 **2.3~2.4**。
按模块: `u_tx` 数据通路 **2.0** / `u_seq` **2.2** / `u_ack` **2.7**(104 位缓冲 + 17 个变址读口的宽 mux 树,
LUT6=4:1 mux 而 LUT4=2:1 ⇒ **桥片的重排/bitslip/lane 对齐正是这一类**)。
量具校验: 同 TD 下 FF 502 vs 491 = 1.02 ✅。

**桥片重算 (估算口径 12k–16k LUT6)**:

| 系数 | LUT4 | 占 19,600 |
|---|---|---|
| 我原估 ×1.5 / ×2.0 | 18k–24k / 24k–32k | 92–122% / 122–163% |
| **实测 ×2.3–2.4** | **27.7k–38k** | **🔴 141%–194%** |
| mux 密集 ×2.7 | 32k–43k | 165–220% |

⇒ **按现役 icnd2260 设计直接放大 24 链, EG4 全家族(都是 19,600 LUT4) 装不下, 最乐观差 1.4×。**

⚠ **一条未验的退路**: 现役设计把帧格式/CHKSUM/寄存器序列全放 FPGA 侧。若改成 **DR1 预算好一切,
桥片只做 "解串 → 位宽扩展 → 扇出 → 串化"** 的极致哑桥, 每链逻辑可压到几十 LUT,
粗估总量 7k–8k LUT4 ≈ 36–41% **可能装下** —— 但那是**全新设计**, 且 DR1 侧要按 24 链算 CHKSUM。
**没验过, 别当已知。**

🔴 **顺带两条新发现**:
1. **DS301 CG324 表末注: Bank1/Bank3 的 VCCIO 与内嵌 SDRAM 电源短接, 只能 3.3V**
   ⇒ **EG4S20 那 50 対真差分用不了 LVDS25**, `eg4_lvdse_oddr` 里 LVDS25 过 DRC 只是工具不知情;
   本次用 **LVDS33** 过到 bit。⚠ EG4A20/X20 **没有**内嵌 SDRAM, 可能不受此限(待查)。
   LVDS33 的 VOCM 对屏的 VIC 1.1~1.3 更糟。
2. CASCADE=9 时 16200×48 帧缓存要 96 个 bram9k > 全片 64, TD **只发一条 `SYN-2599` info** 就拆成
   DRAM+逻辑, `#lut` 多出 ~1,100、Fmax 塌到 62.7 ⇒ 那个数不作数, build.sh 已抓这条拒绝当系数。
3. CPHASE 方向: 上一版 `DIV-1-DIV/4` 是 −90°, 改 `(DIV-1+DIV/4) mod DIV` 为 +90°(工具模型, 硅上未测)。

**⇒ 对照 PH1A60GEG324 (70,848 LUT4)**: 现役设计直接放大 = **39%–54%** ✅ 装得下, 且 100 対全真差分。

## ⚠ ③b 接收侧 200 MHz —— **过, 但余量 2%** (`uplink_rx/`, 提交 58093e9)

`uplink_rx` (13 lane iDDRx2 + bitslip 字对齐 + 13-lane deskew + 200→83 MHz 异步 FIFO, 纯 Verilog)
在 **EG4S20CG324** 上用 F 接法(PLL C0=400 → BUFIO → clko=sclk / clkdivx→BUFG=pclk):

| RTL 版本 | 200 MHz | 175 | 150 | 225 |
|---|---|---|---|---|
| 原版(仿真通过的) | ❌ SWNS −1.409, Fmax 156, 7 级 LUT | ❌ | ✅ +0.101 | — |
| **v2 (加 3 轮流水, 功能不变, 仿真 3/3 照过)** | ✅ **SWNS +0.102 / Fmax 204.2 / 0 违例 / 最深 5 级** | +0.159 | +0.559 | ❌ −0.725 |

⇒ **这颗 55nm 片子上本设计的天花板就是 200 整**: 5 ns 周期只装得下 4 级 LUT, 最差路径布线占 65~70%。
**800 Mbps 档在接收侧成立但无余量**; 真板若要加回读/CRC, **按 175 MHz(700 Mbps, 16 対/面, 双面 32)留退路**。

**LUT(v2 @200)**: `#lut 2,290` (11.7%) / `#reg 2,110` / `#le 2,819`; #Total_luts 1,741 = lut4 1,328 + lut5 413 + **lut6 0**(EG4 无 LUT6);
lane_align ×13 各 ~110 LUT, deskew 585 le, rx_fifo 落 BRAM(12 bram9k)。
⚠ **比我估的 ~1,400 多 60%** —— 桥片总量要按这个数重算。

**顺带查清的**: 7 种时钟接法全部实测, 结论同 `eg4_clknet`; 🔴 **`eg4_lvdse_oddr` 里"CLKDIV 输出上不了时钟网"归因错了 —— 断的是 CLKDIV 的输入**(必须由同 bank IOCLK 驱动), 修法(BUFIO)不变;
🔴 **N14 在 CG324 上是 GND_PLLA1** —— `eg4_lvdse_oddr` 用的是 DS301 §6.4 **BG256** 那页的表, 本目录球位已按 §6.5 CG324 重查;
`EG_LOGIC_IDELAY` 存在(0.52 ns + 0.12 ns/tap × 32) ✅; IDDRx2 q0 = 线上最早一位(DS300 图 2-6-9) ✅;
PLL 的 M 含义随反馈路径变(EXT: fC0=25M; VCO_PHASE_0: fVCO=25M), 填错 TD 不报错。

## 📊 EG4S20CG324 五项计分 (2026-09-03 收工)

| 项 | 结果 | 余量 |
|---|---|---|
| ① 仿真 LVDS + oDDR | ✅ 实测到 bit | — |
| ② pclk 供给 | ✅ F 接法, 有文档背书 | — |
| ③a LUT | 现役代码放大 ≈ **90%** ❌ / 优化后估 ≈ **34%** ✅(workflow 实测中) | 取决于优化 |
| ③b 接收 200 MHz | ✅ 过 | **2%**(+0.102 ns), 要 3 轮流水才过 |
| ④ 真差分电气 | ⚠ Bank1/3 锁 3.3V ⇒ RX 必须放 Bank0/2 ⇒ **33 対真対驱屏共模无保证**(VOCM 0.6–1.4 典型未给) | 靠外部偏置或上板量 |
| ⑤ IOL 内 pclk↔sclk 相位 | ⚠ TD 不检查, F 接法 pclk 有 1.9 ns 插入延迟 | 只能上板量 |

⇒ **EG4S20 "技术上可行, 但三条轴同时零余量"**(时序 2% / 共模无保证 / 相位靠上板)。
**PH1A60GEG324 三条都有余量**(VOCM 典型 1.25 正中; 工艺更新; 70,848 LUT)。

- `td_eg4_port/` 切 EG4S20CG324 综合 icnd2260(1 链)拿 LUT 全字段 ⇒ 换算系数
- `uplink_rx/` 在 EG4 上用 F 接法跑 200 MHz

🔴 **前提更正**: 上一轮 `td_eg4_port` 在 DR1 上跑出 999 LUT6 ≈ Xilinx 988, 但**DR1 是 LUT6 架构不是 LUT4**
(`DR1_LOGIC_SLICE` 六输入 + `LUTMODE=LUT6`, 与 7 系列同构) ⇒ **那一跑给不出 LUT6→LUT4 系数, 只有 EG4 能**。
EG4 是 LE 架构(19600 LUT / 19600 reg / `#le` 1:1, `.area` 分 `#lut4/#lut5/#lut6`)。

## 🔴 TD 2026.1 的三个坑 (与 5.9.1 DR1 版不同)

1. **`td_commands_prompt.exe` 跑完 tcl 不退出**, 停在 `td >` 等 stdin ⇒ 脚本挂死到 timeout。
   两版兼容: **tcl 末尾补 `exit` + `< nul`**。
2. **`N14` 是 dedicated pin**(`USR-8027`), DS301 引脚表却写 `IO_L10P_1`。J16/G16/H15 可用。
3. **EG4 的 `.area` Detailed IO Report 比 DR1 多一列 `DiffResistor`** ⇒ 取 PackReg 要按表头列号,
   `awk '{print $NF}'` 会读错列、DDRX2 计数恒 0、误判打包失败。

## EG4 事实清单 (从新 TD 与米联客 EG4D20 真工程读出)

- 原语前缀 **`EG_`**(不是 `EG4_`); ODDR 类端口与 DR1 同名原语**一模一样**:
  `EG_LOGIC_ODDRx2 (q, pclk, sclk, d3..d0, rst)` / `EG_LOGIC_ODDRx2l (q, sclk, d3..d0, rst)` /
  `EG_LOGIC_IDDRx2 (q3..q0, pclk, sclk, d, rst)` ⇒ 移植 = 换前缀
- `EG_PHY_PLL` **参数名与 DR1 不同**(`FEEDBK_PATH` vs `FBKCLK`, `ICP_CURRENT`, `LPF_CAPACITOR/RESISTOR`,
  多 `KVCO`, 无 `INTPI`, `clkc` 位宽 5 vs 8) ⇒ 不能平移, 每族一整套参数块
- 器件串: `<Family>EG4</Family>` / `EG4S20CG324` / `<Speed></Speed>`(**空**, `import_device` 连 `-speed` 都没有) /
  `arch-db eagle_s20.db`; `tools/td_gen.py` 已支持 `--family/--device/--speed/--arch-db`
- 引脚: `IO_L*_1`(Bank1 左)=真差分, `IO_BE*_0`(Bank0 底)=仿真対; `.adc` 差分只写 P 端
- **DR1 与 EG4 现役目录并存**: `TD_5.9.1_DR1_2025.1_151.508`(DR1 线所有 build.sh 写死) / `TD_Release_2026.1_SP2.200.067`(EG4)

相关: [[project_pov3d_bridge_architecture]] [[project_dr1_uplink_tx_probe]] [[reference_anlogic_td_toolchain_setup]]

## EG4A20BG256 vs EG4S20CG324 —— "换一种零余量" (2026-09-03 晚)

把当天全部实测套到 EG4A20BG256 上:

| 项 | EG4A20BG256 | EG4S20CG324 |
|---|---|---|
| ③a LUT / ③b 200 MHz / ⑤ IOL 相位 | **全同**(同 19,600 LUT、同 55nm、同 IOL) | 同 |
| ④ Bank1/3 电压 | ✅ **无内嵌 SDRAM, 可配 2.5V** | 🔴 锁 3.3V |
| 上行 RX 放哪 | ✅ Bank1/3 真対(VICM 0.05–2.35 @2.5V) | 被迫 Bank0/2 |
| 真対驱屏(共模无保证) | **22 対**(51 仿真全给屏) | 33 対 |
| 总対 (8-bit 需 87) | 90, **余 3** | 104, 余 17 |
| 10-bit(需 90) / 12-bit(需 93) | 零余量 / ❌ | 余 14 / 余 11 |
| 降速退路 | ❌ 锁死 800 Mbps | ✅ 能退 600/500 |

⇒ **EG4A20 用引脚余量(余 3 対, 锁死 8-bit 与 800 Mbps)换回电气余量(RX 能放真対, 共模无保证的対 33→22)。**
但**逃不掉 EG4 家族共有的三条**(LUT / 200 MHz 2% / IOL 相位靠上板), 且在 8-bit 就锁死 ——
而 09-02 验证的帧率模型说屏侧 **12-bit 大概率可行**, EG4A20 等于把这个收益直接放弃。
⇒ **两颗 EG4 都是零余量方案, 只是零在不同的轴上。PH1A60GEG324 三条都有余量。**

⚠ LUT 优化 workflow 第一次因 session 额度全军覆没(4 agent 全报 "session limit resets 8pm"),
20:02 重发为 `wf_8c7caf51-886`。它的结果只影响 ③a 那一格, 改不了 ④⑤。
