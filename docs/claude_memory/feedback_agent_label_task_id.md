---
name: feedback-agent-label-task-id
description: 用户看不懂子 agent 列表里的细节动作; 子 agent 描述要写 "D编号｜显性目的", 并要求 agent 提交/汇报以 [D编号] 开头; 给用户汇报时也按编号+显性目的说
metadata:
  type: feedback
---

用户 10-13: "你能在子 agent 标注他是为哪个标号任务做的不, 这个太细节的任务我看不懂"。

**Why:** 终端 agent 列表只显示 "general-purpose + 自动生成的英文动作", 用户对不上是哪个交付 (D1–D11) 和为什么做。
**How to apply:** ① 新派 agent 的 description 写成 "D8 联合仿真｜颜色更丰富" 这种; ② prompt 里要求提交信息/消息/汇报以 `[D编号]` 开头; ③ 给用户汇报时先说编号和显性目的, 再说细节。相关 [[project-progress-dashboard]] [[feedback-big-picture-first]]
