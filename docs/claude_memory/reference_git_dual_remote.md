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
