---
name: HLS pov_project z-buffer 解决 voxel last-write 覆盖
description: 单 depth-fade 不够 (last-write 让远 voxel 覆盖近 voxel), 加 per-pixel int8 depth_local BRAM + rz 大写小覆盖, II=2 保住, 立体感明显
type: feedback
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
**规则**: voxel cloud HLS 渲染要"前后分得清", 单做 RGB brightness 衰减(`192±rz`)**没用** — 同屏幕像素有多个 voxel 投影, last-write 不分远近, 远 voxel 经常覆盖近 voxel, fade 被洗掉. 必须加 z-buffer (per-pixel depth test).

**Why** (2026-05-21):
- v1.8/v1.9 单 depth-fade 后用户报 "都是后面" / "看不到前面"
- 抓 4 张帧确认旋转 360° OK 包括正面, 但深度衰减视觉效果几乎为 0
- 同像素多 voxel last-write 覆盖, 不管 RGB 多暗多亮, 后写赢
- v1.10 加 `int8 depth_local[SLICE_W*SLICE_H]` BRAM (12720 byte ~3 BRAM block), 12 µs Phase 1b 清零, Phase 2 写前先 read+compare, `rz > old_z` 才写 (+rz = camera-facing)
- HLS II=2 保住 (HLS 自动调度 BRAM read-modify-write 在 2 cycle 内), 没破 pipeline
- Vivado 综合通过, 立体感**显著**: 头发圆顶/披风褶皱/身体厚度都出来了

**How to apply**:
- 任何 voxel/point cloud 渲染要立体感, 第一道是 z-buffer 不是 RGB 衰减
- BRAM 成本: 1 byte/pixel × slot 像素数 (我们 12.7KB)
- 用 int8 够 (rz 范围 ±80, fit int8 ±128). int16 浪费
- 初始值: 最负数 (-128) 表示"无穷远", 任何 voxel 都"近过它"
- 用 in_screen ternary 避免 out-of-range 读 depth_local 越界 (HLS 编译会拒绝跨界 BRAM 访问)
- 配套保留 brightness fade 让残留近 voxel 也有微 contrast, 但 z-buffer 是核心

**关联代码**:
- hls_proj/pov_project.cpp `pov_project_batch`: Phase 1b DEPTH_CLEAR + ok 加 depth check
- hls_proj/run_hls.tcl: -version 1.10
- 不需要 host 改: PovPoint 结构不变, protocol 不变
