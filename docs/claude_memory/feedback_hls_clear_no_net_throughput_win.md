---
name: HLS in-IP slot clear 不能突破 throughput, ESP32 端 single-task 才是真瓶颈
description: v1.4 64-bit SLOT_CLEAR 让 HLS 内部 clear 2.3ms (vs ARM memset 25ms) 数学上更快, 实测 throughput 不变 (~1 fps × 30K compressed)
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**2026-05-14 长链路 throughput 调优收尾**

POV3D WiFi 路径完整 (PC→TCP→ESP32→SDIO→Zynq→render→HDMI), 但 30 fps × 30K compressed 目标 ~30x gap. 实测 ~1.0-1.4 fps × 30K, byte rate 100-200 KB/s.

## 试过的 optimization 跟实测对比

| 优化 | 期望 | 实测 fps × 30K compressed |
|---|---|---|
| baseline (no PPCL fastpath) | — | 0.34 |
| ESP32 alignment buf (修散点) | data clean | 1.09 |
| Zynq scale-blit row inline SDIO drain | +6% | 1.38 |
| PC --fps 100 (unthrottle) | 上限 | 1.30 (same — PC throttle 不是瓶颈) |
| HLS v1.2 SLOT_CLEAR (byte store) | -25ms ARM, +18ms HLS, net +7ms | 1.07 (worse, HLS contention) |
| HLS v1.4 SLOT_CLEAR (64-bit widen) | -25ms ARM, +2.3ms HLS, net +23ms | 1.01 (no improvement) |
| ESP32 pass_buf 64KB | 少 sdio_tx 调用 | 0.51 (worse, alignment 累积时间阻塞 recv) |
| ENABLE_DUAL_CORE=1 | CPU1 fb_A 并行 | 失败 (DAP error, CPU1 hang in core1_asm_entry) |

## 真瓶颈分析

ESP32 RX 测出持续 ~100 KB/s, 远低于:
- WiFi link 5G HT40 实测 30 Mbps = 3750 KB/s
- Zynq main loop iter rate × 16KB SDIO chunk ≈ 286 KB/s

**ESP32 server task 单线程串行**:
```c
recv(client_fd, rx_buf, 32K)   // wait TCP segment
memcpy(pass_buf, rx_buf)         // alignment
sdio_tx_bytes(pass_buf, N×512)   // enqueue SDIO
// repeat
```

每 cycle 处理 N byte 耗时 = recv + memcpy + sdio_tx. 当 sdio_tx 等 ring 空 (Zynq drain), ESP32 不 recv → TCP window=0 → PC sendall 阻塞.

要破 100 KB/s, **必须 ESP32 拆 RX task + SDIO task**, lock-free FIFO 连接. RX task 一直 recv 满, SDIO task 一直 drain. 真 pipeline.

## v1.4 HLS clear 仍是数学胜利, 留作未来 baseline

HLS SLOT_CLEAR v1.2 → v1.4: 38161 cycles → 4771 cycles per slot (8x). 总 18ms → 2.3ms. 即使 net throughput 没变 (ESP32 bound), CPU 空出来等下次 architecture 改造时有用.

## ENABLE_DUAL_CORE=1 hazard

manual release CPU1 reset 后, JTAG DAP 错误 (ARM*#1 enum fail, status 0x30000021), 需要**物理 power-cycle** 才能 recover. core1_asm_entry MMU 初始化阶段 hang, CPU1 PC=N/A. 修需要 core1_boot.S debug, 几个小时 deep dive.

**Why:** 投资了不少时间在 throughput optimization, 但端到端 ceiling 在 ESP32 single-task. 接下来真要 30 fps 需要 ESP32 拆 task 大改造.

**How to apply:**
1. ESP32 SDIO TX ring 64KB + alignment pass_buf 8KB 是 sweet spot, 别动
2. HLS v1.4 BIT 已经 in hello_plat (4-bit @25 MHz 物理还是会散点, 用 1-bit @25 MHz)
3. ARM 端不再 memset ring (HLS 内部清, v1.4 commit 0302b4b)
4. ENABLE_DUAL_CORE 留 0, 不要随便启用 (CPU1 hang 整板)
5. demo 阶段 1-1.4 fps × 30K 或 5 fps × 5K 已经够看
