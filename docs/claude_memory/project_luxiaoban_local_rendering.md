---
name: POV-3D ARM 本地渲染 72 切片 @ 45 FPS
description: 放弃主机传像素（UART 7000× 太慢），改为 ARM 本地渲染硬编码 3D 模型每帧生成 72 切片，45 FPS 刷屏
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**验证日期**: 2026-04-22 21:45

## 背景
Task #8 Stage 3 主机传整帧切片: 72 × 106×120×3 = 2.75 MB/帧, UART 115200 实测 11 KB/s → 一帧 4 分钟, 远远达不到 30 Hz POV 刷新要求. UART 瓶颈是 7000×.

## 核心转变
**让主机负责模型定义, 板子负责渲染**. 主机只传少量模型数据(或硬编码), ARM 每帧本地生成 72 片.

## 实现方案
- Hardcoded 3D 模型: 300 点云 (红 X 轴 + 绿 Y 轴 + 蓝 Z 轴 + 白/橙立方体 12 棱)
- 预计算 72 个角度的 cos/sin × 256 表 (int16_t, Q8.8 定点) — 避免 libm
- 每片渲染: for each point, 绕 Y 轴旋转 (rx = x*c + z*s >> 8) + 正交投影到 2D, 写 2x2 像素到帧缓冲
- 每帧清一次帧缓冲 + 渲染 72 片 + DCache flush
- 动画: `phase` 每帧递增, 起始角度 slide

## 性能实测
- 从串口 frame 计数推算: **~45 FPS** (448 帧 / 10 秒)
- XTime_GetTime + COUNTS_PER_SECOND 组合在 xiltimer 架构下返回 0, 无法直接用其计时. 只能靠帧号增速推算.

## 代码要点 (`helloworld.c`)
- 硬编码 `cos8_table[72]` 和 `sin8_table[72]` 避免 libm 链接
- `add_line(x0,y0,z0, x1,y1,z1, n, r,g,b)` 生成模型
- `render_slice(angle_idx, col, row)`: 清格 + 画边框 + 投影点云
- main loop: 72 次 render_slice + 1 次 DCacheFlushRange(整帧)

## 文件
- `02_hello_zynq/vitis_ws/hello_world/src/helloworld.c`
- `host/send_72_slices.py` (Stage 3 的主机端发送器, 仍保留作为协议例子)

## 下一步可扩展
1. **模型上传**: UART 发 0xAA 0x20 <npts> <pts> 上传点云
2. **PL 硬件加速投影**: HLS 或 Verilog 做 projection engine, 冲 100+ Hz
3. **换 LED 板输出**: VDMA 的输出不接 rgb2dvi/HDMI 而是接 ICND1069 驱动, 架构不变
