---
name: Zynq SDIO 给 ESP32-C5 slave 时钟必须用 divisor=0xFF (~98 kHz init)
description: divisor=64 (~390 kHz, SD spec init max 400 kHz) 在飞线/焊线下 CMD5 必 timeout, 用 0xFF 才稳
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
Zynq SD0 通过 MIO40-45 接 ESP32-C5 SDIO slave (CMD/D0 等飞线/焊线)。SDHCI v2 CLK_CTRL 寄存器 divisor 字段 (bits 15:8) 决定 init clock。

**坑**: 写 divisor=0x40 (64), 算出来 50 MHz/(2*64) = 390 kHz, 在 SD 协议规范 init 范围 (≤400 kHz) 内, **但飞线/焊线信号完整性下 CMD5 SEND_OP_COND 永远 timeout** (ERR_INTR bit 0 = CMD_TIMEOUT_ERR)。

**修法**: 写 divisor=0xFF (255), 算出来 ~98 kHz, 留 4× 余量, CMD5 第一次就响应。init 阶段慢一点没关系 (只跑一次), init 完后用 25 MHz 正常跑数据。

```c
/* sdio_esp.c */
u16 clk_ctrl = (0xFF << 8) | 0x0001;  /* divisor=255 + ICE=1, ~98 kHz */
XSdPs_WriteReg16(base, XSDPS_CLK_CTRL_OFFSET, clk_ctrl);
```

**判别症状**:
- `[sdio-esp] CMD5 err=0x1` → ERR_INTR=0x1 = CMD_TIMEOUT_ERR
- 多次重试 (20 次 + 100ms 间隔) 都 timeout
- ESP32 SDIO slave 那侧明明已经 start (boot log "SDIO slave started")
- 换 ESP32 上不同固件 (IDF example vs pov_bridge) 不影响

**Why:** 2026-05-12 zynq_pov SDIO bring-up 反复失败定位到此。memory 里之前 working session 没记下 divisor 值, 后续session用了"标准 spec 400 kHz" 配置就坏了。

**How to apply:** Zynq-7000 PS SDIO 接任何 SDIO slave 时, init clock 设到 SD spec 上限 (400 kHz) 在板载良好走线下 OK; 飞线 / 后焊接的 jumper 必须降到 ~100 kHz 留信号完整性余量。SDHCI controller 自己 negotiate 后, 高速模式 (25 MHz) 走起来仍然没问题, 是 init 这段对噪声敏感。
