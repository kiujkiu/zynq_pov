---
name: 交互和 memory 全部加时间戳
description: 用户要求 claude 每次回复加时间戳, memory 条目也加 timestamp 字段, 方便后续追溯何时记的
type: feedback
created_at: 2026-06-03 10:59 CST
updated_at: 2026-06-17 14:32 CST
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---
**规则 (2026-06-16 用户重申, 收紧为强制)**: claude 跟用户的**每一条回复**开头都要带时间戳, 无例外。每个 memory 条目也带 created_at/updated_at。

**Why**: 用户 2026-06-03 提出 — 项目进度推进快, 一天可能跑十几个 agent + 多轮迭代, 没时间戳就分不清"现在的状态"是何时的快照, memory 也容易过时。

**How to apply**:

1. **每次回复开头加时间戳**: 用 ``[YYYY-MM-DD HH:MM CST]`` 格式 (CST = Asia/Shanghai), 通过 `date '+%Y-%m-%d %H:%M:%S %Z'` 拿当前时间。
2. **memory 条目 frontmatter 加 `created_at` 和 `updated_at`**:
   ```yaml
   ---
   name: ...
   description: ...
   type: feedback / project / reference
   created_at: 2026-06-03 10:59 CST
   updated_at: 2026-06-03 10:59 CST
   ---
   ```
3. **大段进度快照** (project snapshot 类) 文件名直接带日期, 例如 `project_pov3d_pcb_v1_snapshot_2026-06-02.md` — 这样累积多个 snapshot 时序清晰。
4. **agent 报告也加时间戳**: 在 agent prompt 里要求 "完成后报告里加 ISO 时间", 或我自己接收 task notification 后记一下当时时间。
5. **MEMORY.md 索引行可选加日期** (`(2026-06-03)` 后缀), 仅在该条目 frequently 更新时用。

**例外**: 无 (2026-06-16 起)。连单字 "ok" 回复也带时间戳。唯一不带的是 memory 纯索引行不强制 updated_at。

**优先级**: 强制, 每条回复都带, 不再有"日常对话可省略"。

**🔴 已知失败模式 (2026-06-17 用户第二次抓到)**: **长技术会话(连续 build / 调试 / 逻辑分析仪解码)最容易中途把时间戳丢光** —— 注意力全在技术任务上就忘了开头那行。补救: 把"时间戳"当成每条回复的**第一个动作**, 跟工具调用无关; 时间会漂, 别复用几小时前的旧值, 拿不准就重跑 `date '+%Y-%m-%d %H:%M CST'`。会话越长越要盯。
