---
name: feedback-save-weekly-quota
description: 10-13 用户定省额度规则: Max 20x 的 5 小时够、7 天不够; 只有画电路板派 Codex, 其余 Claude 自己做; 机械子任务用 Sonnet, 分析评审用 Opus, 少开并行窗口
metadata:
  type: feedback
---

用户 10-13: "5 小时够用, 但是 7 天不够"; 已是最高个人档 Max 20x, 要求按以下规则执行并同步各窗口:

1. **只有画电路板 (原理图/layout 执行) 派 Codex** (做法见 [[feedback-claude-review-codex-execute]])。**其余活 (软件/RTL/脚本/文档) 仍由 Claude 自己做**, 不要转给 Codex (用户 10-13 更正: "除了画电路板的活, 还是 claude 自己做")。
2. **机械性子任务 → Sonnet** (Agent 工具传 `model: "sonnet"`): 整理表格、跑固定流程、出图、抽取数据等。
3. **分析 / 评审 / 复验 / 难题 → Opus** (主会话及需要深推理的 agent)。
4. **少开并行窗口**; 话题告一段落 `/clear` 或 `/compact`, 结论靠记忆和文件延续。
5. **派 agent 范围写窄**, 先小样本, 不够再加。
6. 兜底: 撞周上限时可开按量付费或备 API Key 溢出 (用户未定)。

**Why:** 今天单窗口 3 个 agent 各 11–27 万 token, 多窗口全天并行累积吃周额度; 套餐已无更高档。
**How to apply:** 每次派活前先问"这活该给 Codex / Sonnet / Opus 哪个"; 汇报里可顺带说明派给了谁。

**10-14 用户追加: 同时并行的子 agent 不超过 5 个** ("现在 7 天的消耗比例有点超")。派新 agent 前先数在跑的 (含被 SendMessage 唤醒在干活的); 满了就排队, 先合并/复验收尾; 复验跑脚本自己跑不占 agent; 能用 Sonnet 的用 Sonnet。
