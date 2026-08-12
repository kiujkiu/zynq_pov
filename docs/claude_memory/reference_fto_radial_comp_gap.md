---
name: reference_fto_radial_comp_gap
description: FTO claim chart 原本只比对了 multivox, 漏了 PVS1 的 --radial-comp; 它命中的是另一组从属权(空间抖动/亮度占空比), §4 方案A 完全不覆盖; 现状默认关闭
metadata:
  type: reference
---

# FTO 缺口: `--radial-comp` 不在原 claim chart 里 (2026-08-12 补)

> 非法律意见。完整分析在 **`/mnt/d/claude_workspace/pov3d/FTO_voxon_p3.md` §2 补充**。
> ⚠ 那份备忘在**工作区根目录, 不在任何 git 仓库里** —— 换机/清理会丢, 且不受版本管理。

## 一句话

`FTO_voxon_p3.md` 的 claim chart 只比对了 `multivox` 移植代码(命中路径 = **刷新率**,
claims 2-5), 而 **PVS1 渲染管线的 `--radial-comp` 是另一条代码路径、命中另一组从属权**
(**空间抖动 6-8 / 亮度占空比 9-13**)。
🔴 **§4 的方案 A(统一刷新率) 对它完全无效** —— 改完方案 A 这条仍然落入。

这正是 §7 行动清单里那条"全工程 grep radius/radial 二次扫描"要找的东西, 之前没做。

## 技术事实 (与 IP 判断无关, 工程上要知道的)

`tools/gen_anime_slices.py:260` `radial_gain()`:
- 逐列真实半径 **`r = √(u² + axis_off²)`**(偏移面上不是 `|u|`, 见
  [[reference_pov3d_brightness_control_limits]])
- 增益 **∝ r**, 带下限 `--radial-floor`(默认 0.12; 纯 ∝r 会让轴心全黑)
- 叠加双面覆盖阶跃: `r < off` 只被穿心面照到 ⇒ 补 2×
- 1-bit 内容**只能变暗**, 所以增益是**靠抖动密度**兑现的 —— 这就是它同时触及
  "空间抖动"和"亮度/占空比"两组从属权的原因

**为什么这个补偿在物理上是必要的**: 半径 r 处像素每转扫过周长 2πr, 同样的光摊到更大
面积 ⇒ 强度 ∝ 1/r, 轴心过亮。**任何旋转 POV 显示都必须面对这件事** ——
这也是"显而易见性"论点的立足点(待代理人评估)。

## 现状 (2026-08-12 核实)

- `--radial-comp` 是 `action='store_true'`, **默认关闭**
- 全仓 grep: **没有任何脚本 / service / 出厂预设启用它**
- 代码自带警告: `povstream.py:1570` 与 `radial_gain()` docstring

🔴 **保持这个状态就是目前最强的位置**: 出货产品不做这件事。
若要启用, 先看 FTO 备忘 §2 补充里的三条建议。

相关：[[reference_pov3d_brightness_control_limits]] [[project_pov3d_v31_delivery]]
