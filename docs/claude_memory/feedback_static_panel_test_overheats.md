---
name: feedback_static_panel_test_overheats
description: 🔴 静态点屏用生产亮度会把板子烤重启 — oe_w0=184 是为旋转下可见度调的(94%占空), 静态无风冷; Zynq 自己的静态测试脚本一直用 oe=8
metadata:
  type: feedback
---

# 静态点屏会过热重启 (2026-08-28 实机踩到)

`pov_al_01` 上 `povctl fb solid`(整屏全白)静态显示十几分钟後 **板子过热重启**。
第二次用 `OE_W0=24` 又重启了一次(USB 消失约 60 秒 ⇒ 是**掉电**不是软重启,
CH342 由板子供电)。

## Why

| | |
|---|---|
| `oe_w0=184` | **生产亮度**, 为**高速旋转下的可见度**调的。OE 窗 184 / 行周期约 195 拍 ⇒ 占空比 **约 94%** |
| `fb solid` | 每个像素全亮 = 最大电流 |
| **静态** | POV 叶片正常工作时每个 LED 只在自己那一小片角度窗口里亮, **占空比极低**; 而且**转起来有风冷** |

⇒ 静态 + 生产亮度 + 全白 = **整屏 LED 94% 连续导通、零风冷**。过热是必然的。
**这不是配置错, 是用法错。**

## 🎯 正确的静态亮度一直有据可查: **oe=8**

`mlkpai_fs03/tools/pov6_debug/pov6_colors.py` 与 `pov6_chess.py` 的
`cfg = 0x98360001 | ((oe & 0xFF) << 8)`, usage 写着 **`默认 oe=8`**。
**Zynq 自己的静态测试脚本用的就是 8**, 不是 184。我用 24 已经是它的 3 倍。

功耗对照(点亮比例 × oe 占空, 相对烤糊那次):

| 图案 @ oe | 相对功耗 |
|---|---|
| `solid` @184 | 100% (烤糊) |
| `chess_obs_fb.bin` @8 | **2.5%** (低 40 倍) |
| `splash_fb.bin` @8 | **0.49%** (低 200 倍) |

## How to apply

1. **静态测试一律 `oe=8`**(或 `OE_W0=8`)。⚠ 别再低 —— 见
   [[feedback_oe_window_too_low_invisible]](曾调到 8 沿"屏完全没反应"查了几小时,
   那次是**别的**参数不对, 但下界确实在这附近)。
2. **`fb solid` 只做瞬时"通不通"判断, 看一眼就换掉。** 要长时间挂着看,
   用 `chess_obs`(57.6%)、`robot`(15.3%)、`splash`(11.3%) 这些真图案。
3. **不转的时候不要长时间点屏。** 风冷是设计的一部分。
4. 恢复姿势: `povboot.sh pl` + `povboot.sh sw` 装回 PL 和 povmem 但**不碰 auto_en**
   (RTL 复位为 0) ⇒ 屏保持灭, 可以先配好亮度再点。实测有效。
5. ⚠ **板上没有温度传感器**(`/sys/class/thermal`、`hwmon`、`iio` 都没有), 读不到数。

## ⚠ 这条在 Zynq 的 checklist 里没有

现役 Zynq 同一块屏、同样的 `oe_window`, 但那边静态测试大概都很短没撞到。
**不能因为"Zynq 没事"就认为静态全白安全** —— 这是**时长**问题不是平台差异。

相关: [[project_dr1_panel_first_light]] [[feedback_oe_window_too_low_invisible]]
