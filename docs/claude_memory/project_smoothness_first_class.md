---
name: project-smoothness-first-class
description: 10-15 用户: 流畅显示是一等要求 (V0/V1/V2 通用); 物理上限做到最好, 软件卡顿必须可测可拦可修 → D20
metadata:
  type: project
---
用户 10-15: "我需要的肯定是流畅的显示 … 物理上限的转速和屏幕帧率做到最好就行, 但软件导致的卡顿都需要能处理"。
**Why:** 实转 583 rpm 时 PL 换帧只有 8 fps, 8 h 假转长跑没发现 —— 验收只看平均值/单一转速, 漏了观感。
**How to apply:** 所有上板验收都要过流畅度门槛 (换帧率、间隔 p99/max、长停顿、跳帧、撕裂、端到端延迟; 软件损失 = 理想 − 实际), 且在多个转速点测。
D20 阶段 1 (Sonnet): host/smooth_report.py + 门槛 + 基线, 分支 task/d20-smooth; 阶段 2 画面模拟器 (按视觉暂留合成视频给用户看); 阶段 3 修卡顿 (板上播放缓冲均匀出帧、后台活动停顿)。
相关: [[project-rpm-range-300-1200]]
