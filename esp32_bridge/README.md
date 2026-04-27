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

- `firmware/main/pov_bridge.c` — ESP32 主程序（ESP-IDF）
- `firmware/main/CMakeLists.txt`
- `firmware/sdkconfig.defaults` — 默认配置
- `firmware/README.md` — 编译/烧录指南
- `host/network_proto.py` — PC 端 TCP client（pov_gui 集成用）

## 当前状态

🔴 **暂停 — 等 WiFi 硬件就位再做**（2026-04-27 用户决定）。`firmware/main/pov_bridge.c` 已含 WiFi STA + TCP:8888 → UART1 921600 转发完整逻辑,**未烧录、未联调**。

恢复时序:买到 ESP32-WROOM-32 → ESP-IDF v5.x → `idf.py menuconfig` 填 SSID/密码 → `idf.py flash monitor` → host pov_gui.py 加 Network mode 选项,target = `pov-bridge.local:8888` → 联调。

🟡 **代码完成但未烧录测试**（没有实体 ESP32）。代码可即买即用。

测试硬件清单：
- ESP32-WROOM-32（最便宜，约 ¥15）
- Micro-USB 数据线
- 杜邦线 3 根（GND、TX→RX、RX→TX）

接线（Zynq UART0 是 PS 内置，连上 PC 的串口转 USB；ESP32 走另一组 UART）：

```
ESP32 GND  ←→ Zynq GND
ESP32 GPIO17 (TX) ←→ Zynq RX (PMOD JA1 pin 1 if exposed, or via UART1 EMIO)
ESP32 GPIO16 (RX) ←→ Zynq TX
```

注意：**Zynq 板默认串口 UART0 已经接 USB**给 PC 调试用了，ESP32 桥需要走第二条 UART（UART1），需要在 BD 里启用 PS UART1 通过 EMIO 出来。或者直接接 PMOD 上的 UART (FTDI)。
