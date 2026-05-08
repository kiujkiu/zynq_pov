@echo off
REM Run Blender PBR bake on anime_62459.glb -> anime_62459_baked.glb
REM Auto-finds blender.exe in standard winget install paths.
set IN=D:\workspace\zynq_pov\host\anime_62459.glb
set OUT=D:\workspace\zynq_pov\host\anime_62459_baked.glb
set SCRIPT=D:\workspace\zynq_pov\host\blender\bake_pbr.py

set BLENDER=
if exist "C:\Program Files\Blender Foundation\Blender 4.2\blender.exe" set BLENDER=C:\Program Files\Blender Foundation\Blender 4.2\blender.exe
if exist "C:\Program Files\Blender Foundation\Blender 4.5\blender.exe" set BLENDER=C:\Program Files\Blender Foundation\Blender 4.5\blender.exe
if exist "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" set BLENDER=C:\Program Files\Blender Foundation\Blender 5.1\blender.exe

if "%BLENDER%"=="" (
    echo blender.exe not found
    exit /b 1
)
echo Using: %BLENDER%
"%BLENDER%" -b -P "%SCRIPT%" -- "%IN%" "%OUT%"
