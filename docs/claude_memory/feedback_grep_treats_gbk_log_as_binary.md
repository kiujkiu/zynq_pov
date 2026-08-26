---
name: GBK 污染的构建日志让 grep 返回 exit 1 —— 失败的构建会 grep 成"干净"
description: 非法 UTF-8 ⇒ grep 判 binary ⇒ **匹配到也 exit 1**; `grep -q ERROR:` 静默放行失败构建; 修 `-notrace`
type: feedback
---
2026-08-24/25 集成 PL lz4 时踩到，**第一次的归因是错的，这里是修正版**。

Vivado 把 `source` 的命令回显进日志，而**带花括号的块 (`if`/`foreach`/`proc`)
是整块回显的** —— 里面的中文注释一并进去，`cmd.exe` 按 GBK 写出，
注入非法 UTF-8。GNU grep 一旦把文件判成 **binary**，就不再报告匹配，
**并且返回 exit 1**。

## 🔴 危险方向: 失败的构建 grep 成干净的

用真实日志的字节前缀合成的失败日志实测：
```
grep -q "ERROR:"        -> exit 1   ⇒ 判定"干净"    ← 日志里明明有 ERROR:
grep -q "BUILD_FAILED"  -> exit 1   ⇒ 判定"通过"    ← 也明明有
加 -a 之后两条都 exit 0
```
⚠ 我最初只注意到无害方向（`grep '^TIMING_'` 返空 ⇒ 误判成"构建没跑完"），
把它记成了「读日志的不便」。**实际是 exit-status 缺陷，会掩盖构建失败。**

尤其致命：`create_panel_proj_v6.tcl` 的 **WHS 门禁**（hold 违例时 `exit 1`）
正是靠日志判定的 —— 任何不带 `-a` 的外层检查，会把门禁要抓的那次失败原样吞掉。
这个设计的 hold 余量只有 0.020–0.033 ns，门禁失效不是小事。

## 修法

**根治**: `vivado -mode batch -notrace -source ...` ⇒ 不回显 source 的命令。
A/B 实测同一脚本：非 ASCII 字节 **110 → 0**，`grep -q MARK` 从 exit 1 → exit 0。
**已有的旧日志**: 只能靠 `grep -a`。

**Why**: 静默的**假阳性通过**。没有报错、没有异常退出码，
只是判据本身消失了 —— 而判据消失的默认解读恰好是"没问题"。

**How to apply**:
1. Windows 侧 Vivado 一律加 `-notrace`；读旧日志一律 `grep -a`。
2. 更一般地：**用 `grep -q` 做门禁时，exit 1 有两种含义**
   ——「没匹配到」和「grep 根本没在读文本」。
   门禁必须能区分，否则它只在不需要它的时候有效。
3. 同类「判据自身失效却看起来正常」见
   [[feedback_pair_miss_sentinel_was_broken]] 和 [[feedback_sim_verifies_timing_not_semantics]]。
