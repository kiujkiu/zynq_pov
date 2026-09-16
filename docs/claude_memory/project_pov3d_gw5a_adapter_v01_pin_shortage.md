---
name: project_pov3d_gw5a_adapter_v01_pin_shortage
description: 2026-09-16 硬件反馈「高云引脚不够」— 硬件画的 GW5A 转 LED 转接板 V01 原理图逐脚核: 需 162 IO vs ACG525 连接器 154 IO(缺 8, 正是 5/7/8 号 ACK 与 RSTN/SYNC 没分到脚); 根因是偏离了 09-09/10 冻结接口(ACK_I 也拉进 FPGA、ACK_O 不走 mux); 另把 800M 上行放到手册说速率偏低的 bank6
metadata:
  type: project
---

# GW5A 转 LED 转接板 V01 引脚不够 (2026-09-16)

原件: `C:\Users\wanqi.liu\Downloads\高云转LED灯转接板.pdf`(嘉立创 EDA, 标题 "FPGA LVDS CONNETC V01", 创建 09-14 / 更新 09-16, 1 页)。
结构: CN1/CN2 = AXK600337YG 接灯板(12 颗 2260: CLKI + CLKO1~11 + 各 3 数据 = 48 対, 12×ACK_I + 12×ACK_O, RSTN, SYNC1~3, 3V8/2V8);
CN3/CN4 = 接 ACG525-CORE-V2 的 P1/P2(网名 = 核心板网名, 与对接表 v3 的 P1/P2 脚号一致); R5~R100 0Ω 映射下行; R101~R140 → FPC1(60P) 上行;
U1~U4 SN74LVC8T245 做 ACK/RSTN/SYNC 电平转换; CN5 = JTAG 本地座。

## 账
- **核心板连接器可用 = 73 完整対 + 8 半対 = 154 IO**(MIPI 5 対是 D-PHY 专用不算; JTAG 在 bank10 专用不占 IO)。其中 bank0/1 的 4 対是 1.5V(DDR3 组), 只能经电平转换当单端 ⇒ 2.5/3.3V 可做 LVDS 的只有 **69 対**。
- 硬件画法需求: 下行 48 対(12 时钟直出)96 + ACK 24 + RSTN 1 + SYNC 1(三路在 U4 并成一根)+ 上行 18 対 36 + 边带 4 = **162 ⇒ 缺 8**。154 个脚全部用光, 没分到的就是 5/7/8ACK_I/O(U2 A3~A8 悬空) + RSTN + SYNC(U4 A1/A2 悬空)。

## 根因 = 偏离冻结接口
09-09 灯板改板 / 09-10 转接板文档定的是 **48 対 + 9 单端**: ACK_I 每颗 100k 上拉 VDDD 不出板、ACK_O 经 **2×8:1 mux** 出 ACK_D[1:0]+ACK_S[2:0](对上 RTL `ack_d/ack_s`)、I_SYNC 1 根。硬件把 ACK_I/ACK_O 共 24 根全拉进 FPGA。

## 给的方案(09-16 答用户)
1. ACK_I 不进 FPGA(−12)— 已定案, 只是没照做。
2. ACK_O 走 2×8:1 mux(−7), 或保留 12 根直连但余量归零且要改 u_ack。
3. 12 対时钟保持直出(GW5A 文档建议); 扇出 IC 是再省 22 IO 的后手。
⇒ 按契约 20 対上行: 96 + 5 + 2 + 40 + 4 = **147/154 余 7**, LVDS 68/69。

### 单端位只有 10 个 2.5/3.3V (09-16 追问)
LVDS 用 68/69 対后, 2.5/3.3V 能放单端的只剩 1 対(2) + 8 半対 = **10**; 其余只有 bank0/1 的 8 个 **1.5V**(VCCIO01 = 核心板 VCC1P5 给 DDR3, 固定; 用户说成 1.8V 已更正)。
- mux 方案单端 11 根 ⇒ 也要占 1 个 1.5V 脚(上一轮"余 7"没说这点)。
- ACK_O 12 根直连 ⇒ 单端 18 根 ⇒ **154/154 零余量, bank0/1 的 8 个 1.5V 脚全用上**。建议全放 ACK_O(同为输入, 一颗转换器 DIR 固定)。
- 🔴 SN74LVC8T245 VCCA/VCCB 下限 1.65V ⇒ **U3 的 1.5V 侧用不了**, 要换支持 1.5V 的系列(AXC ≤3.6V / LXC 类, 下单前核手册)。
- 零余量代价: EN_3V8/EN_2V8 放不下; bank2/6 下行跑不了时无处挪; 转换器 OE 没脚控 ⇒ RSTN 在 FPGA 侧加下拉(配置期 GPIO 弱上拉)。

## 顺带查出的问题
- 🔴 **上行放在 bank6(Left, 7 対含转发时钟)+ bank7**: DS1103 表 2-11 注[3] GW5A-25 bank2/6 速率偏低; 对接表 v3 定的是上行 20 対全放 VCCIO45(bank4/5 Bottom)。下行 332 Mbps 放 L/R 不可避免(Top/Bottom 只有 48 対, 上行占 20), 800M 上行不该放。
- FPC 只有 18 対(契约 20: UL_D[0..17] + CHK + CLK)、没带 JTAG、60P < 契约 72 位。
- R49/R50(5 号芯片 G 通道 → B3_B67)、R51/R52(R 通道 → B2_R16)**P/N 接反**。
- U1~U4: VCCA/DIR 未接; OE# 的 4.7k 另一端悬空; 同一颗里 ACK_I 与 ACK_O 方向相反(8T245 一颗只有一个 DIR); U1 的 A 口混了 3.3V(B4/B5)、VCCIO23(B2/B3)、2.5V(B7) 三种 bank 电压。
- 本页无电源部分(VCC3P3/VCCIO23/VCCIO45 无来源)。

相关: [[project_pov3d_hw_pack_dr1v90_gw5a]] [[project_pov3d_panel_rework_stamp_interface]] [[reference_icnd2260_ack_wiring_and_levels]] [[project_gw5a_bridge_verification]] [[project_pov3d_two_phase_two_module_architecture]]

## 📦 逐球引脚分配表已出 (09-16, 用户要"出一份给硬件")
- 交付: `pov3d/POV3D_GW5A转LED转接板_逐球引脚分配_2026-09-16/`(+ 同名 .zip): xlsx 7 sheet / 离线 html / `gw5a_led_adapter.cst` / 工具验证_Gowin; Artifact https://claude.ai/artifact/VpCDMtic49bkCFjXUaf8cC
- 生成脚本: `zynq_pov/docs/GW5A转LED转接板_逐球引脚分配_mkxlsx.py 输出目录`(读 v3 xlsx + V01 PDF 机读, 全断言) → `..._html.py 输出目录 [artifact路径]`; 改分配就改脚本重跑两步再重打 zip。**未提交 git**。
- 口径 = ACK_O 12 直连方案(154/154)。分配: 上行/边带/JTAG = v3 原球位; 下行链 6~11 = V01 原样(链 10 的 D1 由 B3_B71 → B3_B67), 链 0~2 → B7, 链 3/4 → B6, 链 5 = B5_B8(CLK)/B5_B12/B7_T21/B2_R16(跨 3 组 2 连接器); ACK_O 8 根进 bank0/1(T1 1.5V), 4 根进 VCCIO45 半対(T2 3.3V); RSTN=B2_R24_P、I_SYNC=B3_B87_P(T3 2.5V)。与 V01: 46 脚不变 / 6 只改转换器 / 102 改接。
- 🎯 **Gowin 实测(A/B 两版本)**: 出 bit 0 错 0 警告, 报告 154 端口球位/IO_TYPE/BankVccio/DIFF_RESISTOR 与表 0 差异。🔴 **必须 `set_option -use_sspi_as_gpio 1 -use_i2c_as_gpio 1 -use_cpu_as_gpio 1`**, 否则 PR2017: B5_B8、B5_B12, 以及 **v3 上行阶段二 lane B5_B14/B5_B4/B5_B10**(v3 当时没过工具, 这条对 v3 也成立)。
- 机读 V01 PDF 的坑: pdftotext -bbox 下连接器外侧脚号个位数 xMin 比两位数大 3pt, 按 x 聚类会漏 1/3/5/7/9; 网标 y = 外侧脚号 y − 1.7pt。
