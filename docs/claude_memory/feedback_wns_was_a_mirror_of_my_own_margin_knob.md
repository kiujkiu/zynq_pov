---
name: feedback_wns_was_a_mirror_of_my_own_margin_knob
description: 追了大半天的 1.652ns Clock Path Skew 是假警报(符号在加号侧, 真实两树失配 1ps); 而所有高频"时序不过"= WNS = MARGIN - 0.78, 是构建脚本魔数的镜像, 与频率无关
metadata:
  type: feedback
---

# 我把一个必需项当成了头号拦路虎, 追了大半天 (2026-09-02)

## 事实一: 1.652 ns 那个 Clock Path Skew 是**假警报**

我看到 `Clock Path Skew 1.652 ns`, 对比"正常 BUFG 树失配 100~200ps", 判定它异常,
并把它当成"通往 10k fps 的头号拦路虎"写进了多轮结论。**错的, 符号是反的。**

它在 setup 里进的是 **required time 的加号侧**:
```
slack = Requirement + CPS − Uncertainty − OutputDelay − DPD
div16:  4.000 + 1.652 − 0.211 − 3.000 − 2.223 = +0.218   ✓ 与报告逐位吻合
```
1.652 = 转发时钟自己的 ODDR(0.411) + net(0.001) + OBUFDS(1.638) = 2.050
        − 两棵树 min/max 降额记账 0.684 + CPR 0.287
**两棵 BUFG 树的真实物理失配 = 1 ps**(Max/Min 段逐级对照), 比预期好两个数量级。

🔴 **教训: 看到一个"异常大"的数字之前, 先搞清楚它在公式里是加还是减。**
我从报告里挑了一行、和一个记忆中的经验值比较, 就下了结论, 中间跳过了"它怎么参与运算"。

## 事实二: 所有高频"时序不过", 是我自己那个魔数的镜像

`tools/build_bit_dbg.tcl` 的 `set MARGIN [expr {$CLK_DIV >= 12 ? 1.0 : 0.3}]`,
而约束里 `TSU = PH_NS − MARGIN`、`Requirement = PH_NS` ⇒ **周期项完全对消**:
```
WNS = MARGIN − 0.78
  div6  0.3 → −0.470 ✓   div8  0.3 → −0.473 ✓   f152 0.3 → −0.468 ✓
  div10 0.8 → +0.024 ✓   div16 1.0 → +0.218 ✓
```
**六个 build 全部命中。**
⇒ 🔴 **WNS 不是物理裕量, 它是 MARGIN 这个人为旋钮的镜像, 与频率无关。**
我曾拿"125 和 152 的 WNS 几乎相同"当作"卡在固定项"的证据 —— 其实只是两次用了同一个 MARGIN。

## 事实三: 手册的典型值在数学上就留不出余量

DDR 下位宽 = tLVCP/2, 而 `tSTU + tHLD = 1/4 + 1/4 = tLVCP/2 = 整个位宽`。
⇒ "满足典型值"等价于"时钟沿精确落在位中心且零抖动", 任何真实 FPGA 都做不到。
**MARGIN 这个旋钮不是作弊, 是必需品**; 真正的判据只能是上板爬频率。

## 事实四: 上板一试就有答案 —— 155 MHz 芯片收不了

【实测 2026-09-02 15:47】`div7_cas2_f155`(155.36MHz):
**FPGA 侧完美** —— `fps=361` 与预测 361 逐位命中, frame_cnt 稳定递增一帧不丢, sticky=0;
**屏是黑的**(先有别的块闪一下, 随后全黑 = 芯片把配置一起收坏后关输出)。
⇒ 发送侧被独立证明健康 ⇒ **失败百分之百在链路/接收端, 是真实物理上限。**

## 可推广的

**当一个"判据"是自己发明的(手册没给最小值), 它红了只说明旋钮拧紧了, 不说明物理不行。**
这种时候唯一的裁判是被测物本身。我应该在第一次看到 `WNS=-0.473` 时就上板试, 而不是
先花几小时去解释它、再基于那个解释做决策。

相关: [[feedback_time_average_cannot_measure_display_rate]]
[[reference_icnd2260_gclk_pm_and_link_ceiling]] [[feedback_verdict_design_before_blaming_dut]]
[[feedback_fixing_the_defect_removed_the_margin]]
