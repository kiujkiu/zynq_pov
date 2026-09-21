---
name: pov3d-memory-store-location
description: pov3d 项目的正式记忆库在仓库内 zynq_pov/docs/claude_memory/，不在默认记忆目录
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d345ff3-499c-4815-bcb3-44284d8c2c85
  modified: 2026-08-10T08:53:39.743Z
---

pov3d 工作区的记忆不在默认的 `~/.claude/projects/.../memory/`，而在仓库内：**`/mnt/d/claude_workspace/pov3d/zynq_pov/docs/claude_memory/`**（**~302 条** `.md` + 自带 `MEMORY.md` 索引，命名前缀 `user_` / `project_` / `feedback_` / `reference_`）。用户说"读一下记忆"指的是这里；**新写的记忆一律落成这里的 `.md`**，不要写到默认目录（机器级事实除外）。

**How to apply:** 被要求读或写 pov3d 记忆时，先看仓库内那份；只有环境/机器级、与项目仓库无关的事实（如 [[statusline-token-bars]]）才写默认目录。

同一套记忆在 `zynq_pov_icnd2047/` `zynq_pov_hdmi516/` `zynq_pov_hdmi_test/` `zynq_pov_slicemap/` 各有一份副本（worktree 复制产生，`mlkpai_fs03/.claude/worktrees/` 下还有一份 docs 副本），**只有 `zynq_pov/` 那份是最新的**，其余是不同时间点的快照。副本会各自漂移，勿写副本。

**Why:** 2026-07-20 第一次问"读一下记忆"时默认目录是空的，差点答成"没有记忆"。

~~截至 2026-07-20，仓库内记忆最后更新是 2026-06-02~~ / ~~09-07 记 244 条~~ —— **已不成立**：截至 **2026-09-20** 仓库内记忆约 **302 条**（MEMORY.md ~307 行），覆盖到 JTAG 台架、lvds_b2b、DR1M90 对齐差距、集创问询单等。直接读仓库内那份即可。
