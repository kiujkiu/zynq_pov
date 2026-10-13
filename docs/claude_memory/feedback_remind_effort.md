---
name: feedback-remind-effort
description: 用户要我在需要提高 effort 时主动提醒; 主窗口平时中档, 到难判断节点 (1.2G 方案变更 / D8 联合仿真设计 / 回板联调) 提醒用户开高档, 难度大的子 agent 可在用户同意后指定 high
metadata:
  type: feedback
---

用户 10-13 问"effort 从中开到高对你有价值吗", 我答主窗口协调工作中档够用、硬骨头时再开; 用户: "需要提高 effort 也提醒我"。

**Why:** 高档更慢更耗额度, 用户想只在值得的时候开。
**How to apply:** 遇到需要深度判断的节点 (方案取舍、复杂 RTL/时序、全链路仿真设计、回板故障定位、结论里推理可疑), 先一句话提醒用户"这一步建议开高档"并说理由; 子 agent 的 effort 只有用户明确同意才在 Agent 调用里指定。相关 [[feedback-agent-label-task-id]]
