---
name: project-gw5a-integrated-bridge-review-1013
description: "10-13 Codex 画的 GW5A 一体桥板 V1.0 (核心板+转接板合一) 评审打回: 原生 ERC 显示核心三页不在网表, 203 单脚网; 返工单在工程 review 目录"
metadata:
  node_type: memory
  type: project
  originSessionId: 48dffb11-59e2-4e99-8576-f8f539c53750
  modified: 2026-10-13T09:21:20.394Z
---

工程 `D:\claude_workspace\pov3d\pcb\projects\POV3D_GW5A_Bridge_V1.0` (由 Codex 生成, 是 [[project-gw5a-adapter-kicad-v1]] 计划的第③步"两块合一")。
10-13 17:20 Claude 用 Windows kicad-cli 跑原生 ERC/网表: 365 条; U1/U2/U3 及核心页不在网表 ⇒ 203 个单脚网; 上行端接 R1000–R1019 两脚都没连。Codex 自写审计报 pass —— 自洽检查不独立。
返工单: `review/Claude评审_2026-10-13_返工单.md`。Codex 沙箱起不了 kicad-cli, 原生 ERC 由 Claude 侧复验。

**Why:** 生成器式原理图必须用原生工具验收。
**How to apply:** Codex 改完后重跑 `kicad-cli sch erc` + `sch export netlist`, 查单脚网为 0 再放行布局。返工改由 Claude 用 codex exec fork 直接派给 Codex (见 [[feedback-claude-review-codex-execute]])。
