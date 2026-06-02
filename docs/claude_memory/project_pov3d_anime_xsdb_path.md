---
name: POV3D anime 完整渲染 xsdb 直推路径 (2026-05-13)
description: 30K anime voxel 通过 JTAG 直推 DDR 0x1A000000, HLS 32K IP 渲染, HDMI 显示无残影完整角色; 配套 ARM ANIME_MAGIC 检测 + ring buffer 清零
type: project
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**完成日期**: 2026-05-13. WiFi 桥被 office AP 阻塞 + UART COM 找不到, 走 xsdb 直推绕开两个通信问题.

**完整数据流**:
```
PC: anime_to_bin.py
  ↓ voxelize_mesh(GLB, target_scale=40, z_stretch=1.5, voxel_size=1.0)
  ↓ pack 16B PovPoint × N → binary file
xsdb tools/dl_helloworld_with_anime.tcl:
  - rst -system, fpga -file new_bit, ps7_init, mwr UART baud
  - dow ELF
  - dow -data anime_points.bin 0x1A000000  # JTAG 直写 DDR
  - mwr 0x1F000000 0xA11ECEC0              # magic
  - mwr 0x1F000004 <count>                 # anime_n
  - con
ARM helloworld.c (我加的):
  - 检测 *(volatile u32 *)0x1F000000 == 0xA11ECEC0
  - 设 model_n = *(volatile int *)0x1F000004
  - 清 magic + Xil_DCacheInvalidateRange(MODEL_ADDR, ...)
  - SKIP build_model() (不覆盖 anime 数据)
  - 继续 voxelize_model() → main loop
HLS pov_project_batch 1.1 (32K BRAM):
  - 读 MODEL_ADDR via HP1 (DDR 非缓存)
  - 渲染 72 个 slice angles 到 ring buffer
  - 每 fire 前 ARM memset ring → 防残影
VDMA → HDMI: 完整 anime 角色清晰显示
```

**关键参数**:
- `MODEL_ADDR = 0x1A000000` (16MB region for 1M points)
- `ANIME_MAGIC_ADDR = 0x1F000000`, value `0xA11ECEC0`
- `model_n` 静态变量在 BSS, 地址 `0x0011c25c` (随 ELF 重 build 会变, 用 nm 找)
- `RING_BUFFER_ADDR = 0x12000000`, N_SLOTS=72, SLOT_BYTES=38160
- HLS IP MAX_BATCH_POINTS=32768, version 1.1, 144 BRAM (留 1 个 IP 实例)

**配套修改**:
- `hls_proj/pov_project.cpp`: MAX_BATCH_POINTS 1024 → 32768
- `hls_proj/run_hls.tcl`: -version 1.0 → 1.1
- `02_hello_zynq.bd`: 删 IP 1/2/3, 保留 IP 0_0
- `helloworld.c`: anime_magic 检测分支 + ring memset 清残影
- `tools/dl_helloworld_with_anime.tcl`: 完整 cold-boot + JTAG 注入流程
- `anime_to_bin.py`: PC 端 GLB → binary 工具

**已知限制**:
- 数据**静态**, 换模型要重跑 dl tcl
- xsdb JTAG 速度 ~1 MB/s, 500KB anime 数据写 ~0.5 秒
- 任何 rst -system 之后重传

**实时流路径** (尚未通):
- WiFi (ESP32 桥): office AP TCP intercept, 换手机热点应能恢复
- UART (CH340 直连 Zynq): COM 口当前未知, 探了 COM3-9 没反应
