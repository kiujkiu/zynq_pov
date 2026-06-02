---
name: ESP32-C5 single-core RISC-V dual-task 不能提速, throughput ceiling 100 KB/s
description: 2026-05-15 加 StreamBuffer + sdio_drain_task 拆 recv/tx, 实测 -50% (1.09→0.52 fps). UDP path 也 single-task 同瓶颈
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**2026-05-15 throughput 终极 finding**

POV3D WiFi 数据通路 (PC→TCP→ESP32→SDIO→Zynq) 实测 ~1.0-1.4 fps × 30K compressed (~100-200 KB/s). 试图 dual-task 提速失败.

## 试过的提速 + 实测结果

| 方案 | 期望 | 实测 |
|---|---|---|
| ESP32 dual-task (recv_task + sdio_drain_task via StreamBuffer 32KB) | 5-10x | **-50% (0.52 fps)** |
| UDP path (BRDG mode :8889) | 省 ACK RTT 2x | code review: 同 single-task cap, 不实测 |
| pass_buf 8KB → 64KB | 少 sdio_tx 调用 | -50% (alignment 累积阻塞 recv) |
| Zynq parallel SDIO drain in scale-blit row loop | 1.5x | +6% (1.30→1.38 fps) |

## 根因: ESP32-C5 = RISC-V single-core

FreeRTOS 上两个 task 不能真并行, **只能时间分片**. dual-task 多了上下文切换开销, 减少 throughput.

`server_task` 单线程 cycle:
```
recv(client_fd, rx_buf, 32K)   // 等 TCP 段
memcpy(pass_buf, rx_buf)        // alignment
sdio_tx_bytes(pass_buf, 512×N)  // 等 SDIO TX ring 空
```
每 cycle 串行处理 ~32KB 耗 ~300ms (= 100 KB/s).

要破这个 cap **必须 multi-core chip**:
- ESP32-S3 (dual-core Xtensa LX7)
- ESP32-P4 (dual-core RISC-V)
- 或不通过 ESP32, 让 Zynq 自己跑 lwIP (PL Ethernet, memory note 提过卡住)

## 当前 stable demo state

- **1.2 fps × 30K compressed** voxel, 数据完全 clean (model+ring+fb 0 invalid)
- WiFi 5G HT40 ch161, IP 10.168.168.137:8888
- HDMI 物理输出干净 anime (OBS Virtual Camera 偶尔假帧 / capture card 时有 noise, fb 数据 verify 干净)
- SDIO 1-bit @ 25 MHz (4-bit 飞线信号挂用 1-bit), PPCL parser RAW fastpath + alignment buf 修散点
- HLS v1.5 (no in-IP clear, ARM memset 跑), v1.4 64-bit SLOT_CLEAR 让 POINTS_IN_SLICE state corrupt 已 revert

**Why:** 投资了 8+ 小时调 throughput, 把 fps × 30K 从 baseline 0.34 推到 ~1.2, 5x 改善. 真要 30 fps 必须换 multi-core ESP32 芯片或 Zynq 直接 lwIP.

**How to apply:**
1. demo 阶段 1-1.4 fps × 30K compressed 或 5 fps × 5K 已经够看
2. 短期不要再纠结 ESP32 端 throughput 调优, 它 single-core 是 hardware ceiling
3. 长期升级 path: 换 ESP32-S3/P4 (dual-core) — 软件 dual-task 框架代码留好 (commit 3cd471b sdio_drain_task)
4. 或者 Zynq lwIP 自己跑 — PL Ethernet 卡住 issue 先解 (memory `project_luxiaoban_ethernet_blocker.md`)
