---
name: project_lane47_soak_verdict_1012
description: 2026-10-12 任务 1.3.9 结论 — ACG525 lane-47 单字错是量具 vid_check 采样使能时序问题, 桥无问题; vcpipe 位流 47.9 h / 1.56e9 帧 / 0 错, BER<8.7e-16
metadata:
  type: project
---

# 1.3.9 lane 47 单字错: 量具问题, 已结 (2026-10-12 11:34 读数)

- 位流 `GW5A/bench_bits/gw5a_bench_verB_vcpipe.fs` (10-10 11:37, 内含 880F), CB-V2 独立供电, 电脑重启不影响, 浸泡**仍在跑未停**。
- 只读监听 COM22 (`GW5A/loop_bits/cap_com22.ps1`, DTR/RTS 关, 每秒自动打 L/V/C/W, 无副作用):
  V 好帧 0x5D022EA5 = 1,560,424,101 (+9041/s) ⇒ **47.9 h**; 坏帧 0 / 坏字位置 0 / aborted 0 / bad_lanes[71:0] 粘滞位全 0;
  L 对齐 F 重训练 0; C 签名 **1ED7F783 / ACEED86D** (= 目标板回归签名)。fid_skip 是 16 位计数会回绕 (每秒刷新跳 1 帧, 正常)。
- 比特量 1920 字位置 × 72 lane × 16 bit/帧 ⇒ 全 lane 3.45e15 bit 0 错, 95% BER < **8.7e-16**; 单 lane 47 < 6.3e-14。
- 旧量具 (组合 tick 直驱 wq CE, slack +0.001) 10.7 h 7 次全在 lane 47 (≈0.65/h, 紧挨最差路径 wq_786/787); 照旧速率 47.9 h 0 错概率 e^-31。
  修法见 `dr1v90/gw5a_bench/rtl/vid_check.v` 94-96 行 (tick 先寄存一拍)。
- 保留: 改量具整片重布局, 严格说证明的是"这一版布局下桥 0 错"。
- 🔴 "1.3 h 0 错"读法错误教训: 交接里的 1.3 h 是 10-10 中午旧数, 板子其实一直在累计 —— 读 V 行好帧 ÷ 9041 反推时长即可, 不用日志。

相关: [[project_validation_board_task_tree]] [[project_gw5a_bench_1009]] [[feedback_acg525_led_active_high]]
