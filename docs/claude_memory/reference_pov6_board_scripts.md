---
name: pov6 板上调试脚本现状 (2026-07-27)
description: /home/uisrc 下 pov6_*.py 用法与陷阱; povcolors.service 开机自启色循环; 板上与仓库有漂移
type: reference
---
板上 `/home/uisrc/`，仓库对应 `mlkpai_fs03/tools/pov6_debug/`。**两边有漂移，改之前先比对**。

## 常用

| 脚本 | 用途 |
|---|---|
| `pov6_colors2.py <轮数> <每色秒> <oe沿数>` | 七色循环，**oe 可调**（新，2026-07-27） |
| `pov6_hold.py <色名\|L0..L8\|OFF> [oe]` | 设单色并**保持不熄屏**；`L0`~`L8` 单 lane 点名，测 lane 映射用 |
| `pov6_chess.py <bin> <oe>` | 数字棋盘格（`chess_fb.bin` 11664B） |
| `pov6_fake.py` / `pov6_rowsweep.py` / `pov6_phase.py` | fake 角度 / 行扫 / 相位 |

⚠ **旧的 `pov6_colors.py` 和 `pov6_chess.py` 默认 oe=8 沿，会暗到看不见**，
见 [[feedback_oe_window_too_low_invisible]]。用 `pov6_colors2.py` 或显式传 oe。

## povcolors.service（开机自启色循环）

`/etc/systemd/system/povcolors.service`，`After=pov.service`，已 enable。
上电 → `pov.service` 拉 WiFi + 默认动画 → `povcolors` 接管开始循环。
`systemctl stop/disable povcolors` 可退回「开机出默认动画」。

## 陷阱

- 脚本退出**默认会停引擎导致熄屏**（`finally` 里写 `0xC1000000`）。`pov6_colors2.py`/`pov6_hold.py`
  已改成保留最后一帧，熄屏用 `pov6_hold.py OFF`
- 寄存器 0x0C 按 **[31:30] 分 subcmd**：`00`=sdi_mask / `10`=cfg(rows/oe/双沿) / `11`=auto_en,use_fb。
  往 subcmd-11 里带脏位会踩到 pattern 字段
- `0x10` 读回是 slice_idx **不是控制影子**，禁止读改写

## 2026-07-28 变更
- `povcolors.service` 已 **disable**(不再开机自启色循环), 开机走 `pov.service` 的默认动画通路
- 开机默认动画换成**盆景** `bonsai_slices.bin` (源 `models/Models/bonsai.glb`, 见 [[reference_model_library]])
- 新增 `wifi-watchdog.timer` (见 [[reference_fs03_board_access]])

## 默认动画

`/home/uisrc/anime_slices.bin`（4,423,680 B = 360 × 0x3000），`pov_boot.sh` 灌进 DDR `0x10000000`。
2026-07-27 起是 **gap 13.8mm 偏移轴版**（见 [[project_pov3d_offset_axis_geometry]]），
穿心旧版备份在 `anime_slices_center.bak`。
