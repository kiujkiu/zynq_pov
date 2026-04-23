@echo off
REM 明天跑综合, 双击此文件或 cmd 里执行即可
cd /d %~dp0
D:\Vitis\2024.2\bin\vitis_hls.bat -f run_hls.tcl
pause
