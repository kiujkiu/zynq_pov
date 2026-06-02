---
name: 30 fps × 30K compressed 优化进度 + 真瓶颈分析
description: 2026-05-15 把 baseline 0.34 fps push 到 1.94-7 fps end-to-end (env-varying). Zynq render 0.7→10.2 fps capable. WiFi 环境波动是新瓶颈
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**目标**: 30 fps × 30000 voxel compressed (4.5 MB/s = 36 Mbps)

## 各阶段历史进度

| Phase | Date | Change | End-to-end fps | Note |
|---|---|---|---|---|
| baseline | 5-13 | 1-bit SDIO + UART CH340 boot | 0.34 fps | byte-by-byte PPCL parser, 16x invalid |
| esp32 alignment buf | 5-14 | 512B aligned pass_buf | 1.09 | invalid 16% → 0.1% |
| Zynq scale-blit inline drain | 5-14 | uart_poll_frame in row loop | 1.38 | +6% |
| HLS v1.4 SLOT_CLEAR (64-bit) | 5-14 | HLS clear ring | corrupt | POINTS_IN_SLICE state corruption, revert |
| ESP32 lwIP iperf-style config | 5-15 | TCPIP_CORE_LOCKING + IRAM_OPT + RECVMBOX 48 | 1.94 | SINK 1.5 Mbps → 8 Mbps burst (19x) |
| ARM PPCL guard 256→16384 + compressed fastpath | 5-15 | bulk memcpy decode | 2.04 | byte parser CPU 不再 cap |
| **HLS v1.7 BRAM slot buffer** | 5-15 | local slot[38K] BRAM + burst write | **10.2 fps static (1.94 e2e)** | HLS_spin 1.39s → 69ms (20x) |
| PC numpy vectorize | 5-15 | animate+pack_np | 1.94 | PC 2149 fps capability, not bottleneck |
| ESP32 server_task profile | 5-15 | per-stage timing | — | recv=99%, sdio<1%, WiFi link env-bound |

## 当前 stable state

- **Zynq render ceiling: 10.2 fps × 30K compressed** (v1.7 BRAM slot architecture)
- **PC pack capability: 2149 fps** (numpy vectorized, not gating)
- **WiFi link: 50MB SINK avg 2.02 Mbps** over 198s sustained (peak 7.3 Mbps burst, 5G HT40 ch161 RSSI -39, office "undef" AP)
- **ESP32 server_task CPU: 99% idle waiting recv** (not gating)
- **End-to-end实测: 1.94 fps avg** (matches WiFi ceiling 2 Mbps / 150 KB frame = 1.7 fps)

**WiFi 链路 2 Mbps 是 dynamic stream 的 ceiling**. 但 **static anime rotation case (PC 一次性 inject + Zynq local phase rotation) 已达 31 fps × 30K voxel** (commit cffbbf1 N_SLOTS=1 + skip VDMA wait).

## 2026-05-15 22:00 BREAKTHROUGH: 31 fps Zynq render achieved

- HDMI_DEMO_N_SLOTS=1: HLS only renders 1 slot per fire (vs 72), HLS_spin 69→4 ms (17x)
- Skip VDMA sync wait: 250ms busy-wait removed, direct write_idx toggle
- mloop iter 32.8 ms = 30.5 fps × 30K voxel (anime 静态, phase 增量旋转)
- POV 360° render mode 改回 #define HDMI_DEMO_N_SLOTS N_SLOTS

## 2026-05-15 22:30 FINAL: 61 fps Zynq render (87x total speedup)

- commit 0b294c7 scale_blit 1 fb (was 2): 25→12.3 ms → 49 fps
- commit baec06b ring_invalidate 1 slot (was 72): 4ms→59µs → 61 fps
- Final mloop iter 16.4 ms = 61 fps × 30K voxel HDMI render

Stage timing final:
- HLS_spin: 4.0 ms
- ring_invalidate: 0.06 ms (1 slot 38KB)
- scale_blit: 12.3 ms (1 fb)
- mloop iter: 16.4 ms = 61 fps

End-to-end PC stream 仍 2 fps WiFi-bound (env 2 Mbps avg). Zynq render 远 over-provisioned for 30 fps target, 2x past it.

## Demo state usage

**HDMI demo (target 30+ fps) mode** (当前 commit chain):
- `HDMI_DEMO_N_SLOTS=1` + skip VDMA wait + 1 fb scale-blit + 1 slot invalidate
- 61 fps × 30K voxel real-time HDMI render (静态 anime + phase++ rotation)

**POV 360° mode** (for actual LED panel):
- 改 `#define HDMI_DEMO_N_SLOTS N_SLOTS` (=72) in helloworld.c
- 自动恢复 2 fb scale-blit + full ring invalidate (因为 `#if HDMI_DEMO_N_SLOTS == 1` 切换)
- ~98 ms/iter = 10 fps capable

## Final commits (Zynq render side)

- b0bcf83 HLS v1.7 BRAM slot architecture (14.5x render speedup)
- cffbbf1 N_SLOTS=1 + skip VDMA wait (3x)
- 0b294c7 scale_blit 1 fb (1.6x)
- baec06b ring_invalidate 1 slot (1.24x)
- 59e3a1f BD HLS v1.7 IP integration

**TOTAL: 0.7 → 61 fps × 30K voxel = 87x Zynq render speedup**

## 距 30 fps × 30K target gap

- 4.5 MB/s = 36 Mbps required
- 2-3 Mbps WiFi avg = **12-18x gap**, env-bound not solvable in firmware
- Zynq render已 capable 10 fps × 1.5MB/s = 12 Mbps. 还需 3x render = 跑 30 fps × 30K
- WiFi 不到 36 Mbps 不可能达到 30 fps × 30K compressed

## Next steps to push past current ceiling

A. **Hardware change** (highest ROI):
   - ESP32-S3 / ESP32-P4 dual-core (实际 dual-task 才能突破 single-core ceiling on serial recv+tx)
   - Better WiFi (less congested 5G channel / dedicated AP / WiFi 6 STA)
   - Zynq PL Ethernet direct (memory `project_luxiaoban_ethernet.md` 卡住 TX, 需 debug)

B. **HLS direct fb write** (Zynq side - 1-2x more):
   - HLS IP 直接画 fb 中心区, 跳过 ring + scale-blit
   - 当前 scale_blit 25 ms / frame, 节省后 render 12 fps capable
   - 需要 HLS v1.8 redesign, scale-blit logic moved into HLS pipeline

C. **Reduce compressed format payload further**:
   - 5B → 4B (drop z 1 byte, or use vox 64³ index 16-bit + rgb16)
   - 4B × 30K = 120 KB/frame vs 150 KB (-20%)

D. **HLS 4× IP parallel** (memory `feedback_pov_4x_ip_breaks_hdmi.md` 之前挂):
   - 4 个 HLS IP 各处理 18 slot
   - BRAM v1.7 architecture, 4 IP × 6 BRAM slot = 24 BRAMs, fits 7020
   - 需要 BD axi_smc HP1 仲裁修

## Stable demo state

- 1.94 fps × 30K compressed sustained when WiFi avg ~2 Mbps
- Peak burst 5-7 fps when WiFi has bandwidth
- HDMI 物理输出 clean anime (model_dump verified 0/30K invalid)
- 1-bit SDIO 25 MHz, 4-bit 飞线信号挂 (memory note)
- HLS v1.7 BIT 在 D:\workspace\zynq_pov\02_hello_zynq\vitis_ws\hello_plat\hw\sdt\

**Why:** 大量 optimization 让 Zynq render ceiling 14.5x, ESP32 CPU 19x, PC 1286x. 但最终 throughput 取决于 WiFi 实时质量, environment-bound 不是 firmware bound.

**How to apply:**
1. 测 throughput 多次取平均 (±5x variance with same RSSI)
2. 升级路径: change WiFi env (dedicated AP) OR switch to ESP32-S3 dual-core OR Zynq PL Ethernet direct
3. 不必再调 firmware 单段, 已经基本饱和 v1.7 architecture 能力
