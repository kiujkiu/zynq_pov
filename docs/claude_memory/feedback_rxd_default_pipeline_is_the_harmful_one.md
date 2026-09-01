---
name: feedback_rxd_default_pipeline_is_the_harmful_one
description: 🔴 pov_rxd 不传 --no-pipeline 会跑在实测有害的那一档(flip 减半+drop 1600); ✅ 2026-08-31 已修 — 根因是 povboot.env **从来没生效过**(两个独立 shell bug), 不只是"RXD_ARGS 默认空"
metadata:
  type: feedback
---

# `--no-pipeline` 的默认档是有害的那个 (2026-08-28 盘出, 2026-08-31 修完)

## 事情

Zynq 现役的 ExecStart(`project_pov2_shipping_config.md:19-21`):
```
--idle-anim helix3b.pvs --idle-fps 11 --pl-lz4 --pl-engines 3 --no-pipeline
```
而 DR1 的 `board/povboot.sh:882` 拉起的是 `--diag on --regs $REGS_PHYS $RXD_ARGS`,
**`RXD_ARGS` 默认是空的**(`:117`) ⇒ **五个参数一个都没传**。

## 🔴 默认值三处打架, 而代码站在有害的那一边

| 说法 | 出处 |
|---|---|
| 「串行优于流水线(`--no-pipeline` **默认**)」 | `pov_rxd.c:110` 文件头移植清单 |
| 「**默认是流水线**」 | `pov_rxd.c:3455` usage 原文 |
| **代码实际**: `static int g_pl_serial;` = 0, 只有 `--no-pipeline` 才置 1 ⇒ **默认流水线** | `:750` 声明 + `:3487` 解析 |

Zynq 侧 A/B 实测(commit `970edce`):

| | rx | **flip** | drop |
|---|---|---|---|
| 流水线 | 15-17/s | **4-8/s** | **1600** |
| 串行(`--no-pipeline`) | 10-12/s | **10-12/s** | **9** |

⚠ 而 usage 那段说流水线把 6.5-7.7 → 12.5-13 fps, **与 A/B 实测方向相反**。
两者可以并存(流水线提高 `rx` 但破坏 flip 窗同步, 见
[[feedback_pipeline_breaks_flip_window_sync]]), **但验收只认 `flip`**。

## Why 这条特别危险

不传 `--no-pipeline` 的现象是 **fps 只有一半 + 疯狂丢帧** ——
**正好长得像"DR1 不行"**。这是典型的会导致**误归因**的缺陷:
把一个配置问题读成平台问题。

而且它和另一个 bug **串联**: 唯一设计好的入口是 `povboot.env`
(`povboot.sh:69-70` 明写 `RXD_ARGS="--pl-lz4 --no-pipeline"` 该放那儿), 而
`S95pov` 里 `. povboot.env` 之後用 `sh $SCRIPT all` 起子进程 ——
**POSIX sh 里 `.` 出来的裸赋值是 shell 变量, 传不进子进程**(dash 实测过)。
⇒ 修好自启也传不进解码策略。最小修复: `set -a; . $POV/povboot.env; set +a`。

## ✅ 2026-08-31 收口: 根因比原以为的更坏 —— `povboot.env` **从来没生效过**

原文只说"`RXD_ARGS` 默认是空的"。实跑后发现: 卡上那份 `povboot.env` 里
**每一个**机械参数(`N_SLICES`/`BPP`/`FOLD_A`/`RXD_ARGS`)都从来没到过 `povboot.sh`,
是**两个互相独立**的 shell bug 叠加(都用 dash 实跑复现):

| # | bug | 出处 |
|---|---|---|
| 1 | `. povboot.env` 之后 `sh $SCRIPT all` 是**子进程**, 只继承 export 过的变量 ⇒ 裸赋值全丢 | `tools/mkrootfs.sh` `pov_up()` |
| 2 | `RXD_ARGS=--decode serial` **没加引号** ⇒ POSIX sh 解析成「带环境变量前缀的命令 `serial`」, 报 `serial: not found`, 变量**在本 shell 里都没设上** | `tools/make_card_image_dr1.sh:203` |

🔴 **为什么一直看不见**: `POV_HOSTNAME` 是在**本进程**里用的, 所以它一直好使 ——
正是它掩盖了 bug 1。而 povboot.sh 用自己的内建默认值(`N_SLICES=360 BPP=1 FOLD_A=0
RXD_ARGS=空`)跑完, **打出一个干干净净的 PASS**。
⇒ 这解释了 08-28 那条"卡上 povboot.sh 是旧版 ⇒ `BPP=3` 一直静默不生效"是**两层**问题。

**修法**(已落地, 未上板): bug1 → `set -a; . $POV/povboot.env; set +a`;
bug2 → `RXD_ARGS="--decode serial"`。

⚠ **`pov_rxd.c:110` 那条"`--no-pipeline` 默认"的错注释已更正**(另两处
`PORT_STATUS.md:132` / `BRINGUP_TOMORROW.md:551` 同样写错, 一并改)。
行号也漂了: usage 现 `:3461`, 解析现 `:3493`。
🎯 **DR1 没有 systemd** ⇒ 上游靠 systemd drop-in 写进 ExecStart 的那条路走不通,
卡上 `povboot.env` 的 `RXD_ARGS` 是**唯一落点**。⇒ 一旦开 `--pl-lz4`, 同一行必须带 `--no-pipeline`。

## How to apply

**DR1 上跑推流前, 先确认 `cat /proc/<pid>/cmdline` 里有 `--no-pipeline`。**
判据不是"env 文件在不在", 是**进程真的收到了**。
⚠ 换一组值能跟着变, 才算这条通路是活的。

相关: [[project_pov2_shipping_config]] [[feedback_pipeline_breaks_flip_window_sync]]
