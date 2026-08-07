---
name: 解码带宽在屏刷新时腰斩 (空载 215 → 带载 111-131 MB/s)
description: 同一二进制同一帧实测 A9; 30fps 的 132.7 MB/s 门槛要拿带载数去比, 不是空载数
type: feedback
---

2026-08-05 为 DR1 换平台评估做跨架构 benchmark 时，顺手在现役 Zynq-7020 上
用**同一个二进制、同一帧 (`frames_robot/frame_0000.bin`, 4,423,680 B)** 实测出来的。

| 条件 | lz4_dec | zlib_dec | memcpy | crc32 |
|---|---|---|---|---|
| **空载**(停 `povrxd.service`) | **215.2 MB/s** (19.6 ms) | 80.4 | 232.8 | 75.4 |
| **带载**(屏在刷新 + 空闲动画 11fps, load≈2.4) | **111.8–130.9 MB/s** (32–38 ms) | 40–44 | 106–130 | 42 |

**空载数与 [[feedback_codec_lz4_beats_zlib_4x]] 记的 204.6 MB/s 吻合** ⇒ 那条没错，
但它是**空载**测的，而真实推流时解压必然与刷新同时发生。

## 为什么这条重要

30 fps 需要 132.7 MB/s 单核解码。拿空载 215 去比 ⇒ 结论"过线，双核能到 48fps"；
拿带载 111-131 去比 ⇒ **单核不过线**。后者才是真实工况，
这正是 [[feedback_lz4_onboard_reality_check]] 里"外推 48fps 只兑现 10-11.4fps"的一个直接来源
(另一个是 cpy20+wait31 和转速天花板)。

**How to apply**: 以后任何 CPU 侧性能外推，先问「这个数是空载测的还是带载测的」。
PL 显示引擎自走扫描会持续吃 DDR 带宽，A9 侧看到的可用带宽就是一半。
换平台对账时**两边必须同工况**——DR1 刚起来时没跑屏，直接拿它的空载数
和 Zynq 的带载数比会得出错误的"DR1 更快"。

## 附带的方法论坑

- 第一次跑脚本里 `sudo systemctl stop` 报 `sudo: no tty present and no askpass program specified`，
  **服务其实没停**，但脚本继续跑完输出了一组"空载"数字 —— 差点当成空载基线。
  plink/非交互下 sudo 要 `echo root | sudo -S -p ''`。
  ⇒ 停服务后**必须验证真的停了**(`pgrep -a pov_rxd`)，别信 stop 命令的退出码。
- 停服务测性能一定要 `trap restore EXIT INT TERM`，否则脚本中途挂掉板子就一直没有显示服务。
- 🔴 **`systemctl start` 成功 ≠ 服务活着**。第二轮恢复后 `pgrep` 有进程、看着像好了，
  实际是 `Restart=always` 的 **crash-loop**：`bind: Address already in use`，
  每 3 s 重启一次并往 `pov_rxd.log` 狂写。`pov_rxd` **没设 SO_REUSEADDR**，
  端口被占或 TIME_WAIT 未过就必然起不来。
  **验收必须三样都看**: `systemctl is-active` = active（不是 `activating`）
  ＋ `pgrep -a` 的**命令行带 `--idle-anim` 参数**（systemd 实例才带，裸起的没有）
  ＋ `ss -tnlp | grep 9500` 在 LISTEN。
- ⚠ 期间出现过一个**来源不明**的 `/home/uisrc/pov_rxd`（无参数、PPID=1、正服务着一个客户端连接），
  占着 9500 让 systemd 实例起不来。`pov_boot.sh` 明确写了自己不起 pov_rxd，
  `pov.service`(oneshot) 也没起 —— **至今没查清是谁拉的**，用户确认不是他手动起的。
  以后再遇到先用 `ps -o pid,ppid,lstart,args` 看启动时间和参数区分实例来源，别默认是 systemd 那个。
  恢复脚本留在 `dr1v90/bench/_restore_povrxd.sh`（停 service → 杀野进程 → 等 9500 释放 → 重起 → 验收）。
