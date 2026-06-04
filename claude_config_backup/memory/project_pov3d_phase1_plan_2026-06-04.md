---
name: POV3D Phase 1 计划 + 3-bit BCM 甜区 + mesh slice 路径 (2026-06-04)
description: FM6124 panel 3-bit BCM @ 2931 fps × 24Hz × 122 slice = POV-3D rotor 1440 RPM sweet spot. mesh slice 走 experiment/triangle-mesh, QSPI flash 存动画
type: project
created_at: 2026-06-04 17:30 CST
updated_at: 2026-06-04 17:30 CST
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
# 当前 baseline + 决策

**Panel**: FM6124 128×64 1/32 scan (已成品), 装 vertical rotor 真旋转 (待硬件)

**BCM 选 3-bit**: 实测 `debug/fm6124-v29` branch:
- 6-bit ~1400 fps (262K 色, reference 平滑)
- **3-bit 2931 fps** (512 色, POV-3D 甜区) ⭐
- 2-bit 4391 fps (64 色)
- 1-bit 8810 fps (8 色 dither)

**POV-3D 参数 lock**:
- 体刷新: 24 Hz (电影感)
- slice 数 N: 122 angle (2931 / 24)
- rotor 转速: 1440 RPM (= 24 RPS)
- 每 slice fb: 128×64×3 = 24 KB raw / 9 KB (3-bit packed)

**QSPI 容量**: W25Q256 32 MB - FSBL/bit/ELF ~10 MB = 22 MB → 7+ 组 122 slice 动画 (1.1 MB packed each)

# Phase 1 路线图 (软件链, 2-3 day)

```
Phase 1.1 PC slice gen (host/panel_slice_gen.py 新建):
  - trimesh load glb (host/anime_34.glb 等已有)
  - 122 angle (Y 轴 0..360°/122 step)
  - silhouette/cross-section render → 128×64 RGB
  - 输出 anime_slices.bin (122 × 24 KB)

Phase 1.2 QSPI flash 写入:
  - 接力 experiment/triangle-mesh 的 dl_qspi_flash_writer (memory commit 083645f...ac8294f, multi-byte 卡)
  - 修 multi-byte transfer (memory feedback_zynq_qspi_* 有线索)
  - 烧 anime_slices.bin 到 QSPI offset (后 FSBL 区)

Phase 1.3 FSBL/Boot 加载:
  - FSBL read QSPI → DDR (e.g. 0x10000000)
  - 或 ARM ELF startup 阶段直接 QSPI read

Phase 1.4 ARM playback (helloworld.c):
  - Timer ISR 24Hz × 122 = 2928 Hz
  - 每 trigger: memcpy DDR slice[i] → PL BRAM (0x40028000 top + 0x4002C000 bot)
  - i = (i+1) % 122
  - 桌面静止 + ARM 自动切 → 看角度切换流畅
```

# Phase 2 路线图 (硬件 rotor, 1-2 week)

```
- BLDC 1440 RPM 控制器选型 + 安全 housing
- 光电 encoder (≥360 step / 转, 122 slice 误差 < 1 度)
- PL: encoder reader IP + angle counter → AXI status
- ARM/PL 闭环: encoder angle → slice index → DMA panel BRAM
- 安全: 启动加速曲线, 物理 limit, 急停
```

# Slice 路径评估 (定 mesh slice, 弃 slicemap LUT)

| 路径 | branch | 状态 | 选 |
|---|---|---|---|
| **mesh slice** | experiment/triangle-mesh | ✅ host code 完整 (anim_loader.py, anime_stream.py, glb x3, Blender bake) | ⭐ |
| QSPI flash 写 | experiment/triangle-mesh (083645f..ac8294f WIP) | ⚠ JEDEC OK, multi-byte 卡 | 接力 |
| slicemap LUT | experiment/slicemap-lut (commit 0d3b4a2) | ❌ 仅 design doc, 没代码 | 弃 |

# 当前 branch 状态 (debug/fm6124-v29)

- HEAD = (v29 timing + runtime BCM planes commit)
- 已 push origin/debug/fm6124-v29
- workspace clean (除 vitis 编译状态)
- 板子上跑 v32 FM6124 PL bit + ARM HDMI→LED bridge + 3-bit BCM, panel 显示 Saber anime 颗粒色彩

# Phase 1 入口 action item

下次 session 开干:
1. `git merge experiment/triangle-mesh -- host/` 或 cherry-pick mesh code 到 debug 分支
2. 新建 `host/panel_slice_gen.py` (trimesh + pyrender, 122 angle)
3. 跑通单 angle render → 128×64 fb 验证
4. 跑全 122 → anime_slices.bin (2.93 MB)
5. ARM timer ISR playback (xsdb DDR 注入 + helloworld 改造)

# 相关 memory

- `project_hub75e_fm6124_lit.md` — v29 timing 优化 baseline
- `project_pov3d_panel_chip_pivot_2026-06-04.md` — FM6124 vs ICND2047 path
- `project_mesh_slice_breakthrough.md` — experiment/triangle-mesh mesh slice 历史
- `project_pov3d_anime_xsdb_path.md` — JTAG 直推 DDR (Phase 1 临时验证用)
- `project_pov3d_final_target.md` — 720×30 终极目标 (Phase 1 是中间站)
