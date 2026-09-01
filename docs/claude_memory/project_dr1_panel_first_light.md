---
name: project_dr1_panel_first_light
description: 🎯 2026-08-28 DR1 第一次点亮面板 + WiFi 通 + 自写 povsh 摆脱串口; 板上没有 telnetd/nc/sshd 所以远程 shell 必须自己造
metadata:
  type: project
---

# DR1 第一次点亮 + 摆脱串口 (2026-08-28)

板: **`pov_al_01`**(换的新板/第二套外设, 与 Zynq 同款屏+接口板+转接板)。

## 里程碑

| | |
|---|---|
| 冷启动 `NO_WIFI=1 povboot.sh all` | **`POVBOOT: PASS` 一次过** ⇒ `povboot.sh` 的判据**首次在真板上全部跑通**(此前 `BRINGUP_TOMORROW.md` 一直写着"没有一条判据在板上验过") |
| **屏第一次亮** | `povctl fb solid` 整屏全白 ⇒ 排线/九条 SDI/地址映射**全通**。双屏两面都画了, `dual_en=1 / mirror_a=0 / mirror_b=0` |
| WiFi | `wlan0` 2s / **MT7921 MCU 固件已加载**(强判据) / `wpa_state=COMPLETED` 6s / IP `10.10.20.239/23` |
| 走 WiFi 的控制通路 | 自写 `povsh`, 实测命令执行 + 退出码正确 + 用它自己推自己的新版上板 |

审计预警的四条**一条都没发生**: U-Boot `boot_type` 正常引导 / MANIFEST 已提前修好 /
`dtb.bin` 正确(CmaTotal 98304) / `stage_enable` 在 `stage_pl` 之前也没出事。

## 🔴 板上没有任何现成的远程 shell

busybox **276 个 applet 但没有 `telnetd`**(只有 telnet 客户端), 也没有
`nc`/`httpd`/`ftpd`/`dropbear`; initrd 里没有 sshd。
而转子最终要旋转 ⇒ **不能挂串口线也不能用网线** ⇒ 走 WiFi 的控制通路必须自己造。

⇒ `board/povsh/povsh.c`(约 130 行) + `host/povsh_run.sh`。协议照抄
`serial_run.ps1` 的标记定界(那套在串口上被反复验证过), 换条传输而已。
🔴 结束标记 `__POVSH_END<rc>` 里的 rc **由板子填**, 命令文本里不会出现它
⇒ 主机侧按整 token 抠, 不会命中命令自身的回显。
🔴 **未加密的局域网工具**, token 只挡随手扫描, 不是安全边界。

⚠ 自己写的时候就踩了一个同类坑: 第一版 `signal(SIGCHLD, SIG_IGN)` ⇒ 内核自动收割
⇒ `pclose()` 的 waitpid 拿不到状态 ⇒ **结束标记永远是 `-1`** ⇒ 那个协议里唯一的
判据变成**永远说不出真话**的。删掉後实测 `rc=0`/`rc=42` 正确。

## 串口的可用配方(默认那条路是坏的)

`serial_send.ps1` 默认(关回显)会 `ABORT: preflight timed out`;
**`-KeepEcho -ChunkSize 512`** 稳定可用(38KB 二进制 71 块 9 秒 md5 精确)。
把行长从 2102 B 压到 567 B, 回显开着 N_TTY 也跟得上。

## ⚠ 一个未解的现象

`povctl fb rows`(源码 `row < ROWS/2`, 应该是**一条分界线半亮半黑**)在 DR1 屏上
显示成**三条竖带**; 而 `fb solid` 全白正常 ⇒ 不是硬件故障, 是**行号到物理位置的
映射**和假设不同。
🎯 **判法: 同一条命令在 Zynq 上跑一遍** —— 第二套外设就是拿来做这种 A/B 的。

相关: [[feedback_static_panel_test_overheats]] [[project_dr1_serial_transfer_channel]]
[[feedback_criterion_must_not_contain_its_answer]] [[project_dr1_hp0_fetch_measured_ok]]
