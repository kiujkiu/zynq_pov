---
name: feedback-deliverables-local-pdf
description: 交付文档(改板单/审查报告等)一律整理成本地 PDF, 不再发布在线 artifact
metadata:
  type: feedback
---

2026-10-12 用户: "整理到本地文件，后续所有文件都整理到本地pdf"。

**Why:** 用户要本地可存档/可转发的文件, 不要在线页。
**How to apply:** 文档先写 HTML (放 zynq_pov/docs/, 沿用改板单样式), 再用 Windows Edge headless `--print-to-pdf` 出 PDF, 把 PDF 路径告诉用户; 不调用 Artifact 发布, 也不再更新改板单在线页 (PDin6aPczGc9NR6uguDnVx 停在 v6)。相关: [[project-handoff-2026-10-12]]
