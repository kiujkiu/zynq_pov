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

**Backlog (用户 10-13 定: 只记录, 暂不派 agent, 嫌 agent 开太多):** B1 启动阶段屏显 — 上电停转时用 0° 片当平面屏: ① 位流加载后 PL 出静态 logo (先确认 2047 显示通路是否要软件先配寄存器, 属显示后端); ② Linux 启动中早启动小程序逐行显示状态 (内核/PL/WiFi/IP 和名字/转速), 出错信息留屏, 做成内容源走公共片流接口 (2260 可沿用); ③ 启动完成转稳后切正常内容。与 D7 转子运维最近。已写入 deliverables.csv B1。
看板 KR 用户 10-13 已定: KR7.1 按片/1 h 窗口/0.1%; KR5.2 等开电机; 新增 KR4.2 链路 12-bit 已验证; KR10.1 V0=2 (走路动画+实时推流); KR1.1 拆假转管线/KR1.6 实转上屏。B 类 (延迟 70 ms+抖动 KR / 无故障拆两条 / 上电出图拆两条 / 找板 20 s) 待用户定。
