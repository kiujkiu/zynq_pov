---
name: reference_eg4_iol_phase_measurable
description: IDDRx2 内 pclk↔sclk 相位从"只能上板量"变成"能算" —— set_annotated_check 能造出 isclk→ipclk 检查弧(手册第一个示例就是它); 实测四种 pclk 供给方案的相位, 直觉写法"两路 BUFG 不移相"最差(0°禁区), 推荐 PLL 直出 + CPHASE=DIV 得 180.0°
metadata:
  type: reference
---

# IOL 内 pclk↔sclk 相位: 能算了 (2026-09-04 实测, EG4A20BG256I7)

## 🎯 突破: 厂家有专门的命令, 手册第一个示例就是这一跳

`set_annotated_check` + `report_annotated_check`【SWUG105 §4.5.19 / §4.9.11】
能在 IOL 的两个时钟脚之间**凭空造一条检查弧**并打印完整插入延迟。
🎯 **SWUG105 转文本第 4376 行, 那条命令的第 1 个示例原文就是 `isclk → ipclk`** —— 厂家专为此准备。

❌ 常规手段全部落空: `set_max_delay` / `set_multicycle_path` / `report_timing_path -from isclk`
都报 `TMR-6526 WARNING: Failed to find any valid -from targets.` / `Total Paths : 0`
—— 因为 **`isclk` 在 TD 的时序图里根本不是 startpoint**。

## 350 MHz 档 (700 Mbps) 四方案实测 Δ = pclk 沿相对 sclk 上升沿

| 方案 | sclk 插入 | pclk 插入 | **Δ (deg of sclk)** | 中心 |
|---|---|---|---|---|
| **F** 现役 BUFIO | **0.000**(标 `unrouted`) | 1.466~1.719 | 185°~217° | 201° |
| **A** 两路 BUFG 不移相 | 1.645~1.927 | 1.645~1.927 | **−25°~+25°** 🔴 | **0° = 禁区** |
| M sclk IOCLK + C1 BUFG | 0.000 | 1.788~2.099 | 225°~265° | 245° |
| ⭐ **A + `CLKC1_CPHASE=4`** | 1.645~1.927 | 1.645~1.927 | **155°~205°** | **180.0°** |

332 档: F = 175°~205°(中心 190°) ⇒ **印证猜测: 厂家把分频器做成 0°对齐再走 GCLK,
就是照 166 MHz 这个 IOL 上限档设计的。**

🔴 **意外: 直觉写法「PLL 出两路各走各的 BUFG」不移相是最差的** —— Δ≈0° 正骑禁区, 比 F 还糟。

## 🔴 方案 F 的数字不可信 —— TD 把 IOCLK 建模成 0 是假值

A/K 对照证实: **同一根 sclk 改走 GCLK 到同一个 IOL 同一个脚, 立刻变成 1.6~1.9 ns**。
⇒ F/M 报的 Δ 是**上界**, 真实值 = 报告值 − IOCLK 真实延迟;
**IOCLK 只要有 1.4 ns, F 就掉进禁区。这条纸面无法证伪。**

## FPHASE/CPHASE: 可用且可验证生效

合法值用报错反推(与 VCM 同法):
`SYN-8127 ERROR: The value '8' of parameter 'CLKC1_FPHASE' is out of range [0, 7].`
`... 'CLKC1_CPHASE' ... out of range [0, 128]`
⚠ 比 `eagle_macro.v:934-943` 注释写的 `1~127` 宽, 且**完全不校验 `CPHASE ≤ DIV`**
(CPHASE=0/5/128 全静默接受, 128 那档结果还不合公式)。

**生效三处可验**: phy_1 日志 `USR-1002 : Derived clock: create_generated_clock ... -phase <度>`;
Clock Summary 的 `Rise/Fall`; 普通路径的 `launch/capture edge` 与 `Budget`。

**步长**: `FPHASE` 一步 = **22.5°** of sclk (0.1786 ns); `CPHASE` 一步 = **180°** (1.4286 ns)。
从 A 的 0° 挪到 180° = **CPHASE 一步**(8 个 FPHASE 步也等于 180° 但上限 7, 够不着)。
🔴 **方案 F 一步都走不了** —— pclk 由 BUFIO 分频器派生, PLL 的 C1 根本没接进电路。

## 两条必须记住的限制
1. `report_annotated_check` **只报插入延迟差, 不含 PLL 波形相位**(扫 7 档 CPHASE/FPHASE 它一个数不变)。
   **总相位 = Clock Summary 的 `Rise` 差 + annotated check 的 `Arrival` 差, TD 不替你加。**
2. 想给 IOCLK 灌假设延迟做 what-if: `set_clock_latency` 打在 pin 上报
   `USR-8125 CRITICAL-WARNING: cannot find target clock.`; 打在 clock 上不报错但
   **SWNS/时钟表/annotated check 逐字不变 = 不生效**。**只能手算。**

## ⭐ 结论与建议
700 Mbps(350 MHz) 档方案 F 落在 **185°~217°, 窗内但不安全**(含一个 TD 记 0 的假值, 无法证伪)。
**建议改 PLL 直出 + `CLKC1_CPHASE = CLKC1_DIV`**: 中心 **180.0°**, 全部由真实布线延迟构成、可复核;
附带取消「BUFIO 必须与 IOL 同 bank」的约束 ⇒ **引脚分配自由度变大**。
代价: sclk 上 GCLK(350 < 440 上限 ✅) 且 skew 变差(9 负载时 0.408 vs 0.254 ns),
⚠ **全量 14 対时要重测 skew**。

## 给 FAE 的两个具体数字 (原第 8 条已缩窄)
1. **IDDRx2 内 sclk 域→pclk 域那一跳的 tsu / th** —— 填进 `set_annotated_check` 就能算真 slack
2. **IOCLK 的真实插入延迟** —— TD 报 0, 但 A/K 对照证明同一根时钟走 GCLK 是 1.6~1.9 ns

工程: `pov3d/eg4_a20_pinfit/build_E.sh` + `rtl/a20_phase_top.v` + `gen/parse_E.py`, 32 个 `_prjE_*`;
报告备份 scratchpad `a20fit/phase/`; README §8。**未 commit(该目录不在任何 git 仓库)**。

相关: [[project_pov3d_eg4a20bg256_bridge_selection]] [[project_eg4_bridge_verification]]
