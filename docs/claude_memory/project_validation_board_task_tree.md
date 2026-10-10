---
name: project_validation_board_task_tree
description: 2026-10-10 用户要的验证板 4 级任务分解表 (1级目标→2级模块 DR1M90 PS/PL、GW5A、PC、联调→3/4级功能), 含完成度/依赖硬件/可否脱离硬件; 表由 docs/验证板任务分解_mkxlsx.py 生成; 一级关键推演: 60 扫 1串2 每面上限 4,300 fps ⇒ 35 Hz 与 503 片不能同时成立
metadata:
  type: project
---

用户 10-10: 「把当前任务拆成 3-4 级 … 进度完成情况, 哪些可以脱离硬件验证, 哪些独立就能验证 … 开 2 个 agent 看哪些可以先跑就跑起来, 记得保存」。
同日用户另说「我没那么多 token, 剩下的任务不并行了」—— 这次是用户明确要 2 个 agent, 属例外。

- 表: `zynq_pov/docs/验证板任务分解_2026-10-10.xlsx` (三页: 1级目标 / 任务分解 / 汇总); **改进度改 `验证板任务分解_mkxlsx.py` 的 ROWS 再重出**
  (WSL 没 pip, 用 Windows python: `cmd.exe /c "cd /d D:\...\zynq_pov\docs && python 验证板任务分解_mkxlsx.py"`, 已 pip 装 openpyxl)。
- 🔴 一级推演: 验证板 160×180 / 60 扫屏**只能 1串2** ⇒ 每面 ≈4,300 fps @166.67 MHz, 名义 503 片 × 17.5 rev/s = 8,802 ⇒ 要降一项:
  A 1050 RPM 35 Hz + ≈245 片 / B 503 片 + ≈513 RPM 17 Hz / C 900 RPM 30 Hz + ≈286 片 —— **用户还没定**。
- 2级: DR1M90 PS 软件 / DR1M90 PL / GW5A-25 桥 / PC 上位机 / 系统联调 (四门)。
- 10-10 开跑的两个 agent: A = GW5A 验证板配置 (1.3.5: CASCADE=2 / LINES=60 / 166.67 MHz, 仿真+综合);
  B = DR1M90 离线 (1.2.3 uplink_tx M90 综合 + 1.1.6 打包脚本 aarch64 化)。

相关: [[project_pov3d_sw_plan_20d_2026_10_09]] [[project_icnd2260_pairing_mode_bench_0921]] [[project_pov3d_trial_board_503_slices_60scan_ok]]
