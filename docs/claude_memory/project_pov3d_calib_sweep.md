---
name: POV3D 1728 bar calibration sweep workflow
description: Firmware mode_calib_sweep + host cap/analyze scripts that build the (chain, chip, bit) → physical (cx, cy) LUT needed before any image-to-panel mapping
type: project
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
第一阶段（2026-05-28 启动）: 在做 HDMI FB → LED panel 桥接前必须先建立映射表.

**架构**:
- 1728 个 bar 位置 (9 chain × 12 chip × 16 bit), 每个亮起来是一条横向 bar
- 这个 sweep 只关心 chip×bit → 物理 (x,y) 映射, row_iter 全 384 都点 (亮整列)
- 每 bit 实际亮 N 个 dots (sub-module duplication), 用 blob detection 不用 centroid

**Why**: 当前 mode_single_pixel 只能盲选 chip/bit, 没有 LUT 没法把任意 (col, row) → 正确的 (chain, chip, bit, row_iter). 也是后续 PWM/BCM 真灰度的前置.

**How to apply**:
- 板端 mode 在 led_panel.c, `mode_calib_sweep()`, `CALIB_FRAMES_PER_TUPLE=8`, ~7-9 分钟跑完
- 主入口 `led_panel_multi_mode_diag()` 已切到 calib_sweep (替换原 mode_single_pixel 5000 次循环)
- 同步: 板端每 tuple 完成后通过 UART 打 `[CAL] idx C K B` 给 host
- 工具: `tools/cap_sweep.py` (UART 触发 grab) + `tools/analyze_sweep.py` (blob detect → calib_lut.json/csv)
- 输出: `D:\workspace\zynq_pov\tools\calib_out\cal_NNNN_C*_K*_B*.jpg` + `calib_lut.json`
- 摄像头默认 idx 1 (MSMF), UART 默认 COM4 @ 921600

**下一步** (LUT 出来后):
1. `viz_lut.py` 出 lut_viz.png, 三 sub-panel (by chain / by chip / by bit), 看分布对不对
2. 若 chain 0..8 形成 3 行带 × 3 色, chip 0..11 列序连续, bit 0..15 子序连续 → 拓扑对
3. **Phase 1 LUT 不含 row_iter 维度** (sweep 时全 384 都点亮 → 每 bit 是整条 bar, 多 blob)
4. Phase 2 sweep: 固定 1 个 (chain, chip, bit), 扫 row_iter 0..383 → 出 row_iter → y 映射
5. 假设 row_iter→y 跟 (chain, chip, bit) 无关, 一条 sweep 套全 panel
6. 反向函数: (x_pct, y_pct) → 找 phase-1 LUT 最近 blob → (chain, chip, bit) + 找 phase-2 LUT 最近 row → row_iter
7. HDMI FB downsample → 帧 buffer 写 chain_data → panel
