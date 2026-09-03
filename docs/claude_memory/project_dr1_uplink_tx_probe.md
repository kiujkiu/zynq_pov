---
name: DR1 上行发送端实测 — 200 MHz 收敛, 800 Mbps 档成立 (双面 28 対)
description: 2026-09-03 首次实跑 uplink_tx 探针: SWNS +0.010ns / Fmax 401.6MHz / PackReg=DDRX2 14/14; TD 把 pclk 域按 400MHz 约束都过了 ⇒ 真实 200MHz 余量一倍; 附三个坑(PHY-8033 BUFG / Error-8221 IOBE / #pad reg 判据对 x2 失效)
metadata:
  type: project
---

# DR1 上行 800 Mbps 实测通过 (2026-09-03)

工程 `dr1v90/uplink_tx/`, 分支 `feature/uplink-tx-probe`, 提交 `f403c91`。
命令 `./build.sh 200` (HARNESS=1, NLANE=13), 器件 DR1V90GEG484 **-2 档**,
TD **5.9.1_DR1_2025.1_151.508** (Tang Dynasty V5.9.151508)。

## 结果

| | |
|---|---|
| **SWNS** | **+0.010 ns** ✅ |
| **HWNS** | **+0.015 ns** ✅ |
| Fmax | **401.606 MHz** |
| Viol Endpoints | **0** / 856 (1741 paths) |
| STA coverage | 99.92% |
| **PackReg = DDRX2** | **14 / 14** ✅ ODDRx2 全部打进 IOL |
| 资源 | 193 LUT6 · 831 reg · 545 slice · 17 IO · 31 pad |
| 关键路径 | **Max-Level = 3** |

## 🎯 这个数比表面强一倍

TD 自推的时钟是 **`Type = User LCLK`, C-Period 2.500 ns = 400 MHz, Fanout 474** ——
**它没把 LCLK 的 ÷2 算进去**, 把 pclk 域的全部逻辑(LFSR + 8:1 mux + 831 寄存器)
一起**按 sclk 的 400 MHz 约束**了, 而这样都过。
⇒ **真实 pclk = 200 MHz (5 ns) 余量约 2.5 ns ≈ 100%。**

⇒ ✅ **800 Mbps 上行档在 DR1 侧成立** ⇒ 每面 14 対, **双面 28 対**
(板级引出 48 対, 余 **1.71×**, 每対还配得起 **1.21 根地**)。**不必退到 600/500 Mbps。**

## 🔴 三个踩到的坑 (换到 EG4 上都要重踩一遍)

1. **`PHY-8033: AL_PHY_LCLK instance ... has an illegal driver ...u_bufg_s`**
   ⇒ **`DR1_PHY_LCLK.clkin` 不能由 BUFG 驱动**, 必须 PLL 输出直驱。去掉 BUFG 即过。
   (顺带好处: sclk 与 pclk 同源同一根线, 不会因为一个过 BUFG 一个不过而引入偏斜。)

2. **`#pad reg` 判据对 ODDRx2 完全失效。** `rtl/oddr_dr1_shim.v` 里那条
   "#pad reg == ODDR 实例数" 只对 **ODDRx1** 成立 —— 逐个查过本仓 6 份 `.area`:
   `#pad reg` 精确等于 `PackReg=DDRX1` 的脚数, **DDRX2 的脚贡献 0**。
   ✅ **正确判据: `.area` 的 `Detailed IO Report` 最后一列 `PackReg` 应为 `DDRX2`, 计数 == 实例数。**

3. **`Error-8221` 没撞上, 但它是最大的雷。** ODDRx2 要求 `.adc` 指定**合法 IOBE 球位**,
   而合法球位表**没有任何公开文档**(不在 DS1200 引脚表, 不在 TD 的文本规则里, 只在
   不透明的 `arch/dr1_90.db` 内)。我们挑的 **Bank 33 那 14 対一次就中** ——
   换器件/换球位时要重新试, 并把 Error-8221 做成硬失败。

## 拓扑上的一条关键决定

**PLL 只出 sclk, pclk 由 `DR1_PHY_LCLK` 硬分频 ÷2** —— 照厂家唯一一份 DR1 的 ODDRx2
参考实现(`TD ip/depot/HSIOF9F0D0P0_1.0/DR1_High_Speed_IO.v:127-139`)。
🔴 **不要用"PLL 出两路 C0=pclk / C1=sclk"**: UG1210 图 3-16/3-18 显示 ODDRx2 内部
DFF7/DFF8 用 **sclk 上升沿**重采 PCLK 域数据 ⇒ **要求 sclk 下降沿对齐 pclk 边沿**,
而 **UG1210/UG1211 正文只写"PCLK 为 SCLK 速度的一半", 一个字没提相位** ⇒
两路 PLL 输出的相位没有任何文档保证, 错了也不告警。硬分频的相位由构造保证。

## SDC: 两趟流程, 第 2 趟没跑通也不影响结论

`get_pins` 的驱动名必须从 `.area` 的 Clock Resource Statistics 逐字抄。
第 1 趟 `derive_pll_clocks` 让 TD 自推 → 打印真实驱动名 → 第 2 趟显式命名。
🔴 **第 2 趟卡在 `USR-8112 cannot find the master clock`**(`rename_clock` 用
`u_pll/u_pll.clkc[0]` 已能绑上, LCLK 的 `get_pins` 也能找到, 但 `create_generated_clock`
带不带 `-master_clock` 都报) —— **不必跑通, 因为第 1 趟是更严的口径。**

## ⚠ 这个数的适用边界

探针是 **HARNESS=1(LFSR + 8:1 mux)**, 仍比真实的
"FIFO 读出 → 8→16 位宽扩展 → 13→72 重排"容易 ⇒ **是乐观上界**。
但 400 MHz 下只用 **3 级逻辑**就收敛, 200 MHz 有整整一倍余量吃更深的逻辑。

相关: [[project_pov3d_bridge_architecture]] [[reference_anlogic_td_toolchain_setup]]
