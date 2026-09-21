---
name: project_pov3d_bridge_logic_need
description: 2026-09-16 桥 FPGA 实际资源需求 (实测报告清点 + 缺块补综合 + 挑错复核) — 阶段一整机实测 EG4A20 布线后 4387 LUT4 / 5942 FF / 46 bram9k / 192 pad; 阶段二全功能 (18+1 lane 800M FIFO768 边带 UART 串行扫眼) 块相加 GW5A ≈7.3~7.9k LUT+ALU / LUT6 ≈4.1~4.5k; 卡选型的是 IO (205~208 脚 / 93~94 対) 不是 LUT —— GW5A-25 UG324 (201 IO/91 対) 不够要 UG324S; 最大变量是扫眼写法 (并行 3.3k vs 串行 0.36k); 本设计 LUT4:LUT6 ≈1.4~1.6 不是 2.3
metadata:
  type: project
---

# 桥 FPGA 真实需要多少资源 (2026-09-16)

workflow `wf_e2e7b514-aed`: 构建报告清点 + 需求缺块补综合 (GW5A gw_sh / EG4 与 PH1A60 TD / Xilinx Vivado 2024.2 xc7a100t, 全在 C:\temp 副本) + 合并 + 挑错。项目目录一个文件没改。

## 实测 (整机, 阶段一 = 现役 14 対: 12 数据 + 1 校验 lane, 8-bit, 24 链, 无边带/扫眼)
| 架构 | LUT | FF | 块 RAM | 其它 |
|---|---|---|---|---|
| **EG4A20BG256 布线后 (eg4_bridge v7 交付版)** | **4387 LUT4** | 5942 | 46 bram9k | 192/195 pad, SWNS +0.100 @dclk150, 只跑过默认种子 |
| GW5A-25 综合 (时钟外壳, 无 PLLA/HCLK) | 4961 | 6429 | 25 BSRAM (18kb) | |
| Xilinx xc7a100t 布局后 | 3008 LUT6 | 5159 | 9 RAMB36 | |
| PH1A60 gate 位点 | 2377 | 5090 | 22 eram20k | |
出处: `dr1v90/eg4_bridge/results/real_d150_poultra_u0.160/fpga_prj_phy.area`。🔴 eg4_bridge 其它 seed / d166 结果是 v7 之前的 RTL, 不能当交付版引用。

## 全功能 (阶段二契约: 18+1 lane 800M, FIFO 768, 边带 UART + SB_ALIGNED/RSTN, 串行扫眼) —— 各块实测相加, **整机从没一起综合过**
- **GW5A ≈7.3k~7.9k LUT+ALU** (块和 7237 + 扫眼胶合 50~300 + 5%), FF ≈8.2k~8.5k, BSRAM 42/56 (FIFO 512 时 26)
- **LUT6 (Xilinx) ≈4.1k~4.5k**, 16 RAMB36; PH1 ≈3.6k; EG4 布线后 ≈6.3k 但只放得下 FIFO 512 (50/64 bram9k), FIFO 768 要 ~82 块
- **扫眼写法是最大变量**: 沿用 gw5a_loop 现有并行 eye_scan (19 lane GW5A 3315 LUT) ⇒ GW5A ≈10.2k~10.7k; 改一次扫一条的串行版 364 LUT (扫完 19 lane ≈50 ms) —— 串行版还没实现, 只有资源代理
- 12-bit (D06 未定义, 代理): GW5A ≈7.8k / FF ≈9.0k; 12-bit + FIFO 768 BSRAM ≈58 > GW5A-25 的 56
- T20 对照 ≈6.7k; 一颗桥片带两面 (与 D1/D2 冲突) ≈13.5k + 83 BSRAM 要 484 球封装
- 各块 (GW5A, 19 lane): lane_align 2068 / lane_deskew 1369 (被推成寄存器阵列, 改显式 SSRAM 估省 ~1k LUT+1k FF) / rx_top+fifo 128 / ul_dispatch 959 / tx_array 1139 / icnd2260_seq 227 / ack_rx 97 / 顶层 241 / sb_ctrl 562 (代理) / 串行扫眼 364 (代理)

## 选型结论
- **LUT 不卡, IO 卡**: 用户脚 ≈205~208 (漏算的 SCL/SDA、LED 已补), LVDS **93~94 対**。
  - GW5A-25 **UG324: 201 IO / 工具认 91 対 ⇒ 不够**; **UG324S: 218 IO / 可用约 97~98 対 ⇒ 放得下但余量 <5%** (不是 116 対, 116 是封装物理対数)。
  - EG4A20BG256 195 pad 无条件放不下 (D3 禁止回收 JTAG); 块 RAM 只在 FIFO 768 或 12-bit 时超。
- 块 RAM 只在 12-bit + FIFO 768 时卡 GW5A-25。
- 留量建议 LUT ≤50% ⇒ LUT4 ≥~15k / LUT6 ≥~9k (绝对底线约 11k / 6.2k)。挑错代理指出 5% 集成余量与 50% 规则里的不确定性重复计了一次, 下限可以放宽讨论。
- **时序风险未计**: GW5A 综合里 u_rx fifo → u_disp CRC 路径 13 lane Fmax 121 MHz, 19 lane 92~98 MHz, 目标 dclk 150 MHz ⇒ 要加流水; 19 lane 变体三家都没布线。

## 口径更正
- 本设计 **LUT4:LUT6 ≈1.4~1.6** (只比逻辑); 旧系数 2.3 来自宽 mux 的单链 icnd2260, 用在桥片上系统性低估。⇒ [[reference_bridge_fpga_alternatives]] 里 "4387 LUT4 ≈ 1.9k LUT6" 错, 实测 3008 LUT6。
- S1 早先估的 "GW5A 整桥 BSRAM ≈46/56" 错: GW5A 块是 18kb, 阶段一实测 25 块。
- EG4 gate 报告里 `#Total_luts` 不能当逻辑量, 一律用 `#lut`。

## 下一次最值得做的实测
把 19 lane + FIFO 768 + sb_ctrl + 串行扫眼 + 胶合, 在真实时钟 (PLLA/CLKDIV, dclk 150 / pclk 100) 与 **UG324S 引脚约束**下在 GW5A 上整机综合 + 布局布线, 替换块相加, 并确认 CRC 路径能否 150 MHz 收敛。
另注: UG324S 的 JTAG 同样与 VCCX 共球 (见 [[reference_bridge_fpga_jtag_voltage]]), 电平转换器照旧要。
