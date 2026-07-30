---
name: 换 FPGA 平台的依赖清单 (以安路 DR1V90M 评估为例)
description: RTL 只依赖 14 处 ODDR, 其余纯 Verilog; 真正决定工作量的是 PS 侧有没有硬核 + Linux BSP
type: reference
---
2026-07-30 用户问"换安路 DR1V90M 的移植难度", 做了依赖盘点。**结论: RTL 很干净, 风险全在 PS 侧。**

## RTL 依赖 (在用约 1600 行: pov_dual_top + icnd2047_panel_core + row_drv_icnd1028 + ddr_slice_fetch)

| 依赖 | 数量 | 说明 |
|---|---|---|
| **ODDR 原语** | **14 处** | ⚠ 唯一硬骨头 |
| 其他原语 (BUFG/MMCM/RAMB/DSP48/XPM…) | **0** | BRAM 与时钟全是推断的 |
| Xilinx IP | 3 (processing_system7 / smartconnect / proc_sys_reset) | 看新平台形态 |

盘点方法: `grep -ohE "\b(ODDR|IDDR|BUFG|MMCME2|RAMB|XPM_[A-Z_]+|DSP48)[A-Z0-9_]*" vivado/hdl/*.v | sort | uniq -c`

**ODDR 为什么关键**: 那 14 处是双沿输出核心, DCLK 用 `SAME_EDGE` 把边沿推迟半拍(10ns)
落在数据眼图中点, 是 50 Mbps/lane 能成立的原因 (setup/hold 名义 10/10ns vs 芯片要求 5/5ns)。
换平台不是改个原语名 —— **不同厂商 DDR 输出原语的 clk→out 延迟/抖动/占空比失真都不同,
必须重做时序收敛并重测眼图**。

## PS 侧才是工作量大头

现依赖 Zynq-7020 **硬核 Cortex-A9 双核 + Linux 6.6**:
`pov_rxd`(C, TCP+zlib+写DDR) / `povmem.ko`(WC 映射) / mt7921u WiFi / systemd 三个服务 /
`/dev/mem` 访寄存器 / AXI HP 口共享 DDR。

移植难度**完全取决于新平台形态**:
- **硬核 ARM + 官方 Linux BSP** → 基本可平移, 主要是重编内核/改 devicetree/DDR 地址重规划
- **仅软核 (RISC-V)** → Linux 能跑但性能另说。当前解压一帧 64ms 是 A9@667MHz 的成绩,
  软核大概率跑不动 ⇒ **整个推流架构要重设计**
- **纯 FPGA 无处理器** → 外挂 MCU 或控制逻辑全搬进 RTL, **是重做不是移植**

## 换平台前必须先问清楚

1. 有无硬核处理器? 架构/核数/主频  2. 有无官方 Linux BSP + 内核版本
3. DDR 控制器硬核还是软 IP, 位宽带宽  4. 双沿输出原语叫什么 + datasheet 时序
5. **换的动因是什么?**

🔴 第 5 条最重要: 若是供货/成本 → 移植是必须的; **若是性能不够 → 先确认新平台真能解决**。
按当前实测, 瓶颈是 **推流逐帧 ACK**(软件, 见 [[feedback_povrxd_stop_and_wait_limit]]) 和
**转速与刷新率不匹配**(机械+配置, 见 [[project_pov3d_refresh_vs_rpm]]) —— **这两个换 FPGA 都解决不了**。

## 我(Claude)能做与不能做

能做: RTL 移植(ODDR 外基本是改约束与工程脚本)、软件层适配、驱动/服务移植、协议与上层逻辑。
不能做: **无硬件则无法验证任何时序**; 安路 TD 工具链的坑只能撞一个学一个; 若无官方 BSP, 从零做 BSP 无法可靠承诺。
