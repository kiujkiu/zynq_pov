@echo off
call D:\Vivado\2024.2\settings64.bat
cd /d D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq
set TEMP=C:\Users\kiujkiu\AppData\Local\Temp
set TMP=C:\Users\kiujkiu\AppData\Local\Temp
vivado.bat -mode batch -source D:\claude_workspace\pov3d\zynq_pov\tools\_vivado_validate_bd.tcl -nojournal -nolog 1> D:\claude_workspace\pov3d\zynq_pov\tools\vivado_set.log 2>&1
