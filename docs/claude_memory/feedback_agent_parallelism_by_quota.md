---
name: feedback_agent_parallelism_by_quota
description: 用户 10-10 定: 并行 agent 数按 5h 限额自动调 —— 用量% 超过时间% 就减, 远低于就加; 读法 python3 /mnt/d/claude_workspace/pov3d/tools/quota.py
metadata:
  type: feedback
---

用户原话 (2026-10-10): 「你能读到 5h 的 token 使用情况吗, 你自动调整并行数量, 当 5h 的使用比例超过时间比例, 你应该知道我啥意思, 就减少 agent, 如果远远少于就加一些, 你自己调整」。
同日早些时候用户说过「我没那么多 token, 剩下的任务不并行了」—— 被这条规则取代: 不是一律不并行, 而是按额度动态调。

**Why:** 用户按 5 小时窗口付额度, 用超了会被卡住, 用不完是浪费。

**How to apply:**
- 开新 agent 前、以及 agent 回来时, 跑 `python3 /mnt/d/claude_workspace/pov3d/tools/quota.py`
  (读状态栏缓存 /tmp/claude_statusline_last.json, 由 statusline_with_bars.py 每次刷新写入; 看 data age, 太旧就别信)。
- 窗口前 30% 时间内给 10 个点宽限 (时间% 太小); 🔴 跨窗口时在跑的 agent 会把消耗带进新窗口, 新窗口开头先别加。
- 输出 REDUCE ⇒ 不再开新 agent, 已有的让它跑完; ADD (用量比时间少 ≥25 点且 7d 不超) ⇒ 可多开 1 个; HOLD ⇒ 维持。
- 并行的前提不变: 不碰同一批文件/同一块板/同一个串口; 结果回来由主会话更新任务表。
