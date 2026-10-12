---
name: user-chinese-only
description: 用户要求全程中文交互 (回复+思考); 正式记忆库在仓库 zynq_pov/docs/claude_memory/
metadata:
  node_type: memory
  type: user
  originSessionId: 0a4eac0d-a239-44ca-8199-2ed019ee1d1c
  modified: 2026-10-10T09:54:15.420Z
---

🔴 **回复一律用中文**，包括正文、表格、小标题、代码注释；思考过程也用中文。技术名词 (LVDS25、bank、SERDES、PLL 等) 保留原文。

**Why:** 2026-09-18 用户两次打断提醒"中文交互"；2026-10-10 新会话里因这条只存在仓库记忆、未自动加载，又提醒了一次。
**How to apply:** 每个会话从第一句起就用中文。pov3d 的正式记忆在 `/mnt/d/claude_workspace/pov3d/zynq_pov/docs/claude_memory/` (含 `user_role.md`、`MEMORY.md` 索引)，被问到记忆时先读那里；本目录只放机器级/会话启动必需的事实。
