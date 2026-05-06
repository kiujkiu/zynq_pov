---
name: 鹿小班 LXB-ZYNQ7000 HDMI 时钟策略
description: HDMI 管线像素时钟的已验证方案（用 PS FCLK_CLK1=75MHz，不要用 Clocking Wizard）
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
**验证通过（2026-04-22）**：鹿小班板 HDMI 彩条（1280×720 @ 60.6Hz）能出图的时钟策略：

- **PS 直出 FCLK_CLK1**（74.25 要求写 74.25，PS PLL 实际给 75 MHz）
- **全板统一一个时钟域**：AXI + 视频 IP 全部 `FCLK_CLK1`
- **不要用 Clocking Wizard** 把 50 MHz 升到 74.25 —— 实际跑会出现 AXI 总线死锁（clk_wiz 产生的 clk_pixel 锁不住或 proc_sys_reset 握手不到位，PS 访问 AXI 寄存器会永远 hang 在第一笔 write）

**BD 关键配置**：
```
ZYNQ PS:
  PCW_EN_CLK1_PORT = 1
  PCW_FPGA1_PERIPHERAL_FREQMHZ = 74.25  (实际=75.000)
  PCW_FCLK1_PERIPHERAL_CLKSRC = "IO PLL"

统一连 FCLK_CLK1:
  processing_system7_0/M_AXI_GP0_ACLK
  axi_smc/aclk
  axi_gpio_0/s_axi_aclk
  proc_sys_reset_0/slowest_sync_clk
  v_tpg_0/ap_clk
  v_tc_0/clk
  v_tc_0/s_axi_aclk
  v_axi4s_vid_out_0/aclk
  v_axi4s_vid_out_0/vid_io_out_clk
  rgb2dvi_0/PixelClk
```

**Why:** 75 MHz vs 理想 74.25 MHz 偏差 1%，帧率变 60.6Hz。市售普通 HDMI 显示器接受这个偏差；实测显示器能正常显示彩条。PS IOPLL 整数分频凑不出精确 74.25，但 75 MHz 足够用。用 clk_wiz 升频理论上能做到 74.25，但本项目上实际部署不稳（耗时 2 小时调 BD + reset + dcm_locked 都没让 clk_pixel 稳定工作）。

**How to apply:** 任何用到 HDMI 彩条/静态图的场合，Vivado BD 里：
1. PS 配置里开 FCLK_CLK1 = 74.25（Vivado 自动给 75）
2. **不要** Add IP Clocking Wizard
3. 所有视频 IP 和 AXI 总线都连 FCLK_CLK1
4. 保留一个 proc_sys_reset，slowest_sync_clk 也给 FCLK_CLK1

**rgb2dvi 配置**：保持默认 `kGenerateSerialClk = True`（让它内部 MMCM 自己生 5× 串行时钟），这样只需要给 PixelClk 一个输入。

**最终 BD 文件模板**：
`/mnt/d/workspace/zynq_pov/tools/bd_route_b.tcl` 是跑通的 Tcl 脚本，批处理模式下 `vivado -mode batch -source bd_route_b.tcl` 就能从当前工程生成能出图的 bitstream + XSA。
