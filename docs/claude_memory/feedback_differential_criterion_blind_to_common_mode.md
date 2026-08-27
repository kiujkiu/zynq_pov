---
name: feedback_differential_criterion_blind_to_common_mode
description: 差分判据(新东西 vs 已知good基准)在两边一样坏时会一起放过; 而"基准是上板验证过的"这个前提必须核到同一个模块, 不能从一个模块搬到另一个
metadata:
  type: feedback
---

# 差分判据看不见共模故障 (2026-08-27, DR1 HP1)

## 事情经过

把 DR1 的第二个 HP 口(HP1)接出来之后, 要判断"接对了没有"。
第一版判据写的是 **「HP1 相关警告必须为 0 条」**, 跑出来 22 条。
查下去发现 HP0 本身就带同样的 8 条 `SYN-5013 Undriven net (ar/awlen)` + 1 条 `arst_n`。

⇒ 改成差分的: **「HP1 的警告集合与 HP0 的是不是逐条相同」**。
**这一步改对了** —— 绝对判据会被既有噪声顶死, 还会诱使人去"修"一个没坏的东西。
判据通过: 各 17 条, 归一化后逐字相同。✅

## 🔴 但当时给出的理由是错的, 而错的理由放过了一个真 bug

理由写的是: **「那些是既有噪声, 因为 HP0 也有, 而 HP0 是上板验证过的」**。

**「上板验证过」被从一个模块搬到了另一个模块。**
上板验证过的是 `td_pov`(走 `axi4_to_axi3_hp`, Step 3 取片 148,561 字零错);
而这 8 条 undriven 警告**只出现在测量工程 `measure/01_hpbw` 里** ——
`td_pov` 的综合日志里 HP0 一条 undriven 都没有。查一下就知道, 但我没查。

真 bug 是: `hp_traffic_gen.v` 的 `m_arlen`/`m_awlen` 声明成 `output wire [3:0]`,
却**全文件没有任何 `assign` 驱动它们**。TD 把未驱动网当 0
⇒ **每笔 burst 退化成 1 拍而不是 16 拍** ⇒ 那个工程的自变量(`blen × outst` 扫描)
根本没接到总线上, **整张带宽表都是错的, 而曲线会很平滑很可信**(因为 `outst` 是真在变)。

修完之后, 警告从每边 **17 条掉到 1 条**。

## 两条可推广的

1. 🔴 **差分判据在两边一样坏时会一起放过 —— 它对共模故障是盲的。**
   HP0 与 HP1 用的是**同一个** `hp_traffic_gen`, 同一个 bug 在两边对称出现
   ⇒ 集合相同 ⇒ 判据 ✅。
   ⇒ 用差分判据时要问一句: **"被比的两边有没有共用的东西?"** 共用的部分不在判据覆盖内。
2. 🔴 **「基准是已知 good 的」这个前提, 必须核到同一个模块/同一份设计。**
   "上板验证过"是对某个具体工程说的, 不能顺着信号名搬到另一个工程。
   核一下的成本是一条 grep。

## 顺带: 另外三条也在同一轮审计里被逮到, 共同点都是"判据看不见"

- `err_cnt` 只统计 `RRESP/BRESP != OKAY` ⇒ **看不见"根本没应答"**
  (完全不应答的口给出的正是 `err=0`/`stable=1`, 旧判据 `err==0 && stable` 会给它 PASS)。
  ⇒ 补了粘滞位「`arready`/`awready` 曾经拉高过没有」。
- 加的两个观测寄存器与"HP1 能不能应答"**电路上毫无关系**(它们看的是 `p2f_clk1`,
  而 HP1 的 aclk 是 `p2f_clk0`) ⇒ **两个读数全绿的同时 HP1 可以是死的**。
- 16 位计数器在 100 MHz 下 655 µs 绕一圈, 而现成范例用 1.5 s 窗口
  ⇒ **混叠是确定性的** ⇒ 重复测得同一个错值, **看上去很稳很可信**。

## How to apply

**判据全过之后, 再单独跑一轮"专门找判据覆盖不到什么"的审计。**
这次那轮用了四个视角(漏接错接 / 配置被改坏 / 静默失败 / 判据可信度),
**四个视角一个都没说干净**, 19 条里四个是真缺陷 —— 而前面那五条判据全是绿的。

相关: [[feedback_verdict_design_before_blaming_dut]] [[feedback_pair_miss_sentinel_was_broken]]
[[feedback_only_synthesis_catches_it]] [[feedback_touch_success_is_not_writable]]
[[feedback_grep_treats_gbk_log_as_binary]] [[project_dr1_hp_topology_decision]]
