---
name: 交互和 memory 全部加时间戳
description: 用户要求 claude 每次回复加时间戳, memory 条目也加 timestamp 字段, 方便后续追溯何时记的
type: feedback
created_at: 2026-06-03 10:59 CST
updated_at: 2026-06-03 10:59 CST
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---
**规则**: claude 跟用户的每次交互、每个 memory 条目都要带时间戳。

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

**例外**:
- memory 不更新内容只索引时, 不强制加 updated_at
- 短回复 (e.g., 单字 "ok", "继续") 不强制带时间戳

**优先级**: 新建/更新 memory 时强制, 日常对话可省略 (但项目里程碑、状态汇报必带)。
