---
name: PDF schematic pin map 抽错坑 (LXB GPIO1 pinout pin 19/20/21/22 全错位)
description: 之前 raw text dump SCH PDF 漏对齐 Y 行, GPIO1 pin 19/20/21/22 跟 31/32/33/34 抽反了, 调 v34e dual panel 时让 panel 2 G/B/R2/G2 全接错 PL pin, 2026-06-08 调试 2 小时才发现
type: feedback
created_at: 2026-06-08 18:45 CST
updated_at: 2026-06-08 18:45 CST
originSessionId: c65586d5-1bd7-42fb-bf7e-7a8b7f63582c
---
**踩坑**: `reference_lxb_gpio1_pinout.md` 2026-05 抽 GPIO1 connector pin map 时, pin 19/20/21/22 跟 31/32/33/34 互换了. 原因: 直接 `pdftotext` raw dump SCH page 8, GPIO1 connector 渲染时双排 pin 编号 + IO_L 网络名都在同 Y 但相邻 column, raw text 把 row N 跟 row N+15 的 net 错配到 pin. 没人发现, 直到用这个表设计 v34e dual panel SDI wiring → 用户按表接到 J1.31/32/33/34, 实际板上这些 pin 是 Y14/AA14/V15/V14 (4 个其他 PL pin), PL 信号 (AA13/Y13/AB15/AB14) 实际在 J1.22/21/20/19, 完全没接到 panel 2 → panel 2 只有 R 信号(AA19=J1.13 碰巧 memory 对) 和 B2 (Y16=J1.30 也碰巧对) 工作.

**根因**: PDF schematic 双排 connector 必须用 PyMuPDF (`fitz`) 提取**坐标** + Y 行匹配, 不能用 `get_text()` 直接 dump.

**Fix flow** (2026-06-08 调通):
1. `tools/_extract_sch4.py` PyMuPDF 提取 page 8 所有 text item + (x,y) 坐标
2. 按 Y bin (4-px tolerance) 分行
3. 每行从左到右排序 → pin 号 (x=402/439) + net 名 (x=344/473) 对应

**How to apply**:
- 抽任何 board PDF schematic pin map 前先用 `pdftoppm` 渲染对比, 或者用坐标提取脚本
- memory 里凡是 "PDF SCH 提取" 的表都标 "原始 PDF page X" 留 audit trail
- 用 memory 表前先 sanity check (比如查 1-2 个 pin 跟设计文档对) 防类似 swap

**调试时间**: 2026-06-08, dual panel v34e bring-up. wiring 表设计 → 用户按表接 → R/B2 偶然对 → G/B/R2/G2 全测不通 → 怀疑 dont_touch synth merge → 翻 routed.dcp 路由 → 证 PL 100% 正确 → 用户提"J1.31=Y14" → 翻原始 SCH 才发现 memory 错位.

**memory 已纠正**: `reference_lxb_gpio1_pinout.md` 重写, pin 19/20/21/22/31/32/33/34 全表已 verified against schematic page 8 via PyMuPDF extraction.
