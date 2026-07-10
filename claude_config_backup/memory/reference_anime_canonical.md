---
name: anime 默认指代 (POV3D 标准测试角色)
description: 用户说 "anime" 一律指这个角色 — 金发武士, 白色铠甲带红边, 蓝色披风/阴影. 数据源 fb_anime_top.bin/fb_anime_bot.bin (128×64 panel BRAM 格式), 也对应 anime_points.bin (HLS voxel) + glb 源文件
type: reference
created_at: 2026-06-08 19:38 CST
updated_at: 2026-06-08 19:38 CST
originSessionId: c65586d5-1bd7-42fb-bf7e-7a8b7f63582c
---
**角色特征** (2026-06-08 v34e dual panel 上首次同步显示, 用户确认 = canonical):
- 金发 / 黄色头发
- 白色铠甲 (头盔 + 胸甲), 带红色边/装饰
- 蓝色披风或阴影
- 武士 / knight 风格

**数据文件路径**:
- panel BRAM 格式 (128×64, 24-bit RGB): `tools/fb_anime_top.bin` + `tools/fb_anime_bot.bin` (各 16KB)
- HLS voxel 格式 (16B × 30803 点): `anime_points.bin`
- 渲染源图: `tools/anime_crop.png`
- glb 模型: 不知道哪里 (可能 `pov3d/glb/` 或 `models/`)

**生成流程**:
- glb → glb_to_points.py → anime_points.bin (voxel for HLS 投影到 ring buffer → HDMI)
- glb 或 PNG → anime_to_fb.py → fb_anime_top.bin + fb_anime_bot.bin (HUB75E panel BRAM)

**用法**:
- `tools/anime_load_v34e.tcl`: 直接加 panel BRAM 显示 anime
- `tools/dl_minimal.tcl`: 加 anime_points.bin 到 DDR 0x1A000000 + magic 0xA11ECEC0 → ARM 走 HLS → HDMI 显示

**以后约定**: 任何 "把 anime 显示出来" / "anime 加载" / "anime 测试" 都指这个角色, 不用反问.
