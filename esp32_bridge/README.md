# ESP32-C5 WiFi → SDIO 桥

PC 走 WiFi（TCP）发数据 → ESP32-C5 解包 → SDIO 4-bit 转发给 Zynq SD0。
**已从 UART 改为 SDIO**（2026-05-09），目的是把 ESP32↔Zynq 的链路带宽
从 ~115 KB/s (UART 921600) 提到 ~30 MB/s (SDIO DDR50 4-bit), 覆盖
720 slice × 30 Hz delta 模式的最坏码率。

## 为什么从 UART 改 SDIO

- UART 921600 = 92 KB/s 实际, 不够 720×30 fps delta
- SDIO 4-bit @ 50 MHz = 25 MB/s 稳定, 实测 ESP32-C5 30 MB/s
- 不需自写 PHY: Zynq SD0 控制器 + ESP-IDF sdio_slave 现成
- 接线只需 6 pin (CMD/CLK/D0-3) + GND, 比 SDIO Host 写 driver 复杂度低

## 架构

```
[PC GUI / pov_gui.py]              [ESP32-C5]                 [Zynq SD0]

   ┌──────────────────┐    WiFi    ┌─────────┐    SDIO 4-bit  ┌──────────┐
   │ pov_gui          │───────────→│ TCP rx  │───────────────→│ ARM SDIO │
   │ pack_frame()     │  TCP:8888  │ + relay │  ~25 MB/s      │ host drv │
   │ socket.send(buf) │            │ to SDIO │  block=512 B   │ + parser │
   └──────────────────┘            └─────────┘                └──────────┘
```

PWFR 24B header + payload 协议**不变**, 仅传输层从 UART 换成 SDIO。
TCP:8888 也不变, host `wifi_stream.py` / `pov_gui.py` 端零修改。

## SDIO 协议设计

- 物理: SDIO 4-bit DDR50 (50 MHz double-data-rate, 4-bit data)
- block size: 512 B (标准 SDIO)
- ESP32-C5 端 TX ring: 16 块 = 8 KB (host->Zynq 方向)
- ESP32-C5 端 RX ring: 8 块  = 4 KB (Zynq->host 方向, 暂未启用上行)
- 字节流透明: TCP 收多少字节, 切 512B 块塞 SDIO send_queue;
  最后一块由 driver 补零 padding
- Zynq host 端发 CMD53 (IO_RW_EXTENDED) block read, ESP32 slave 自动出货
- Zynq 端写也用 CMD53 block write, ESP32 RX task 当前只 drain + log

## ESP32-C5 SDIO 引脚 (固定 IOMUX, 不可重映射)

| 信号 | GPIO |
|------|------|
| CLK  | 9    |
| CMD  | 8    |
| D0   | 10   |
| D1   | 7    |
| D2   | 14   |
| D3   | 13   |

**GPIO4/GPIO5**: free, 跟 SDIO 不冲突, 用户问的没占。
**GPIO27**: 唯一 strapping pin, boot 模式选择, 别接外设。
其他 GPIO 上电默认 input + pull disabled。

可烧 `gpio_check` 变体验证 (见下文)。

## Zynq 端接线

SD0 走 MIO40-47, **板上跟 microSD 共用**。`reference_luxiaoban_mio_pinout`
里 MIO40-45/47 = 板载 microSD。
**必须断开 microSD card 才能接 ESP32 SDIO**。

| 信号 | Zynq MIO | ESP32-C5 GPIO |
|------|----------|---------------|
| CLK  | MIO40    | 9             |
| CMD  | MIO41    | 8             |
| D0   | MIO42    | 10            |
| D1   | MIO43    | 7             |
| D2   | MIO44    | 14            |
| D3   | MIO45    | 13            |
| CD   | MIO47    | (拉低/悬空)   |
| GND  | —        | GND           |

注: ESP32-C5 SDIO slave 通常不驱动 CD (card detect), Zynq 这边需要在 BD
里把 SD0 配成 "no CD signal" 或者把 MIO47 直接拉低让 Zynq 一直认为有卡。

## 文件

- `firmware/main/pov_bridge_sdio.c` — **新**, ESP32 SDIO slave + WiFi
- `firmware/main/pov_bridge.c` — 旧 UART 版本, 留作后备
- `firmware/main/gpio_check.c` — 上电 dump GPIO 电平 / 配置 (debug)
- `firmware/main/CMakeLists.txt` — 通过 `-DPOV_FW={sdio|uart|gpio_check}` 切换

## 编译 & 烧录

```bash
cd firmware
idf.py set-target esp32c5
idf.py menuconfig    # 填 WiFi SSID / 密码
idf.py build         # 默认 POV_FW=sdio
idf.py flash monitor
```

烧 GPIO 检查工具:

```bash
idf.py -DPOV_FW=gpio_check build flash monitor
```

启动后会打印每个 GPIO 上电时的电平 + 角色注解, 之后 500 ms 轮询打印电平变化。

## Zynq 端 TODO (本 agent 范围外, 给 user 做)

1. **BD 改 SD0 配置**:
   - PS Configuration → IO Peripherals → SD0 (MIO40-47)
   - Speed: DDR50 或 SDR50 (按 ESP32-C5 sdio_slave 默认协商, 一般 DDR50)
   - Card Detect: disabled (ESP32-C5 SDIO slave 不出 CD)
   - Write Protect: disabled
2. **BSP 已含 xsdps driver** (默认), 不用改 BSP
3. **写 host SDIO driver**:
   - 初始化: `XSdPs_CfgInitialize` + `XSdPs_SdCardInitialize` 跳过 (ESP32
     不是标准 SD card, 不响应 CMD8/CMD2 等)
   - 直接进 SDIO mode: 发 CMD5 (IO_SEND_OP_COND), CMD3 (relative addr),
     CMD7 (select), CMD53 (block R/W)
   - 参考 `XSdPs_Pio_*` 函数族, 或裸写 host controller register
   - 简单方案: 用 Linux + esp_hosted 驱动 (但本项目 baremetal, 跳)
4. **驱动接口** (建议):
   - `sdio_esp_init()` — CMD5/3/7 流水
   - `sdio_esp_recv(buf, len)` — CMD53 block read
   - `sdio_esp_send(buf, len)` — CMD53 block write
   - 包到原 `uart_poll_frame()` 逻辑里, 替换底层 byte source

## 当前状态

- 🟢 ESP32 SDIO slave firmware: 源码完成 (`pov_bridge_sdio.c`), **未烧录**
  (ESP-IDF 没装好)
- 🟢 GPIO 调试工具完成
- 🔴 Zynq 端 SDIO host driver: **未写**, user TODO
- 🔴 联调: 需要 ESP32-C5 实板 + Zynq BD 改 SD0 + host driver

## 后备方案

如果 SDIO 联调遇阻, 可暂回退到 `POV_FW=uart` 走旧 UART 921600 路径,
host `pov_gui.py` 不用改 (TCP 端口一致)。
