---
name: POV-3D 产品路径决策 — 锁 A (voxel 4× IP)
description: ADR-001 拍板. voxel 4× pov_project_batch_v1 IP 是产品 LED slice 路径. mesh 路径保留 backup, 等 LED 屏到货 + 切精简 BD 时再考虑.
type: project
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**决策 (2026-05-09)**: 产品 LED 720 slice × 30 Hz 路径 = **A: voxel 4× pov_project_batch IP**.

**Why**:
- 已实测综合 + impl + bit 全过 (LUT 56% / Timing WNS +0.240 ns)
- 4× @ 150 MHz = 48K slice/sec, 超 21.6K 目标 2.2× 余量
- 资源余量大 (LUT 余 44%), 跟现 HDMI/ETH/UART 共存无障碍
- Phase 8 颜色已 tune warm bake → anime 接近, voxel 离散散布在 LED 上视觉接受度可
- mesh 路径单 IP LUT 97% 跟 HDMI/ETH 共存超 110% (估算), 不可行

**How to apply**:
- 主 BD 当前已含 4× pov_project_batch (phase9.5-task-I-dual-core 分支)
- helloworld.c 仍用 1× IP 调用 (POV_BASE 0x43C20000); 实际跑 4× 需切 driver header `pov_project_batch_4x.h` 的 p4x_fire_all
- LED 屏到货前不必切 4× driver (现 1× 已够 24-cell HDMI debug)
- LED 屏接通后再切 4× driver + 跑产品 720 slice flow

**Backup mesh 路径**:
- mesh_slice_render IP zip 在 `hls_proj/mesh_slice_ip.zip` + 解压在 `hls_proj/mesh_slice_ip/`
- BD swap tcl 在 `tools/bd_swap_to_mesh_slice.tcl` (WIP, 待修 rgb2dvi locked + connect_bd_net 错)
- 走 mesh 路径条件: 去 HDMI debug + 去 ETH (走 ESP32 桥), 释放 ~15% LUT, 让 mesh + WiFi 跑得动
- 完整 ADR: `docs/ADR-001-voxel-vs-mesh-product-path.md` 在 experiment/mesh-slice-bd 分支

**反向条件 (从 A 切到 mesh)**:
- voxel 4× LED 实测颜色"碎片色块"严重不可接受
- 或 host 端 voxel→mesh 转换性能瓶颈无法解
- 切换成本: 1 个 BD 切换 tcl + 重综合 ~30 min, 已有备货
