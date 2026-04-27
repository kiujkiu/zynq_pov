@echo off
REM Double-click launcher for POV3D Streamer GUI.
REM Sits next to pov_gui.py — runs in this directory so relative imports work.
cd /d "%~dp0"
python pov_gui.py
if errorlevel 1 (
    echo.
    echo [!] pov_gui.py exited with error %errorlevel%
    pause
)
