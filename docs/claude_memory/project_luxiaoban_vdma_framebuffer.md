---
name: 鹿小班 HDMI VDMA 帧缓冲已验证配置
description: PS 写 DDR → VDMA 读 → HDMI 显示的端到端架构，2026-04-22 彻底跑通
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**验证日期**: 2026-04-22 20:33

**架构**：
```
ARM (FRAMEBUF_ADDR=0x10000000) → DDR → AXI HP0 → axi_smc_hp
  → axi_vdma_0.M_AXI_MM2S → axi_vdma_0.M_AXIS_MM2S
  → v_axi4s_vid_out_0 (VTC 720p 时序) → rgb2dvi_0 → HDMI
```

**关键 VDMA BD 配置**:
- `axi_vdma:6.3` 参数: `c_include_sg=0`, `c_num_fstores=1`, `c_include_mm2s=1`, `c_m_axi_mm2s_data_width=64`, `c_m_axis_mm2s_tdata_width=24`, `c_include_s2mm=0`, `c_mm2s_linebuffer_depth=512`
- ⚠️ VDMA IP 约束: `s_axi_lite_aclk ≤ m_axi_mm2s_aclk` — 我们全部用 FCLK_CLK1 (75MHz) 避免违反
- PS `CONFIG.PCW_USE_S_AXI_HP0=1` 必须打开
- 专门加一个 `axi_smc_hp` (SmartConnect) 给 VDMA.M_AXI_MM2S → PS.S_AXI_HP0 的数据路径
- PHY 硬件复位 H17 接 `xlconstant=1`（vendor PL 参考: `assign eth_rstn=1`）

**关键地址**:
- VDMA 控制寄存器: `0x43C10000` (原 VTPG 位置, VTPG 已删)
- 帧缓冲 DDR: `0x10000000` (256MB 偏移, 安全区)
- VTC 控制: `0x43C00000` (未动)
- AXI GPIO: `0x41200000` (未动)

**关键 C API**:
```c
XAxiVdma_DmaSetup setup = {0};
setup.VertSizeInput = HEIGHT;      // 720
setup.HoriSizeInput = WIDTH * 3;   // 3840 bytes/line
setup.Stride        = WIDTH * 3;
setup.EnableCircularBuf = 1;
XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_READ, &setup);
UINTPTR fbs[1] = { FRAMEBUF_ADDR };
XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_READ, fbs);
XAxiVdma_DmaStart(&Vdma, XAXIVDMA_READ);
```

**像素写入字节序 (踩坑记)**:
AXIS TDATA 24-bit 到 S2V/rgb2dvi：`TDATA[7:0]=B, [15:8]=G, [23:16]=R`
所以内存里 `fb[y*stride + x*3 + {0,1,2}] = {B, G, R}` 不是 RGB!
（我第一版写成 RGB 顺序，监视器显示 R→G、G→B、B→R 错位）

**工具脚本**:
- `/mnt/d/workspace/zynq_pov/tools/bd_add_vdma.tcl` — 加 VDMA + 删 VTPG 的 BD 改造
- `/mnt/d/workspace/zynq_pov/tools/bd_add_eth_rstn.tcl` — 顺便加了 PHY hw reset 在 H17

**用法**: 任何基于鹿小班的 HDMI 应用都可以直接 ARM 代码画到 DDR 0x10000000，内存布局 1280*720*3 BGR → HDMI 自动出。
