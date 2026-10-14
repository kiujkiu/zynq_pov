---
name: project-gw5a-bridge-handoff-1014
description: 10-14 GW5A 一体桥板监工窗口压缩前的交接: 进度、下一步、待办、关键文件位置
metadata:
  type: project
---

工程 `D:\claude_workspace\pov3d\pcb\projects\POV3D_GW5A_Bridge_V1.0`。总览看 `review/合作路线_闸门.md`, Codex 交接看 `review/交接_当前状态.md`, 全部往来在 `review/Claude-Codex交互记录.md`。分工与做法见 [[feedback-claude-review-codex-execute]]、省额度见 [[feedback-save-weekly-quota]], 项目背景见 [[project-gw5a-integrated-bridge-review-1013]]。

**进度 (10-14 傍晚)**
- 原理图 G0–G2 通过 (原生 ERC 0); 芯片确认 GW5A-LV25 UG324C2/I1; 叠层 6 层 S2 + 规则 G3a 通过; 布局 G3b 通过。
- G4: 扇出已合并; 上行 20 对布通, 原生 DRC 上行剩 gap 14 + uncoupled 13 (6.35 mm 预算未放宽)。下行/电源平面/其余未布。
- Codex 周额度用了 90%, **10-20 16:05 重置**; 一个会话最多 2–3 轮, 下一轮开新会话 (用交接文档)。

**下一步 (额度重置后, 按序)**
0. 每路 FPGA 电源补 1 颗 0402 1µF (用户已批, 依据 UG987 图 2-1)。
1. 上行收尾 (gap 14 + uncoupled 13)。
2. 下行块 → 电源平面 → 其余网 → 出图。
- 固件交接: 14 对上行换球映射 `layout/g4_r9/mapping.csv`、Gowin device 改 UG324C2/I1、DIFF_RESISTOR=ON。

**待用户/同事**: 灯板对插座排距 (4.446 vs 5.00, 投板前必须定)、两板间距与 B 面空间、8 件高度/3 个料号。

**进行中的小事**: 后台在渲染本板 BGA 区 SVG (`review/render_r9/`), 做完把本板扇出与官方板 (`core/gowin_vendor/render/top_bga.png`、`bot_bga.png`) 并排给用户看, 回答"扇出和官方区别大吗"。

**窗口约定**: 监工用 Sonnet; 需设计判断时第一行写"⚠ 建议切回 Opus"。复验统一 `python3 -I ~/.claude/skills/pcb-native-verify/verify.py <工程> <标签> --drc`。
