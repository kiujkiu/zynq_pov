# 在另一台机器接续这个项目

如果你换了笔记本/PC，按这个步骤就能继续。

## 1. 克隆仓库

```bash
git clone https://github.com/kiujkiu/zynq_pov.git
cd zynq_pov
```

仓库里**不包含**：Vivado checkpoints (.dcp)、bitstream (.bit)、生成的 IP 包、Vitis 平台导出。这些是从源文件 + tcl 重新生成的。

## 2. 必备软件

| 软件 | 版本 | 用途 |
|---|---|---|
| Xilinx Vivado | 2024.2 | BD 设计 + bitstream |
| Xilinx Vitis | 2024.2 | ARM app 编译 + xsdb |
| Vitis HLS | 2024.2 | 综合 pov_project IP |
| Python 3.10+ | | host 工具链 |

Python 包：
```bash
pip install pygltflib numpy Pillow pyserial imageio[ffmpeg]
```

## 3. 重建 bitstream + ELF

按顺序：

### 3.1 综合 HLS IP
```bash
cd hls_proj
D:\Vitis\2024.2\bin\vitis-run.bat --mode hls --tcl run_hls.tcl --work_dir .
```
约 5 分钟。产物：`proj_pov/solution1/impl/ip/povlab_user_pov_project_*.zip`

### 3.2 Vivado BD + bitstream
```bash
cd 02_hello_zynq    # 应已经有 .xpr 项目（git 包含 srcs/）
D:\Vivado\2024.2\bin\vivado.bat -mode batch -source ../tools/bd_use_batch_ip.tcl -nojournal
```
约 20 分钟。产物：`02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit` + `hello_zynq_wrapper.xsa`

### 3.3 Vitis 平台 + ARM app
```bash
cd tools
D:\Vitis\2024.2\bin\vitis.bat -s switch_xsa_and_build.py    # 平台
D:\Vitis\2024.2\bin\vitis.bat -s build_hello_world.py       # app
```
约 3 分钟。产物：`vitis_ws/hello_world/build/hello_world.elf`

### 3.4 下板
```bash
cp ../02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit ../vitis_ws/hello_world/_ide/bitstream/
cp ../vitis_ws/hello_plat/hw/ps7_init.tcl ../vitis_ws/hello_world/_ide/psinit/
D:\Vitis\2024.2\bin\xsdb.bat dl_helloworld.tcl
```

## 4. 跑 demo

### 4.1 检查 COM 口
```powershell
powershell -ExecutionPolicy Bypass -File tools\check_jtag.ps1
# 看到 USB-SERIAL CH340 (COMx)，记下 COMx
```

### 4.2 用 GUI 发送模型
```bash
cd host
python pov_gui.py
# 软件里：
# - 选 .glb 文件
# - 选 COM 口（自动检测）
# - 点 Open 打开端口
# - 点 Send static 发一帧 / Start animated stream 循环动画
```

### 4.3 命令行流（脚本化用）
```bash
python anime_stream.py anime_62459.glb --port COM9 \
  --points 5000 --fps 0.3 --count 5 \
  --color keep --brighten 1.5 --gamma 0.8 --compressed
```

### 4.4 截 HDMI（不需物理显示器）
```bash
python tools\capture_ffmpeg.py
# 输出到 hdmi_ff.jpg
```

## 5. 重要文件路径

```
02_hello_zynq/
  02_hello_zynq.xpr           # Vivado 工程
  02_hello_zynq.srcs/         # BD source（已 commit）
  vitis_ws/hello_world/
    src/helloworld.c           # ARM 主程序
    _ide/bitstream/             # 下板用 bit（gitignored，需重生成）
    _ide/psinit/ps7_init.tcl    # 同上
    build/hello_world.elf       # ARM ELF（gitignored）

hls_proj/
  pov_project.{cpp,h,tcl}     # HLS 源 + 综合脚本

host/
  pov_gui.py                   # 主 GUI
  glb_to_points.py             # glb 加载
  pointcloud_proto.py          # 协议
  anim_loader.py               # 动画器
  anime_*.glb                  # 测试模型

tools/
  bd_*.tcl                     # 各种 Vivado BD 修改脚本
  dl_helloworld.tcl            # xsdb 下载脚本
  capture_ffmpeg.py            # HDMI 抓帧
```

## 6. 已知问题（debugging 时小心）

1. **Vitis workspace lock**：开多个 Vitis instance 会冲突。每次跑前 `taskkill /F /IM java.exe`
2. **JTAG 偶尔掉**：有时连续运行后 USB Serial Converter 消失。物理拔插 USB 线即恢复
3. **COM 口可能漂移**：板子重启 USB 重枚举可能换号（COM7 → COM9 等）。GUI 里 ↻ Detect 重检测
4. **HDMI 黑屏**：如果改 BD 里 axi_smc 的 NUM_CLKS 会破坏 video。安全做法：原 axi_smc 不动
5. **PL batch IP model-update bug**：USE_PL=1 + DEFEAT_ADDR_CACHE=1 是实验代码，未完全解决
6. **HDMI 双缓冲撕裂**：未修。最终 LED 板不依赖 VDMA，可忽略

## 7. 文档索引

- `DEBUG_LOG_2026-04-22.md` 早期 ARM CPU 渲染
- `DEBUG_LOG_2026-04-23.md` HLS IP 综合 + 集成
- `DEBUG_LOG_2026-04-25.md` anime demo + HDMI 采集
- `STATUS_2026-04-23_EOD.md` BD 双缓冲调试
- `AUTONOMOUS_RUN_2026-04-25_to_27.md` 自主运行计划
- `docs/capacity_analysis.html` 带宽 + LED 分辨率扩展评估

## 8. 下一步建议任务

按重要性：
- LED 板硬件设计开始（屏幕到了）
- Host 端做 PBR pre-bake 让颜色更亮
- WiFi/ETH 换 UART（ESP32 桥最简单）
- 修 PL batch IP model-update bug
- 1080p30 HDMI（pixel clock 不变，只改 VTC + fb 大小）
