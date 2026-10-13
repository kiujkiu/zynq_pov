---
name: feedback-pov-in-subagent
description: "POV 项目的实际开发/仿真/综合工作交给独立后台 agent 跑, 主窗口保持空闲处理杂事"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8546d15b-e447-401c-ad29-dcf7e23adf7b
  modified: 2026-10-12T03:53:40.189Z
---

POV 项目（1.3.x 任务、仿真、综合等）的实际工作放到独立的后台 agent 里跑，主会话只负责派活、汇总和处理挂载/设置之类的杂事。

**Why:** 2026-10-12 用户明确要求"pov的项目你放在独立agent跑"。当时主会话被 D 盘 EIO 和窗口误关打断过，主窗口需要随时能响应。

**How to apply:** 派 agent 时要写清楚完整背景、只在本地提交不 push、不碰开发板（上屏/烧写由主会话问过用户再做）。token 充足时用户希望多开并发 agent。
工作地点 (10-12 起回到 D 盘, 见 [[project-dr1v90-in-wsl-d-is-mirror]]): `git clone /mnt/d/claude_workspace/pov3d/dr1v90 /mnt/d/claude_workspace/pov3d/_work/<任务>`, 交付时 push 回 D 盘 dr1v90 的 task/* 新分支 (主仓检出着的分支推不进, 推 task/* 让主会话 ff), 主会话再合并。多个 agent 都要综合时用 `flock ~/.gw5a_synth.lock` 串行化 Gowin。

**10-13 用户:** "不要在 wsl 内工作, 在 d 盘操作" —— agent 的克隆、仿真、综合、输出全放 D 盘 _work/, 不用 ~/pov_work (之前"重 IO 放 WSL ext4 躲 EIO"的建议作废)。
