---
name: Mesh slice B 路径 + 颜色对比结论 (2026-05-08 update)
description: experiment/triangle-mesh 分支完成 mesh→angle slice 板端 + host pipeline. 颜色质量 vs 点云对比验证: 点云路径 HDMI 颜色更优, mesh 价值在产品 POV slice.
type: project
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
实验分支 `experiment/triangle-mesh` 共 10 个 commit (ccc9ae7 / 85bb599 / ae3e11f / 037f16f / aedb10a / 9ae69e8 / 7193243 / ab0e515 / 8b5078b / bbd8c8d) 完成 B 路径 mesh slice + 多版颜色 baking 实验.

**B 路径 mesh→slice 通**:
- host/mesh_slice.py + 板端 cpu_render_mesh_slice_panel() 镜像算法: scanline fill, tri∩plane segments, x-crossings 排序配对填 Gouraud lerp. numpy 4ms/slice, ARM 1.5ms/cell. 切平面坐标 y-up (GLB 约定), 绕 y 轴 z'=0.
- v2 协议: vert 6B (xyz Q8.4), tri 9B (idx + RGB), flag bit 0 切换. 板端 rasterize_tri_flat 内层省 color lerp.
- mesh_compute_aabb() 在 mesh receive 时算 slice 范围.

**颜色 baking 演化** (glb_to_mesh.py build_simplified_mesh_per_tri):
1. v1 area-weighted vertex color → 颜色稀释
2. saturation-weighted dominant baking → 高对比 detail (黑帽/白领) 保留
3. v2 per-tri color (KDTree NN single sample) → 仍 1px texture sample
4. per-orig-tri 7-point bary median + simplified KDTree top-K=32 median → 仍碎片
5. PBR 4-light IBL + abs(dot) lambert 双面 → 立体感 / 颜色受 IBL 推变
6. lighting=False 纯 baseColor → cel-shading 风格

**关键结论**:
mesh per-tri 单色是颜色质量上限. 6K~20K tri × 1 sample/tri 拿不出 anime 大色块 (头发/铠甲). 任何 simplification + sample 策略改进都在"碎片色块的色调"上微调.

**用户验证 2026-05-08**:
HDMI 走 voxel/点云路径 (test_send_one.py + voxelize_mesh + Option B PBR/IBL/lambert + brighten 1.5/gamma 0.9/sat 2.0/ambient 0.7) 颜色显著更接近 3D viewer 第二张 ref 图: 金发/深蓝衣/白铠甲/黑装饰/金剑完整 palette 可辨, RIGHT 24-cell voxel slice 是产品输出参照.

**架构等价性**:
mesh + 256² texture mapping (v3 协议未实现) 与点云每像素一颜色本质等价. wire mesh 290 KB vs 点云 0.5-5 MB, 板端 raster 复杂度 vs splat 简单. 都是 per-surface-sample 的不同表达.

**路径分工**:
- HDMI 视觉调试 / 颜色匹配 → 点云 (test_send_one.py, Option B PBR)
- 产品输出 LED matrix POV slice → mesh slice (实体填充连续切片, 离散点云不行)

**剩余 mesh 局限**:
- LEFT mesh raster render 36-41ms > vsync 16.6ms, 撕裂 (产品不用 raster 不影响)
- 板端 MAX_MESH_TRIS=32K, MAX_MESH_VERTS=16K (协议 vert idx u16 硬限 65K vert)
- mesh 颜色 detail 受 per-tri 单色限制 (跟 3D viewer 1:1 需 texture mapping 大改)

**未 push 远端**: 10 commit 全在 local, GitHub 网络间歇性 GFW 卡 https/443. 后续用户网络好时跑 `cmd.exe /c "cd /d D:\workspace\zynq_pov && git push origin experiment/triangle-mesh"`.
