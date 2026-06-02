---
name: ESP32-C5 WiFi 桥已通 (5G HT40 ch161)
description: 2026-05-14 sdkconfig 密码修对后 pov_bridge_sdio 5G HT40 attach + DHCP + TCP :8888 listening, Windows TcpTestSucceeded=True
type: project
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**2026-05-14 闭环验证**

- Board: ESP32-C5 DevKitC on **COM5 (CH340 USB-UART, VID_1A86&PID_7523)**, USB-Serial-JTAG **没枚举** (PnP 不见 esp32 内置 USB)
- sdkconfig 改对密码 (`"undef"` → `"undefoffice1010"`) 后, build + flash 秒连:
  - 5G band, ch=161, phy_11n=1, rssi -40, HT40 11n only mode
  - DHCP OK → IP **10.168.168.137**, mask /23, gw 10.168.168.168
  - TCP listening :8888, mDNS pov-bridge.local
  - Disconnect reason 计数 = 0
- Windows host (10.168.168.119) `Test-NetConnection 10.168.168.137 -Port 8888`: **TcpTestSucceeded=True**

**Why:** 把 WiFi 路径从 "假装死了" 还原回可用, anime stream / 控制信号都能走 TCP, 不用再走 UART COM4 921600 (1-5K 点) 或 xsdb JTAG (静态).

**How to apply:**
1. Push anime/控制数据用 `socket.connect(("10.168.168.137", 8888))` 即可
2. mDNS 可用: `pov-bridge.local:8888` (替代写死 IP)
3. ESP32 → Zynq 这一段走 SDIO slave (memory `project_esp32c5_sdio_slave.md`), 在 ESP32 firmware `pov_bridge_sdio.c` 里把 TCP recv buffer 转发到 SDIO slave TX queue
4. IP 是 DHCP 动态的, AP 重启可能换 — 真要稳定可在 ESP32 静态 IP 或用 mDNS
