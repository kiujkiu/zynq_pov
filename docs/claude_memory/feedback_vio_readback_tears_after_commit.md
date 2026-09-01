---
name: feedback_vio_readback_tears_after_commit
description: commit_hw_vio 之后立刻 refresh_hw_vio, 32 位探针会被读成"同一个 16 位值高低半区重复"; 今天所有"三千万帧/回包超上界"的假数据都是这个
metadata:
  type: feedback
---

# VIO 读回撕裂: commit 之后不能马上 refresh (2026-09-01)

2026-09-01 一天之内, 扫参数的脚本**五次**给出离谱数字:
`frames+34,144,777`、`ack_cnt+2818 err+2818`、`ack_cnt+16641`…
每次都被守卫判废, 但当时不知道根因。

## 根因

在 `hw_pat_step.tcl` 里同时打印 32 位的 `frame_cnt`, 露馅了:

```
frame_cnt = 0x9a999a99 / 0x9c7c9c7c / 0xa042a042 / 0xa225a225
```

**每一个都是同一个 16 位值在高低半区重复。** 不是随机噪声, 是
`commit_hw_vio` 之后立刻 `refresh_hw_vio`, JTAG 移位链还没稳,
**32 位探针被读成一个 16 位值重复两遍**。

这也解释了为什么 `ack_frame_cnt` 和 `ack_err_cnt` 的增量总是**完全相同** ——
两个 16 位计数器被从同一段撕裂数据里切出来。

## 修法

所有 `proc setp` 里 `commit_hw_vio $p` 后加 `after 120`。已改:
`hw_sweep.tcl` / `hw_ask_all.tcl` / `hw_crc_ab.tcl` / `hw_pattern.tcl` / `hw_poke_regs.tcl`。

**更稳的做法(建议保留)**: 每个计数器读两次、间隔 250ms, 两次不一致就标 `TORN-READ` 判废
—— `hw_sweep.tcl` 的 `snap` proc 就是这么做的, 它**在根因不明的情况下依然挡住了全部五次假数据**。

**How to apply**: 这是"量具自己会骗人"的又一例。判据设计上的通用做法:
1. **同一个量读两次要求一致**(撕裂不会重复)
2. **给每个计数器配一个物理上界**(回包不能超过提问次数、帧数不能超过 fps×时间)
3. **两个由互斥条件驱动的计数器, 增量相同就是量具坏了**

相关: [[feedback_ack_silence_is_not_evidence]] [[project_lxb_icnd2260_bringup]]
