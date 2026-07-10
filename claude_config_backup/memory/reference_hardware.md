---
name: Hardware setup and Windows toolchain paths
description: COM port, JTAG, HDMI capture device, and Windows-side Vivado/Vitis tool paths used to drive builds from WSL
type: reference
originSessionId: a079e7ff-01aa-4018-abc1-014cf07015a0
---
**Board/host connection**:
- USB-Serial CH340 = ARM UART, COM port may drift across reboots (was COM7, became COM9 — GUI auto-detects)
- JTAG cable = **Digilent JTAG-SMT2 module** (淘宝"7020 配套下载器"内部集成的 OEM module, SN 210251A08870, FT2232H 内核, EEPROM 配 D2XX-only). Windows enum 成 `USB Serial Converter VID_0403/PID_6014`, 无 VCP COM child. `xsdb` 看到 `digilent-ftdi cables 1 / Digilent JTAG-SMT2`. 卡住时 fix = `taskkill /F /IM hw_server.exe` + 板子冷循环 (拔 USB + 断电 + 等 10s + 重插)
- HDMI capture: USB3 device "C1-1 USB3 Video" (VID 345F:2130). OpenCV DSHOW/MSMF cannot see it — use ffmpeg dshow input via `tools/capture_ffmpeg.py` (imageio bundles ffmpeg). Output goes to `hdmi_ff.jpg`.

**Windows toolchain (called from WSL via `powershell.exe`)**:
- Vivado 2024.2: `D:\Vivado\2024.2\bin\vivado.bat`
- Vitis 2024.2: `D:\Vitis\2024.2\bin\vitis.bat`
- Vitis HLS: `D:\Vitis_HLS\2024.2\bin\vitis_hls.bat`（注意是独立目录，不在 `D:\Vitis\bin\` 下）
- xsdb: `D:\Vitis\2024.2\bin\xsdb.bat`
- bootgen: `D:\Vitis\2024.2\bin\bootgen.bat`；program_flash: `D:\Vitis\2024.2\bin\program_flash.bat`

**本机（2026-05-06 起）实际安装位置 = `C:\Xilinx\{Vivado,Vitis,Vitis_HLS}\2024.2`**。已建符号链接：
- `D:\Vivado` → `C:\Xilinx\Vivado`
- `D:\Vitis` → `C:\Xilinx\Vitis`
- `D:\Vitis_HLS` → `C:\Xilinx\Vitis_HLS`

所以仓库里所有硬编码 `D:\Vivado\...` / `D:\Vitis\...` 路径都正常工作，不用改脚本。`run_hls.tcl` 注释里写的 `D:\Vitis\2024.2\bin\vitis_hls.bat` 路径错误（HLS 在独立 Vitis_HLS 目录），实际调用要走 `D:\Vitis_HLS\2024.2\bin\vitis_hls.bat`。

**Vivado/Vitis gotchas**:
- Vitis workspace lock: multiple Vitis instances conflict — run `taskkill /F /IM java.exe` before rebuild
- TCL `puts "[xxx]"` gets command-substituted; use `puts "XXX:"` instead
- Don't change `axi_smc` `NUM_CLKS` — breaks video path

**Don't touch physical wiring** during autonomous runs (per user's autonomous-run rules in AUTONOMOUS_RUN_2026-04-25_to_27.md).
