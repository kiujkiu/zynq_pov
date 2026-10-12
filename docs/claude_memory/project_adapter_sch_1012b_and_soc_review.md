---
name: project_adapter_sch_1012b_and_soc_review
description: 2026-10-12 傍晚审桥转接板 10-12 第二版 "(1)" + SoC 转接板首版 Schematic1 — 桥: VCCIO45 已回 3.3V、U18 补齐, 但新 U19 边带 A/B 两侧接反; SoC: FPC 70 导体逐脚对上, 但 2.5V DCDC VIN 悬空、JTAG 菊花链; TPS56A37 吃 24V 合法 (4.5–28V)
metadata:
  type: project
---

## 桥转接板 `SCH_GW5A to LED board V01_2026-10-12 (1).pdf` (md5 435a245d, 17:43)
- ✅ 改板单② VCCIO45 回 3.3V (L3 贴, L7 NC)。U18 补 R219 (TDO 10k 下拉)、R221–R223 (TDI/TMS/TCK 10k 均下拉)、R220 (OE# 10k 下拉常使能); 下载座 H1 PZ254V-11-06P 在 A 侧 2.5V (1 GND/2 TCK/3 TMS/4 TDI/5 TDO/6 PWR2V5), 用时须拔 FPC。
- 🔴 新 U19 SN74AVC4T774 (边带) **A/B 两侧接反**: A 侧 (VCCA=PWR2V5) 经 R228–R231 接了 B4_B29_N/B52_N/B39_P/B39_N, B 侧 (VCCB=VCC3P3) 经 R224–R227 接了 DR1V_ACK/RST/UART_RX/UART_TX (主会话看图确认)。DIR1..4 = L/H/L/H, 两侧对调即全对。上下拉 R235/R236 在 GW5A 侧, 应改 FPC 侧 (RST 下拉、UART_TX 上拉), R236 (UART 下拉) 删。
- 🔴 仍未改: CN3/CN6 脚号 101−n; FPC2 尾部 (62 ACK/63 RST/64 UART_RX/65 UART_TX/66 GND/67–70 TDO,TDI,TMS,TCK, 71 列外接地); 标题栏 _1010。删掉的 R129–R132 (0Ω 直连) / R173 由 U19 一组接替。

## SoC 转接板 `SCH_Schematic1_2026-10-12.pdf` (md5 5e6df52c, DR1M90/FS03 底板 → 两路 FPC)
- ✅ FPC1 (面 A, CEP1=bank33) / FPC2 (面 B, CEP2=bank11) 与桥 FPC2 1–70 逐脚同名; 40 对 P/N 同一差分对, 无交叉。两端座子同为 XW0525512-702R-001 ⇒ FPC 线必须 1↔1 导通 (线型要写进图纸)。阶段一 CLK=CEP1_12、CHK=CEP1_13、D0..5=CEP1_6..11、D6..11=CEP1_14..19。
- 🔴 U5 STI3411A VIN 接孤立网 PWR5V (全图仅 1 次) ⇒ PWR2V5 不出电; 应接 VCC_5V。H7/H9 (PWR2V5 两针) 推测给 FS03 bank33/11 改 2.5V 的飞线, 待确认。
- 🔴 JTAG 菊花链: CEP1_24N→桥A TDI, FPGA1_TDO→桥B TDI, 桥B TDO→CEP1_24P; TMS/TCK=CEP1_4P/N 共用。违反契约每面独立/按面 IDCODE。建议桥 B 单独 TDI/TDO 用空闲 CEP2_8P/N。
- 前提: FS03 bank33/bank11 须 2.5V (原厂只有 3.3/1.8 档); bank11 改后 2047 屏不能接 CEP2; CN3 光电开关 3.3V 供电进 2.5V bank 要处理。面 A 6 对 + 面 B 全部 20 对 ODDRx2 未验证 ⇒ 重出 .adc 跑 TD。发送端 100Ω/NC (R182–R201、R53–R72) 必须 NC。
- ✗ agent 曾报 "TPS56A37 VIN 4.5–16V, 24V 超压" —— 错, TI 官网 4.5–28V, 24V 合法 (余量小, 滑环场合建议 TVS)。

相关: [[project_adapter_sch_1012_review]] [[reference_adapter_change_order_1010]]
