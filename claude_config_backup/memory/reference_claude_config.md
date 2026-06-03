---
name: Claude Code 配置中心
description: 本地 Claude Code 所有自定义配置 (statusline/permissions/hooks/scripts) 的中心索引 + 备份 + 恢复方法。后续所有 Claude 相关设置改动都必须更新这里
type: reference
created_at: 2026-06-03 12:08 CST
updated_at: 2026-06-03 12:16 CST
originSessionId: d8fa45a6-872d-42f7-81a0-cb5be6c962bd
---
# Claude Code 配置中心

**这是本机 Claude Code 配置的唯一权威 memory**。

> ⚠️ **维护规则**: 以后任何新增 / 修改 Claude Code 配置 (settings.json、hooks、statusline、自定义 skill、permissions、env vars 等) **必须**:
> 1. 更新本文件对应章节
> 2. 同步备份 `claude_config_backup/`
> 3. git commit + push (`chore/claude-config-backup` 分支)

## 文件清单

| 路径 | 作用 | 备份位置 |
|---|---|---|
| `~/.claude/settings.json` | statusLine + permissions + hooks 配置 | `claude_config_backup/settings.json` |
| `~/.claude/statusline_with_bars.py` | 自制 statusline wrapper | `claude_config_backup/statusline_with_bars.py` |
| `~/.claude/projects/-mnt-d-claude-workspace-pov3d/memory/` | auto-memory 全部 .md | `claude_config_backup/memory/` |
| `~/.claude/hooks/codexflow_stop_notify.js` | codexflow Stop 通知 (机器外部依赖, 不备份) | - |

## 当前自定义清单

### 1. 自制 statusline 进度条 (新增 2026-06-03)

`~/.claude/statusline_with_bars.py` wrapper 在 `ccusage statusline` 原输出后追加 4 条:

| 段 | 含义 | 来源 |
|---|---|---|
| `5h用 ████░░ 44%` | 5h 滚动窗口配额已用 % | stdin JSON `rate_limits.five_hour.used_percentage` |
| `7d用 ██░░░░ 25%` | 7d 周配额已用 % | stdin JSON `rate_limits.seven_day.used_percentage` |
| `5h时 ██░░░░ 余3h53m ↻15:50` | 5h 窗口已过时间 % + 剩余 + 重置时刻 | `rate_limits.five_hour.resets_at` |
| `7d时 ████████ 余1d7h ↻06-04 19:00` | 同上 7d 版 | `rate_limits.seven_day.resets_at` |

**配色**: < 70% 绿 / 70-90% 黄 / ≥ 90% 红 / 时间条青 / 数据缺失灰(`\x1b[2m`)。

**对比用法**: 用量条 > 时间条 = 烧得比时间快, 会提前触顶。

**限制**:
- `Current week (Sonnet only)` 拿不到 — 服务端只渲染给 `/usage` UI
- 仅 **Pro/Max 订阅**有 `rate_limits` 字段, API-key 用户没有
- 新会话首条响应前 `rate_limits` 缺失, 显示灰色占位 `--`, 首条响应后填充

**调试**: wrapper 每次执行 dump stdin 到 `/tmp/claude_statusline_last.json`。

### 2. 权限模式 = auto

`settings.json` 的 `permissions.defaultMode = "auto"` + `skipDangerousModePermissionPrompt` + `skipAutoPermissionPrompt`。

### 3. Stop hook = codexflow 通知

每次 Claude Code 回复结束触发 `node ~/.claude/hooks/codexflow_stop_notify.js`。**此 hook 依赖 codexflow 工具链**, 新机器没装时要在恢复后从 settings.json 删掉 hooks 块, 不然 statusline 也可能波及。

## 备份位置

`/mnt/d/claude_workspace/pov3d/zynq_pov/claude_config_backup/` (zynq_pov repo 内, `chore/claude-config-backup` 分支)

```
claude_config_backup/
├── RESTORE.sh                   一键恢复脚本
├── settings.json                statusLine + permissions + hooks
├── statusline_with_bars.py      wrapper
└── memory/                      全部 auto-memory .md
```

GitHub: `https://github.com/kiujkiu/zynq_pov` 分支 `chore/claude-config-backup`。

## 换机/换号恢复流程

新机器:

```bash
# 1. 装依赖
npm i -g ccusage
sudo apt install python3   # 通常自带

# 2. 装 Claude Code 并登一次 (Anthropic 账号)
# (按官方文档安装, 登陆生成 ~/.claude/.credentials.json)

# 3. 克隆并恢复
git clone https://github.com/kiujkiu/zynq_pov.git ~/zynq_pov
cd ~/zynq_pov && git checkout chore/claude-config-backup
bash claude_config_backup/RESTORE.sh

# 4. 新机器没装 codexflow → 编辑 settings.json 删 hooks 块
nano ~/.claude/settings.json
```

新开 Claude Code 窗口即可看到 4 条进度条 (首条消息后填色)。

**换号同机**: 啥都不用动, Claude Code 自管换 credentials, 其他文件原样保留。

## 已知边界

- `RESTORE.sh` 里 `DEST_MEM` 路径 hardcoded 为 `-mnt-d-claude-workspace-pov3d`。新机器项目若不在 `D:\claude_workspace\pov3d\`, 改 RESTORE.sh 这行
- 备份不含 `~/.claude/.credentials.json` (账号凭据, 故意不带)
- 备份不含 `~/.claude/hooks/codexflow_stop_notify.js` (codexflow 装好它自己会写)
- 备份不含 `~/.claude/plugins/` (插件靠 Claude Code 自动同步)
