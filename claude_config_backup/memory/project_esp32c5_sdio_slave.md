---
name: ESP32-C5 SDIO slave 实测可用 (IDF v6.0)
description: C5 chip rev v1.0 + IDF v6.0 SDIO slave example 验证通过，固定引脚 + USB-JTAG 冲突
type: project
originSessionId: 8002516f-20d0-4b20-8757-a51821fbfd7d
---
ESP32-C5 在 IDF v6.0 下 SDIO slave 完整通路已验证：clone → set-target → build → flash → boot 显示 `slave ready`。

**硬件要求**
- Chip revision ≥ **v1.0**（v0.0 / v0.1 SDIO slave 硬件不支持，datasheet 明说）

**引脚 IOMUX 固定，不能改**（`components/esp_hal_sd/esp32c5/include/soc/sdio_slave_pins.h`）

| 信号 | GPIO |
|------|------|
| CLK  | 9    |
| CMD  | 10   |
| D0   | 8    |
| D1   | 7    |
| D2   | 14   |
| D3   | 13   |

**关键坑：D2/D3 (GPIO14/13) = 内置 USB-JTAG 的 D+/D-**
- **4-bit 模式 → USB-JTAG 失效**，烧录/调试只能走 UART0 (GPIO11/12)
- 1-bit 或 SPI 模式可以和 USB-JTAG 共存
- 板上的 DevKitC 有 CH340 UART 桥（COM6），4-bit 测试就用这条线

**Example 路径**：`D:\esp-idf\examples\peripherals\sdio\slave`（IDF 自带，C5 在 `Supported Targets` 表里）

**测真实数据传输还需要 SDIO host 端**（另一片 ESP32/S3/P4 跑 sdio host example，或 Linux SBC 带 SDIO 接口；普通 SD 读卡器不行，要私有协议）

**Why:** 原始问题是"C5 在 IDF v6 下 SDIO slave 是否支持"，已用实物 + 烧录验证。

**How to apply:** 后续如果做 host-slave 通信、esp-hosted 集成、QSPI slave 备选时引用这条；4-bit 配置必须切到 UART 烧录线。
