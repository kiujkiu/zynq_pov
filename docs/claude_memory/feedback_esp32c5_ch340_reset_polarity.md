---
name: ESP32-C5 (这台机) CH340 reset 极性非 esptool 默认
description: COM5 上 ESP32-C5 normal run 要 rts=True dtr=False→True (释放), 普通 setRTS(True);setRTS(False) 进不去 → 全 0 byte 误判芯片没跑
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**2026-05-14**: pov_bridge_sdio flash 后 `python -m serial.tools.miniterm COM5 115200` 一直 0 byte, 之前几个 watch 脚本 (`esp32_watch5.py`, `esp32_watch_long.py`) 用 `setRTS(True); setRTS(False)` 单 RTS toggle 也都 0 byte, 让人以为 firmware 卡死.

**根因**: 这台机 ESP32-C5 DevKitC 板上 CH340 → EN/IO0 接法不是 esptool 默认极性. 单纯 RTS toggle 不能让 chip 离开 download mode. 必须三步:
```python
s.rts = False; s.dtr = True   # clear (EN released, IO0 high)
s.rts = True;  s.dtr = False  # apply: IO0 high, EN low (reset)
s.dtr = True                  # release EN → boots into NORMAL (IO0 已 high)
```

实测 4 个极性组合中只有 `rts=True dtr=False → dtr=True` 这一个 work, 抓到完整 boot log (3.8 KB / 3 秒).

**Why:** ESP32-C5 DevKitC 内置 USB-Serial-JTAG **本机没枚举** (PnP 列表只有 2 个 CH340, VID_1A86&PID_7523), 全部 console + flash 都走 CH340 UART0. 这块 CH340 跟标准 esptool/USB-Serial-JTAG 板的 RTS/DTR 接 EN/IO0 极性不同 (具体连法看不到 schematic).

**How to apply:**
1. 任何脚本 reset ESP32-C5 走 COM5: 用上面三步序列, **不要**用 `setRTS(True); time.sleep(0.1); setRTS(False)`
2. `idf.py monitor` 需要 TTY, WSL/bash redirect 下用不了 — 直接 pyserial 读 + esptool reset
3. 看是不是 COM5 还是其他端口: PowerShell `Get-WmiObject Win32_PnPEntity | Where Name -like *COM*` 找 VID_1A86&PID_7523 的那个
4. ESP32-C5 上跑的 4-bit SDIO 占 GPIO 12/13 = USB-D+/D-, application 启动后 USB-Serial-JTAG 自动失效, 这台机已经看不到 ESP32 内置 USB 设备

**这是 board-specific 经验**, 不是 ESP32-C5 通病; 换 DevKitC v1.2 / 自制板可能极性又变.
