---
name: project_gw5a_bridge_verification
description: GW5A 桥片工具层实测三项 (2026-09-11, Gowin V1.9.12.03) — 下行 OSER8+LVDS 全过且 73 対装得下; icnd2260 LUT≈EG4×1.11 但 150MHz 过 (EG4 不过); 上行 uplink_rx 4:1 @200MHz GW5A-25 −0.071/60 +0.011 与 EG4 同档, 且 IDES4 规格仅 800Mbps ⇒ 必须改 IDES8 + lane_align 每拍一字; VCCX=3.3 (V1/V2 原理图), VOS 仍超 2260
metadata:
  type: project
---

目录 `dr1v90/gw5a_oser8/` 与 `dr1v90/gw5a_port/` (README + build.sh + results/), 工程在 `C:\temp\gw5a\`。**已提交 dr1v90 `904c269` (分支 feature/uplink-tx-probe)**; uplink_rx 的 GW5A 版 (`uplink_rx/build_gw5a.sh` `synth/uplink_rx_synth_top_gw5a.v` `results_gw5a/` `README_gw5a.md`) **已提交 `ecc7145`**。
前置: [[reference_gowin_eda_install]]; 对照: [[project_eg4_bridge_verification]] [[reference_bridge_fpga_alternatives]]。

## ③ 下行 8:1 串化 + LVDS 输出 —— ✅ 工具层全过
`PLLA(50→VCO)→CLKOUT0=FCLK→CLKDIV "4"→PCLK`, 每 lane PRBS7→`OSER8`→`TLVDS_OBUF`/`ELVDS_OBUF`, 时钟 lane 喂 10101010。
- 36+1 対 × {25,60} × {T,E} × {800,1000,1200} Mbps: **12/12 出 bit, setup/hold/recovery 0 违例**, OSER8 全进 IOLOGIC, FCLK 走 HCLK。
- **容量: 72+1=73 対 TLVDS (目标板需求) 两颗都过**; GW5A-25 工具认到 91 対, 101 対报 `PA2024` 常规 IO 仅 201; GW5A-60 101 対 `PR0003`。
  自动放置会占 8 个配置脚 (D11~D15/EMCCLK/DOUT/PUDC_B), 真板要手工排。
- 🔴 **STA 不查 IOLOGIC 最高速率** (1200 Mbps 也 0 违例) ⇒ 速率只能看手册。

## DS1103-1.0.9 硬数 (`pov3d/GW5A/DS1103-1.0.9_GW5A系列FPGA产品数据手册.pdf`)
- 表 3-34(25)/3-33(60): **OSER8/10/OVIDEO 2000 Mbps, IDES8/10/IVIDEO 1600, IDES4 与 OSER4 仅 800, IDDR/ODDR 400**
  ⇒ 🔴 上行若照 EG4/PH1 用 4:1 (IDES4), 800 Mbps = 规格零余量; **GW5A 上行应走 IDES8 (pclk 100 MHz)**, 但现 uplink_rx 的 lane_align 是 4bit/拍, 要改成每拍一字。
- 表 2-6(25)/2-3(60): **TLVDS LVDS25 输出 VCCIO 2.5 或 3.3** ⇒ 真差分不受 bank 电压锁 (对比 EG4S20 Bank1/3 锁 3.3)。🔴 我曾以为"LVDS25 进 3.3V bank 工具不报错=工具不知情", 查手册是**合法**的, 已更正。
- 表 3-27: TLVDS VOD 250/350/600 mV, **VOS 1.125/1.25/1.375** (GW5A-138 是 1.000~1.425) ⇒ max 仍超 2260 VIC 1.3。
- §3.2 注[1] (属 GW5A-60 表 3-5): **>600 Mbps IO 要 VCCX ≥2.5 V, 片内差分端接要 VCCX ≥3 V**; GW5A-25 的 VCCX 推荐范围本就 2.375~3.465 ⇒ 对 25 只剩 "ODT 要 ≥3V" 这条要看核心板 (见下节, 推断 3.3V)。
- UG324 封装 bank 两两共 VCCIO (0/1, 2/3, 4/5, 6/7)。

## 坑
- OSER8/IDES 的 RESET 别从 PCLK 同步后给, STA 按 FCLK 半周期查 recovery 出假违例 (37 端点 −0.615); 照官方 DDR IP 同一根异步复位接 CLKDIV.RESETN(~rst) 与 OSER.RESET。
- `Setup Violated Endpoints` 计数含 recovery, 看 3.1.3 表才知道。

## ACG525 板资料核对 (09-11, `D:\BaiduNetdiskDownload\小梅哥ACG525型国产高云FPGA教学开发板\`)
资料初看没有核心板原理图, 后补到 `06_硬件图纸\AltiumDesigner\` (见下); 初看时 06_硬件图纸 只有 核心板封装 PcbLib/SchLib、CB 机械 PcbDoc、核心板**引出信号线长报告** PDF、联系方式);
04 引脚表 xlsx = 评估底板外设分配 (CLK_G 50M = **T9**, DDR3 16bit 占 bank0/1 ⇒ bank0/1 基本不引出); 09 厂家手册含 **UG985-1.7.2 GW5A-25 Pinout** / UG987 原理图指导。
- 🎯 **UG985 UG324 表逐行解析: 104 个完整差分対, LVDS 列全部 True** (7 个 none 都是 RECONFIGN 之类单脚) ⇒ 与工具 json/DRC 一致, 第③项 73 対结论成立。
  🔴 旧记忆 "GW5A-25 116 対标称/最坏 85" 与 "LVDS 列=NONE 的対不能 TLVDS_OBUF" **都不是 GW5A-25 UG324 的数** (出处封装不明), 以本条为准;
  工具不用双功能脚认到 **91 対** (90+1 过, 100+1 报常规 IO 仅 201) ⇒ 8-bit 88 対够, **12-bit 97 対要动用配置双功能脚, 零余量**。
- ✅ **VCCX = VCC3P3 已由原理图坐实 (V1)**: 用户 15:06 补到 `06_硬件图纸\AltiumDesigner\ACG525-CORE-核心板原理图-修正芯片型号.pdf` (2025-04, 另有 2024-04 原版; `cadence\` 下 CB/CORE-240402 DSN/brd/pdf) 第 3 页 Bank Power: `VCCX/M0_VDDX/VCCIO10` 12 脚全接 **VCC3P3**; VCC = VCC0P9 经 FB1 (FB2 DNI 为 1.2V 选项), VCC_REG = VCC1P2, VQPS = VCC1P8; 第 1 页连接器 (P1/P2 各 100 脚 = V1 布局): **VCC3P3 由底板经 A1~A4 输入**, VCCIO01/23/45/67 同样由底板供 ⇒ **VCCX 的 3.3V 是底板给的, 自画底板这路要干净 (纹波 ≤5%)**, 满足 ODT ≥3V。V2 核心板原理图仍没有; V2 底板 (CB-V2 2026-03) 连接器页同样送 VCC3P3+4 路 VCCIO ⇒ 供电结构应一致 (未直接核)。以下为看到原理图前的推断记录, 结论一致:  UG324 上 VCCX 与 VCCIO10、VDDX_MIPI 共 12 球 (`VDDX_MIPI/VCCIO10/VCCX`); 线长报告 (2023-12, 即 **V1** 核心板) 电源网
  VCC0P9(5) VCC1P2(9=VDD12M 7球+2) VCC1P5(46,DDR3) VCC1P8(6) VCC2P5(5) VCC3P3(67) VCCC(24≈VCC 10球+电容) VCC_EXT(15) VCCIO01/23/45/67 (由底板供) ⇒
  挂得下 12 球的只有 **VCC3P3 ⇒ VCCX 大概率 3.3 V** (满足 ODT ≥3V)。另: **GW5A-25 VCCX 推荐范围本就 2.375~3.465 V** (DS1103 表 3-6), ">600Mbps 要 VCCX≥2.5" 那条注是 GW5A-60 表 3-5 的 (60 的 VCCX 可 1.8)。V2 核心板是否同, 待问小梅哥。
- **VCCIO 由底板供** (连接器网 VCCIO01/23/45/67, CB-V2 原理图可见) ⇒ 自画底板可按 bank 对定 2.5/3.3。
- **核心板线长 (V1 报告)**: 引出 76 完整対 + 8 半対; 每 bank 内対间长差 ≤47 mil (≈8 ps @0.17 ps/mil), 対内 ≤36 mil (≈6 ps); 跨 bank 563~1107 mil 差 544 mil ≈ 90 ps
  ⇒ **一条链的全部 lane 放同一 bank**, 核心板对 800 Mbps (UI 1250 ps) skew 贡献可忽略。bank4 最长 (~1.1 in)。

## ③a icnd2260 1 链 LUT (09-11, `dr1v90/gw5a_port/` README + results/, 分支 agent 实跑, 协调者抽查过 rpt 数)
同口径 c1 / PIX40 LINES45 NLANE3 / 150 MHz PLL / 同一份 fb .mem:
| | Xilinx | DR1 | EG4S20 | **GW5A-25** | **GW5A-60** |
|---|---|---|---|---|---|
| LUT (布线后) | 988 | 960 lut6 | 2,277 | **2,519** (2,418 LUT+101 ALU, 10.9%) | **2,520** (4.2%) |
| @150 | 收敛 | +1.26 | −1.66 / 227 违例 | **+0.014 / 0 违例** | +0.027 |
| Fmax (过约束测) | ~145 | 184.9 | 120.2 | **164.2** (9 级) | 165.3 |
- 系数: 对 Xilinx **2.55** (c9 同口径 2.58); **对 EG4 1.11 —— 同为 LUT4 架构, 面积几乎一样**; 宽 mux (u_ack) 仍 ~3× 对 DR1 (另有 1,006 MUX2 不占 LUT)。
- **CASCADE=9 帧缓存 GW5A-25 装得下** (37/56 BSRAM), EG4S20 装不下。
- (b) 优化口径 (桥片工作参数) GW5A-25: u_ack 1,515→**81** / u_seq 377→**221** / u_tx 526→**168** (ctrl 116~117 + 每链 52); **三优化叠加整机首跑 (EG4 上从没跑过) 523 LUT, 200 MHz +0.144 0 违例**; 24 链外推 ≈1,690 LUT = GW5A-25 的 7.3% (估)。
- 移植: Gowin 自带同名 ODDR ⇒ Xilinx 版改名 XIL_ODDR→ODDRC (D1→D0, D2→D1, 按 prim_sim.v 行为模型推); OBUFDS→TLVDS_OBUF 保留 _p/_n; 90° = `CLKOUTx_PE_COARSE=ODIV/4` (STA Rise=period/4 三档核过); `$readmemh`+syn_romstyle 推成 pROM。
- 🔴 坑: **Gowin SDC 引用不存在的对象直接 ERROR 不出 bit** (TD/Vivado 只警告)。
- 未验: 无功能仿真; ODDR 位序/90° 方向只是模型; 150 下 +0.014 是"够用就停"; GW5A-60 叠加版 200 MHz −0.617 是自动放脚的 BSRAM→ODDR 长线。

## ✅ V2 核心板原理图 (用户 09-11 15:19 给, 已存 `pov3d/GW5A/ACG525-CORE-V2_核心板原理图_2026-07-09.pdf`, 原件 `D:\工程软件\gowin\ACG525-CORE-V2.pdf`)
- 第 3 页: **VCCX/M0_VDDX/VCCIO10 12 脚 = VCC3P3 (与 V1 相同)**; FB1 定型 BLM18KG121TN1D (VCC0P9→VCCC), FB2 DNI 仍为 1.2V 选项。
- 第 1 页: P1/P2 = **AXK500137YG** (松下 100 脚 B2B, 1~100 编号); VCC3P3 (1~4) 与 VCCIO01/23/45/67 由底板输入; 引出网名与 V1 相同 (B*_T/B/L/R*_P/N, MIPI_RX 在 B6 L23~L31, JTAG 在 P1 94~100)。
- 配对件核对: 官方 **CB-V2 底板 BOM P1/P2 = LB3524-G100P-W0R** (连兴旺) ⇒ 任务表写的配对料号正确, 不是同性别。

## ③b 上行 uplink_rx @200 MHz (09-11, `dr1v90/uplink_rx/README_gw5a.md`, 分支 agent 31 跑, 协调者核过 3 个 WNS 原始报告)
4:1 同口径: PLLA→FCLK 400→CLKDIV÷2→pclk 200, IDES4×13 (13/13 进 IOLOGIC), rclk 80 MHz (PLL 整数比约束, EG4 是 83.33)。
| rtl_v3 | EG4S20 | **GW5A-25** | **GW5A-60** | PH1A60 |
|---|---|---|---|---|
| WNS @200 | +0.102 | **−0.071** (288 端点; `place_option 2/3` +0.003) | **+0.011** | +1.488 |
| 天花板 | 200~215 | **≈197~200** | **≈234** | ≈380 |
| 级数/LUT/FF | 5/2290/2110 | 5/2596/2801 | 5/2595/2801 | 3/1167 LUT6/1894 |
- ⇒ **GW5A 在这份 RTL 上与 EG4S20 同一档 (都是 LUT4), 远不到 PH1A60**; 同一 200 档换布局算法漂 0.7 ns。v2 @200: 25 +0.003 / 60 +0.047 (噪声内)。无 IO 层 @300 Fmax 25:218 / 60:244 ⇒ IO 层不吃时序。
- 限速路径: **lane_deskew 缓冲被 GowinSynthesis 推成寄存器阵列** (EG4 是 104 DRAM LUT), `is_sync2→do_push→mem_RAMREG/CE` 5 级布线占 64~76%; `-replicate_resources` 更差, `-ram_style distributed_ram` 没出 SSRAM 反把 rx_fifo 拆寄存器 (60 天花板 234→204) ⇒ 只能改 RTL。
- 第二道天花板: rx_fifo BSRAM 最小脉宽 0.776 ns (pclk 全局网占空比损 0.8~1.1 ns), 60 ≥300 / 25 ≥350 过不了, 200 档余 +0.96/+0.64。
- 🎯🔴 **结论: GW5A 上行不能照搬 4:1** —— IDES4 规格 800 Mbps 顶格 + fabric 200 MHz 零余量, 双零; 应走 **IDES8 (1600 Mbps, pclk 100 MHz)**, 但要把 lane_align 改成每拍一字 (8→4 拆两拍喂现 RTL 等于回到 200 MHz, 无意义)。**这是 GW5A 路线下一个该做的 RTL 活, 未做。**
- 未验: FCLK 由 PLL 出 (同 EG4/PH1 口径), 源同步正规做法转发时钟当 FCLK 没做; GW5A-25 上 fclk 被放到 PRIMARY 没走 HCLK; IDES4 位序 (Q0=最早) 按 prim_sim.v 推。
- 🔴 工具坑: 旧 `gw5a_oser8/summ.py` 在 recovery 表为空时误抓 3.2 最小脉宽首行 (T2 发现) ⇒ 第③项表里"recovery"列实为 MPW, 已修脚本+README+重生成 SUMMARY; 结论不变 (recovery 本无路径)。

## 📊 三项总评 (工具层, 未上板)
| 项 | EG4S20 | GW5A-25 | GW5A-60 | PH1A60 |
|---|---|---|---|---|
| 下行串化 | 4:1 ODDRx2 | **8:1 OSER8, 规格 2000** | 同 | 4:1 |
| icnd2260 1 链 LUT / @150 | 2,277 / −1.66 ❌ | 2,519 / +0.014 ✅ (Fmax 164) | 2,520 / +0.027 | — |
| 优化三件叠加 | 未跑 | 523 LUT @200 ✅ | @200 −0.617 (放脚) | — |
| 上行 4:1 @200 | +0.102 | −0.071 (换算法 +0.003) | +0.011 | +1.488 |
| 真差分对 / bank 电压 | 50 / Bank1/3 锁 3.3 | **104 (工具用 91) / 2.5 或 3.3 任选** | 110 | 100 |
| 驱屏共模 VOS max | 1.4 | 1.375 | 1.375 | — |
⇒ GW5A 相对 EG4: 下行 IO 与引脚/电压全面占优, icnd2260 时序也好; **上行 fabric 同档, 要靠 IDES8 重写 lane_align 才能甩开**。

## 🎯 GW5A-LV25UG324S 评估 (09-11 用户问"这颗是优选吗"; 纯技术, 供货不计 [[feedback_tech_eval_excludes_supply]])
- UG324S ≠ 核心板的 UG324: **116 対全 TRUELVDS, 239 IO (工具常规 IO 218 ≈107 対), 干净対 (无配置/测试功能) 98** ⇒ 旧记忆 "GW5A-25 116 対" 是这个封装的数。
- 工具实测 `GW5A-LV25UG324SC2/I1 -device_version A`: **96+1=97 対 (12-bit 门槛) TLVDS 出 bit 0 违例**; 109+1 超常规 IO。
- 对 GW5A-60 UG324S (110 対/干净 95): **109 対同球位, 两颗都干净 90 対** ⇒ 可画 25S 主、60S 脚对脚备份的板 (需逐球核电源: 60S 各 bank 独立 VCCIO、14 个 25S IO 球在 60S 是 NC)。
- 结论 (已答用户): **GW5A 线内技术首选 = GW5A-LV25UG324SC2/I1** —— 12-bit 97 対只用干净対即够 (60S 要占 2 対配置脚)、同 die 已验证、可换 60S;
  前提 ① 必须走优化 RTL (估 6~7k LUT ≈30%; 现役直放 17~21k = 72~92% 不可行, 不想赌就上 60S) ② 上行改 IDES8 (25 的 4:1 fabric 天花板 197 < 60 的 234)。

## ✅ ③c 上行改 1:8 (IDES8 + rtl_x8) —— 双零余量解掉 (09-11, `dr1v90/uplink_rx/README_x8.md`, 已提交 `422b771`)
- `rtl_x8/`: 只改 lane_align (oct[7:0] 输入, sr 每拍进 8 bit, **删 par/word_tick** —— 每拍进一个字长 ⇒ 正确偏移与拍号无关) + 顶层端口 nib→oct;
  deskew/rx_fifo 逐字拷贝, 帧定位/beat/FIFO 不改 (全按 valid 选通, fifo_wr 每 2 个 100 MHz 拍 = 50 M beat/s 同 v3)。rtl_v3 一字未动。
- 仿真 `sim/run_sim_x8.sh` (新 ides8_behav + tb_x8): **三项全过** (对齐 2292 ns / 1000 beat 全等 / 注入偏移 5.5 µs 掉锁→2.4 µs 重锁→1001 beat 全等);
  **两个变异 (移位方向反 / 取字偏一位) 都被抓出** (超时失败); verilator 只有与 v3 相同的 2 条 UNUSED。
- **IDES8 位序已逐行核 prim_sim.v**: Q0 = d0_reg4 最早, Q0→Q7 时间递增 (d0 上升沿/d1 下降沿两链, 下标大=早)。
- 综合 (`build_gw5a_x8.sh <25S|25|60> <800|1000|1200|1600>`, 12 跑全出 bit, WNS 逐个核过原始 .tr):
  **800 Mbps (pclk 100): 25S +2.278 / 25 +1.986 / 60 +2.683, 全 0 违例** (4:1 同器件 −0.071); 1000/1200 全过;
  1600 (pclk 200, IDES8 规格顶格): 25S +0.000 / 60 +0.003 过, 25 −0.719 (布局噪声 ~0.7ns) ⇒ **fabric 天花板 ≈ pclk 175~200 = 1400~1600 Mbps**。
  LUT 2617 / FF 2787 / BSRAM 12 / IDES8 13 进 IOLOGIC (与 4:1 的 2596/2801/12 同量)。
- ⚠ Gowin 报告 Fmax "跟着约束走" (达标即停), 低档 Fmax 是下限, 天花板要超约束测。
- ⇒ 800 Mbps 上行在 GW5A 上: **IO 2× (800/1600) + fabric ~2×**, 相对余量 (20~27%) 与 PH1A60 4:1 (30%) 同级; IO 规格余量 2× vs PH1A60 1250/800=1.56× (GW5A 略宽) ⇒ **GW5A 与 PH1A60 的技术排序由此翻到 GW5A 不输** (未上板)。
- 未做: 转发时钟当 FCLK (仍 PLL 出); 单板环回测试工程 (评估底板 40 针 18 対 / 36 针 13 対, 同板同源时钟要 IODELAY 扫眼; 引脚表是 V1 底板, 要对 V2 核)。

## GW5A 上行最高速率 (09-11 答用户)
- 单対上限 **1.6 Gbps**: DS1103 §1 总表 "LVDS (Gbps) 1.6(RX) / 2.0(TX)" (25/60; 138 是 1.5/1.6) + FMAXIDES8 1600; rtl_x8 @1600 (pclk 200) 25S +0.000 / 60 +0.003 / 25 −0.719 ⇒ 顶格零余量。
- 建议工作点 **1.0~1.2 Gbps** (IO 1.6×/1.33×, fabric 按天花板 1400~1600 反推 30~40% / 15~25%; 报告里 1000/1200 档 WNS 小是"达标即停")。
- 对数账 (帧开销 126/128): 8-bit 10.04 Gbps → 800M 13 対(余2%) / 1.2G 9 対 / 1.6G 7 対; 12-bit ≈15.05 Gbps → 800M ~20 対 / **1.2G 13 対刚好(余2%)** / 1.6G 13 対余 36%。
- 🔴 系统上限不在 GW5A: DR1 发送侧只验到 800 (fabric 按 400 MHz 约束过, **DR1 LVDS 输出 IO 规格未查**) + 板级通道 (EG4 800M 实测板级只剩 40 ps) + 真实眼宽 (上板扫 IODELAY)。

## ✅ 单板环回测试工程 `dr1v90/gw5a_loop/` (09-11, 提交 `d441b28`, 板到即可烧)
- 本板 OSER8 按上行协议发 → **V2 底板 P6(40 针)/P11(36 针) 上相邻两对短线环回** → IODELAY+IDES8 → rtl_x8 → beat_check 逐字节;
  上电自动 **每 lane 扫 IODELAY 眼 + 判 P/N 极性** (字节 ∈ 0x35 / 0xCA 的循环移位, 两集合不相交, 不依赖字对齐), UART 115200 每秒报 B/E/Y。
- 预出 bit + 接线表: `D:\claude_workspace\pov3d\GW5A\loop_bits\` (n13/n4 × verA/verB @800, n4/n13 verA @400; 二进制不进 git)。
  🔴 **上板先用 Programmer 读 ID 定 25A/25B**; 下载器接底板 P5 牛角座, USB 驱动未装。先 4 lane (8 根线)。
- **V2 底板引脚全部从 Altium 原理图机器解出** (`tools/schnet.py` 几何连通 + `mk_header_map.py` → `pins_v2.tsv`): 排针 64 脚 + LED/KEY/UART **73/73 与 V1 引脚表一致**;
  时钟 T9 = 核心板 50 MHz 有源晶振 OT2JI-111-50M; 排针 bank 2/3/4 VCCIO = 3.3 V (底板 VCC3P3 经 FB5/FB4); 官方例程 LED/KEY/UART 均 BANK_VCCIO=3.3。
- 仿真用**高云原语模型** `IDE/simlib/gw5a/prim_sim.v` (PLLA/CLKDIV/OSER8/IDES8/IODELAY/TLVDS 全可用; 🔴 iverilog 必须 `-s <top>` 否则未例化原语找不到 GSR.GSRO):
  4 / 13 lane 全过 (2009 beat 0 坏, 故意接反的 lane 判 inv=1); 反例 3 个毛刺 → 3 坏 beat。PLLA 模型实测 50→400/80 MHz, 顺带证实 gw5a_pll 分频。
- 综合 6 变体全 0 违例; 13 lane 800M LUT 6.7k, WNS +2.34 ns。
- 🔴 坑: **IODELAY 动态模式要 SDTAP/VALUE 跳变才装载 DLYSTEP** (模型 `always @(SDTAP or VALUE) if(!SDTAP) delay_data<=DLYSTEP`), 接常 0 则扫眼形同虚设 ⇒ DLYSTEP 变就打 4 拍 SDTAP 脉冲 (硅上语义待板测);
  STA 把 DLYSTEP→DO 当数据弧 (−1.75 ns) ⇒ `set_false_path -from [get_regs {u/u_scan/dly_*}]`; 复位组合或门高扇出 (+0.48→寄存后 +2.34); 扫眼步长须 ≪1 UI (仿真 32 档失败, 8 档过)。
- 未验: SDTAP 装载在硅上是否生效 / LED 极性 / 排针+杜邦线 800M 眼宽 / 同源时钟≠真上行的转发时钟。

## 🔴 1.6 Gbps/対上行评估 (09-11, `dr1v90/uplink_rx/README_1g6.md`, 提交 `9ad16c5`; 协调者核过 DS1200 表 3-22/3-16、DS1103 表 3-38 原文)
- **结论: 以 DR1V90 为发送端, 1.6G 做不了, 卡在 DR1**: DS1200 表 3-22 **LVDS25/LVDS18 输出上限 1250 Mbps** (注: 能否到最高以 Timing Report 为准);
  表 3-16 **IOCLK 680 MHz (-2)** 而 DR1 只有 4:1 ⇒ 1.6G 要 SCLK 800 超规格。**DR1 发送下现实上限 ≈1.2 Gbps** (IO 余 4%, SCLK 600 余 13%) ⇒ 12-bit 13 対刚好 (余 2%) / 8-bit 9 対。
- GW5A 侧: rtl_x8 @1600 74 跑: 25S 3/15、25 6/15、60 5/5 过 (过也只 +0.000~0.026); rtl_x8b (独热写指针+retrain 寄存, 逐拍等价, 新增 `sim/chk_x8b_equiv.v` 逐拍检查器) 25S→8/15; 1400 三颗全过; 瓶颈 deskew 写口 CE 5 级 (x8c 延后一拍未做)。
- 🔴 **GW5A PLL 经 HCLK cycle-cycle 抖动 <300 ps (DS1103 表 3-38)** = 24% UI @800M / 48% UI @1.6G ⇒ "本地 PLL 同源采样" 在高速下按规格不成立, **真上行要转发时钟直驱 HCLK→IDES8.FCLK** (未综合过)。IODELAY 步长 10/12.5/15 ps 随 PVT ±20%, 量程 2.76~4.14 ns。
- 接插件: AXK500137YG / LB3524 **无公开 SI 数据**; 同类 0.5 mm B2B (Hirose FX23 8 Gbps+, Samtec QSH 17 Gbps); 200 mm FPC @800 MHz 插损估 0.5~1.9 dB ⇒ 有条件可做 (G-S-S-G, 100Ω±10%, 板测 PRBS)。
  🔴 **核心板连接器 200 脚只 20 地, 差分对连排、相邻对间无地** (底板改不了) ⇒ 隔一対用一対: 上行 28 + 下行 37 = 65 ≤ 73 可放。
- 纠正: "EG4 实测 800M 板级只剩 40 ps" 实为 **EG4 TD STA 在 input_delay=0 下的 IO 路径余量** (出处 [[project_pov3d_eg4a20bg256_bridge_selection]] 证据 2), 不是板级实测。
- ✅ **XC7Z020 已查 (DS187 v1.20.1 2018 量产版表 50)**: DDR LVDS TX (OSERDES 4~14) **-3/-2 1250, -1 950 Mb/s**; FMAX_BUFIO 680/680/600 MHz; TSAMP_BUFIO 0.35/0.40/0.46 ns; PL 只有 HR bank (LVDS_25 要 VCCO 2.5)。
  ⇒ **换 7020 不改结论**: -2 与 DR1 同为 1250 且 1.6G 要 BUFIO 800>680 ⇒ 1.6G 也不行, 上限 ≈1.2G; **-1 只有 950 (1.0G 就超)** ⇒ 主控选 7020 必须 -2。现役主工程 02_hello_zynq 按 -2 建, icnd2260 脚本按 -1, 板上丝印未核。

## 🎯 链路速率结论 (09-11 与用户确认)
- **上行 (DR1/7020 → 桥片) 1.2 Gbps/対 = 天花板, 不是舒服工作点**: 卡在发送端 —— DR1 LVDS 输出 1250 (DS1200 表 3-22) / 7020 -2 1250、**-1 仅 950** (DS187 表 50), 1.2G 离规格只剩 4%。
  GW5A 收端 fabric 天花板 1.4~1.6G 够, 但 PLL 抖动 <300 ps 在 1.2G 占 36% UI ⇒ 要改转发时钟采样。
  **三档: 800M = 当前方案 (两端工具层验过) / 1.0G = 稳妥升级档 (DR1 IO 余 20%) / 1.2G = 转发时钟方案 + 上板 PRBS 过了才定**。
  对数: 12-bit 在 1.2G 13 対刚好 (余 2%), 1.0G 要 16 対。
- **下行 (桥片 → ICND2260) 166 MHz 时钟 / 332 Mbps 每対 DDR = 2260 的限制, 不是 FPGA 的** (每颗 3 lane 共 996 Mbps; 4×6 排布实用 833.6 = 83.7%, 每対 ≈278 Mbps);
  GW5A OSER8 规格 2000 Mbps, 下行速率对它无压力; 下行真正风险是共模 (GW5A TLVDS VOS max 1.375 > 2260 VIC max 1.3)。
