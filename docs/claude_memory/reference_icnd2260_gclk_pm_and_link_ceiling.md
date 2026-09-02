---
name: reference_icnd2260_gclk_pm_and_link_ceiling
description: 0x06 的 P/M 手册明写 F_GCLK=DCLK×P/M, 出厂 0xAA44 是 P/M=0.5 => 改 0xAA48 白捡 2 倍显示帧率且色深零代价; 单颗帧内容实测 15,268 拍 => 62.5MHz 硬顶 4032 fps
metadata:
  type: reference
---

# GCLK 的 P/M, 和单颗的链路硬顶 (2026-09-02)

## 一、🔴 出厂配置只用了一半的 GCLK

【手册明确·PG `docs/pg.txt:1575-1582` + `:2067`】
```
P = Reg0x06[4:0]   (TTL & mini-LVDS)
M = Reg0x06[8:5]   (TTL)  /  Reg0x06[8:5] x 4  (mini-LVDS)
Tgclk = 1/(Fdclk x (P/M))        =>  F_GCLK = DCLK x P/M
```
出厂 `0x06 = 0xAA44` ⇒ bits[4:0]=4 ⇒ **P=4**; bits[8:5]=2 ⇒ mini-LVDS **M=2x4=8** ⇒ **P/M = 0.5**

⇒ 改成 **`0x06 = 0xAA48`**(P=8) ⇒ **P/M = 1.0, GCLK 翻倍, 显示帧率翻倍,
   而刷新分组数不动 ⇒ 色深一位不掉。**
⚠ 【手册明确·DS 第2页】F_GCLK Max **600 MHz**, 改之前先算别超。
⚠ 这条只能用**短曝光拍照**验证(见 [[feedback_time_average_cannot_measure_display_rate]]),
  静态图案上翻倍与否看不出任何区别。

## 二、单颗 (CASCADE=1) 的链路硬顶 —— 实测

从高速档反解(gap 小的时候精度高得多; 低帧率点因 fps 取整误差被放大几百倍, 不可用):
```
4200 档: 62.5e6/3848 - 973  = 15,269 拍
3800 档: 62.5e6/3510 - 2540 = 15,266 拍     三点一致到 3 拍以内
3000 档: 62.5e6/2816 - 6926 = 15,268 拍
gap=0  : 62.5e6/4032        = 15,501 拍     (多的 233 拍 = 每 64 帧一次整表刷新摊到每帧)
```
**⇒ 帧内容 ≈ 15,268 拍。62.5 MHz 硬顶 = 4,032 fps(实测) / 4,093(算)。**
并行独立从 RTL 帧结构逐拍数出 **15,262 拍**, 与实测差 0.04% —— 互相印证。

**⇒ 10,000 fps 需要 DCLK ≈ 155 MHz**(手册允许 20~170MHz, 余量仅 9%)。

## 三、高频时序: 卡的是固定项, 降频救不了

| bit | 位时钟 | WNS | WHS |
|---|---|---|---|
| div8_cas1 | 125 MHz | **-0.473** | -0.489 |
| div7_cas1_f152 | 151.8 MHz | **-0.468** | -0.484 |

🔴 **两个频率差 21%, 违规量却几乎相同** ⇒ 违规由**固定大小的项**主导(实测 Clock Path Skew
**1.652 ns**), 而约束窗口随周期缩小。**降频不能救, 必须修偏斜本身。**

## 四、MMCM 的 VCO 现在是参数了

原来 `CLKFBOUT_MULT_F` 写死 20.0 (VCO=1000MHz), 而 `CLKOUT1_DIVIDE` 必须是整数
⇒ 位时钟只能取 1000/N, **152 MHz 取不到**。
已加 `parameter integer VCO_MULT_X8`(默认 160 = 原行为), 构建关键字 `f152/f143/f167`。
🔴 同时修了 `localparam BITCLK_HZ`(帧率计数器的 1 秒窗口)—— 它原本写死 1e9/CLK_DIV,
  换 VCO 后**每个 fps 读数都会错且错得自洽**。

相关: [[project_icnd2260_single_chip_fps_pivot]] [[feedback_time_average_cannot_measure_display_rate]]
[[reference_icnd2260_startup_writes_table_66_times]]
