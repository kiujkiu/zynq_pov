---
name: USE_PL=1 boot 模式 anime UART receive 不可靠
description: USE_PL=1 时 boot main loop (model_n<1000) 跑 60 FPS, anime 大量 (154 KB) UART 接收 ~50% 概率 stuck 在 ~20K/30803 points, 即使加 50× / 10000× polls per iter 也不稳.
type: feedback
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
USE_PL=1 时 main loop boot 阶段 (model_n<1000, PL/blit skip) 跑 60 FPS = 16.67 ms/帧. ARM 在 main loop 顶部 + vsync wait 内 都 poll uart_poll_frame, 但 anime 30K points (154 KB) 接收时大概率 stuck 在 20K-22K 范围, 不再 progress.

**Why:** 不是 polling 频率不够 (ARM 处理能力 750 KB/s 远超 anime 144 KB/s 流量). 真因可能是:
1. PS HP1 互联和 PS UART RX 之间存在 timing race
2. USB-UART converter buffer (16 KB) 在 specific byte 处异常 drop
3. ARM cache + RX FIFO 协调时 specific cache line eviction 让 byte 丢失

**对比:** USE_PL=0 时 main loop 30 FPS (cpu_render_voxel_panel ~30 ms 每帧, 内有 280+ polls per frame), anime UART receive 100% reliable.

**How to apply:** USE_PL=1 是不 reliable 的 anime 接收路径. 推荐:
1. **回 USE_PL=0** 用 ARM render (验证完美, 60 FPS, 颜色正确) — 当前 baseline
2. 或者实现 **hybrid mode**: boot 时 ARM render (UART receive 可靠), 收到 anime 后切到 USE_PL=1 PL render. 需要 runtime mode switch 代码

**附 Cache 关键发现:** USE_PL=1 模式下 `Xil_DCacheFlushRange(addr, size)` 不彻底, 必须用 `Xil_DCacheFlush()` 全 flush 才能让 fb 数据真到 DDR / VDMA 看见. Range 版只 flush 部分 cache lines.
