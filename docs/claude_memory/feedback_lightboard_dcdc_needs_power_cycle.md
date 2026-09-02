---
name: feedback_lightboard_dcdc_needs_power_cycle
description: 灯板 DCDC 有需要重新上电才能恢复的故障 — 每个测量点前必须真正断电 2 秒; 连续改参数不断电的测量(如帧率梯子)可能是在劣化供电上做的
metadata:
  type: feedback
---

# 灯板 DCDC 要每次重新上电 (2026-09-02, 用户实测)

> 用户原话:「每次显示之前你重启一下电源, 这个 dcdc 有些故障需要重启恢复」

## 影响面比看起来大

🔴 **任何"不重新上电就连续跑多个工作点"的测量, 后面的点都可能是在已经劣化的供电上做的。**
今天的帧率梯子(40 → 4032 fps, 11 档)就是这样跑的 —— 我当时刻意不复位, 为的是把帧率
隔离成唯一变量。**在 DCDC 会劣化的前提下, 这个设计反而引入了一个随时间漂移的隐藏变量。**

⇒ 那批梯子数据的**高帧率档需要复测**才能完全采信(低帧率档在前面, 受影响小)。

## 怎么断电

`soft_rst` 会让 `icnd2260_seq.v` 回到 `P_RST` 并清掉 `en_3v8/en_2v8` ⇒ **是真正的断电**,
不只是逻辑复位。但**必须断够久让灯板体电容放干净**: 原来各脚本用的 300~500 ms 不够,
已统一改成 **2000 ms**(16 个 `tools/hw_*.tcl` 全部)。

`tools/hw_fps_ladder.tcl` / `hw_stripe_run.tcl` 还额外在**每一档之间**加了断电重启。

## 可推广的

**"为了隔离变量而保持某个状态不变"这个做法, 前提是那个状态本身是稳定的。**
被测物有随时间劣化的部件时, 保持不变 = 引入一个你看不见的漂移变量。
这与 [[feedback_fixing_the_defect_removed_the_margin]] 是一类问题:
**实验设计的正确性依赖于对被测物的假设, 而那些假设需要单独验证。**

相关: [[feedback_vddr_sags_to_1v9_invalidates_fps_limits]] [[feedback_fixing_the_defect_removed_the_margin]]
[[reference_icnd2260_display_rate_model_validated]]
