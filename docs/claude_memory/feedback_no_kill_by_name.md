---
name: feedback-no-kill-by-name
description: 多 agent 共用主机时, 脚本只能按自己记录的 PID/进程组杀进程, 禁止 pkill/killall/pidof 按名字杀 (10-13 D16 收尾误伤疑致 D2 验收进程树被杀)
metadata:
  type: feedback
---

10-13 夜: D2 的新克隆 verify 两次在纯切片仿真时整棵进程树被外部杀掉; D16 自查发现 board_d16.sh 收尾用 pidof/pkill -f 按名字杀 voxrxd_aarch64/ddrload, 离线干跑在 PC 上执行, 可能误伤别的 agent 的 qemu 进程, 还按名字 SIGSTOP 主机上的 povnetd/povstat。已改 (2defce6)。另: ssh 命令行含进程名时 `ps|grep` 会杀到自己 shell (exit 144), 主会话 10-13 也踩过两次。

**Why:** 同一主机上多个 agent 并行跑仿真/测试, 按名字杀会互相误伤, 表现为"无报错、进程消失、验收偶发失败", 极难排查。
**How to apply:** 派活时在任务说明里写明"只杀自己启动并记下 PID 的进程, 杀前核对 /proc/PID/cmdline, 禁 pkill/killall/pidof 杀"; 主会话自己杀进程也按 PID, 或用 `pgrep -f '^[^ ]*python[^ ]* .*xxx'` 这种不会匹配到 bash -c 自身的锚定模式。相关 [[feedback-agent-label-task-id]]

- 10-15 同类坑 (排队等待): 后台排队脚本用 `pgrep -f "<文字>"` 判断前一个任务是否还在跑, 会匹配到排队脚本自己的命令行 (含同一段文字) → 永远等, 板上排队链全卡 2 h。**排队一律 `kill -0 <记录的 PID>`**, 不用 pgrep -f 文字。
