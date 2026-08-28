---
name: feedback_criterion_must_not_contain_its_answer
description: 🔴 判据文本里不能出现答案字面量 — 回显/日志/提示符会把命令本身送回同一条通道, 主机 grep 命中的是命令不是输出; 一天内咬了三次
metadata:
  type: feedback
---

# 判据里不能出现它自己的答案 (2026-08-27, 一天三次)

**在命令和输出走同一条通道时** (串口回显、shell 日志、`set -x`、CI 里 echo 了命令的
构建日志、把 prompt 一起收进来的 pexpect), 主机侧对"答案字符串"做 grep,
**命中的可能是命令本身**。

## 三次实例, 全是同一个病

| # | 写法 | 为什么恒错 |
|---|---|---|
| 1 | `grep -q -- '-echo'` | **子串**命中 `-echonl`/`-echoprt`/`-echoctl` —— 而这些在回显**开着**时也是关的 ⇒ **永远报 OFF, 不可能报 ON**。实测原文: `isig icanon -iexten -echo echoe echok -echonl -noflsh -xcase -tostop -echoprt` |
| 2 | `... && echo TTY-ECHO-OFF \|\| echo TTY-ECHO-ON` | 这条命令**自身含两个答案字面量**; 回显开着时板子把整条命令原样吐回, 主机 grep 命中的是**命令的回显**。80 列折行还会把字面量从中间切断 |
| 3 | `echo "$out" \| grep -oE "Q=(ON\|OFF)"` | 同上, 一次探测吐出三个 `Q=`: 前两个来自命令回显, 只有第三个是真结果 |

## ✅ 正确写法

**让命令文本里根本不出现答案 —— 只回 `$?`, 答案在主机侧解码。**

```sh
stty -a 2>/dev/null | tr ' ;' '\n\n' | grep -qx -- '-echo'; echo "ECHOQ=$?"
```
主机侧: `ECHOQ=1` = 没找到 `-echo` = 回显开着。

配套两条:
- **按词匹配, 不按子串**: `tr` 拆开 + `grep -qx`。флаг 名互为前缀是常态。
- **答案 token 要和命令文本正交**: 用 `$?`、随机 GUID 标记、或输出里才可能出现的编码值。

## Why

本项目的判据大量依赖"主机读串口 + grep"。这条通道**天生把命令和输出混在一起**,
而这正是判据最容易静默失效的地方 —— 它不报错, 它给你一个**看起来合理的错答案**。
同源的老伤: [[feedback_pair_miss_sentinel_was_broken]] (会饱和又不能清的计数器),
以及 `serial_run.ps1` header 记的"标记被 80 列折行切断"。

## How to apply

写任何"读回来 grep 一下"的判据时, 先问两句:
1. **这条通道会不会把我的命令也送回来?** 会 ⇒ 答案字面量不许进命令文本。
2. **我要匹配的 token 是别的 token 的前缀/子串吗?** 是 ⇒ 按词匹配。

⚠ 并且: 判据报 FAIL 时, **先怀疑判据**再怀疑被测对象。上面第 1、2 次都花了一轮
去修"被测对象", 而被测对象一直是好的。

相关: [[feedback_only_synthesis_catches_it]] [[feedback_differential_criterion_blind_to_common_mode]]
[[feedback_pair_miss_sentinel_was_broken]] [[project_dr1_serial_transfer_channel]]
