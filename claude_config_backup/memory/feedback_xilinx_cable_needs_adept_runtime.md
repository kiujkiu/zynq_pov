---
name: xsdb jtag targets 空 = 先 taskkill hw_server, 不是 driver 版本问题
description: Adept 2.8.5 (2018) + Vivado 2024.2 + Digilent JTAG-SMT2 cable 历史上一直能用, 周末回来突然死是 hw_server 进程状态错乱, kill 后重启 + 冷循环就好
type: feedback
created_at: 2026-06-08 17:15 CST
updated_at: 2026-06-08 17:55 CST
originSessionId: pov3d-dual-panel-v34e-recovery
---
**症状**: xsdb `connect; jtag targets; targets` 返回**全空**. hw_server 启动正常 (TCP:127.0.0.1:3121), USB Serial Converter VID_0403/PID_6014 status=OK. 周末关机后第一次开机, 之前一直能用.

**真根因 (2026-06-08 实测确认)**: **旧 hw_server 进程状态卡死 / cable handle 没释放**. 杀掉之前所有 hw_server 进程后, xsdb 启动新 hw_server 立刻就能 enum 出 cable.

```
--- jtag servers ---
  digilent-ftdi cables 1
  ...
--- jtag targets ---
  1  Digilent JTAG-SMT2 210251A08870
     2  arm_dap (idcode 4ba00477 irlen 4)
     3  xc7z020 (idcode 23727093 irlen 6 fpga)
```

**Fix (按顺序试)**:
1. `cmd.exe /c "taskkill /F /IM hw_server.exe"` 然后重跑 xsdb (最快, 一般直接好)
2. 板子断电 + 拔 USB + 等 10s + 重新插 USB + 板上电 (cold cycle, 之前 hw_server 把 cable handle 占着不释放时需要)
3. 重启 PC (终极手段, 极少需要)

**走过的弯路 (这次踩坑流程)**:
1. 第一反应"FT232H 没装 Xilinx driver" → 跑 `install_drivers_wrapper.bat` (没用, 那个只装 Platform Cable USB II 不管 Digilent)
2. 然后看 System32 里 dmgr.dll 2.8.5 (2018) → **误判**为 "Adept Runtime 太老 ABI 不兼容". 但 memory 5/13 anime xsdb path 跑通时也是这版本, 说明版本完全 OK.
3. 让用户冷循环板子 + 杀 hw_server 后通了.

**Cable identity**: 下载器内部是 **Digilent JTAG-SMT2 module** (SN 210251A08870, Surface Mount Module Type 2, FT2232H based). 不是 HS3 也不是 Platform Cable USB II 克隆. JTAG-SMT2 是 Digilent 卖给板厂的 OEM module, 经常被淘宝"配套下载器"集成. 但 Windows 端只看到 generic `USB Serial Converter (FTDIBUS)` 因为 EEPROM 配 D2XX-only mode (没 VCP COM child).

**易混淆点**:
- 用户自称"不是 FT232 下载" — 是误解, JTAG-SMT2 内部就是 FT2232H 芯片 (VID/PID 是 FTDI 通用 0403/6014).
- `C:\Program Files (x86)\Digilent\` 下只有 USB Driver subset. 完整 Adept Runtime CLI (`djtgcfg.exe` 等) 没装但**不影响 hw_server** — hw_server 直接调 System32 的 dmgr/djtg DLL.
- 版本: dmgr 2.8.5 / djtg 2.13.1 / dpcutil 2.9.5 (2018) + Vivado 2024.2 实测**能正常 enum cable**, 不要被 "lib 太老" 误导.

**调试时间**: 2026-06-08, dual panel v34e 烧 bit 时发现 cable enum 死, 排查 1.5h 在错误方向 (driver/Adept 版本), 实际 30 秒 (taskkill + cold cycle) 就好.
