# ESP32-C5 烧录 step-by-step

目标: 把 ESP32-C5 烧成 WiFi-UART 桥, COM5 (USB-Serial-JTAG) 烧录, 跑起来后做路由器 ↔ Zynq 之间的中继。

## 1. 装 ESP-IDF v5.4 (Windows)

- 下载 ESP-IDF Tools Installer v5.4 (Espressif 官网 dl.espressif.com, 选 5.4+ Windows online installer)。
- 默认装到 `C:\Espressif\frameworks\esp-idf-v5.4`, 工具链装到 `C:\Espressif\tools\`。
- 安装完后开 **"ESP-IDF 5.4 PowerShell"** 或 **"ESP-IDF 5.4 CMD"** 快捷方式 — 该 shell 已 `export.bat` 设好 `IDF_PATH` 和 `PATH`。
- ESP32-C5 在 v5.4 才稳定支持, **不要用 v5.2/v5.3**。

## 2. 改 SSID/密码

打开 `esp32_bridge/firmware/main/pov_bridge.c`, 改两行 (~第 41-42 行):

```c
#define POV_WIFI_SSID  "YOUR_SSID_HERE"   // 改成你家路由器 SSID
#define POV_WIFI_PASS  "YOUR_PASSWORD_HERE" // 改成密码
```

ESP32-C5 支持双频, 2.4 GHz / 5 GHz 都行。WPA2-PSK 假设, 若是 WPA3 需要改 `threshold.authmode` 为 `WIFI_AUTH_WPA3_PSK`。

## 3. (可选) 改 UART pin

默认 `UART_TX_PIN=GPIO4`, `UART_RX_PIN=GPIO5`。如果板子上这两 pin 被占, 改 `pov_bridge.c` 里的 `UART_TX_PIN`/`UART_RX_PIN`。

避开:
- **GPIO11, GPIO12** — USB-Serial-JTAG (烧录/console)
- **GPIO2, GPIO7, GPIO8, GPIO9, GPIO15, GPIO27, GPIO28** — strapping pins
- **GPIO24-26** — SPI flash

## 4. 编译

在 ESP-IDF shell 里 `cd` 到 `esp32_bridge/firmware/`:

```cmd
cd D:\claude_workspace\pov3d\zynq_pov\esp32_bridge\firmware
idf.py set-target esp32c5
idf.py build
```

第一次 `set-target` 会扫 `sdkconfig.defaults` 写到 `sdkconfig`。后续改 `pov_bridge.c` 直接 `idf.py build`。

## 5. 烧录

ESP32-C5 接 PC, Windows 应该识别成 COM5 (USB-Serial-JTAG 自带 driver):

```cmd
idf.py -p COM5 flash
```

烧录后:

```cmd
idf.py -p COM5 monitor
```

看输出:
```
I (1234) pov_bridge: WiFi STA started, connecting to 'YOUR_SSID'
I (4567) pov_bridge: Got IP: 192.168.1.42        <-- 记下这个 IP
I (4570) pov_bridge: mDNS: pov-bridge.local:8888
I (4580) pov_bridge: TCP listening on :8888
```

退出 monitor: `Ctrl-]`。

## 6. 接线 ESP32-C5 ↔ Zynq

```
ESP32-C5 GND   ↔ Zynq GND
ESP32-C5 GPIO4 (TX) ↔ Zynq UART1 RX (EMIO 出来的 PL pin, 或 PMOD UART)
ESP32-C5 GPIO5 (RX) ↔ Zynq UART1 TX
```

Zynq 端 UART1 配 921600 baud, 8N1, 无流控。

## 7. 测试 host 端

PC 端:

```bash
python host/wifi_stream.py --target pov-bridge.local:8888 model.glb
```

或者用 ESP32 monitor 报的 IP 直连: `192.168.1.42:8888`。

## TODO / 用户需要做

- [ ] 装 ESP-IDF v5.4 (Windows installer)
- [ ] 改 `pov_bridge.c` 里 `POV_WIFI_SSID` / `POV_WIFI_PASS`
- [ ] 确认路由器是 WPA2 (若 WPA3 改 `threshold.authmode`)
- [ ] 若 GPIO4/5 被占, 改 `UART_TX_PIN`/`UART_RX_PIN`
- [ ] Zynq BD 开 PS UART1 EMIO 或确认 PMOD UART 走向
- [ ] Zynq baud 改 921600

## 排错

- **找不到 COM5**: 装 Espressif USB-Serial-JTAG driver, 或检查 Device Manager 看实际 COM 号。
- **WiFi 连不上**: monitor 看是不是 disconnect retry 循环, 检查 SSID/密码/频段 (路由器可能只开 2.4 GHz 而 SSID 在 5 GHz)。
- **TCP 连上但收不到数据**: 检查 host 端 IP 是否正确, 防火墙是否放行 8888 出口。
- **UART 输出乱码**: Zynq 端 baud 不匹配, 必须 921600 8N1。
