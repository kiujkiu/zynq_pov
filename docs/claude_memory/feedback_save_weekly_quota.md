---
name: feedback-save-weekly-quota
description: 省 Claude/Codex 额度规则 + 10-14 实测有效做法 (技能脚本化、后台单次唤醒代替 Monitor 重挂、安静模式、Codex 会话 2–3 轮换新、规则写进技能); 只有画板派 Codex, 机械活 Sonnet/Haiku, 评审 Opus, 并行 agent ≤5
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
- 10-14 用户: 跑完的 agent 要关掉 (TaskStop), 方便区分。约定: 交付并通过主会话复验后立即 TaskStop; 后续工作开新 agent (用 D 编号命名, 背景写进说明), 不唤醒累积了几十万 token 上下文的老 agent。
- **10-14 下午用户: 7 天额度一天不到用了 42%**, "只要完成效果一致, 其实可以灵活调整, 减少点用量"; "有些任务可以开 sonnet 和 haiku"。⇒ 默认: 机械活 (看板/日志/固定流程/抽数据) 用 Sonnet, 更简单的 (读日志判 PASS/FAIL、跑一条命令汇报) 用 Haiku; 主会话自己能用 shell 几步做完的事不派 agent; 复验只跑关键项, 不重复跑 agent 已在新克隆跑过且风险低的全量; 汇报写短; 能等的活合并成一批做。

## 10-14 实测有效的省 token 做法 (GW5A 窗口总结, 用户要求同步各窗口)
**Claude 侧**
- **重复的检查/派活做成技能脚本**, 不每轮手写解析代码: `pcb-native-verify` (一条命令原生复验)、`codex-pcb-round` (派活+记录)。凡是一个流程跑第二次, 就该脚本化。
- **监工不用 Monitor 反复重挂**: Monitor 最长 30 分钟, 每次到期都唤醒一轮。长任务用一个 `run_in_background` 的 Bash 等进程结束 (`while kill -0 $PID; do sleep 60; done`), 只唤醒一次。判断进程用 PID 文件, 不用 `pgrep -f` (会匹配到自己, 永远"在跑")。
- **安静模式**: 后台过程不逐条转述, 只在 提问/真错误/结束 时说话; 汇报只给结论。
- **答复写进文件让对方自己读** (如 `review/Claude-Codex交互记录.md`), 不中途插话。
- 读大 PDF/图纸这类机械提取派 Sonnet 子 agent, 主会话只做判断。
- 能用现成工具的不自己造: 例 Allegro .brd 用 KiCad 10 Python 的 PCB_IO 导入一步转成 (kicad-cli 不列此格式)。

**Codex 侧 (额度与 Claude 分开, 但也有周上限)**
- 🔴 **一个会话最多连用 2–3 轮**: 同一会话 resume 到第 9 轮, 单轮 token 从 1.3M 涨到 3.8M (每轮背着全部历史), 一天用掉 Codex 周额度 3%→84%。之后写精简交接文档开**新会话**。
- **把规则/坑写进 Codex 技能** (`~/.codex/skills/kicad-pcb-rules`), 不在每轮提示词里重复交代, 也减少返工。
- 每轮范围写窄 (一块一块来); 派活前查 `used_percent`, >80% 先问用户。

- 10-14 晚用户: 本周 (10-14 起剩 5 天, 含周末) 总用量争取不超过 60% (当时已 48%)。做法: D16b 分块 (Opus 改 RTL+收时序) 推迟到下周额度刷新后; 本周只做主会话 shell 能完成的事 (长跑判读、QoS 对照用现成 board_qos.sh、看板), 不开 Opus 重活; 必要时开 Sonnet 窄任务。
- 10-14 晚用户: 周额度超过 70% 就先保存再停 (停 agent; 后台脚本照跑; 提交交接/看板推两远端)。Claude 看不到用量, 由用户报数。
