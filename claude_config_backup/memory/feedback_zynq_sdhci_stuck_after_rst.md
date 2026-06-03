---
name: Zynq PS SDHCI 控制器反复 rst -system 会卡死, 必须物理 power-cycle
description: xsdb rst -system 多次后 SD0 SDHCI 进入死锁, CMD5 永远 timeout 直到拔电重插
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
Zynq-7000 PS SD0 控制器 (Arasan SDHCI v2.x) 接 ESP32-C5 SDIO slave 飞线/焊线场景下, 软件层 `xsdb rst -system` (= POR reset 信号到 PS 系统) **反复触发后, SDHCI 控制器会进入死状态**, CMD5 永远 ERR_INTR=0x1 (CMD_TIMEOUT_ERR), 即使 ESP32 那边明明是新固件刚 boot 完, slave 也正常 start。

软件 SDHCI SW reset (写 XSDPS_SW_RST_OFFSET=0x07) 救不回来 — 寄存器 reset 完看起来回到默认值, 但 CMD line 已经不工作。

**唯一办法: 物理拔电再插电 Zynq 板**。USB-JTAG 线可不动, 但 power 那条 USB 拔一下再插, 整个 PS+PL 走真正的 POR。

**症状判别**:
- xsdb `rst -system` 之前 SDIO 工作 (CMD5 OK)
- 几次 reload ELF (每次都做 rst -system) 之后, CMD5 突然全 timeout
- 即使 firmware 不变, 物理硬件也没动, 也救不回来
- 偶尔还会让 xsdb 找不到 APU target (`available targets: none`)

**绕开方案**:
- ELF 重载时改用 `rst -processor` (只重置 ARM 不动 PS SDIO), 避开 SDHCI 状态被破坏
- 但首次 boot 一定要 `rst -system + ps7_init + dow ELF` (cold start)
- 见 `tools/dl_helloworld_proc.tcl`

**Why:** 2026-05-12 zynq_pov SDIO 调试: 一开始 divisor=0xFF 后第一次 CMD5 OK, 之后改 firmware/sdkconfig 反复 reload 6-7 次, CMD5 全失败。再 power-cycle Zynq 一次又通了, 然后又一次 rst -system 又坏。最后烧 IDF example 当 control 也失败 → 排除是 firmware 问题 → 定位 Zynq SDHCI 状态卡死。

**How to apply:** 任何 Zynq PS SDIO bring-up debug, 频繁 reload ELF 时优先用 `rst -processor`。如果 SDIO 突然全部 CMD5 timeout 而之前在跑, 先 power-cycle Zynq 再说, 不要怀疑硬件/wire 焊接。
