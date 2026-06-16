# 路线 B1 HLS IP — pov_render_full

点云直接进 FPGA, 芯片内一条龙做 **清网格 + 散射体素化 + gather 切片**, 出 LED compact 切片。
ARM 不参与渲染, 只把点云 DMA 进 DDR + 写触发寄存器。

扩展自已上板验证的 A 路径 (`pov_proj`): A 在 ARM 散射 (`pov_chain_src/main.c`),
B1 把散射搬进 HLS。gather 阶段逐字节复用 `pov_proj`。

## 文件
- `pov_render_full.h` / `pov_render_full.cpp` — 可综合 top (新, 不动现有 pov_proj)
- `pov_render_full_tb.cpp` — host g++ 测试台, 喂真实 anime 点云, 逐字节比对参考
- `run_hls_full.tcl` — csynth + export IP zip

## host 验证 (WSL, 不用 vitis_hls)
```
cd 02_hello_zynq/hls_pov
g++ -O2 -std=c++11 pov_render_full_tb.cpp pov_render_full.cpp -o pov_render_full_tb
./pov_render_full_tb
```
喂 `tools/anime_points.bin` (raw point_t[], 30803 点, 无头) + `tools/transform_lut.bin`。
参考 = ARM 同款散射 (main.c clip127) 造 grid + pov_proj gather 造 golden。
**结果: grid 全 cell match + 720/720 切片 100% 逐字节相同 (PASS)**。
另外 scratch grid 预填 0xAB 验证 Phase 0 清网格确实生效。

## 综合 (主进程跑, 我不跑)
```
D:\Vitis\2024.2\bin\vitis_hls.bat -f run_hls_full.tcl
```
产物: `proj_full/sol1/syn/report/pov_render_full_csynth.rpt`, `pov_render_full_ip.zip`
(vendor=povlab library=user version=1.0, part xc7z020clg484-2, clk 150 MHz)。

## top 接口
```c
void pov_render_full(
    const point_t *points,      // m_axi gmem_pts  读 n_points 个 point_t (DDR)
    voxel_t       *voxel_grid,  // m_axi gmem_vox  读+写 128^3 scratch (8 MB DDR)
    const lut_t   *lut,         // m_axi gmem_pts  读 16384 lut_t (同 pts bundle)
    uint32_t      *slice_base,  // m_axi gmem_out  写 compact 切片 (DDR ring)
    int n_points, int n_total, int slot_start, int n_slots);
```

## m_axi bundle 安排 (3 个 master)
| bundle    | port(s)            | 方向  | 用途 / 参数 |
|-----------|--------------------|-------|-------------|
| gmem_pts  | points, lut        | 读    | points + lut 同 bundle, adapter 参数**必须一致** (max_read_burst=64, num_read_outstanding=16), 否则 csynth ERROR 214-215 |
| gmem_vox  | voxel_grid         | 读+写 | Phase0 顺序 burst 写 / Phase1 随机写 / Phase2 随机读 (read+write outstanding=16, burst=64) |
| gmem_out  | slice_base         | 写    | widen 64 burst 写 ring (max_widen_bitwidth=64, write_burst=256) |

注: 比 pov_proj 多一个 m_axi 读端口 (points)。pov_proj 是 2 master (gmem0 读 vox+lut, gmem1 写)。

## 三阶段 (共享 voxel_grid DDR, 顺序依赖, 不能跨阶段 dataflow)
- **Phase 0 CLEAR**: 顺序写 0 到 128^3 voxel_grid (8 MB), II=1, 可 burst。
- **Phase 1 SCATTER**: 读 n_points point_t, `vx=clip127(x+64)` 同 y,z, 随机写
  `voxel_grid[(vx*128+vy)*128+vz]={r,g,b,0}` (last-write)。逐字节 == main.c。
- **Phase 2 GATHER**: == pov_proj。LUT->BRAM, 逐角度 gather (随机读 grid) -> pack -> burst 写 ring。

## csynth 资源 / II 预期 (估, 未跑)
- BRAM: lut_d/lut_wy (各 16384×16b) + slot_local (2048×32b) ≈ 20 BRAM18 / 280, 充裕。
  彩色网格 8 MB 留 DDR, **不进 BRAM** (7020 装不下)。
- DSP: gather 内层 d*cs / d*sn, UNROLL×8 ≈ 16 DSP。
- Phase 0 CLEAR ≈ 2.10M cell, widen 64 每拍 2 cell, II=1 ≈ 7 ms @150 MHz (一次性, 非热路径)。
- Phase 1 SCATTER ≈ 30K 点, 随机写无 burst, m_axi 延迟主导, ~ 百 us~1 ms 量级 (实测会高于估算)。
- Phase 2 GATHER 同 pov_proj: 每片 2048 word × II=8 = 16384 拍, 720 片 ≈ 11.8M 拍 ≈ 79 ms 理论,
  随机 DDR 读实测远超 (见 memory feedback_hls_cycle_estimate_optimistic) → 4-IP 并行 + 离线批算。
- 单 IP B1 全程被 Phase 2 主导; Phase 0/1 一次性开销 < 10 ms, 与 A 热路径量级一致。

## BD 集成清单
1. 灌 `pov_render_full_ip.zip` 进 Vivado IP repo, 替换/并存 pov_proj cell。
2. 三个 m_axi (gmem_pts / gmem_vox / gmem_out) 全接 axi_smc → **PS HP1** (复用现有 axi_smc_pov_hp)。
   - 比 pov_proj 多 1 个 master, 检查 SMC slave 口够数, 不够则加 1 口。
3. AXI-Lite control 接 PS GP (沿用 pov_proj 的 0x43C20000 段或新分配)。
4. voxel_grid 改为 **DDR scratch** (ARM 不再写, 8 MB, 可复用原 VOX_ADDR=0x1C000000)。
5. ARM 侧改动: **删掉 main.c 里的清网格 + 散射循环** (Phase 0/1 全搬进 IP), 只留:
   - JTAG/WiFi 把点云 (raw point_t[], 或带 PPC0 头自行剥) DMA 进 DDR (如 0x16000008)。
   - flush 点云到 DDR (HP1 读)。
   - 写触发寄存器序列 (见下) → 等 ap_done。

## ARM 触发寄存器序列
新 IP 多 `points_addr` + `n_points` 两个寄存器。**实际字节偏移由 HLS 生成的
`xpov_render_full_hw.h` 为准** (端口多了, 偏移会和 pov_proj 不同), 概念顺序:
```c
Xil_Out32(BASE + OFF_POINTS,     PTS_DATA_ADDR);  // 点云首地址 (剥头后的 point_t[])
Xil_Out32(BASE + OFF_VOXEL_GRID, VOX_SCRATCH);    // 8 MB DDR scratch
Xil_Out32(BASE + OFF_LUT,        LUT_ADDR);       // transform_lut.bin @ DDR
Xil_Out32(BASE + OFF_SLICE_BASE, RING_ADDR);      // compact ring
Xil_Out32(BASE + OFF_N_POINTS,   n_points);
Xil_Out32(BASE + OFF_N_TOTAL,    720);
Xil_Out32(BASE + OFF_SLOT_START, 0);
Xil_Out32(BASE + OFF_N_SLOTS,    720);
Xil_Out32(BASE + 0x00, 0x1);                      // ap_start
while (!(Xil_In32(BASE + 0x00) & 0x2)) { ; }      // 等 ap_done
```
参考 pov_proj 当前偏移 (AP=0x00, VOX=0x10, LUT=0x1C, SB=0x28, NT=0x34, SS=0x3C, NS=0x44);
B1 因多 2 个 scalar + 1 个 addr, 偏移整体后移, 必须读生成头确认。
4-IP 并行: IP_i 用 `slot_start=i*180, n_slots=180` (但散射/清网格只需 1 个 IP 做,
其余 3 个 IP 只跑 Phase 2 gather — 否则 4 份散射写同一 grid 冲突; 见下方"4-IP 注意")。

## 4-IP 并行注意
B1 把散射纳入 top, 若 4 个 B1 IP 都跑会 4 次清网格 + 4 次散射写同一 grid (浪费 + 写竞争)。
推荐分工: **1 个 B1 IP (slot_start=0,n_slots=180) 做完整三阶段**, 另 **3 个仍用 pov_proj**
(只 gather, slot_start=180/360/540) 共享同一 grid。需保证 B1 的 Phase0/1 在 3 个 pov_proj
启动**之前**完成 (ARM 串行触发: 先 B1, 等其 Phase1 完成的屏障, 再触发 3×pov_proj)。
HLS 无内建跨 IP 屏障, 最简单做法是 ARM 先单独触发"只清+散射"再触发 4 个纯 gather —
即把 Phase0/1 拆成独立 IP (后续可做)。当前 B1 单 IP 已端到端正确, 多 IP 优化留后。
另注: memory feedback_pov_4x_ip_breaks_hdmi — 4× 同时 fire 曾破坏 HDMI (HP1 仲裁/cache),
4-IP 仍是离线批算路径, 非显示热路径。
```
