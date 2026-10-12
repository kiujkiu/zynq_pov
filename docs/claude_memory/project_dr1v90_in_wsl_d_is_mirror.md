---
name: project-dr1v90-in-wsl-d-is-mirror
description: 2026-10-12 换 IP-guard 兼容内核后 D 盘恢复, 用户定: 工作回到 D 盘 dr1v90, 不再在 WSL ~/ 里做; 推送 = origin + yjhh
metadata:
  type: project
---

**现行 (2026-10-12 16:5x 起):** 用户: "d盘恢复了, 后续任务都在d盘操作, 就不在wsl内了, 推送还是推到git和远端2个地址"。
- 工作副本 = `/mnt/d/claude_workspace/pov3d/dr1v90` (切换时 WSL 那份 ~/pov3d/dr1v90 已 sync 过来, 两边都在 5b69726)。agent 的克隆也放 D 盘 (如 /mnt/d/claude_workspace/pov3d/_work/<任务>), origin 指 D 盘 dr1v90。
- `~/pov3d/dr1v90`、`~/pov_work` 是旧副本, 不再用, 不要再跑 `_wsl_sync/sync_to_d.sh` (它会 --delete 覆盖 D 盘)。旧 pov_work 的同步件在 D:\claude_workspace\pov3d\_wsl_sync\pov_work\ (含 budget35 报告)。
- "保存" = 提交 (别 add -A) → 推 origin + yjhh。push 用 WSL git 借 Windows GCM: `git -c credential.helper= -c "credential.helper=/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe" push <远端> <分支>`。zynq_pov 推 origin + yjhh; dr1v90 的 yjhh 远端 10-12 起改指 **pov-yjhh/dr1m90** (私有, 用户定: 整份 dr1v90 推过去, pov-yjhh 下不建 dr1v90)。建仓用 GCM 里 kiujkiu 的令牌调 API (/orgs/pov-yjhh/repos), 没装 gh。

**Why:** 换内核后 13 GB 并发压测零错误, 用户不想维护两份副本。若 EIO 复发, 回看 [[feedback-wsl-d-eio-remount]] 和 [[project-ipg-wsl-kernel-switch]]。
