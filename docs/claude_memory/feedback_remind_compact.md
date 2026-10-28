---
name: feedback-remind-compact
description: 主窗口上下文太长或一段工作告一段落时, 主动提醒用户 /compact 或换窗口 (Claude 不能自己执行斜杠命令), 提醒前先写好交接记忆; 有后台任务/agent 在跑时建议 compact 不要关窗
metadata:
  type: feedback
---

用户 10-14: "以后有这种关窗口或者 compact 的需求你可以自己来补"。Claude 不能自己执行 /compact 或关窗口, 所以改为主动提醒。

**Why:** 7 天额度一天用 42%, 主窗口连续两天上下文极长, 每轮成本高; 进度都在记忆/看板, 压缩不丢东西。
**How to apply:** 遇到 (a) 一大段工作收尾、(b) 主窗口已跑很久/很多轮、(c) 用户问额度 时, 先写/更新交接记忆 (project_handoff_*), 再一句话提醒"现在适合 /compact"; 若有后台 Bash 或子 agent 在跑, 建议 /compact 而不是关窗 (关窗会杀掉它们)。相关 [[feedback-dispatch-token-playbook]]

**10-28 用户再次要求 (记入工作流):** "以后需要 compact 提醒我"。固定动作:
1. 每次汇报一个里程碑结束 (上板长跑出结果 / 一批分支合完 / 一轮派活收齐) 时, 末尾检查是否该 compact, 该就一句话提醒。
2. 提醒前先清点后台: 列出还在跑的 Bash/agent/监视, 说清哪些在干活、哪些是空转残留; 残留按 PID 停 (被拦就给用户 `! kill <PID>`), 在跑的说预计何时结束。
3. 写好交接 (project_v01_stage_1026 等), 再说"现在可以 /compact"或"等 X 跑完 (约 HH:MM) 再 compact"。
4. 等待脚本别写 `until ! pgrep -f "<名>"` —— pgrep -f 会匹配到自己的命令行, 永远等不完 (10-28 发现两个挂了 11/14 小时)。用 PID 文件或 `kill -0 <PID>`。
