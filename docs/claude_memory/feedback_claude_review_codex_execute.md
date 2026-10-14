---
name: feedback-claude-review-codex-execute
description: 10-13 定的 Claude 评审 × Codex(GPT) 执行 工作流: codex exec fork/resume 派活, Monitor 直播进对话框, 分闸门放行, 原生工具复验, 每轮存记录
metadata:
  type: feedback
---

用户 10-13 定: **Claude 评审 + 指导 + 复验放行, Codex (本机 WSL `codex` CLI, gpt-6.1-sol) 动手改**。首用在 GW5A 一体桥板 ([[project-gw5a-integrated-bridge-review-1013]])。

## 怎么做
1. **派活**: 用户界面里开着的 Codex 会话被锁 (`~/.codex/thread-writer-locks/<id>.lock`), 不要 resume 它; 用 `codex exec fork <原会话id>` 继承全部上下文开新会话 (用户说"单开一个")。在工程目录下跑, `-c sandbox_mode='"workspace-write"' --skip-git-repo-check -o <回复文件> -` 从 stdin 喂提示词, nohup 后台。之后同一会话用 `codex exec resume <新id>` 续聊。会话 id 在日志头 `session id:`。原会话 id 用 `grep -rl <工程名> ~/.codex/sessions` 找。
2. **让用户看得见 (默认安静模式, 用户 10-13 定, 省 Claude token)**: 只在 Codex 提问/要拍板、真错误、一轮结束复验后说话; 中间过程只进日志和交互记录。用户要直播时: 用户要求"你操作我直接能看到"。用 Monitor tail 日志, 只转 `codex` 段落 (前缀【Codex】) + ERROR (【异常】) + 进程结束; 不转命令刷屏。用户想在界面里看就等跑完后 `codex resume <id>` (跑的时候别开, 会冲突)。
3. **提示词要点**: 说明我是谁和分工; 给证据文件路径; 本轮只做哪几项、明确不许动什么 (布局/架构/我的评审文件); 要求它的自写检查能对已知坏文件报 fail; 结尾要求中文回复 根因/改了哪些文件/意见/剩余风险。
4. **放行以原生工具为准**: Codex 沙箱起不了 Windows kicad-cli, 由 Claude 侧跑 `"/mnt/c/Program Files/KiCad/10.0/bin/kicad-cli.exe" sch erc / sch export netlist` 复验。自写审计自洽 ≠ 正确 (首轮它报 pass, 原生网表 203 个单脚网)。
5. **分闸门, 一步一步**: G0 连通 → G1 设计内容 → G2 器件冻结 (这三步 Codex 执行 + Claude 评审) → G3a 叠层+约束 (模型) → G3b 布局初稿 (模型: 大件分区做好+机械件锁定, 细节出初稿) → G3c 接口契约+FPGA 换脚 (换完回 G0/G1 + Gowin P&R 重过) → G4 关键走线 (10-13 改: 用户不会画 ⇒ 机器分块生成 layout-as-code, Claude 审, 原生 DRC 裁判, 见 [[project_layout_divide_conquer_1013]]) → G5 全布线出图 (Freerouting + 机器修 + 原生 DRC)。🔴 用户 10-13 定: **实现不能找人, G3–G5 全由机器做; 人只做最终外部评审** (板厂 DFM、Altium 同事外审); 没过不进下一步。依据 [[feedback_pcb_model_division]]: 模型布局弱、布线很弱。详表在工程 `review/合作路线_闸门.md`。
6. **并行提效**: Codex 改的同时, Claude 派独立评审 agent 细审设计意图, 产出逐条指导意见 (结论+证据+改法), 上一闸一过直接下发。
7. **保存记录**: 每轮提示词+回复+复验结论追加到工程 `review/Claude-Codex交互记录.md`; 阶段结论同步记忆; 做完主动通知用户。

**Why:** 用户要 Claude 当评审/把关、GPT 当执行, 两者互为独立复验; 要过程可见、留痕, 并按闸门推进避免返工。
**How to apply:** 用户说"让 gpt/codex 做、你来评审"时照此执行; 不能直接给用户界面里的 Codex 窗口发消息, 只能 fork/resume。

**技能 (10-13 建)**: Claude 侧 `~/.claude/skills/pcb-native-verify` (一条命令原生复验) 与 `codex-pcb-round` (派活脚本+安静监视); Codex 侧 `~/.codex/skills/kicad-pcb-rules` (原则+KiCad 10.0.3 生成器坑+自查要求)。新踩的坑要补进 kicad-pcb-rules。

**省额度监工 (用户 10-14, Claude 7 天额度紧)**: 不用 Monitor 30 分钟反复重挂 (每次到期都耗一轮); 改用一个 `run_in_background` 的 Bash 等 Codex 进程结束 (`while kill -0 pid; do sleep 60; done`), 只在结束时被唤醒一次; 中途提问让 Codex 按自己的兜底方案走。回复用户只给结论, 不逐条转述。

**Codex 额度 (10-14)**: 同一会话 resume 到第 9 轮, 单轮 token 1.3M→3.8M, 一天用掉 Codex 周额度 3%→84% (prolite 档, 10-20 16:05 重置)。⇒ 一个会话最多 2–3 轮, 之后写 `review/交接_当前状态.md` 开新会话; 派活前查 used_percent, >80% 先问用户。
