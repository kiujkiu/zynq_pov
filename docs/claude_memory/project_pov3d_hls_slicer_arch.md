---
name: 渲染 IP 架构定案 — 点云投影版走不通(BRAM 66%), 改 voxel 切片版 ×4 并行
description: csynth 实证: pov_project_batch 单IP占66% BRAM ⇒ 4路并行物理不可能; pov_voxel_slice_batch 只占1%, 快3.7×; 需解 II=3→1 + 体素布局改 y-innermost
type: project
---

2026-08-04 用 Vitis HLS 2024.2 实跑 csynth 定的架构。**推翻了之前所有"4 路并行 IP"的计划**
(包括写好的 `pov_project_batch_4x.h` 和 `tools/bd_4x_pov_project_batch.tcl`)。

上位: 目标口径见 [[project_pov3d_final_target]]; 屏侧见 [[reference_icnd2260_spec]]。

## 🔴 结论一: `pov_project_batch` 的 4 路并行**物理不可能**

| 资源 | 单 IP | 4 路 |
|---|---|---|
| **BRAM_18K** | **185 / 280 = 66%** | **264%** ❌ |

`local_model[32768] × 16B = 512 KB` 一个数组就吃掉大半。
⇒ **这才是 4x 一直没落地的真原因**, 不是 BD 仲裁、不是 HP 端口。

## 🔴 结论二: 每片 89,050 cycles 固定开销与点数无关

csynth 实测 (106×120, 150MHz):
```
SLOT_LOCAL_CLEAR  38,163      ← 逐 byte 清 38KB, II=1 一次一 byte
DEPTH_CLEAR       12,722      ← 同上
SLOT_BURST_WRITE  38,165      ← max_widen_bitwidth=64 **没生效**
                  ───────
                  89,050 cycles = 594 µs @150MHz
SLICES_LOOP 每迭代 76,625 ~ 141,961 cycles
```
widen 没生效的原因: `ARRAY_PARTITION cyclic factor=6` 让连续 8 byte 落不到 8 个不同 bank。
(要修得改 factor=24 = lcm(6,8)。但架构已换, 不修了。)

⚠ **别再引用 "355 µs/片" 那个数** —— 那是**旧的非 batch `pov_project`** 在 **300 点**场景,
且被 DDR 写延迟主导。v1.7 batch 架构实测是 **958 µs/片** (`HLS_spin 69ms / 72 slot`),
与 csynth 吻合。目标 73.7 µs/片 ⇒ **差 13×, 不是 4.8×**。

## ✅ 定案: 改用 `pov_voxel_slice_batch`

同一份 `hls_proj/pov_project.cpp` 里已经写好的另一个 top。csynth 对比 (同 106×120):

| | `pov_project_batch` | **`pov_voxel_slice_batch`** |
|---|---|---|
| cycles/片 @30K 点 | 141,961 | **38,161** |
| **BRAM_18K** | 185 (66%) | **3 (1%)** |
| LUT | 12,789 (24%) | 6,608 (12%) |
| DSP | 35 | 9 |
| 清屏开销 | 89,050 | **0** (每像素都写, 无需清) |

⇒ 快 **3.7×**, BRAM 少 **62 倍**, **4 路并行装得下** (4×BRAM=4% / 4×LUT=50% / 4×DSP=16%)。

代价: 多一个 **voxelize 环节** (点云 → 体素网格, 每体一次 30Hz, 不是每片)。

## 还差两步 (都已定位, 未实施)

### ① 内层 II=3 → 1
```
SLICES_LOOP_YY_LOOP_XX_LOOP:  achieved II = 3 (target 1)
38,161 cycles ÷ 12,720 像素 = 3.0 cycles/像素
```
原因: 每像素写 3 个独立 byte 到 m_axi (`slot[off+0/1/2]`), 一个 W 端口一拍只能出一笔。

按新屏 192×216 = 41,472 像素折算 @150MHz:
| 配置 | µs/片 | vs 目标 73.7 |
|---|---|---|
| 1 IP II=3 (现状) | 829 | ❌ 11× |
| 1 IP II=1 | 276 | ❌ 3.7× |
| **4 IP II=1** | **69** | ✅ |
⇒ **II=1 与 4 路并行两个都要, 缺一不可。**

### ② 🔴 体素布局必须改成 y-innermost, 否则 DDR 散读
读的**总量**没问题 (41,472 × 2B × 13,575 片/s = **1.13 GB/s**), 问题是**模式**:
```
现在: idx = (vz*RES + vy)*RES + vx    内层沿 px 走 ⇒ vx/vz 同时按 cos/sin 变 = 斜线散读
      每次只取 2 byte, DDR 最小交付 8 byte ⇒ 有效带宽浪费 4× ⇒ 实际 ~4.5 GB/s, 超预算
改成: idx = (vz*XZ + vx)*Y + vy       内层沿 py 走 ⇒ vy 连续 ⇒ 432B 突发 ✓
```
🔴 **关键洞察: y 轴不参与旋转** (`my = ry_panel`), 它天然是连续维度, 现在却被放在中间。

代价: 输出变列优先 ⇒ 缓一个 tile 再按行写出。选 **TILE_W=64**:
`64 列 × 216 行 × 2B(rgb16) = 27.6 KB = 14 BRAM_18K/IP`, ×4 = 20% ✓,
写出时每行 64×3 = **192 B 连续块**。

## 新屏参数 (与旧 IP 完全不同, 必须重新参数化)

| | 旧 IP | **新目标** |
|---|---|---|
| `SLICE_W × SLICE_H` | **106 × 120** (HDMI 预览用, 不是 LED 屏!) | **192 × 216** |
| `NUM_ANGLES` | 72 (5° 步进) | **603** (见 [[project_pov3d_final_target]]) |
| slot 字节 | 38,160 | **124,416** (3.26×) |
| 体素网格 | 128³ RGB565 = 4 MB | **192×192×216 × 2B = 15.9 MB** |

## 目标架构

```
点云 →[ARM/PL voxelize, 每体一次 30Hz]→ voxel grid (DDR, z-x-y 布局)
     →[4× voxel slicer, II=1]→ 切片 (DDR, 8-bit)
     →[PL 左移对齐 16-bit]→ mini-LVDS → 48× ICND2260
```

## 工具链备忘

- `C:\Xilinx\Vitis_HLS\2024.2\bin\vitis_hls.bat -f run.tcl` 从 WSL 用 `cmd.exe /c` 调, 可用。
  ⚠ 工程目录必须放 **Windows 可见路径** (`/mnt/d/...`), 放 `/tmp` 不行。
- 复现基线: `set_top pov_project_batch` / `set_part xc7z020clg484-1` / `create_clock -period 6.67`。
- 报告在 `<proj>/<sol>/syn/report/<top>_csynth.rpt`, 内层 II 看
  `<top>_Pipeline_<loop>_csynth.rpt` 的 `achieved` 列。

## 分支

`feature/icnd2260-dualface` (**`mlkpai_fs03` 与 `zynq_pov` 两个仓库同名**, 工作跨仓)。
