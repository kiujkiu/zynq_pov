# POV-3D Zynq 工程使用说明

## 场景 A：只想把已编好的程序刷到板子上跑（最常见）

1. 板子插 **USB-JTAG** 线 + **USB-UART** 线，开电源
2. 串口终端开 **COM2 @ 115200 8-N-1**（SSCOM、PuTTY、MobaXterm 都行）
3. 在 WSL 或 Windows 命令行里跑：
   ```bash
   # WSL
   cmd.exe /c "D:\\Vitis\\2024.2\\bin\\xsdb.bat D:\\workspace\\zynq_pov\\tools\\dl_helloworld.tcl"

   # 或在 PowerShell:
   D:\Vitis\2024.2\bin\xsdb.bat D:\workspace\zynq_pov\tools\dl_helloworld.tcl
   ```
4. 串口应该看到 `=== VDMA+UART->HDMI Text Console ===`，HDMI 出文字
5. 键盘敲字，HDMI 实时显示

当前默认 app = `hello_world` (UART-HDMI 文本控制台)。

另一个 app：`lwip_echo_server`（以太网已验证硬件层无法跑通，暂搁置）。

---

## 场景 B：改了 C 代码，重新编 app，再运行

```bash
# 1. 编辑源文件，例如
#    D:\workspace\zynq_pov\02_hello_zynq\vitis_ws\hello_world\src\helloworld.c

# 2. 编译 (WSL)
cmd.exe /c "powershell -File D:\\workspace\\zynq_pov\\tools\\kill_vitis.ps1"
cmd.exe /c "D:\\Vitis\\2024.2\\bin\\vitis.bat -s D:\\workspace\\zynq_pov\\tools\\build_hello_world.py"

# 3. 下载+跑
cmd.exe /c "D:\\Vitis\\2024.2\\bin\\xsdb.bat D:\\workspace\\zynq_pov\\tools\\dl_helloworld.tcl"
```

或者打开 Vitis IDE → `hello_world` → Build → Run（GUI 方式，多几步鼠标点）。

---

## 场景 C：改了硬件（BD / XDC），需要重编 bitstream

```bash
# 0. 确保 Vivado GUI 关闭（不然工程被锁）

# 1. 修改或新建 TCL 脚本 (参考 /mnt/d/workspace/zynq_pov/tools/bd_*.tcl)

# 2. 跑 Vivado 批处理（修改 BD + 生成 bitstream + 导出 XSA，约 8-10 分钟）
cmd.exe /c "cd /d D:\\workspace\\zynq_pov\\tools\\logs && \
  D:\\Vivado\\2024.2\\bin\\vivado.bat -mode batch \
  -source D:\\workspace\\zynq_pov\\tools\\<your_script>.tcl \
  -log vivado.log -journal vivado.jou -notrace"

# 3. 把新 bit 同步到 Vitis 缓存
bash /mnt/d/workspace/zynq_pov/tools/refresh_bit.sh /mnt/d/workspace/zynq_pov/02_hello_zynq

# 4. 让 Vitis 平台重新吃入 XSA (BSP 会重建 xparameters.h)
cmd.exe /c "powershell -File D:\\workspace\\zynq_pov\\tools\\kill_vitis.ps1"
cmd.exe /c "D:\\Vitis\\2024.2\\bin\\vitis.bat -s D:\\workspace\\zynq_pov\\tools\\switch_xsa_and_build.py"

# 5. 重编 app
cmd.exe /c "D:\\Vitis\\2024.2\\bin\\vitis.bat -s D:\\workspace\\zynq_pov\\tools\\build_hello_world.py"

# 6. 下载+跑
cmd.exe /c "D:\\Vitis\\2024.2\\bin\\xsdb.bat D:\\workspace\\zynq_pov\\tools\\dl_helloworld.tcl"
```

---

## 场景 D：要把主机端 Python 接上板子

```powershell
# 确保 Vitis 串口终端已断开 COM2（不然 Python 抢不到）
pip install pyserial
cd D:\workspace\zynq_pov\host
python send_text.py
```

---

## 常用路径速查

| 东西 | 路径 |
|------|------|
| Vivado 工程 | `D:\workspace\zynq_pov\02_hello_zynq\02_hello_zynq.xpr` |
| BD 文件 | `02_hello_zynq\02_hello_zynq.srcs\sources_1\bd\hello_zynq\hello_zynq.bd` |
| XDC 约束 | `02_hello_zynq\02_hello_zynq.srcs\constrs_1\new\*.xdc` |
| 导出的 XSA | `02_hello_zynq\hello_zynq_wrapper.xsa` |
| Vitis workspace | `02_hello_zynq\vitis_ws\` |
| Platform BSP | `vitis_ws\hello_plat\` |
| App 源文件 | `vitis_ws\hello_world\src\helloworld.c` |
| 自动化脚本 | `D:\workspace\zynq_pov\tools\` |
| 主机 Python | `D:\workspace\zynq_pov\host\` |

---

## 故障排查（遇到时看这里）

| 问题 | 诊断 |
|------|------|
| Vivado 批处理说 "workspace in use" | 运行 `kill_vitis.ps1` 清理残留进程 |
| FSBL build 报 `undefined reference to XTime_GetTime` | 跑 `fix_xiltimer.sh` |
| Run 后串口没输出 | 检查 JTAG 连接，板子电源，COM 口号；序号换了就关闭再开串口软件 |
| 板子 ping 不通（以太网） | 已知硬件问题，已搁置，用 UART 代替 |
| HDMI 没信号 / 花屏 | 检查 bit 是否真的下到 FPGA（XSDB 日志有 "Device configured successfully"）|
| HDMI 颜色错乱 | 帧缓冲字节序是 **BGR** 不是 RGB（`fb[x*3+0]=B, [+1]=G, [+2]=R`）|

---

## 记忆文件（跨会话的参考）

所有关键决策、踩坑、配置都存在：
```
/home/kiujkiu/.claude/projects/-home-kiujkiu-workspace-pov3d/memory/
```

里面有：PS/DDR 配置、HDMI 时钟策略、以太网阻塞记录、VDMA 帧缓冲架构等。
