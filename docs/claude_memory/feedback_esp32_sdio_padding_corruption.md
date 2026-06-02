---
name: ESP32 SDIO slave 自动 0-padding 非 512B 写 → byte stream 错位
description: 2026-05-14 pov_bridge_sdio passthrough mode 漏了 alignment buf, 让 SDIO 中间插 0 padding, Zynq PPCL parser 5B/16B 边界全错, model[] 16.5% voxel 离 anime range
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**2026-05-14 找到散点根因**

PC → ESP32 PPCL stream 长度不固定 (frame size 150016 / 480016 byte 不是 512 倍数),
ESP32 端 `pov_bridge_sdio.c::server_task()` 之前 passthrough mode:
```c
sdio_tx_bytes(p, (size_t)rem);  // rem 任意 byte 数, 比如 32KB recv 后 32000B
```
**ESP32 SDIO slave 内部把不足 512B 的写 padding 到 512B** (comment line 331 说 DFLT mode 早就这么处理, passthrough 漏了). 比如 sdio_tx 1024B → slave 实际推 1024B; 但 sdio_tx 1023B → 推 1024B (1 byte 0).

Zynq PPCL parser 一字节一字节读, 看到这些 0 padding **混在 5B point payload 里**, 后续 voxel 边界全错位.

实测: dump model[0..29999] via xsdb:
- 修复前: x ∈ [-128, 127], y ∈ [-128, 127], z ∈ [-128, 127], **16.5% voxel 离 anime range [-40, +39]**
- 修复后: x ∈ [-125, 123], y ∈ [-38, 40], z ∈ [-36, 53], **0.1% invalid**

HDMI 上表现: anime 主体 + 大量随机彩色 voxel 散布 (随机坐标 + RGB565 解码错). 跟"4-bit SDIO 飞线 bit-flip" 完全不像 (其实根本不是 SDIO 物理问题, 是 protocol/alignment).

**修复** (commit 2529e2c):
```c
static uint8_t pass_buf[8192];
static size_t  pass_pos = 0;
// 累积 rem byte 到 pass_buf, 满 512 倍数才 sdio_tx_bytes
// 不足 512B 留到下次 recv 拼
```
跟 DFLT mode 的 `dflt_flush_buf` 一样处理.

**Why:** 之前误以为 4-bit SDIO 25 MHz 飞线 bit-flip, 退回 1-bit 也散点 (因为根因是 SDIO byte alignment 不是物理层). 浪费了 1-bit/4-bit/12.5MHz/25MHz 几个组合时间.

**How to apply:**
1. ESP32 SDIO slave bridge 任何 mode (passthrough/DFLT/SINK 之外) 都必须累积到 SDIO_BLOCK_SIZE 倍数才 tx
2. 看到 HDMI 散点 / model[] data out-of-range, **先看 ESP32 端 alignment**, 然后才是物理层
3. Cross-frame boundary 不连续: PC frame N 尾巴 32B 留 alignment buf, frame N+1 前 480B 拼 = 512B 块 sdio_tx — wire 上 byte 连续, parser 解析正常
