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
工作地点放 WSL 本地盘: `git clone ~/pov3d/dr1v90 ~/pov_work/<任务>`, 在克隆里跑仿真/综合, 交付时 push 回 ~/pov3d/dr1v90 的 task/* 新分支, 主会话再合并 (10-12 起主仓已迁进 WSL, D 盘是镜像, 见 [[project-dr1v90-in-wsl-d-is-mirror]])。原因: 10-12 D 盘 EIO 四次, 其中一次 agent 根本没在跑重 I/O, 所以"串行跑"不解决问题（见 [[feedback-wsl-d-eio-remount]]）。多个 agent 都要综合时用 `flock ~/.gw5a_synth.lock` 串行化 Gowin。
