---
name: Phase 4b HLS pov_project IP 已完成
description: 本 IP 已经综合进 BD 并在板上跑通，加速 3D 点云投影；含性能数据、接口、已知限制
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**位置**：`hls_proj/pov_project.{cpp,h}` + `hls_proj/proj_pov/solution1/impl/ip/` 打包的 IP。Vivado BD 里叫 `pov_project_0`，寄存器 base = `0x43C20000`。

**架构**：
- 混合：ARM 做 framebuffer memset + 画边框，IP 只负责渲染点云点（2×2 像素/点）
- 跑在 FCLK_CLK3 @ 150 MHz（独立时钟，避免干扰 rgb2dvi PLL）
- `m_axi_gmem0` (128b) 读模型 + `m_axi_gmem1` (32b) 写 fb，都通过 `axi_smc_pov_hp` smartconnect → PS HP1
- `s_axi_control` 走 `axi_smc` M03 端口（axi_smc 做了 2-clock CDC）

**性能**：
- 单 slice 355 μs（约 1.15 μs/点，300 点场景）
- 每帧 72 slice → 28 FPS
- 瓶颈是 m_axi + HP1 + DDR 真实延迟，不是 IP 内部逻辑（HLS cycle 估算偏乐观 ~14×）
- Fmax 综合余量 205 MHz，跑 150 已经时序紧

**Why：** 点云流应用的 POV3D 显示器核心加速模块。ARM CPU 能跑 45 FPS 但 CPU 负载高、不能 scale 到 30K 点模型；IP 当前虽然慢于 CPU，但把 CPU 解放出来，大模型时优势才显现。

**How to apply：** 
- 做 4 路并行 IP 时，复用这个 IP 核，只改 BD。IP 内部已经 II=12 稳定
- 不要再试 memcpy 把 3-byte 写合并成 6-byte 或 4-byte，实测全都变慢
- 优化方向：HP1 换 HP0（独占）、多个 HP 端口分流、或 IP 内加 dataflow

**已知限制**：
- 单路 IP 最大吞吐约 2800 slice/sec（现网测），远低于最终 LED 板需要的 21600 slice/sec
- HDMI 撕裂未修（VDMA park_ptr 写入问题悬挂）
