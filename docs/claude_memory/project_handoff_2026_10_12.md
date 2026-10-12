---
name: project-handoff-2026-10-12
description: 2026-10-12 D盘WSL挂载EIO中断时的交接状态; 恢复后先做什么
metadata:
  node_type: memory
  type: project
  originSessionId: 6b82b1aa-c5c2-422e-85e6-0d5d60392dcf
  modified: 2026-10-12T02:29:24.453Z
---

2026-10-12 D 盘在 WSL 里 EIO(连 bash 都起不来), 用户重启电脑。中断前所有改动已提交并推远端(zynq_pov 双远端 / dr1v90 origin), 无半成品。
正式记忆库在 zynq_pov/docs/claude_memory/ (D 盘), 恢复后把本条同步过去。

板子状态: DR1M90-02 走 WiFi(按名字连: dr1v90/host/dr1ssh.sh dr1m90-02), 串口已拔, 独立供电。
屏是故意黑着的: guard.sh 守卫脚本保持屏关(无人值守规则), 寄存器停在 3-bit 设置且 pov_en=0。用户回来问"屏不亮"时已解释为预期行为。
ACG525(COM22) 在跑 lane-47 浸泡(bit 0x880F, 1.3h 时 0 错), 需读计数下结论。

**Why:** 环境中断, 需要无缝接续。
**How to apply:** 恢复后依次:
1. python3 tools/quota.py 看配额; 后台 agent 重做 1.3.14(目标板 UL_IDLE_OK 默认 1 + 仿真 + 回归签名 1ED7F783/ACEED86D + build_gw5a.sh 25S 150) 和 1.3.6(GW5A_PROFILE_STRESS 宏)。
2. 用户在场项: 先 kill guard.sh, 低亮度点亮; D5 双面目视, D8 3-bit 画面(期望 frame_period 31590, auto_en=1), D9 电机看体像。
3. 读 ACG525 浸泡计数, 更新任务表 xlsx。
相关: [[project_dr1m90_d1_display_bit]] [[project_validation_board_task_tree]]
