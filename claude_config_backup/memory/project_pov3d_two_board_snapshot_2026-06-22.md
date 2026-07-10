---
name: pov3d-two-board-snapshot-2026-06-22
description: 两块板(FM6124旋转体128×128 / ICND2047棋盘格128×64)各自 HEAD commit + 已验证状态 + 未提交WIP 总览; 记忆/git/工作区三方对账结果
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-22 CST
  updated_at: 2026-06-22 CST
  originSessionId: fe6cecaa-6915-4b7c-91e6-2e0b62bc1aaa
---

两条**完全独立**的线, 别混 (cable SN 区分: 板1=210251A08870). 2026-06-22 对账 记忆 vs git HEAD vs 工作区 的结果:

| | **板 1 (FM6124, 旋转体主线)** | **板 2 (ICND2047, bring-up)** |
|---|---|---|
| panel | FM6124 **128×128** dual panel 竖拼 (MTR转接板) | ICND2047 **128×64 / 32扫** HUB75E (MTR P3) |
| 仓/工作区 | 主仓 `D:\...\zynq_pov` | worktree `D:\...\zynq_pov_icnd2047` |
| 分支 | `debug/fm6124-v29` | `debug/icnd2047-mtr-p3` |
| **HEAD commit** | **44fb05d (2026-06-16 17:55)** | **62031f3 (2026-06-17 16:48)** |
| HEAD 内容 | pov_render_full 上板 — 点云直进FPGA一条龙 (anime + **地球仪**) | 驱动验证: 色序重映射+纯LE脉冲修偏移+panel IP inline |
| 已验证显示 | **旋转体 POV**: 点云→ARM体素化→pov_proj切片→720片现算; **最后跑 anime+地球仪** | **8色竖条 + 红绿棋盘格**(8列×4行,上下半相位反); 色序/偏移/几何全对 |
| **当前实测配置** | DDR帧, v6 dual 8205fps | **1-bit BCM / W=128 / 32扫 / 50MHz = ~11.7k ✅** (`_flash_fps.tcl` planes=1 坐实; v30 7540→纯LE脉冲→11.7k) |
| W (移位链长) | — (DDR帧/multivox切片) | **当前实际 W=128** (run脚本 _flash_icnd/_run_icnd_verify 全写 `mwr 0x40020008 127`=128列全宽, 8颗ICND2047 daisy单链, 每行128clk). ⚠综合参数 PANEL_WIDTH=16 只是默认值, 被运行时 PARAM=127 覆盖. 三个"16/128"别混: 芯片通道=16 / 当前整行W=128 / 拆daisy未来单链=16(需48lane) |
| fb 路径 | DDR framebuffer 已通 (v6 IP AXI master 自取帧) | **HEAD=STUBBED** (fb_*_dout=24'h0, 棋盘格是LUT test_mode); **工作区未提交WIP正在实现真fb** |

## 板2 fb 路径 WIP 已提交 (2026-06-22)
HEAD(62031f3)的 fb 是 stub(=0)。fb 路径实现已提交到**分支 `feat/icnd2047-fb-path` @ `535a862`** (基于 62031f3, 8 files +333/-8):
- `icnd2047_panel_seq.v` — fb_top/fb_bot 各 4096×24bit 双口 BRAM, AXI 写口 0x8000+ 灌帧, use_fb=1 显示真内容
- `gen_chess32.py`(128×64 编号棋盘) + `chess32.png` + `_fb_load.tcl`(灌帧+开use_fb, fb基址 0x40028000) + `_flash_fps.tcl`/`_fps.tcl`(fps测量) + `_setctrl.tcl` + `_la_ov.py`
- helloworld.c bridge 已写 CTRL=0x561(use_fb=1)+TUNIT=8 → 配这版 Verilog 才显示真内容
- **WIP: fb 路径上板验证待做**。调试产物 (la2.dsl/panel_cap.jpg/bd ipshared) 有意未纳入, 仍在工作区未跟踪。**未 push** (push 走 cmd.exe, 见 [[reference_git_push_via_cmd]])。

## 板1 FM6124 POV 部署流程 (2026-06-22 跑通: 冷启地球仪 + 热换anime)
板1 = JTAG cable SN 210251A08870, panel CTRL 基址 0x40020000, B1渲染IP 0x43C20000. xsct=`C:\Xilinx\Vitis\2024.2\bin\xsct.bat`, 经 `cmd.exe /c "cd /d D:\...\zynq_pov && xsct.bat tools\脚本.tcl"`.
- **🔴 一个 xsct session 干完所有事, 绝不先探测再断开重连** (会 churn 出 DAP 锁, 见 [[feedback_jtag_dl_reflash_loop_dead]] 2026-06-22 复现).
- **冷启 (断电后 PL bit 丢)**: `tools/_run_globe_cold.tcl` = connect→stop ARM→**fpga -file(单次)**→ps7_init→灌预渲染切片 `globe_slices_720_compact.bin`(5.7M→0x18000000)→启显示. 冷板必须 fpga 先于任何 AXI 写 (空 slave 写挂总线锁 DAP).
- **热换 (板已 live, 不重烧)**: `_run_anime_live.tcl` / `_run_b1_globe_live.tcl` = connect→CTRL=0 停DMA→灌新切片→重启显示. 无 fpga, 无 DAP 风险. anime↔globe 自由热换.
- **显示寄存器**: 0x14=t_unit(0x1FF=255满亮) / 0x08=PARAM(127=128列) / 0x18=SLICE_BASE(0x18000000) / 0x1C=ANGLE_PERIOD(14577≈490RPM **假周期手动**, 非自动) / 0x20=N_SLICES(720) / 0x00=CTRL(**0xC5E1**=sensor_en显示) / 0x24=DBG(DMA status, 非零=取帧在跑).
- 切片数据 (compact 5.7M / 非compact 45M) + globe_points.bin(B1现算路径用) 在工作区**未提交** (见上 fb WIP 同性质摊子).
- ✅ **转速自动检测(angle_tracker) 已集成进部署的 v8** (2026-06-23 核实, 推翻早前"v6没接入"误判): BD synth 网表 `x_ipName=hub75e_panel_seq_v8` (commit bb70adb 06-15). v8 line333 `sensor_en=reg_ctrl[15]`, line340 `.fake_en(~sensor_en).fake_period(reg_angle_period)`, line344 `slice_idx_live=trk_slice`(无条件来自 angle_tracker, sensor_pulse 不会被trim). **部署 CTRL=0xC5E1 bit15=1 → 真光电开关自动检测已开**, ANGLE_PERIOD(0x1C=14577) 退化成未lock时fallback. DBG(0x24) bit16=trk_locked: 本会话 globe locked=1 / anime locked=0. ⚠ 教训: 别拿磁盘旧版.v(v6)当部署真相, 必追 BD synth 网表用哪版 (v6未接→v7/v8接入). 待目视验证: 转动下 POV 是否真跟转(lock 稳).

## fps 现实 (详见 [[project_pov3d_panel_fps_roadmap]])
- 板1 FM6124: v6 dual 8205fps=22.8rev/s (1-bit全彩)
- 板2 ICND2047: v30 直连 7540@50M / 10919@72M (当前 W=128 单链, 1-bit). ⚠**6bit/overlap 9.5-11.5k 是拆daisy(W=16×8=48lane)之后的数, 不是当前**; 当前单链 W=128 跑 6bit 只 ~2k(移位卡). 1-bit 因plane少 W=128 单链仍 ~11.5k. **8bit 任何W都被 OE40ns 地板硬顶~3k**

关联: [[project_pov3d_icnd2047_p3_bringup]] [[project_pov3d_onchip_chain_handoff]] [[project_pov3d_globe_and_volumetric_render]] [[project_pov3d_dual_panel_v34g_chess]] [[reference_mtr_board_v01]] [[project_pov3d_panel_fps_roadmap]]
