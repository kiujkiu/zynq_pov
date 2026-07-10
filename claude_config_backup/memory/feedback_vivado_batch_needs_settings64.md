---
name: Vivado batch 用 vivado.bat 绝对路径, vivado.exe 不在 PATH
description: WSL→cmd /c vivado.exe 报"不是内部或外部命令"; settings64.bat 不加 PATH; 必须 call settings64 + vivado.bat 绝对路径
type: feedback
created_at: 2026-06-09 19:59 CST
updated_at: 2026-06-09 22:11 CST
originSessionId: c65586d5-1bd7-42fb-bf7e-7a8b7f63582c
---
**关键事实** (2026-06-09 22:11 翻案):
1. **vivado.exe 不在 PATH**, 即使 call 了 `C:\Xilinx\Vivado\2024.2\settings64.bat`. 必须用 `C:\Xilinx\Vivado\2024.2\bin\vivado.bat` 绝对路径
2. settings64.bat 设的是 Xilinx 内部 PATH (xelab 等), 不把自己的 bin/ 加进 cmd 的 PATH
3. 之前以为 "batch spawn 卡死" 其实是命令找不到, 退 exit 0 + 错误信息 GBK 乱码看不出

**v34h build 验证通过的命令** (WSL bash → cmd.exe):
```bash
cmd.exe /c "call C:\Xilinx\Vivado\2024.2\settings64.bat && cd /d D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq && C:\Xilinx\Vivado\2024.2\bin\vivado.bat -mode batch -source D:\claude_workspace\pov3d\zynq_pov\tools\build_v34h.tcl -log build_v34h.log -journal build_v34h.jou"
```
~7-8 min 完成 (synth + impl + bitgen + xsa export, 02_hello_zynq 工程规模).

**老的 Spawn failed 现象**:
```
ERROR: [Common 17-180] Spawn failed: No error
```
那是 vivado.exe 在 cmd 里能 spawn subprocess (xelab/xvhdl) 但 PATH 不全 → subprocess 起不来. 现在用 vivado.bat 走 wrapper 路径正常.

**Why:** Vivado batch 走 cmd.exe 时要靠 vivado.bat 这个 wrapper 自己 setup 环境, 直接 vivado.exe 缺一截.

**How to apply:** 所有 WSL→cmd 调 Vivado batch:
- ✅ `C:\Xilinx\Vivado\<ver>\bin\vivado.bat` 绝对路径
- ❌ `vivado.exe` 在 PATH (没加)
- ✅ 前置 `call settings64.bat` (即使不加 PATH, 设了 Xilinx 内部环境变量)
- 日志/jou 用 `-log -journal` 自定义文件名, 默认 vivado.log 会被多次覆盖
