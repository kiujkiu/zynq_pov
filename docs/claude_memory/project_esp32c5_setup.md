---
name: ESP32-C5 DevKitC bring-up state
description: Hardware + IDF v6.0 install paths + COM port for ESP32-C5 DevKitC board
type: project
originSessionId: 8002516f-20d0-4b20-8757-a51821fbfd7d
---
ESP32-C5 DevKitC-1 模组在 COM6 上调通，IDF v6.0 已装好。

**硬件**
- ESP32-C5 DevKitC-1，**chip revision v1.0**（SDIO slave 需要 ≥ v1.0，OK）
- Wi-Fi 6 双频 + BT 5 LE + 802.15.4，单核 RISC-V @ 240 MHz + LP core，48 MHz 晶振
- MAC `d0:cf:13:e3:a8:d0`
- 板上两个 USB-C 口：`UART`（CH340 桥 → COM6）和 `USB`（内置 USB-JTAG）
- **默认走 COM6 (UART 口) 烧录 + monitor**，因为 4-bit SDIO slave 时 USB-JTAG 引脚会被占（GPIO13/14）

**ESP-IDF v6.0 路径**
- 源码：`D:\esp-idf`（git clone release/v6.0，commit `de7baafb`）
- toolchain / Python env：`C:\Users\kiujkiu\.espressif`（含 riscv32-esp-elf 16.3，python_env 3.12）
- export 脚本：`D:\esp-idf\export.bat`（cmd）/ `export.ps1`（PowerShell）

**调用方式**（从 WSL 通过 cmd.exe）
```
cmd.exe /c "cd /d D:\esp-idf && call export.bat && cd examples\<path> && idf.py ..."
```

**Why:** 第一次给这台机子装 ESP32 工具链，记录路径避免下次再到处找。

**How to apply:** 后续 C5 相关工作直接用上面的路径；如果换 esptool/idf.py 入口先 source `export.bat`。
