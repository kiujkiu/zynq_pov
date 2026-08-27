---
name: feedback_only_synthesis_catches_it
description: 多驱动与端口位宽不符这两类错, 只有综合(TD)能抓 — iverilog 不报、verilator 5.032 连 5 行最小复现都不报; 而 TD 对位宽不符也只发 WARNING 不发 ERROR, 照样出 bit
metadata:
  type: feedback
---

# 有一类错只有综合能抓, 仿真和 lint 都不行 (2026-08-27, DR1 B 线)

## 事实一: 同一个 reg 被两个 always 块赋值 = 多驱动

`dr1v90/rtl/axi_hp_arb.v` 的 `len_err`/`size_err` 是 `output reg`, 而读通路和写通路是
**两个独立的 always 块**, 两块都会拉它们。

| 工具 | 反应 |
|---|---|
| **TD 5.9.1** | `HDL-8007 ERROR: net 'len_err' is constantly driven from multiple places` ⇒ 模块变黑盒, 综合停 |
| iverilog | **一声不吭**(调度上"最后写的赢", 而两块都只写 `1'b1`, 看不出差别) |
| **verilator 5.032** | **一声不吭** —— 连 5 行的最小复现都不报 |

⚠ verilator 那条是**实测确认**的, 不是猜: 专门造了 `md_probe.v`(两个 always 都写同一个
`f <= 1'b1`)跑 `--lint-only -Wall`, 退出码 0、零输出。**先证明量具, 再下结论。**

**为什么 11 档功能回归 + 7 条变异测试全过还是没抓到**: tb 只断言这两个标志**保持 0**,
而全部激励都是合法突发 ⇒ **那段逻辑一次都没被执行过**。判据只验了健康路径。

## 事实二: 但也别指望 TD —— 位宽不符它只发 WARNING

`HDL-5007 WARNING: actual bit length 32 differs from formal bit length 64`, **不是 ERROR**,
照样产出 `.db` 和 `.bit`, 全流程 0 个 ERROR。
证据就在本项目自己身上: 厂商 PS 生成器给 64 位的 `slave_hp1_axi_wdata` 接了 `32'b0`、
给 8 位的 `wstrb` 接了 `4'b0`, **这个状态在工程里静默躺了几个月**。

⇒ 🔴 **「接错了 TD 会告诉我」这个安全网不存在。**
`docs/hp_topology.md` 原文写的「连了如果不存在, TD 会在 elaboration 直接报错,
是**能立刻发现**的那种失败, 不会静默」—— **这句是错的**, 已在文档里划掉。

## 事实三: 未驱动的网 TD 静默当 0

`SYN-5025 WARNING: Using 0 for all undriven pins and nets`。
所以「输入忘了接」在综合上是**功能等价于接 0**, 板上量不出差别, 但:
- 取值静默依赖工具默认, 而这不是 Verilog 语义, 换工具/换版本就变
- 仿真看到的是 X/Z ⇒ **仿真与综合从此不一致**

## How to apply

1. **新写的 RTL, 在「仿真全过」之后、上板之前必须过一遍综合。**
   为此建了 `dr1v90/td_arb/build.sh`(表征顶层 + 一分钟跑完), 见 [[project_dr1_hp_topology_decision]]。
2. **未用的端口要显式 tie, 不要靠"不连"。** `pov_dr1_top.v:73` 自己写着
   「awvalid/wvalid=0 最关键, 绝不能悬空」—— 那条规矩是对的, 要执行到每个新口。
3. **写回归时, 对判据本身也要有一次"注入必然失败、确认它会 FAIL"的自检**(变异测试)。
   只断言"某标志保持 0"而从不制造非 0, 等于那段逻辑没被测。

相关: [[feedback_verdict_design_before_blaming_dut]] [[feedback_sim_verifies_timing_not_semantics]]
[[feedback_always_ready_tb_hides_handshake_bugs]] [[feedback_differential_criterion_blind_to_common_mode]]
[[project_dr1_hp_topology_decision]] [[feedback_td_infer_ram_skips_generate_blocks]]
