---
name: project_icnd2260_link_ceiling_and_clock
description: 9颗40x45x16bit 三通道 mini-LVDS 的链路天花板只有 ~1310 fps(170MHz 规格上限下), 9000 fps 物理上做不到; 且供应商那份表是在 DCLK≈149MHz/GCLK 595MHz 上标定的, 我们跑 20.8MHz 低 7 倍
metadata:
  type: project
---

# mini-LVDS 链路天花板 + 我们跑在供应商工作点的 1/7 (2026-09-01)

## 当前时钟(`icnd2260_lxb_lvds_top.v:98-118`)

```
板载 PL_CLK_50M (M19) 50 MHz
MMCM: 50M × 20 ÷ 1 ⇒ VCO = 1000 MHz  (固定)
CLKOUT0 ÷ CLK_DIV ⇒ clkbit    数据, 0°
CLKOUT1 ÷ CLK_DIV ⇒ clkbit90  转发时钟, 相移 CLK_PHASE(90°)
```
⇒ **可选档就是 `1000/CLK_DIV` MHz**: 48→20.83 / 24→41.67 / **20→50.0(手册建议值)** /
12→83.33 / 7→142.86 / 6→166.67。CLK_DIV=48 时 clkbit = **20.833 MHz**(周期 48 ns),
线上差分时钟同频, 每 lane 双沿 = 41.67 Mbps, 三 lane 合计 125 Mbps。

手册: `tLVCP = 6~50 ns` ⇒ 允许 **20~170 MHz**。**我们只比下限高 4%**, 而手册【文·PG19】
建议默认 **50 MHz**。PLL 在下限边缘能不能锁, 手册没写。

## 🔴 链路天花板: 这块灯板配置下 mini-LVDS 最多 ~1310 fps

每 lane 每帧要送 `9 颗 × 45 行 × 40 px × 16 bit = 259,200 bit`:

| 差分时钟 | 位速率/lane | 最大帧率 |
|---|---|---|
| 20.83 MHz(现在) | 41.7 Mbps | **161 fps** ← 与实测 fps=160 吻合 |
| 50 MHz(手册建议) | 100 Mbps | 386 fps |
| **170 MHz(规格上限)** | **340 Mbps** | **1,312 fps** |

⇒ **目标 9,000 fps 在"9 颗级联 / 40×45 / 16 bit 线上位宽"下, 用 mini-LVDS 物理上做不到, 差 7 倍。**
出路只有三条: (a) 降线上位宽 —— 但 `VHEAD[23:20]` 手册只定义了 `0x3 = 16 位`, 有没有
8/10/12 bit 编码**手册没写, 必须问厂家**; (b) 减像素/扫描行; (c) 拆成多条并行链路。

⚠ 与 [[reference_icnd2260_spec]] 里"帧频 = GCLK/(灰度等级×扫描数)"那条不矛盾:
那算的是**芯片显示**能力, 这算的是**链路灌数据**能力, 两者取小。

## 🔴 供应商那份表是在 GCLK 595 MHz 上标定的, 我们跑 83 MHz

从 `icnd2260_regs_vendor.mem` 实算(手册 §PG20: **mini-LVDS 下 M = Reg0x06[8:5] × 4**, TTL 是 ×1):

```
0x06 = 0xaa44 → P = 4, M_field = 2 ⇒ M = 8
0x00 = 0x493c → N = 8
R = P/M × N = 4.0      GCLK = DCLK × R
```

| DCLK | GCLK |
|---|---|
| 20.83 MHz(我们) | **83.3 MHz** |
| 149 MHz(反推) | **595 MHz** ← 灯板基线工作点(`docs/04_fps_sweep.md:80`), 芯片上限 600 |

⇒ **他们那 238 个寄存器、包括 48 个我们推不出来的每色标定值, 全是在 GCLK 595 MHz 上测的。**
所有标定量(消影等级/补偿时间/曝光/低灰补偿)都是**绝对的 GCLK 计数, 不是比例** ⇒ 我们低 7 倍,
等于拿一套标定跑在完全不同的时基上。

**How to apply**: 想复现供应商的点亮条件, 应该把 CLK_DIV 压到 **7**(142.9 MHz ⇒ GCLK 571 MHz,
在 600 上限内、离 595 只差 4%)。`div6` 档以前编过能出 bit, 所以 div7 大概率也行;
构建脚本按 CLK_DIV 自动算 `BITCLK_NS`/`MARGIN`, 不用手改 XDC。

顺带核实过(都对): `0x06[9]=1` / `0x1a[9]=1`(mLVDS 使能) / `0xb4[5:4]=2`(3 通道) /
`0x04[13:8]=45`(扫描行数, 与灯板一致)。

相关: [[project_lxb_icnd2260_bringup]] [[reference_icnd2260_spec]] [[project_pov3d_final_target_chip_verdict]]
