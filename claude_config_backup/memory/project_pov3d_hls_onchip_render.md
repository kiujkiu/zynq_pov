---
name: hls-pov-proj-2026-06-16
description: "新 HLS IP pov_proj (架构B 体素gather+transform LUT) 替换旧 pov_project_batch, 集成 BD HP1 跑通; PC 只送体素+LUT, 芯片 700ms 现算 720 片, 跟 PC 100% 逐字节"
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-16 14:17 CST
  updated_at: 2026-06-16 14:17 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

## 成果 (2026-06-16, branch debug/fm6124-v29)
把切片生成从 PC 搬上芯片. PC 不再算+传 5.76MB 切片, 只送 **8MB 体素网格 + 64KB transform LUT**, 芯片 HLS IP 现算全部 720 片到 DDR, 显示 IP 直接 DMA.

## HLS IP: pov_proj (hls_pov/pov_proj.cpp)
- 架构 B: 体素 gather, 复用 transform_lut.bin (固化 panel 变换). top function 吃 voxel_grid(m_axi gmem0)+lut(gmem0)+slice_base(gmem1 写), s_axilite control.
- 综合: 150M 目标实测 205MHz, BRAM 14%/DSP 7%. 720 片 ~0.168s 理想 / 实测 ap_done ~700ms (DDR 随机读, 对上 0.6s 估算).
- **m_axi 同 bundle 坑**: gmem0 上 voxel_grid+lut 的 max_read_burst_length/num_read_outstanding 必须一致, 否则 csynth ERROR 214-215. 统一 64/16.
- 100% 逐字节 == PC: PC 切片生成必须用同套 **Q15 定点** (tools/_q15.py: round(cos*32768) clamp int16 + round-half-away), 替换 float np.rint. 否则 ±1voxel 量化差 (97.4%→100%).

## BD 集成 (02_hello_zynq/integrate_pov_proj.tcl)
drop-in 替换旧 pov_project_batch_0 → pov_proj_0, **复用旧 pov 基础设施**: axi_smc_pov_hp→HP1, sc_pov_axilite (control@**0x43C20000**), proc_sys_reset_pov@FCLK3. gmem0/gmem1→HP1 (跟显示 HP2 / VDMA HP0 隔离, 避 [[feedback_pov_4x_ip_breaks_hdmi]] 仲裁坑). HLS IP 接口名跟旧的一样 (m_axi_gmem0/gmem1/s_axi_control, 同 HLS bundle 命名) → 真 drop-in.
- ⚠⚠ **ip_repo_paths 必须 concat 追加, 不能 set 替换!** 替换会丢 $PPRDIR/../vivado-library (rgb2dvi TMDS) → hdmi_tmds 接口定义找不到 → BD 锁死 validate fail, 且 close_project 把坏 .xpr 存盘. 踩过, git checkout .bd/.bda/.xpr 恢复.

## 寄存器 (base 0x43C20000, xpov_proj_hw.h)
0x00 AP_CTRL (bit0 ap_start, bit1 ap_done, bit2 ap_idle), 0x10 VOXEL_GRID, 0x1C LUT, 0x28 SLICE_BASE, 0x34 N_TOTAL, 0x3C SLOT_START, 0x44 N_SLOTS.

## DDR 布局 (板端测试 tools/_run_hls_globe.tcl, 冷启动安全)
voxel grid(voxel_t{r,g,b,pad} 128³×4B=8MB)@0x1C000000, LUT@0x1B000000, compact ring@0x18000000(=显示 SLICE_BASE). 流程: 注入 voxel+LUT → 写参数 → ap_start → poll ap_done → 配显示 sensor CTRL=0xC5E1.

## 性能 / 后续
DDR 网格 ~700ms/720片 = 静态内容够 (发体素现算). 30fps 动图(21600片/s)需 **1-bit voxel grid 塞 BRAM** + 多 IP, 且真瓶颈在 panel 显示(9800<21600, 需 48-SDI [[project_pov3d_48sdi_io_plan]]) + 1800RPM 转子. 彩色 128³×3bit=6.3Mb>BRAM 4.9Mb 塞不下. 关联 [[project_pov3d_globe_and_volumetric_render]] (ARM 版 + 交错), [[feedback_angle_tracker_two_interp_bugs]], [[project_pov3d_final_target]].
