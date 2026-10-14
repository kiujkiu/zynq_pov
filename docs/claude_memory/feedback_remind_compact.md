---
name: feedback-remind-compact
description: 主窗口上下文太长或一段工作告一段落时, 主动提醒用户 /compact 或换窗口 (Claude 不能自己执行斜杠命令), 提醒前先写好交接记忆; 有后台任务/agent 在跑时建议 compact 不要关窗
metadata:
  type: feedback
---

用户 10-14: "以后有这种关窗口或者 compact 的需求你可以自己来补"。Claude 不能自己执行 /compact 或关窗口, 所以改为主动提醒。

**Why:** 7 天额度一天用 42%, 主窗口连续两天上下文极长, 每轮成本高; 进度都在记忆/看板, 压缩不丢东西。
**How to apply:** 遇到 (a) 一大段工作收尾、(b) 主窗口已跑很久/很多轮、(c) 用户问额度 时, 先写/更新交接记忆 (project_handoff_*), 再一句话提醒"现在适合 /compact"; 若有后台 Bash 或子 agent 在跑, 建议 /compact 而不是关窗 (关窗会杀掉它们)。相关 [[feedback-dispatch-token-playbook]]
