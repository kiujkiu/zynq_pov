@echo off
REM Compile + elaborate + run xsim batch
setlocal
set VIV=D:\Vivado\2024.2\bin
call "%VIV%\xvlog.bat" led_panel_drv.v led_panel_drv_tb.v
if errorlevel 1 exit /b 1
call "%VIV%\xelab.bat" -debug typical led_panel_drv_tb -s led_panel_drv_sim
if errorlevel 1 exit /b 1
call "%VIV%\xsim.bat" led_panel_drv_sim -tclbatch run_sim.tcl -log xsim.log
exit /b %errorlevel%
