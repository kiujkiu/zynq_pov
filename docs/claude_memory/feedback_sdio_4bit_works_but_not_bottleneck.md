---
name: SDIO 4-bit @ 25 MHz 可跑通但不是瓶颈
description: 2026-05-14 4-bit init OK + sustained, 但 throughput 跟 1-bit @ 25MHz 一样 160 KB/s — 真瓶颈在 ARM PPCL byte parser
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**2026-05-14 翻案 2026-05-11 "4-bit 飞线挂"**:

c35ff1a commit 当年 4-bit 失败 (CMD53 data fail, 5-11 飞线), 留指导 "shorter wires + 12.5 MHz". 这次 (board 现状 internal pull-up + 板可能 settle) 试**4-bit + 25 MHz 直接通**:

- sdio_bridge_active=1, last_sdio_init_rc=0
- HC1=0xC2 (bit1=4-bit), CLK_CTRL=0x0107 (DIV=1, 25 MHz)
- g_last_err_intr=0 持续, 无 CMD timeout
- 4-bit @ 12.5 MHz 也 OK (中间步骤验证)

## throughput 三档对比 (PC 30 fps × 30K pts × 16B 推, 测 ESP32→Zynq drain rate)

| 配置 | 物理上限 | 实测 | 利用率 |
|---|---|---|---|
| 1-bit @ 25 MHz | 3.1 MB/s | 191 KB/s | 6.1% |
| 4-bit @ 12.5 MHz | 6.25 MB/s | 180 KB/s | 2.9% |
| 4-bit @ 25 MHz | **12.5 MB/s** | **160 KB/s** | **1.3%** |

**三档 throughput 都几乎一样 ≈ 1.3-1.5 Mbps** → SDIO 物理层完全不是瓶颈.

## 真正瓶颈: ARM 端 PPCL byte parser

```c
// helloworld.c 主循环
static inline u8 uart_rx_byte(void) {    // 一次 1 byte
    if (sdio_bridge_active && sdio_rx_head != sdio_rx_tail)
        return sdio_rx_buf[sdio_rx_head++];
    ...
}
// PPCL parser 每帧 480 KB anime = 480K 次 function call
// 处理完旧 buf (head==tail) 才下次 sdio_rx_refill_nonblock
// → SDIO 大块 idle
```

ESP32 RX rate 显示 backpressure: peak 290 KB/s burst, 掉到 130 KB/s sustained = SDIO TX queue 满 → TCP recv 停 → PC sendall 阻塞.

## 提速路径 (实测后修正)

1. **PC `--compressed` 5B/pt** — anime 30K @ 30fps fps: 0.34 → 1.63 (4.8x); byte rate 还是 ~250 KB/s, frame 小所以 fps 大涨. 已 done (commit 605e327 后版本可直接 --compressed)
2. **PPCL parser RAW memcpy fastpath** (commit a246569) — raw 30K @ 30fps: byte rate 160→227 KB/s (+42%), fps 0.34→0.47. ARM byte parser 不再 CPU bound, 但 SDIO refill 速率才是真瓶颈
3. **SDIO_RX_CHUNK 16→64 KB** — 试过, throughput **减半** (一次 refill 阻塞 main-loop 过久, 挤掉 render time). 保留 16KB

## 真瓶颈 (memcpy 化后确认)

main loop iter rate × 16KB per iter = ~320 KB/s ceiling
- HLS fire + scale-blit + flush 一帧 ~50ms = 20 fps render
- 每 iter 调一次 sdio_rx_refill_nonblock 最多 16 KB
- 即使 ARM parse 0 cost, SDIO 也只能拿 20 × 16KB = 320 KB/s

要再提速需要并行化:
- HLS fire 期间 (ARM idle 等 ap_done) 同时 SDIO drain
- 或 CPU1 (dual-core) 专做 SDIO drain

**Why:** WiFi → ESP32 → SDIO → Zynq 整条链跑通, 但 throughput 卡在 1.5 Mbps. 不是 WiFi (实测 30 Mbps), 不是 SDIO (物理 12.5 MB/s). 是 ARM byte-level parser CPU bound.

**How to apply:**
1. SDIO 配置: `sdio_esp.c` 里 `SDIO_ESP_USE_4BIT=1` + `SDIO_ESP_CLK_DIV=0x01` (25 MHz). 已 commit
2. 4-bit 切 1-bit 退回方式: `SDIO_ESP_USE_4BIT 0`. 12.5 MHz 退回方式: `SDIO_ESP_CLK_DIV 0x02`
3. 提速软件改: PPCL parser memcpy 化 — 这是 next step, 现在没做
