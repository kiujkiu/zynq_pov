---
name: project-dr1v90-in-wsl-d-is-mirror
description: 2026-10-12 起 dr1v90 工作副本在 ~/pov3d/dr1v90 (WSL ext4), D 盘那份是单向镜像; "保存" = 提交 + sync_to_d.sh + 推远端
metadata:
  type: project
---

2026-10-12 为躲 D 盘 EIO (见 [[feedback-wsl-d-eio-remount]]) 把 dr1v90 迁进 WSL:
- **工作副本** `~/pov3d/dr1v90` (含全部分支/未提交/未跟踪)。`~/pov3d/` 下其它名字都是指回 `/mnt/d/claude_workspace/pov3d/*` 的软链, 所以 `$REPO/../zynq_pov` 照常可用。zynq_pov、mlkpai_fs03 等其它仓**仍在 D 盘**。
- `~/pov_work/*` 克隆的 origin 已改成 `/home/wanqi/pov3d/dr1v90`, agent 交活推到这里 (不再推 D 盘)。
- **D 盘 `dr1v90` 是单向镜像**, 不要在里面改或提交 —— `sync_to_d.sh` 会 `--delete` 覆盖 (有护栏: D 有本地没有的提交时拒绝同步)。D 盘的 dr1v90_wt_base / wt_stress 仍挂在 D 那份上, 删不删待用户定。
- 脚本都在 D 盘 `/mnt/d/claude_workspace/pov3d/_wsl_sync/` (WSL 被换掉也在): `sync_to_d.sh [-n]` 同步 dr1v90 + ~/pov_work + 本目录自动记忆; `restore_from_d.sh` 新 WSL 一键恢复; `LAST_SYNC` 时间戳。增量同步约 2–3 分钟 (5.6 万文件比对)。

**Why:** 用户 2026-10-12: "WSL 内的环境大概率会频繁更换, 记得把结果同步 D 盘, 记忆和项目内容都同步, 后面说保存的时候就包含推到 D 和两个远端"。

**How to apply:** 用户说"保存" = ① 记忆/docs 提交进 zynq_pov、工程提交进 ~/pov3d/dr1v90 (别 add -A) ② 跑 `sync_to_d.sh` ③ 推远端: zynq_pov 推 origin + yjhh; dr1v90 推 origin —— 从 **D 盘镜像** 用 `cmd.exe /c "cd /d D:\claude_workspace\pov3d\dr1v90 && git push origin <分支>"` (cmd.exe 进不了 /home 的 UNC 路径)。Claude 仍从 /mnt/d/claude_workspace/pov3d 启动, 自动记忆按启动目录取。
