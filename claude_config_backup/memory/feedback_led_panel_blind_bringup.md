---
name: 多色 LED panel bring-up 没厂家文档不要盲试
description: ICND1069 panel bring-up 卡在 chain 数 + scan ratio 不知, 盲试 HUB75 / LE / SPI 3 套协议都不亮, 时间花在错误方向 - 必须先要协议文档
type: feedback
originSessionId: 4a5ca456-0b28-4ae3-b178-c2e4275a5f3c
---
**规则**: 接 LED panel / 多色 cascade matrix 这类硬件 bring-up 前, 必须先确认拿到 panel 厂家给的 demo code / 协议文档 / 配套主控 firmware 任一. 没有这些资源 → **不要开工**, 没法判断是协议错还是参数错, 盲试空间无限大.

**Why**: 2026-05-18 ICND1069 panel bring-up — datasheet (ICND1069 V1.2 编程指导) 给的是协议规范, 但 panel-specific 参数 (chain 拓扑 / scan ratio / 寄存器值 / chain map) 不在 datasheet 里. panel 物理参数 (160×180 LED / 108 chip / 16 ch/chip = 16.67 不整除 scan ratio) 无法纯计算反推. 接线图作者 (我之前 conversation 给的) 协议假设错 (标 GCLK = "ICND1069 内置 PLL 可 NC", 但同类 panel SCH 揭示是 OEIN), 引导后续盲试方向也错. 一天时间花在搬协议过来过去, panel 始终不亮.

**How to apply**:
- bring-up 前明确问 user: "panel 厂家有没有给 demo code / 协议文档 / 配套主控板 firmware?" 没有就 stop, 把 finding panel 文档列为 prerequisite, 不开始写驱动.
- 即使 datasheet 协议明确 (e.g. ICND1069 LE 编码完整), panel-specific 参数 (chain map / scan / register init seq) 没文档就盲不到.
- 接线图 / SCH / datasheet 三个都不是 panel 厂商权威文档, 信不过 — 接线图作者也是推测.
- 同类硬件: HUB75 panel, P0.9375 / P1.5 / P2 LED 模组, ICND10xx / ICND20xx / MBI5xxx 系列 driver chip 都属这一类.
- 如果 user 不能拿厂家协议: 建议**退货 / 换标准 HUB75 模组** 而不是继续盲试.

**对比 (有文档 vs 没文档)**:
- 有 datasheet + chain map: 1-2 天 bring-up 通 (写代码 + 调时序)
- 只 datasheet 没 chain map: 1 周-1 月盲试, 最后可能仍 stuck
- 完全无文档 (本次): 不可解
