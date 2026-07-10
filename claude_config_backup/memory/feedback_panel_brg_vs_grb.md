---
name: panel 2 内部是 BRG, panel 1 是 GRB (同款 panel 不一定同 IDC pin 色序)
description: 2026-06-08 v34f panel 2 实测发现 IDC pin 1/3 上的 chip 跟 panel 1 G/B 反, 同款 panel 模块也可能不同批次不同 RGB pin 排布, 必须先单板单色测过才能定型
type: feedback
created_at: 2026-06-08 19:24 CST
updated_at: 2026-06-08 19:24 CST
originSessionId: c65586d5-1bd7-42fb-bf7e-7a8b7f63582c
---
**踩坑**: dual panel v34 mirror, panel 1 跟 panel 2 用"同款" HUB75E 模块, 默认假定 RGB pin 顺序一样. panel 1 实测是 **GRB swap** (IDC pin 1=chip G, pin 2=chip R, pin 3=chip B), v34 xdc 按 GRB swap 设计接 panel 2. 实测 panel 2 是 **BRG swap** (IDC pin 1=chip B, pin 2=chip R, pin 3=chip G) — chip G 跟 chip B 反!

**症状**: 写 GREEN, panel 2 显示蓝色 (chip B 亮); 写 BLUE, panel 2 显示绿色 (chip G 亮). 写 RED 对 (chip R 没变). 即在 panel 2 上 G/B 互换.

**Why**: 同一 panel 厂可能不同批次 / 不同 PCB rev 用不同 IDC pin 跟 LED chip 的排布. 没厂家文档时无从知道.

**Fix v34e + 物理换线 (2026-06-08, 用户选这条路)**: 保持 xdc 跟 panel 1 同 GRB swap, 物理换线适配 panel 2 BRG:
- panel 2 IDC pin 1 ← J1.21 (B 信号 Y13) [was J1.22 G 信号]
- panel 2 IDC pin 3 ← J1.22 (G 信号 AA13) [was J1.21 B 信号]
- panel 2 IDC pin 5 ← J1.30 (B2 信号 Y16) [was J1.19 G2 信号]
- panel 2 IDC pin 7 ← J1.19 (G2 信号 AB14) [was J1.30 B2 信号]
也就是 J1.21↔J1.22 和 J1.19↔J1.30 互换. 优点: 两块 panel xdc 一致, 后续上 panel 3/4 加排针只要按物理 chip 色序换线 1 次, PL 不动.

**备选 v34f xdc swap (尝试后撤回)**: 改 xdc rgb2[1]<->rgb2[2] + [4]<->[5], 不动 wiring. 缺点: 两块 panel xdc 不一致, 多 panel 时 xdc 越来越乱.

**How to apply (新装 panel)**:
1. 单色 R/G/B 各跑一次, 看 panel 显示哪个颜色
2. 反推 IDC pin → chip 映射
3. xdc 按反推映射写 (一般 G/R 跟 R/G 互换, B 不动 = GRB. 但也可能 G/B 反 = BRG)
4. 不要靠 silkscreen "R1/G1/B1" 标签 (那只是 HUB75E 标准 IDC label, 不代表内部 chip)

**额外坑**: 这次还混了 GPIO1 pin map 抽错 (memory 把 J1.19/20/21/22 跟 J1.31/32/33/34 抽反, 见 feedback_memory_pdf_pinout_swap.md), 调试时间多花 2 小时.

**调试时间**: 2026-06-08, 上午到傍晚, v34e dual panel bring-up 总共 5h. 后半段定位 panel 内部 BRG vs GRB 用了 30 min.
