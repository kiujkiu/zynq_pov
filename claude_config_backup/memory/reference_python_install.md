---
name: Win Python 安装位置和环境
description: 本机 Win 端 Python 3.12 安装位置 + 已装的项目相关包列表，host 脚本（test_send_one.py 等）依赖
type: reference
originSessionId: 1356c92a-50d7-4bd3-bfcb-d227e41ecfa9
---
**安装路径（winget user-scope, 2026-05-06）**：
- `C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\python.exe`
- Scripts: `C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\Scripts\`
- 已加入用户 PATH，**新开 cmd / PowerShell** 才生效；本会话里 cmd.exe 继承的是旧 env，要用全路径。

**Microsoft Store 占位符 `python` 仍存在** 在 `C:\Users\kiujkiu\AppData\Local\Microsoft\WindowsApps\python.exe`。在 user PATH 排序里 Python312 在前，新 shell 应该优先匹配真 Python。

**已装包（按 NEW_MACHINE_SETUP.md §2.2 + 项目实际依赖）**：
- pyserial 3.5、trimesh 4.12.2、numpy 2.4.4、pillow 12.2.0
- pygltflib 1.16.5、PyQt6 6.11.0、obs-websocket-py 1.0
- imageio 2.37.3、imageio-ffmpeg 0.6.0（替代 host/tools/capture_obs.py 等所需的 ffmpeg）

**WSL Python 3.12** 默认无 pip / 无包；host 脚本一律走 Win Python（COM 口在 Windows 侧）。如果要在 WSL 里用 Python，需要 `sudo apt install python3-pip python3-venv` 自行装。

**未装的可选项（NEW_MACHINE_SETUP.md §2.4）**：
- Blender 4.2 LTS — 跑 `host/blender/bake_pbr.py` 才需要
- OBS Studio + obs-websocket plugin — `tools/capture_obs.py` 才需要
- VS Code — 编辑器，可选

**How to apply**：跑 `python host/test_send_one.py` 之类直接用新 cmd 即可。如果在 WSL bash 里要调，用：
```
cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\host && python test_send_one.py"
```
或者直接用全路径 `C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\python.exe`。
