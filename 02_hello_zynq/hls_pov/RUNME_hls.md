# RUNME_hls — pov_proj IP 综合 / 集成 / 触发 (主进程执行)

> 我 (子 agent) 不跑 Vivado/Vitis/JTAG。下面是给主进程统一构建的步骤。
> 对齐 memory `feedback_hls_resynth_full_flow` 的踩坑流程。

目录: `02_hello_zynq/hls_pov/`
文件: `pov_proj.{cpp,h}` + `cos_sin_q15.h` + `run_hls.tcl` + `pov_proj_tb.cpp`

---

## 0. (已做) host 逻辑验证 — 无需 Vivado

```bash
cd 02_hello_zynq/hls_pov
# 产输入 (globe voxel + LUT + golden), Windows python:
cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\hls_pov && %LOCALAPPDATA%\Programs\Python\Python312\python.exe _gen_tb_inputs.py"
g++ -O2 -std=c++11 pov_proj_tb.cpp pov_proj.cpp -o pov_proj_tb && ./pov_proj_tb
# 期望: RESULT: PASS  (701/720 片 bit-exact vs PC golden, 19 片 ±1voxel 量化差)
```

## 1. Vitis HLS 综合出 IP

```
cd D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\hls_pov
D:\Vitis\2024.2\bin\vitis_hls.bat -f run_hls.tcl
```
- 看 `proj_povproj/sol1/syn/report/pov_proj_csynth.rpt`: BRAM(~22)/DSP/II/Timing。
- 改 cpp 后重综合: **先删 `proj_povproj/sol1/impl/`** (否则 export 打包旧 impl RTL,
  memory 踩过), 并把 `run_hls.tcl` 的 `-version 1.0` 递增。
- batch mode 不能 `launch_runs`; HLS 这步是 `csynth_design`/`export_design`, 没问题。

## 2. 加进 Vivado BD

显示链 BD 在 `02_hello_zynq/02_hello_zynq.srcs/sources_1/bd/hello_zynq/`。

a. IP repo: 把 `pov_proj_ip.zip` 解压进 IP 目录, `update_ip_catalog -rebuild`。
   同版本号不 pull 新 RTL → 改 IP 时必须升 `-version` (memory 踩过)。
b. `create_bd_cell -type ip -vlnv povlab:user:pov_proj:1.0 pov_proj_0`。
c. 时钟/复位: `ap_clk`/`ap_rst_n` 接显示 IP 同 FCLK (单时钟域)。
d. **HP 口分配 (避 HDMI/显示仲裁坑, 见 DESIGN_hls §5)**:
   - 显示 IP `m_axi` (DMA 读 compact) 走 **HP0**。
   - pov_proj `gmem0` (读 grid+lut) 走 **HP2**, `gmem1` (写 ring) 走 **HP3**
     (或 HP2 共享但与显示 HP0 分开)。经 axi_smc 连 PS7 S_AXI_HPx。
   - 不要把 pov_proj 的 master 和显示 IP 的 master 合到同一个 SmartConnect 段。
e. `s_axilite control` 接 AXI-Lite, 分一个地址段 (如 `0x43C30000`),
   `assign_bd_address`。
f. DDR 地址映射 (Address Editor): grid/lut/ring 都在 PS DDR, master 段覆盖
   0x10000000–0x1FFFFFFF 即可。
g. validate → 综合 → impl → bitstream。BRAM 紧张时删 BD 里未用旧 IP 实例
   (`delete_bd_objs [get_bd_cells pov_project_batch_*]`)。

## 3. DDR 内存布局 (ARM 侧约定)

| 区 | 地址 | 大小 | 说明 |
|--|--|--|--|
| compact ring (slice_base) | `0x18000000` | 720×8KB = 5.76MB | **= 显示 IP SLICE_BASE** (pov_boot HUB_SLICEBASE 已用此值) |
| transform LUT | `0x1B000000` | 64KB | `transform_lut.bin` 灌入 |
| voxel grid (彩色) | `0x1C000000` | 8MB | 128³×4B `voxel_t{r,g,b,pad}` |

⚠ 老 helloworld 把 `VOXEL_GRID_ADDR=0x18000000` (RGB565 旧 grid) — **新路径冲突**,
新 grid 移到 0x1C000000, 0x18000000 专给 compact ring。

## 4. 软件触发 (ARM, 批算模式)

```c
#define POVP_BASE     0x43C30000U   /* BD assign 的地址 */
#define POVP_AP_CTRL  (POVP_BASE+0x00)
/* offset 寄存器按 csynth 生成的 driver header (xpov_proj_hw.h) 取, 名字形如
 * XPOV_PROJ_CONTROL_ADDR_VOXEL_GRID_DATA 等. 下面用占位 offset 说明流程: */

/* 1) host/ARM 准备 voxel grid + LUT 到 DDR */
load_voxel_grid_to(0x1C000000);          /* 8MB, 各通道 0 或 255 (阈值>=128) */
load_file("transform_lut.bin", 0x1B000000);
Xil_DCacheFlushRange(0x1C000000, 8*1024*1024);
Xil_DCacheFlushRange(0x1B000000, 64*1024);

/* 2) 写参数寄存器 */
Xil_Out32(POVP_VOXEL_GRID, 0x1C000000);
Xil_Out32(POVP_LUT,        0x1B000000);
Xil_Out32(POVP_SLICE_BASE, 0x18000000);
Xil_Out32(POVP_N_TOTAL,    720);
Xil_Out32(POVP_SLOT_START, 0);
Xil_Out32(POVP_N_SLOTS,    720);

/* 3) ap_start, 等 ap_done (单 IP). 多 IP 必须 latch done (clear-on-read, 见 memory) */
Xil_Out32(POVP_AP_CTRL, 0x1);
while (!(Xil_In32(POVP_AP_CTRL) & 0x2)) { /* poll ap_done bit1 */ }

/* 4) 整个 ring flush, 再让显示 IP DMA (避 cache-stale) */
Xil_DCacheInvalidateRange(0x18000000, 720*8192);  /* IP 写过, 让 CPU 视图刷新; 实际显示IP直接DMA DDR */
/* 显示 IP CTRL 已是 compact_en+dma_en (pov_boot 0xC5E1), 自动跟 angle_tracker 扫片 */
```

**多 IP 并行** (冲性能时): 4 个 cell 各设 `slot_start = i*180, n_slots=180`,
全部 ap_start, **latch done_mask 等齐** (memory `feedback_hls_ap_done_clear_on_read`),
再 flush ring。每 IP 独立 HP 口。

## 5. 性能优化版 (后续, 见 DESIGN §6)

DDR-grid 单 IP ~1.6fps (16384 随机读/片瓶颈)。达标路径:
**1-bit voxel grid (128³=2Mb) 塞片上 BRAM** → 随机读变 1-cycle → 单 IP >9000 片/s 过标。
届时改 `voxel_grid` 为内部 `static` BRAM + 开头一次 DMA 载入 (类似 LUT)。
