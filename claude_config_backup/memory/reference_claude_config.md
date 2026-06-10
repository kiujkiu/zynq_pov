---
name: Claude Code 配置中心
description: 本地 Claude Code 所有自定义配置 (statusline/permissions/hooks/scripts) 的中心索引 + 备份 + 恢复方法。后续所有 Claude 相关设置改动都必须更新这里
type: reference
created_at: 2026-06-03 12:08 CST
updated_at: 2026-06-10 22:10 CST
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

### 4. Binary 安装方式 = native (~/.local/bin) (2026-06-10 切换)

| | 旧 | 新 |
|---|---|---|
| 路径 | `/usr/bin/claude` → `/usr/lib/node_modules/@anthropic-ai/claude-code/` | `~/.local/bin/claude` |
| 装法 | `sudo npm install -g @anthropic-ai/claude-code` | `claude install stable` (native build) |
| 权限 | root, 升级要 sudo | 用户拥有, 不需要 sudo |
| 版本 (切换时) | 2.1.118 | 2.1.153 |

**关键**:
- PATH 里 `~/.local/bin` 在 `/usr/bin` 前 (`.profile` 自动加), `which claude` 自动指向新版
- 旧 `/usr/bin/claude` 没删, 留作 fallback
- 以后**升级直接 `claude update`** (内部走 `claude install`, 无 sudo 问题), 不要再用 `sudo npm install -g`
- ⚠️ **`claude update` 默认查 stable channel**, settings.json 里的 `autoUpdatesChannel=latest` 不影响这条命令的查版本动作. 想要最新版必须 `claude install latest` (2026-06-10 实测: `claude update` 报 stable 停 2.1.153, `claude install latest` 拿到 2.1.170)
- `claude update` 失败时手动 `claude install stable` (或 `latest` / 具体版本号)

**契机**: codexflow 显示 Opus 4.8 (1M), 而旧 2.1.118 `/model` 菜单里看不到 4.8, 推测新模型 access 需要 CLI 较新版本

### 5. 默认模型 = `opus` 别名 = Opus 4.8 (新增 2026-06-10)

`settings.json` 加 `"model": "opus"`. alias 不锁版本, Anthropic 推 4.9/5.0 时自动跟最新 opus.

| 写法 | 效果 |
|---|---|
| `"model": "opus"` | 自动跟最新 opus (当前 Opus 4.8) ✅ 当前用这个 |
| `"model": "sonnet"` | 自动跟最新 sonnet |
| `"model": "fable"` | Claude Fable 5 (2026-06-22 才对 Pro/Max 免费开放) |
| `"model": "claude-opus-4-8"` | 锁版本, 不自动升 |

**命令行临时切**: `claude --model sonnet` 单 session 覆盖, settings.json 不变.

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
