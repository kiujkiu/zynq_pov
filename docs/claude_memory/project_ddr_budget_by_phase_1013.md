---
name: project-ddr-budget-by-phase-1013
description: 10-13 结论: 现主控 DR1M90 (FS03 型板, 512MB 16bit DDR3L) 容量够; 带宽 0/1 期充裕, 2 期 30Hz 仅余约 11%, 偶发单片慢读 133µs>110µs; 建议自研 SoC 板上 32bit DDR
metadata:
  type: project
---

用户 10-13 要求保存的结论 (截图存档):
- 现板: DR1M90 (与 DR1V90 pin2pin, 米联客 FS03 型板), 512 MB DDR3L 16 bit (MemTotal 468 MB), 32 MB QSPI, TF 卡启动, 无 eMMC。
- **容量够**: 系统跑 RAM + 帧区 CMA 128 MB + 体素网格 (2 期 16 MB, 双缓冲 32 MB)。
- **带宽** (16 bit 实测上限 1.786 GB/s, PL 直供切片):
  | 期 | 需求 | 余量 |
  |---|---|---|
  | 0 期 2047 | 很小 | 充裕 |
  | 1 期 160×180, 24 Hz×358 片 | ≈0.5 GB/s | ≈72% |
  | 2 期 192×216, 30 Hz×605 片 | 1.505 GB/s | 15.7%, 扣 CPU 散写 3–4% 后 ≈11% |
- 2 期隐患: 长跑测到一次单片读 133 µs > 110.19 µs 窗口 → 片间要有缓冲 (FIFO)。
- 解法: 自研 SoC 板 32 bit DDR (带宽翻倍, 余量 >50%, 最划算); 或 8 bit 调色板 (读量减半, 余 ≈58%, 色彩受限)。
- TF 卡在转子上: 900 RPM、r 5–10 cm 约 45–91 g, 卡受力 0.2–0.4 N, 打胶可行; 插入方向朝轴心、避免按压弹出式卡座、用硅胶/热熔胶不用 502、升级走网络; 打胶不解决热重启认卡问题; 量产建议自研板留 eMMC 位。

**Why:** 用户关心现硬件能撑到哪一期, 以及自研板该补什么。
**How to apply:** 2 期/自研 SoC 板 (T2) 讨论时以此为基线; 预算出处 zynq_pov/docs/budget/budget_30hz_2026-10-12.md。相关 [[project-sw-three-phases-1013]] [[project-target-35hz-budget-recheck]]

## 慢读隐患能否软件解 (10-13 回答用户)
能, 不改硬件。依据 X1 实测 (zynq_pov/docs/claude_memory/project_dr1m90_ddr_eta_x1.md): 均 92.9 µs/片, 最慢 95–98, 3 万片长跑一次 133; 30 Hz 窗口 110.19 µs, 每片平均富余 ~17 µs。
1. PL 片间预取缓冲 (改 RTL): 超时 23 µs × 1.786 GB/s ≈ 41 KB, 留 2 倍 ≈ 80 KB (半片), 2 片内追回。主解法, 需核 PL BRAM 余量。
2. 降争用 (软件): CPU 散写/WiFi/大 memcpy 限速错峰; 查 DDRC 端口/QoS (两 HP 都进端口 2)。
3. 兜底: 迟到片重复上一片或黑片, 不撕裂。
4. 先长跑带载定位慢读来源。
平均余量 11% 是带宽本身, 软件只能降需求 (8-bit 调色板) 不能造带宽。

## 🎯 用户 10-13 定: 两条线同步
- **A 线: 现有 16 bit DDR 做到极限** (软件+PL, 不改硬件): PL 片间预取缓冲 (~80 KB) + 降 CPU/WiFi 争用与端口/QoS + 迟到片兜底 + 带载长跑定位慢读; 目标 2 期 30 Hz 在 16 bit 上稳跑。
- **B 线: 同步开始 32 bit DDR** (自研 SoC 板 T2): 芯片支持 32 bit/最大 1 GB (DS1200), FS03 只贴 16 bit。两条线并行, 不互相等。
已转给调试窗口评估是否调整任务。

## 执行归属 (10-13 21:xx 查)
- A 线 = **D16, 调试窗口 pov3d-a8 负责**, 分支 dr1v90 `task/d16-ddr`, 计划 10-17。顺序: 慢读定位长跑 → HP 分端口/QoS → PL 预取缓冲 (~80 KB, D2 合后改 RTL) → 迟到兜底 → 降争用。
- 已做: 预取缓冲仿真 run_d16.sh, 注入 133 µs 慢片 / 连续 3 片 98 µs / 长降速, RING 384 验收 8/8 零迟到零掉片, RING 192 反例必 FAIL; 每秒兜底计数探针。
- 待做: 当晚上板定位长跑 + 8 小时长跑 (屏黑无人值守, pov3d-a8 自己盯)。
- B 线 32 bit DDR 并入 T2 自研 SoC 板硬件任务, 不开软件任务。
- 旁证: 10-12 纯切片上板每 10 s 一阵 late 来自 netguard, 暂停后归零 (task/pure-onboard)。
- **本窗口 (pov3d-84) 不重复派 DDR 任务**, 结果去 pov3d-a8 / task/d16-ddr 看。

## 10-14 D16 (A 线) 结论 (task/d16-ddr 7efe529, 离线 8/8)
- 迟到/掉片**全部来自"阵"** (周期性系统活动让 DDR 变慢约 19 ms, 每面 ~175 片迟到); 孤立慢片 133–188 µs 已被现 RING 384 (每面 2 片, 领先 1 片 ≈83 KB) 吸收, 仿真注入 133 µs/连续 98 µs 零迟到。**PL 预取缓冲不需改 RTL**; 吸收一个 19 ms 阵要每面 ~3 MB, eram 仅 ~700 KB ⇒ 只能压源头。
- 新事实: DDRC 端口 0 = CPU, 端口 1 = USB/SDIO/DMA, 端口 2 = HP (两 HP 都在 2); XMON DDR_S2.QOS_CONFIG 0xF8440804 上电默认固定 qos 0, 写 0x0F 可让端口 2 读优先 (待用户批准 A/B); RING 480 eram 174 / 576 eram 208 时序为正。
- 探针 measure/09_ddr_slow/ddrprobe.c (1 ms 一拍, DDRC 四口带宽 + 中断/fork/收包对齐); 上板 1 h 长跑 `host_d16.sh --main 3600 --abl 300 --sweep 1|2` 定阵源。按 10-13 每 10 s 一阵算迟到率 ≈0.19% > 0.1%; povnetd 已去掉最大源。
- ⚠ D7 的"不开 voxrxd 就不出阵"对照可能口径错 (不起 voxrxd 时 LUT 全 0, PL 不读 DDR)。
