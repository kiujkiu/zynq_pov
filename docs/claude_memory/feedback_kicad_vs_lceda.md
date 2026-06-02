---
name: 自做 PCB 工具选 KiCad 不选立创EDA
description: 用户要 claude 深度参与画板时, 选 KiCad (文本工程文件 claude 可 Edit), 不选立创EDA
type: feedback
originSessionId: a0de8487-f937-42a3-9099-232556741253
---
**规则**: 用户做 PCB 想让 claude 帮画图/审稿/写文件时, 用 KiCad 9。

**Why**: 
- KiCad 工程文件全是 text S-expression (.kicad_pro JSON / .kicad_sch / .kicad_sym / .kicad_pcb / .kicad_mod), claude 用 Read/Edit/Write 直接干, 不依赖 GUI
- `kicad-cli` 命令行能跑 DRC/gerber/BOM 导出
- git diff 友好
- 立创EDA 标准版纯网页 claude 完全帮不上, 专业版 .esch/.epcb 格式不公开 schema, Edit 风险大
- 立创EDA 元件库优势 (国产 IC LCSC 编号现成) 通过在 BOM 写 LCSC 编号 + KiCad 自建 sym/fp 解决

**How to apply**:
- 用户问 "用哪个 PCB 工具" 时, 默认推 KiCad 9 (Windows)
- 用户已经在用立创EDA 时, claude 只能审截图 / 出 BOM / 出 IO 表, 不能改文件
- 推 KiCad 后告诉用户文件路径在 `D:\claude_workspace\...`, Windows GUI 跟 WSL claude 共享路径
- 关键自制元件 (BGA 大芯片) 优先用脚本从 vendor 数据 (IBIS pkg / datasheet) 自动生成 sym/fp, 不要手写 484 pin

**例外**: 用户已经在立创EDA 画了不想换 / 需要嘉立创 PCBA 流水线集成 / 元件库 100% LCSC 时, claude 自降为顾问 (review + BOM + IO 表)。
