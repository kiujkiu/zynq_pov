---
name: project-progress-dashboard
description: 10-13 用户要的"显性目的"进度看板: OKR (O=观众看到的产品效果, KR=量化指标) + KR 趋势图 + 燃起图 + 里程碑趋势 MTA; 数据 csv 在 zynq_pov/docs/progress/, 脚本生成 Excel, 每周 PDF 快照
metadata:
  type: project
---

用户 10-13: 要统一口径, 每项任务找到产品上的"显性目的" (例: WiFi 提速/板上切片 = 拓宽数据通路 ⇒ 画面能实时变化; 换 2260 = 显示优化 ⇒ 真实 30 Hz 体帧率); "我需要看到变化趋势"。主会话推荐 OKR + 三图 (KR 趋势 / 燃起图 / MTA), 用户认可"按这个做第一版"。

- 10 条显性目的: 实时变化 / 30 Hz 体帧率 / 清晰度 / 色深 / 几何不变形 / 亮度与停转 / 长时间稳定 / 上电即用 / 转起来能看状态和远程升级 / 内容丰富。
- 数据: zynq_pov/docs/progress/{goals,krs,metrics,deliverables,mta}.csv, 每个实测点必须有来源; mk_progress.py → 显性目的进度_<日期>.xlsx (现状/指标趋势/燃起图/里程碑趋势/历史记录) + HTML→Edge PDF。第一版 10-13 派 agent 做。

**How to apply:** 每次交付复验通过合主线后, 往 metrics.csv / deliverables.csv 追加并重新生成; 每周加一行 mta.csv 并出 PDF 快照。汇报进度时按显性目的说, 不按模块说。相关 [[project-short-term-delivery-1013]] [[project-sw-three-phases-1013]]
