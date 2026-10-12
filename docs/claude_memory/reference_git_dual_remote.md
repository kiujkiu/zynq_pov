---
name: 🔴 提交 = 推两个远端 (kiujkiu 原仓 + pov-yjhh 组织)
description: 用户 2026-07-30 要求; 两个本地仓库各配 origin(kiujkiu) + yjhh(pov-yjhh), 说"提交"就是两边都推
type: feedback
---
🔴 **用户 2026-07-30 明确要求: 以后说"提交"就是推到两个远端, 两边都要同步。**

## 远端配置

| 本地仓库 | remote | URL |
|---|---|---|
| `mlkpai_fs03` | `origin` | `https://github.com/kiujkiu/mlkpai_fs03.git` |
| | `yjhh` | `https://github.com/pov-yjhh/mlkpai_fs03.git` |
| `zynq_pov` | `origin` | `https://github.com/kiujkiu/zynq_pov.git` |
| | `yjhh` | `https://github.com/pov-yjhh/zynq_pov.git` |
| `dr1v90`（工程/RTL） | `origin` | `https://github.com/kiujkiu/dr1v90.git`（私有；**只有这一个远端**，2026-10-09 核） |

## 推送方式

WSL 里必须走 `cmd.exe` 用 Windows 凭据管理器 (见 [[reference_git_push_via_cmd]]):
```bash
cmd.exe /c "cd /d D:\claude_workspace\pov3d\<repo> && git push origin <branch> && git push yjhh <branch>"
```
⚠ 换机遗留: 仓库属主是 `kiujkiu`, 当前 Windows 用户可能不同, 需
`git config --global --add safe.directory D:/claude_workspace/pov3d/<repo>` (已配过)。

## 踩过的坑

`pov-yjhh/aibrain-app` **是另一个活跃项目**(Docker/app.py/ai/audio/camera/glb_models/sim,
最新提交还是 POV 1-bit 占空比相关), **不能往它的 main 推** —— 会覆盖别人的工作。
故改为在 `pov-yjhh` 组织下各建独立仓库。

⚠ 组织下的仓库需**用户手工创建**(本机无 `gh` CLI), 建时**不要勾 README/.gitignore/license**,
否则首次推送会冲突。

## 推之前要意识到的

仓库里有: `BOOT.BIN`(4.7MB)、切片 bin(4.4MB×数个)、硬件引脚推导表、板子 IP 与 SSH 访问方式。
`stream/pc/frames_*` 那 30+ 套动画帧共**数 GB**(多数未跟踪, 别误 add)。
推到新组织前应确认仓库可见性 (public/private)。

## 「保存记录」= 两个仓 (2026-10-09 用户再次强调)

- **记忆 + docs 计划/报告** → `zynq_pov`（当前分支 `feature/icnd2260-lvds-debug`）→ 推 origin + yjhh。
- **工程（RTL/脚本/README）** → `dr1v90`（当前分支 `feature/lvds-b2b`）→ 推 origin。
- dr1v90 工作区有 ~1.4 万个未跟踪文件（jtag_load mock_board 产物、boot 镜像、frames 等，单个到 36 MB），
  **不要 `git add -A`**；只加已跟踪改动 + 明确是源码/文档的新文件。

## 2026-10-12 起「保存」还包括同步 D 盘 (用户要求)

dr1v90 工作副本迁进了 WSL (`~/pov3d/dr1v90`), D 盘那份变成镜像。「保存」= 提交 → `bash /mnt/d/claude_workspace/pov3d/_wsl_sync/sync_to_d.sh` → 推远端。
dr1v90 直接在 ~/pov3d/dr1v90 用 WSL git 借 Windows GCM 推 (见 [[reference_git_push_via_cmd]])。10-12 用户要求 dr1v90 也推 yjhh: remote 已配好, **等用户在 pov-yjhh 建空仓 dr1v90** (不勾 README)。详见 [[project_dr1v90_in_wsl_d_is_mirror]]。
