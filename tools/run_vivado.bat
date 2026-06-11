@echo off
cd /d D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq
set TEMP=C:\Users\kiujkiu\AppData\Local\Temp
set TMP=C:\Users\kiujkiu\AppData\Local\Temp
set XILINX_REALPATH_NO_DOSDEV=1
D:\Vivado\2024.2\bin\vivado.bat -mode batch -source ..\tools\_vivado_build_strict.tcl -nojournal -nolog 1> D:\claude_workspace\pov3d\zynq_pov\tools\vivado_out.log 2>&1
