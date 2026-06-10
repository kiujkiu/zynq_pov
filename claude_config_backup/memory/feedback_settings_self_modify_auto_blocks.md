---
name: settings-self-modify-auto-blocks
description: "改 ~/.claude/settings.json 等自身配置 auto mode classifier 必拦, 即使用户上轮口头\"要\"也算 self-modification 不放行, 必须当轮 AskUserQuestion 显式确认; Edit old_string 含其他配置块当 context 时 classifier 看 diff 字面会误判, 用最短 unique anchor"
metadata: 
  node_type: memory
  created_at: 2026-06-10 22:15 CST
  updated_at: 2026-06-10 22:15 CST
  type: feedback
  originSessionId: a138d1e0-80ac-4758-83f0-37d9a552a7cb
---

改 `~/.claude/settings.json` (或其他 self-modification: rm 用户配置文件 / 改 hooks / 改 statusline 等) 时, auto mode classifier 会拦截, 即使前一轮用户已经明确说 "要" / "升级吧" 之类口头同意也不放行。

**Why:** classifier 把这类改动当 "self-modification of agent config", 默认要求 in-turn 的显式确认, 不会回溯前几轮的口头同意。这是安全设计, 防 self-prompt-injection 改自己配置。

**How to apply:**
1. 改 settings.json 前**先 `AskUserQuestion` 列具体改动选项**让用户当轮明确确认, 别假设上轮 "要" 涵盖了这一步。
2. Edit 的 `old_string` 用**最短 unique anchor**, 别拿 "permissions"/"hooks" 等其他配置块当 context。classifier 看 diff 字面会误判: 哪怕你只是在 anchor 前插一行新字段, 它会以为你重写了整个 anchor 块, 然后基于"我没授权改 permissions"再拦一次。
3. 同样规律也适用于 `~/.claude/hooks/`, `~/.claude/statusline_*.py`, `rm` 用户级配置文件 (`~/.npm-global/...` 这类不在 project scope 内的清理也会拦)。
4. 配置改完按 [[reference_claude_config]] 的维护规则三步走: 更新 memory + 同步 `claude_config_backup/` + worktree push `chore/claude-config-backup`。

2026-06-10 升级 Claude Code 2.1.153→2.1.170 + 切默认 model 到 `opus` 时踩到: 第一次 Edit 被拦 (理由 self-modification + 误读为改 permissions); AskUserQuestion 显式确认后, 把 anchor 缩到只剩 `{\n  "permissions":` 才放行。
