---
name: project_gw5a_xboard_rx
description: 2026-10-10 任务 1.3.12 跨板上行接收 (DR1M90→ACG525) — GW5A 上行 PLL 参考改用 DR1 转发时钟 (线速/8, >87MHz 时 IDIV=2) + 每 lane IODELAY 扫眼定中点/极性; 仿真正例 800M/1.0G +100ppm 各 100k beat 0 错, 反例本地参考链路起不来 (连 2ppm 都 74k 错); 板上 D13 未做
metadata:
  type: project
---

# gw5a_xboard 跨板上行接收 (1.3.12 仿真完成, 1.3.13 bit 已出未上板)

代码: `dr1v90/gw5a_xboard` (README 有框图/板上流程/串口 S 行格式), commit 84d0c02 (RTL+bit) + 419a60e (仿真修好+README)。

- **时钟**: `gw5a_bridge/rtl/bridge_clk_gw5a.v` 上行 PLL 参考 = DR1 转发时钟 (`load_ul_m90.sh fwd 2` = 线速/8: 100 MHz@800M, 125@1.0G),
  GW5A PLL 鉴相 19–87.5 MHz ⇒ 参考 >87 时 UL_IDIV=2。默认本地 50 MHz 配置不变。
- **采样点**: `rtl/ul_rxfe_gw5a.v` 每 lane IODELAY (SDTAP 脉冲装载) → IDES8, `gw5a_loop/rtl/eye_scan.v` 训练码期间扫, 定中点 + P/N 极性;
  扫完前 rx_hold 压住 uplink_rx_top。板上扫眼 ≈1.33 ms ⇒ DR1 用 `train` → 等 S 行 scan_done=1 → `go` (或 run ≥2000 us)。
- **仿真结果** (`sim/run_sim.sh`, 每次 ~10 s): 正例 800M/1.0G +100 ppm 各 100 000 beat 0 错 0 重训练, inv=lane3 (注入的 P/N 反接);
  PPM ±300、PLL 相位 0–900 ps 扫参全过。反例本地参考: 800M 28 次 / 1.0G 34 次重训练, 链路从未起来; +2 ppm 本地参考 85 806 beat 错 74 330。
- 🔴 第一版 TB 的坑 (都已修, 详见 README): ① 前端 oct/rx_hold/scan_done 接线被写进 `//` 注释 → 仿真挂死 0 字节日志;
  ② timescale 1ps 把 TBIT/2=624.94 取整成 625, ppm 被丢 → 要 1fs; ③ **高云 prim_sim PLLA 是开环模型** (量平均周期后自由翻转, 半周期 1 ps 取整),
  表示不出 ppm 跟踪 → TB 用理想锁相模型 force CLKOUT0; ④ 无抖动时扫眼全程"干净" (跨边沿只移一位仍是 0x35 循环移位), 要加 ±150 ps 抖动才考到中点算法。

**How to apply:** 任何要靠仿真证明"跨时钟域/ppm"的场合都别信厂商 PLL 模型做频率跟踪; 1ps 精度下检查时钟半周期是否被取整。
板上 D13: FS03 换 0Ω 排阻 + J2=1.8V, 接线表 `dr1v90/uplink_tx/m90/README.md`, 转发时钟进 P11-20/19 (L15 GCLK)。

## 10-10 落到文档
- 规格书 v3 (`POV3D_模组间接口规格书_v3_2026-09-15.html`) 页首加 10-10 修订: **UL_CLK 频率 = 线速/8** (800M 100 MHz / 1.0G 125 MHz, 原 400 MHz 备选, 只改协议); UL_CLK 桥侧必须进 B4_B33 (GCLKT_9A / BPLL_T_IN1)。
- 改板结论 09-18: "UL_CLK 换回 B4_B33" 补注**上行前提**, "补 JTAG 电平转换 + 下载座" 补注**远程升级前提**。任务表新增 1.5.6 转接板改版前提。
- SoC↔桥之间**不需要加 pin**: 契约 20 対 + 边带 4 (SB_ALIGNED 握手兼重训练 / SB_RSTN / UART×2) + JTAG 4 已覆盖握手、复位、状态回读、远程升级; GW5A READY/RECONFIG_N 引给 DR1 属可选 (JTAG 可替代)。
