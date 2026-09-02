---
name: reference_icnd2260_startup_writes_table_66_times
description: 上电到第一张真图之间整表已写 66~67 遍且全在全黑期(LED 电流≈0); div16/div48 次数相同只有时长不同 ⇒ "重发配置"解释不了两档差别; 另: 失效永远不在第1跳
metadata:
  type: reference
---

# 上电配置其实写了 66 遍, 不是 1 遍 (2026-09-02)

## 事实一: 66~67 遍, 全在黑暗中

`rtl/icnd2260_seq.v` 主线 `P_SETTLE → P_VS_1 → P_REG_1 → P_VS_2 → P_REG_2 → P_BLANK → P_RUN`:

| 来源 | 遍数 |
|---|---|
| `:310-313` P_REG_1 + P_REG_2 | 2 |
| `:319` P_BLANK **每帧无条件一遍** × `BLANK_FRAMES=64` | 64 |
| 进 P_RUN 第一帧 `refresh_cnt` 恰好回绕到 0 | 1 |
| **合计** | **66~67** |

**全部发生在 `SRC_ZERO` 全黑期, LED 电流 ≈ 0。**

进入 P_RUN 后由 `:352` + `REG_REFRESH_FR=64` 继续每 64 帧重发一次
(div16@118fps = 0.54 s 一次; div48@39fps = 1.64 s 一次)。

## 事实二: 🔴 这条否掉了"重发次数"这个解释

div16 和 div48 的**上电配置遍数完全相同**, 唯一差别是这 66 遍的墙钟时长
(RAIL_SETTLE 是**拍数** 500_000 ⇒ div16 = 8.0 ms, div48 = 24.0 ms)。
⇒ **"重发配置收敛"作为两档成功率差异的解释, 在数学上塌缩成"等待时间"。**
我曾提出的"随机游走: 重发在反复打坏好芯片"模型, 至少在上电阶段不成立。

## 事实三: 🔴 失效永远不在第 1 跳

第 1 跳直接吃 FPGA 出口眼图 —— 那是全链**唯一由我们控制、也是最差控的**一只眼
(ODDR + OBUFDS, 两棵 BUFG 树, 实测 Clock Path Skew 1.652 ns)。
**它从不失败**, 而芯片自己再生转发的第 2~9 跳会坏。
⇒ **纯 FPGA 侧时序(相位/偏斜)解释不了失效位置。** 沿链累积的量(地弹、共模漂移、
抖动累积)才天然给出"从第 k 跳起往下全死"的前缀形状。

## 事实四: 相位扫描在结构上是瞎的

`tools/build_bit_dbg.tcl` 让 XDC 的 TSU/THD 跟着相位一起走 ⇒ PH_NS 在 slack 里被完全约掉
⇒ **WNS 永远是 0.218, 时序报告对相位结构性无感**。
加上 n=10 的统计噪声(σ≈1.55), 那条 2/10~6/10 的相位曲线读不出任何东西。
⚠ 另: `90°→2/10` 那个点用的 bit 是 09-01 21:15 编的, 比其余五点早一整晚的 RTL 改动,
**不能和它们放在一起比**。

## 事实五: 这些参数 `-generic` 传不进去

`rtl/icnd2260_lxb_lvds_top.v:224-234` 的 `u_seq` 例化参数表只有
`NLANE / PIX_PER_LINE / LINES / CASCADE / BLANK_FRAMES / FRAME_GAP / FB_AW / REG_MEM`。
🔴 **`RAIL_SETTLE` / `REG_REFRESH_FR` / `READ_PROBE_FR` / `RAIL_STAGGER` / `QUIET_CYCLES`
都不是顶层参数, `-generic` 会被 Vivado 静默忽略**(只留一条 warning), 产出的 bit 与对照组
逐位相同 ⇒ 会拿到"改了没变化"的**假阴性**。要改必须动 `icnd2260_seq.v` 的默认值本身。

相关: [[feedback_slower_clock_does_not_reduce_per_bit_noise]]
[[feedback_fixing_the_defect_removed_the_margin]] [[reference_icnd2260_forward_delay_reg_absent]]
[[project_lxb_icnd2260_bringup]]
