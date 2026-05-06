---
name: HDMI 颜色匹配 3D Viewer 的 host 调参
description: anime 模型在板子上的视觉色彩与 Windows 3D Viewer 对齐的最佳 host 端参数和已知限制.
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
板子 HDMI 显示 anime 模型时, 与 Windows 3D Viewer 双击 GLB 显示的鲜艳色彩对比, 板子偏暗淡. 经调试 sample_glb 参数对齐到 `brighten=1.3, gamma=0.85, lighting="studio", ambient=0.3, saturation=1.8` (在 test_send_one.py 中), 能显示金黄头发 + 蓝披风 + 白盔甲对比, 接近 3D Viewer.

**Why:** 与 PC 渲染对比时, 板子有三个固有损失无法完全消除:
1. RGB565 量化 (5/6/5 bit, 损失约 5% 精度)
2. Voxel last-write (30K 点 → ~17K voxel cells, 重叠点的颜色被最后写入覆盖, 高饱和色可能被中性色盖掉)
3. 30K 散点 vs 3D Viewer 连续表面 — 即使颜色一致, 散点穿插黑色背景看起来更暗

要更鲜艳可以推 `saturation=2.5, brighten=1.5, gamma=0.7`, 但中性色会被推到失真色调.

**How to apply:** test_send_one.py 默认值已经是 1.3/0.85/studio/0.3/1.8 配置. GUI (pov_gui.py) 默认仍然是 1.0/1.0/studio/0.3/1.0 — 如果用户想 GUI preview 也匹配这个鲜艳调, 需要更新 GUI 默认.

**Voxel 平均色 (2026-04-28 加):** test_send_one.py 在发送前先在 host 用 numpy np.add.at 做 voxel 化 + RGB888 累加平均, 然后每 cell 一个点用 cloud 协议发送 (~17K 点, 比 30K 节约 wire 又避免板子 last-write). 显著改善"金黄头发/蓝披风"色彩还原, 接近 Windows 3D Viewer. 不要走 SPARSE_VOXEL 协议 — 板子在 SPARSE_VOXEL 接收前 memset 32MB voxel_grid 会让 UART RX FIFO 溢出 (200+ms 阻塞期间丢字节, 造成彩色噪点).

**Mesh-aware voxel rasterization (Option A, 2026-04-28):** glb_to_points.py 加了 voxelize_mesh() 函数. 每 triangle 取 centroid 落入的 voxel cell + 用 area 加权累加 RGB (大三角面 dominate 颜色); 多 triangles 落同 cell 时 area-weighted 平均. 加了 lighting (half-lambert/lambert/studio) 给 raw albedo 提亮 (anime baseColor 平均亮度才 47%, 没 lighting 显灰).

**Blender bake PBR (Option A, 2026-04-28):** 用 Blender 4.2 LTS 离线 bake anime GLB. 流程: import GLB → set Sky Texture (Nishita) IBL strength=1.0 → Cycles render with Standard view + bake type='DIFFUSE' (pass: COLOR/DIRECT/INDIRECT) → 创建 1024x1024 image per material → bake 到 image → rewire material baseColor 用该 image → export 新 GLB. 脚本: host/blender/bake_pbr.py. 命令行: `blender.exe -b -P bake_pbr.py -- input.glb output.glb`. test_send_one.py 默认走 anime_62459_baked.glb (如果存在). voxelize_mesh 用 lighting=none + saturation=2.5 让 baked color 不被双重 lighting. 效果: 金黄/蓝/米白颜色比 Option B 更柔和但更接近 anime PBR 风格.

**Simplified PBR + Multi-dir IBL (Option B, 2026-04-28):** voxelize_mesh 内实现简化 PBR:
- **不 global brighten 暗色**: 黑色 baseColor (剑/衣裤) 保持黑, 不被拉成中性灰
- **多方向 IBL**: 4 光源 (key 暖光 + fill 冷光 + sky 冷光 + ground 暖光), per-channel 不同色温, li_r/g/b 分别累加
- **lambert lighting + ambient=0.55** 给立体感
- 输出: tri_color * (li_r, li_g, li_b) per channel
- 后处理: gamma 0.95 + saturation 2.0 (无 selective)

最佳配置: voxel_size=1.0, brighten=1.2, gamma=0.95, saturation=2.0, lighting="lambert", ambient=0.55. 30 FPS (31K cells). HDMI 视觉: 金黄头发+深蓝披风+米黄盔甲+黑剑, 大色块对比清晰, 接近 Windows 3D Viewer 的 PBR 风格.
