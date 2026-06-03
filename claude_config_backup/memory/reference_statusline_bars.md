---
name: Claude Code statusline 配额进度条
description: 自制 statusline wrapper, 在 ccusage 输出后追加 5h/7d 配额条 + 时间条, 配置文件位置和恢复方法
type: reference
created_at: 2026-06-03 12:08 CST
updated_at: 2026-06-03 12:08 CST
originSessionId: d8fa45a6-872d-42f7-81a0-cb5be6c962bd
---
# Claude Code statusline 配额进度条

## 设计

在 `ccusage statusline` 原输出后追加 4 条进度条:

| 段 | 含义 | 来源 |
|---|---|---|
| `5h用 ████░░ 44%` | 5h 滚动窗口配额已用 % | stdin JSON `rate_limits.five_hour.used_percentage` |
| `7d用 ██░░░░ 25%` | 7d 周配额已用 % | stdin JSON `rate_limits.seven_day.used_percentage` |
| `5h时 ██░░░░ 余3h53m ↻15:50` | 5h 窗口已过时间 % + 剩余 + 重置时刻 | `rate_limits.five_hour.resets_at` |
| `7d时 ████████ 余1d7h ↻06-04 19:00` | 同上 7d 版 | `rate_limits.seven_day.resets_at` |

配色:< 70% 绿 / 70-90% 黄 / ≥ 90% 红 / 时间条青 / 数据缺失灰(`\x1b[2m`)。

**对比用法**:用量条 > 时间条 = 烧得比时间快,会提前触顶。

## 文件位置

- `~/.claude/settings.json` — `statusLine.command` 指向 wrapper
- `~/.claude/statusline_with_bars.py` — wrapper 本体, 转发 stdin 给 ccusage, 再解析同一份 JSON 追加 bars

依赖:`ccusage` (npm 全局, 路径 `/home/kiujkiu/.npm-global/bin/ccusage`) + `python3`。

## 限制

- `Current week (Sonnet only)` 那条**拿不到** — Claude Code 只把 `five_hour` 和 `seven_day` 推给 statusline JSON, per-model 拆分服务端只渲染给 `/usage` UI
- 仅 **Pro/Max 订阅**有 `rate_limits` 字段, API-key 用户没有
- 新会话首条消息前 `rate_limits` 缺失, 显示灰色占位 `5h用 ░░░░░░░░░░ --`, 首条响应后自动填充

## 备份/恢复

完整备份在 `/mnt/d/claude_workspace/pov3d/zynq_pov/claude_config_backup/`:
- `settings.json`
- `statusline_with_bars.py`
- `memory/` (整个 auto-memory 目录)
- `RESTORE.sh` (一键恢复脚本)

**换机/换号恢复**:`bash /mnt/d/claude_workspace/pov3d/zynq_pov/claude_config_backup/RESTORE.sh`

设置 + memory 跨 Anthropic 账号通用(不含凭据), 跨机器需带上 backup 目录并装好 `ccusage` + `python3`。

## stdin 调试

wrapper 每次执行都把 stdin dump 到 `/tmp/claude_statusline_last.json`, 失败时 cat 看是否有 `rate_limits` 字段。
