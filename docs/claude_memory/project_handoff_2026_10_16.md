---
name: project-handoff-2026-10-16
description: 10-16 凌晨交接: V0 97.5% 必须项全完成; 10-15/16 合主线 D19/D20/D20b/D20c/D20d/D8/D21/D22; 卡上=主线 1d23e50; 待办 D10 合并、相位锁定、D23 V1 真内容通路
metadata:
  type: project
---
**主线 dr1v90 feature/lvds-b2b = a3055dd** (之后若有新合并以 git log 为准)。达成率 V0 97.5% / V1 77.6% / V2 67.9%。
已合主线 (10-15~16): D19 半圈换帧 (300-1200 rpm) / D20 流畅度 smooth_report+--flip-log / D20b 画面模拟器 pov_view / D20c --fps auto / D20d ACK 回传转速 + 默认 板 max-fps 20 margin 1.0 推流 auto / D8 V1 联合仿真 (修 12-bit 格式 PK12 + NXG) / D21 每圈片数换档 (+ voxslice sub01 修复) / D22 不插串口永远连得上 (povreach+看门狗 32 s+兜底热点 POV-<板名> pw pov3d-rescue+povnetd 1.2+povmdns IGMP) / QoS 开机默认 / voxlive 自动重连 / D14 内容+手机。
**卡上部署 = 主线** (10-16 02:xx 用 d19_rpm/verify.sh --board 装): voxslice ecdc246f, PL 位流 0x20471019 (D19; D21 位流 0x20471021 未上卡默认), QoS 0x0F, povreach。串口可拔。
**待办**:
1. ✅ D10 已合主线 a3055dd (回板主用 ul800_p1_b12 023e6582, 步骤 d10_v1bit/BOARD_DAY.md)。V1 线速 800M。
2. 相位锁定: D 组上板 auto 锁 19.4 帧但间隔 p95 103 ms (>5% 滑格), 推流应跟板端 ACK 节奏 (task/d20d-ackrps 的 agent 有上下文)。
3. D23 V1 真内容板端通路 (voxslice 只支持 2047 后端) —— D20d 已合, 可开。
4. V1 C1 台架等用户接线; PC 的 USB WiFi MT7921 待用户装驱动 (热点自动测)。
5. D12 降延迟复测 (加分)。
**教训**: 板上多步任务写进同一脚本串行; 排队只用 kill -0 PID; 新克隆在 WSL 本地盘时 git 模式 644 的二进制不可执行; verify 里 "老基准" 用 merge-base 时新克隆要 BASE= 指定。
用户偏好: 自主推进只同步结论, 结果记看板不单独汇报, 不阻塞; 流畅度与无串口连网是一等要求; 周额度到 70% 先保存再停 (用户报数)。
