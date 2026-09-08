---
name: reference_eg4s20_bank_voltage_and_lvds33
description: EG4S20 Bank1/3 VCCIO 与内嵌 SDRAM+VCCAUX 短接只能 3.3V(BG256/CG324 两表下同注), 但锁的正好是真差分那两个 bank, 而真対走 LVDS33 与 LVDS25 电气无差别(400MHz/VOCM 同窗口); 仿真対是唯一强制 2.5V 的(无 LVDS33E), 正好在没锁的 Bank0/2
metadata:
  type: reference
---

# EG4S20 的 bank 电压与 LVDS33 (2026-09-04 逐条核过)

## 硬约束(比之前记的更严)

【DS301 原文·BG256 与 CG324 两张引脚表下各一份, 一字不差】
> 因为内部 BANK1 与 BANK3VCCIO 与 SDR SDRAM 电源相连, 所以 VCCO1、VCCO3 只能接 3.3V 电源,
> 且 **VCCIO3、VCCAUX、VCCIO1 内部相互短路**, 使用时需要注意。

不只短接 SDRAM, **还短接 VCCAUX**(3.3V 硬轨) ⇒ 没有绕法。
⚠ 这条**只适用于 EG4S20**(合封 SDRAM 的型号)。EG4A20/EG4X20 无内嵌 SDRAM, 不受此限。
另: 【DS301】EG4S20**NG88** 更严 —— BANK1~7 全须 3.3V, 只有 BANK8 可 1.2~3.3V。

## 但锁的正好是真差分那两个 bank

【CG324 引脚表数 P 脚】+【DS300 表 2-7-1: 左/右 = True LVDS(无需外部电阻), 上/下 = Emulated(需 3R)】

| Bank | 引脚前缀 | 対数 | 类型 | VCCIO |
|---|---|---|---|---|
| Bank1 | `IO_L*` | 20 | **真** | 锁 3.3V |
| Bank3 | `IO_R*` | 30 | **真** | 锁 3.3V |
| Bank0 | `IO_BE*` | 29 | 仿真 | **可 2.5V** |
| Bank2 | `IO_TE*` | 25 | 仿真 | **可 2.5V** |

50 真 + 54 仿真 = 104, 与 DS301 表 1-2 的 `215/(50+54)` 精确吻合。

## 关键: 真対在 3.3V 下用 LVDS33, 与 LVDS25 电气无差别

【DS300 表 3-2-5】`LVDS25`(VCCIO 2.5V) 与 `LVDS33`(VCCIO 3.3V) **输入输出都是 400 MHz / 800 Mbps**
【DS300 表 3-1-15】**`VOCM` 在 2.5V 与 3.3V 下是同一个窗口 0.6~1.4V**, `VOD` 也不分电压
【DS300 表 3-1-15】LVDS33 输入 `VICM` = 0.6~3.15V

⇒ **真対走 LVDS33 驱屏, 没问题。**

🔴 **但"收上行也没问题"这半句 2026-09-04 被推翻** —— 上面是按发端 **LVDS25(VOCM 1.25)** 算的。
过渡台 **FS03 没有 2.5V 轨**(只有 3.3/1.8/1.35), DR1 只能发 **LVDS18: VOCM 0.3/0.6/0.8V**,
而 EG4 @VCCIO=3.3V 的 **VICM 下限就是 0.6V** ⇒ 典型值压在窗口下沿、最小值出窗 300 mV。
- 对 **EG4S20**(本文主体): Bank1/3 锁死 3.3V ⇒ 上行 RX 只能挪到 Bank0/2 仿真対 @2.5V,
  代价是仿真対无片内 100Ω, 端接要外挂。
- ✅ 对 09-07 选定的 **EG4A20**: 无内嵌 SDRAM ⇒ Bank1/3 可配 2.5V, VICM 0.05~2.35 完整包住, 自动解掉。
详见 [[project_pov3d_fs03_cep_ground_and_third_row]] §3。

## 仿真対是唯一强制 2.5V 的

输出标准表里只有 **`LVDS25E`(Emulated, VCCIO=2.5V, 166 MHz)**, **没有 `LVDS33E`**。
⇒ 仿真対必须放 2.5V 的 bank —— 正好 Bank0/2 没被锁。
(输入不受限: 【DS300】"True LVDS 与 Emulated LVDS 均可作为 LVDS25 标准输入, 最大 400 MHz")

## 引脚分配规则(由此推出)

仿真対只能 166 MHz 输出 ⇒ **下行(73 対 @166MHz)先用满 54 対仿真, 溢出 19 対走真対**;
上行入対再从真対里取。所以 "真対用量 = 19 + 上行対数"。

## 🔴 真正的隐患不是电压, 是共模

【ICND2260 DS V1.7】`VIC` = 1.1 / 1.2 / **1.3** V (min/typ/max)
【EG4 DS300】`VOCM` = **0.6 ~ 1.4 V**
⇒ EG4 规格窗口**两端都超出屏侧接受窗口**, 且 2.5V/3.3V 下完全相同, **换电压救不了**。
上板实测过 1.294V 能收, 但那是单颗样品值, 不是规格保证。
对比: 【记忆】GW5A 的 VOS 可选 1.125/1.25/1.375, 是候选表里**唯一能调共模去贴窗口的**。

相关: [[project_eg4_bridge_verification]] [[project_pov3d_uplink_rate_pin_budget]]
[[reference_bridge_fpga_alternatives]] [[reference_icnd2260_spec]]
