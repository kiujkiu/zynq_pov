@echo off
REM ===================================================================
REM 一键持久化:bootgen 生成 BOOT.bin + program_flash 烧 QSPI
REM 用法:双击此 .bat 或 cmd 中跑
REM ===================================================================

setlocal
cd /d %~dp0

echo [1/2] bootgen: 合 FSBL + bitstream + hello_world.elf -> BOOT.bin
D:\Vitis\2024.2\bin\bootgen.bat -arch zynq -image bootgen.bif -o BOOT.bin -w on
if errorlevel 1 (
    echo bootgen 失败,退出
    pause
    exit /b 1
)
echo BOOT.bin 生成 OK

echo.
echo [2/2] program_flash 烧 QSPI (~1-2 分钟)
D:\Vitis\2024.2\bin\program_flash.bat ^
  -f BOOT.bin ^
  -offset 0 ^
  -flash_type qspi-x4-single ^
  -fsbl D:\workspace\zynq_pov\02_hello_zynq\vitis_ws\hello_plat\export\hello_plat\sw\boot\fsbl.elf ^
  -blank_check ^
  -verify ^
  -url TCP:127.0.0.1:3121
if errorlevel 1 (
    echo program_flash 失败,退出
    pause
    exit /b 1
)

echo.
echo === 完成 ===
echo 现在:
echo   1) 拔 USB / 断电
echo   2) 改 BOOT MODE 跳线 → QSPI (一般 MIO5:2 = 0001)
echo   3) 上电 → 板子从 QSPI 自动启动 helloworld
echo.
pause
