---
name: 2026-06-16-a
description: "点云→ARM体素化→pov_proj切片→显示 链(路线A)已 build+跑, slices=anime 大概率通; 诊断\"grid空\"是采样bug(步进512=128倍数只扫vz=0); 路线B(点投影HLS)未做; 双板JTAG按cable序列号区分"
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-16 14:43 CST
  updated_at: 2026-06-16 14:43 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

## 当前进度 (branch debug/fm6124-v29, 最新 commit e8bb6f9)
HLS 芯片现算切片**已上板跑通**(见 [[project_pov3d_hls_onchip_render]]). 在此基础上做"发点云全芯片":

### 路线 A: 点云→ARM体素化→pov_proj切片→显示 ✅ 已确认通 (2026-06-16)
**确认**: _diag_chain2.tcl 用互质步进(1009)重扫 grid → 8000 抽样 72 非零 + 中心列非零 → ARM 真填了 grid; slices 58/21 非零=anime. 点云(100k)→ARM体素化→pov_proj切片→显示 全芯片端到端通. (之前 _diag_chain "grid 0" 是步进 512=128倍数只扫 vz=0 平面的采样 bug.) 报告: D:\claude_workspace\pov3d\onchip_pipeline_report.html (流程+占用+速度+拓展).
整设计占用(impl): LUT 24.3% / FF 15.9% / BRAM 35.4% / DSP 14.5%, 余量大. 速度: ARM体素化~50-100ms + pov_proj 720片~700ms (一次) + panel 9800片/s 连续 = 13.6体帧/s上限.

#### (历史) 路线 A build + 首跑记录
- ARM app: `02_hello_zynq/vitis_ws/pov_chain_src/main.c` (+ build_pov_chain.py). 编译 OK (pov_chain.elf 28KB).
  读点云头(PPC0+count)@0x16000000 → invalidate cache → 体素化成 **voxel_t 4字节**(r,g,b,pad)网格@0x1C000000 → flush → 写 pov_proj 寄存器 ap_start 等 done → 配显示 sensor CTRL=0xC5E1.
- 测试 `tools/_run_chain_anime.tcl` (冷启动安全): 注入 anime_points_hdr.bin@0x16000000 + transform_lut.bin@0x1B000000 → dow elf → con.
- **跑的结果**: magic=PPC0 count=100000 ✓; ELF 跑到底(显示 CTRL=0xC5E1 是 ELF step4 设的); pov_proj AP idle; **slices 58/32/21/34 非零 word = 对得上 anime(非 globe), 说明 pov_proj 切了被填充的 grid → 链大概率通**.
- ⚠ **诊断陷阱**: `_diag_chain.tcl` 扫 grid 用步进 512 voxel, 512 是 128 倍数 → vz=(i*512)%128=0 只扫 vz=0 平面(居中 anime 在 vz44-83 本来空)→ 误报"grid 全 0". **不是 grid 空, 是采样 bug**. 下次确认用非 128 倍数步进, 或直接转电机看 anime.
- **下次第一件事**: 转电机看是不是 anime(确认路线A真通), 或修 _diag_chain 采样步进重扫 grid.

### 路线 B1: FPGA 体素化+gather 一条龙 ✅ 上板跑通 (2026-06-16)
**点云直进 FPGA, 芯片清网格+散射体素化+gather 全包, ARM 不碰渲染.** (注: B 最终选 B1 = FPGA 先体素化再 gather, 不是 B2 点投影 — 对 100k 点 gather 比投影省 6×, 且 pov_proj gather 已验证.)
- HLS IP `02_hello_zynq/hls_pov/pov_render_full.cpp` (top pov_render_full). 三阶段: Phase0 清8MB grid(burst) + Phase1 散射点云→voxel_t网格(逐字节==ARM main.c) + Phase2 gather(复用 pov_proj). 3 m_axi: gmem_pts(points+lut)/gmem_vox(scratch)/gmem_out(slice). host tb 100% 逐字节. 综合 205MHz, BRAM 51/280, LUT 12474.
- BD: `integrate_b1.tcl` 替换 pov_proj_0→pov_render_full_0, 3 master→axi_smc_pov_hp S00/S01/S02→HP1, control@**0x43C20000**. (ip_repo_paths concat!) validate OK, bitstream met.
- **寄存器 base 0x43C20000**: 0x00 AP, 0x10 POINTS, 0x1C VOXEL_GRID(scratch), 0x28 LUT, 0x34 SLICE_BASE, 0x40 N_POINTS, 0x48 N_TOTAL, 0x50 SLOT_START, 0x58 N_SLOTS.
- 板端 `tools/_run_b1.tcl`(冷启动) / `_run_b1_globe_live.tcl`(live换点云): anime 100k → grid散射43/slice0 58; 地球仪 128944点(`_globe_to_points.py` 从 tb_globe_voxel.bin 转) → grid 262/slice0 344. done ~900ms. xsdb 只注入点云+写寄存器, ARM 不参与.
- 地球仪点云 `globe_points.bin`(128944点) = globe shell voxel 转点.

### 路线 B2: 点投影 HLS (没做, 不推荐)
点→切片直接投影无网格. 但 100k 点 = 720×100k=72M 投影 >> gather 11.8M, 且要 z-buffer 防残影. 仅点很稀疏(<16384)才划算.

## 双板 JTAG (用户要接第二个下载器 + 第二块鹿小班)
- 每根 cable 唯一 `jsn-<型号>-<序列号>`. 转子板 cable = **jsn-JTAG-SMT2-210251A08870-...** (Digilent SMT2, 也见过 jsn-DLC10-0000153f74cd01).
- 两板同时接 → 有两个 APU target, 现有脚本 `targets -filter {name=~APU*}` 歧义. 必须加 cable 过滤: `targets -set -filter {jtag_cable_name =~ "*<序列号>*"}`.
- 流程: 两根接好 → `jtag targets` 列两序列号 → 用户标注哪个=转子/哪个=新开发板 → 脚本钉 cable. 新板专门 build/调, 不碰转子板(省 DAP 锁 + 冷循环).

## 关键地址 / 寄存器
点云@0x16000000(PPC0 magic 0x30435050 + u32 count + point_t[]), LUT@0x1B000000, voxel_t网格@0x1C000000(128³×4B=8MB), compact ring@0x18000000. pov_proj base **0x43C20000** (0x00 AP_CTRL, 0x10 VOXEL_GRID, 0x1C LUT, 0x28 SLICE_BASE, 0x34 N_TOTAL, 0x3C SLOT_START, 0x44 N_SLOTS). 显示 0x40020000 CTRL=0xC5E1 sensor.
关联 [[project_pov3d_hls_onchip_render]] [[feedback_jtag_dl_reflash_loop_dead]] [[feedback_sensor_const0_panel_spi_miso_workaround]].
