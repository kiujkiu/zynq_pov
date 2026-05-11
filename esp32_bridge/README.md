# ESP32 WiFi → UART 桥

把 ESP32 当 PC 和 Zynq 之间的桥：PC 走 WiFi（TCP）发数据 → ESP32 解包 → 串口转发给 Zynq。

## 为什么需要

- 直接 UART 115200 baud = 11.5 KB/s，10K 点压缩流要 4 秒/帧
- WiFi 实测 2-5 MB/s，可流式 30 FPS 大模型
- ESP32 只 ¥10-20 一片
- Zynq PS ETH 调过有硬件层问题（gmii_to_rgmii TX frames 发不出去），用 ESP32 绕开

## 架构

```
[PC GUI / pov_gui.py]              [ESP32]                   [Zynq 板]
                                    
   ┌──────────────────┐    WiFi    ┌─────────┐    UART     ┌──────────┐
   │ pov_gui          │───────────→│ TCP rx  │───────────→ │ ARM RX   │
   │ pack_frame()     │  TCP:8888  │ + relay │ 921600 baud │ helloworld│
   │ socket.send(buf) │            │ to UART │             │           │
   └──────────────────┘            └─────────┘             └──────────┘
```

- PC 端：原 `pov_gui.py` 加 "Network mode" 选项，target IP = ESP32 IP
- ESP32 firmware：WiFi STA 连家用路由器 → mDNS 公布 `pov-bridge.local:8888` → 收到的字节直接 write 到串口
- Zynq 端：UART 配置改 921600 baud，**协议不变**

## 文件

- `firmware/main/pov_bridge.c` — ESP32-C5 主程序（ESP-IDF v5.4+, target esp32c5）
- `firmware/main/CMakeLists.txt` — 组件 register
- `firmware/CMakeLists.txt` — 顶层 IDF project
- `firmware/sdkconfig.defaults` — WiFi/lwIP/FreeRTOS 调优 (含 `CONFIG_IDF_TARGET=esp32c5`)
- `HOWTO.md` — Windows 装 IDF + 改 SSID + 烧 COM5 step-by-step
- `host/wifi_stream.py` (项目根 `host/`) — PC 端 TCP client

## 当前状态

🟡 **代码 ESP32-C5 就绪, 待用户烧录**（Phase 9-A, 2026-05-09）。firmware target 已切到 ESP32-C5 (RISC-V, 双频 WiFi 6, 需 ESP-IDF v5.4+)。详细烧录步骤见 `HOWTO.md`。

之前的 ESP32-WROOM-32 路线已 deprecated — 用户实际拿到的是 ESP32-C5。

🔴 **未烧录、未联调** — 等用户在 Windows 装 ESP-IDF v5.4 + 烧 COM5。

测试硬件清单：
- ESP32-C5-DevKitC-1（用户已购）
- USB-C 数据线
- 杜邦线 3 根（GND、TX→RX、RX→TX）

接线（Zynq UART0 是 PS 内置，连上 PC 的串口转 USB；ESP32 走另一组 UART）：

```
ESP32-C5 GND       ←→ Zynq GND
ESP32-C5 GPIO4 (TX) ←→ Zynq UART1 RX (PMOD JA1 pin 1 if exposed, or via UART1 EMIO)
ESP32-C5 GPIO5 (RX) ←→ Zynq UART1 TX
```

注意：**Zynq 板默认串口 UART0 已经接 USB**给 PC 调试用了，ESP32 桥需要走第二条 UART（UART1），需要在 BD 里启用 PS UART1 通过 EMIO 出来。或者直接接 PMOD 上的 UART (FTDI)。

ESP32-C5 没有"默认" UART1 pin map（GPIO matrix 全可路由），GPIO4/5 是 dev board 上没占用、没 strapping 冲突的安全选择。
