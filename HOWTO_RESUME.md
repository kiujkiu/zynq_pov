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

### 4.2 用 GUI 发送模型(双击 host\pov_gui.bat)
GUI 右侧参数:
- **Points**: 默认 100000,5K-1M 可调
  - 5K: 稀疏轮廓但流畅
  - 100K: 接近饱和密度,推荐
  - 1M: 极限,wire 60 秒
- **Color**: keep(原 glb 纹理) / height(彩虹) / random / uniform
- **Lighting**: studio(三光 HDR-like 推荐) / lambert / half-lambert / none
- **Z-stretch**: 1.0-8.0,薄模型可调高
- **Crop top**: 0=全身,0.25=头肩,0.15=脸
- **Baud**: **921600**(默认,8× 提速)
- 点 **Send static** 发一帧

### 4.3 命令行(脚本化)
```bash
python host\test_send_one.py 1.5 100000   # z_stretch points
```

### 4.4 截 HDMI(OBS Virtual Camera 链路)
要先 OBS Tools → Virtual Camera → Start。然后:
```bash
python tools\capture_obs.py
# 输出到 hdmi_obs.jpg (1280×720)
```
注: OBS Virtual Camera + USB capture 卡多限 720p。1080p30 模式下抓帧返黑(代码工作,显示器直连可看)。

### 4.5 启用 1080p30(可选)
helloworld.c 取消 `// #define USE_1080P30 1` 注释,重 build + dl。ARM 报 30 FPS = 1080p30 vsync 锁定。需 1080p HDMI 显示器直连。

### 4.6 4-IP 并行(可选,需重综合)
LED 板真上线时跑:
```cmd
cd 02_hello_zynq
D:\Vivado\2024.2\bin\vivado.bat -mode batch -source ..\tools\bd_4ip_voxel_slicer.tcl -nojournal
```
~30 分钟综合 + bitstream。然后 helloworld.c include voxel_slicer_4ip.h 替换 cpu_render_voxel_panel。

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
3. **COM 口可能漂移**：板子重启 USB 重枚举可能换号。GUI ↻ Detect 重检测
4. **HDMI 黑屏**：改 BD 里 axi_smc 的 NUM_CLKS 会破坏 video。安全做法：原 axi_smc 不动
5. ~~**PL batch IP model-update bug**~~：旧 pov_project_batch IP 内部 BRAM cache 持久化问题。**voxel 路径已绕开**(pov_voxel_slice_batch 不用 BRAM)
6. ~~**HDMI 双缓冲撕裂**~~：**已修(2026-04-27)** — pure circular VDMA + ARM vsync poll
7. **BAUDDIV ≥ 4**: Zynq TRM 限制,<4 写不进。当前 921600 用 BDIV=5/BGEN=18
8. **occupied_list 不能放固定 DDR 地址**: BSP MMU 配置问题。回 BSS 静态数组
9. **OBS Virtual Camera 限 720p**: 1080p30 板子能输出但 capture 卡看不到,需直连 1080p 显示器
10. **Voxel 分辨率天花板**: 256³ + cell=1 单位,模型表面 ~30K voxel 饱和。100K+ 点不再增加细节,要更细需 512³(256MB DDR,板子撑不住) 或 host 预渲染切片图

## 7. 文档索引

- `DEBUG_LOG_2026-04-22.md` 早期 ARM CPU 渲染
- `DEBUG_LOG_2026-04-23.md` HLS IP 综合 + 集成
- `DEBUG_LOG_2026-04-25.md` anime demo + HDMI 采集
- `DEBUG_LOG_2026-04-27.md` **voxelization + UART 921600 + HDMI 撕裂修 + 1080p30**
- `STATUS_2026-04-23_EOD.md` BD 双缓冲调试
- `AUTONOMOUS_RUN_2026-04-25_to_27.md` 自主运行计划
- `docs/capacity_analysis.html` 带宽 + LED 分辨率扩展评估

## 8. 当前性能基线

| 配置 | FPS @ 720p | 备注 |
|---|---|---|
| 32K 点 + 256³ voxel | 65 FPS 自由跑 | 默认 |
| 100K 点 + 256³ voxel | 30 FPS | 高细节 |
| 100K 点 + vsync-locked | 60.54 FPS | **撕裂修后** |
| 1M 点 (饱和) | 7.7 FPS | 极限 |
| 1080p30 + 100K | 30.27 FPS | USE_1080P30 |
| **未来 4-IP 并行 voxel** | **~120 FPS** | 综合后预估 |

## 9. 下一步建议

按硬件就位顺序:
1. **LED 板硬件**（屏幕到了)— 用 4-IP voxel slicer + 真切片 driver
2. **ESP32 WiFi 桥**（板子到了)— 替换 UART 拿 100× 带宽
3. host 预渲染高清切片图(看脸部表情)— 绕开 voxel 分辨率天花板
4. host 端动画 glb 优化(skeletal/keyframe 解码)
