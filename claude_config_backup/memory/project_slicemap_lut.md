---
name: slicemap LUT 实验分支
description: zynq_pov experiment/slicemap-lut 分支与设计文档位置；PoC 设计完成、代码未落地
type: project
originSessionId: 9140baa0-1b84-4f19-82c6-641cbfce0b0d
---
**分支** `experiment/slicemap-lut`（基于 master @ b0d825d，与 experiment/triangle-mesh 平级）
**worktree** `/mnt/d/claude_workspace/pov3d/zynq_pov_slicemap`（与主 worktree 隔离，主 worktree 在 mesh 分支有未提交修改）
**设计文档** `SLICEMAP_LUT_DESIGN.md` 已 commit (0d3b4a2, 2026-05-07)，167 行
**目标** 把 `pov_voxel_slice_batch`（hls_proj/pov_project.cpp:243-256）内层 `(rx_panel*cs)>>8` 与 `(rx_panel*sn)>>8` 替成 `LUT[angle][px] → (mx,mz)`；PoC 规模 72×106×4B=30KB 单 BRAM36K 装下

**Why:** voxel renderer 那两个乘法只依赖 (angle, px)，与 py 无关，YY 循环 120 次完全冗余；同时为 720 slice 终极目标铺路（届时 LUT 460KB，需 URAM 或 DDR cached）。点云正向路径 `pov_project_batch` 瓶颈在 gmem1 写 II=12，不要在那里搞 LUT。

**How to apply:** 下次继续这条线时，先读 SLICEMAP_LUT_DESIGN.md §7 实施步骤；csim 等价对拍务必 bit-exact（C 整数除法负数向 0 舍 vs Python `//` 向负无穷舍，要用 `int(np.fix(x/256))`）。**不要动** cos_sin_lut.h，两套 LUT 共存。
