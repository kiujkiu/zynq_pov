---
name: zynq_pov project goals and architecture (Phase 9 snapshot 2026-05-09)
description: POV-3D rotating LED display on Zynq 7020. Phase 8 mesh slice + Phase 9 ABDE 并行: HLS 4× IP 代码 / WiFi framework / QSPI fix / Blender warm bake.
type: project
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
**Project**: `zynq_pov` rotating-LED persistence-of-vision 3D display. Repo: https://github.com/kiujkiu/zynq_pov. WSL clone: `/mnt/d/claude_workspace/pov3d/zynq_pov/`. Windows: `D:\workspace\zynq_pov\`.

**Final spec**: 720 slices × 30 Hz × 160×180 pixels = 21600 slice/sec, LED panel + WiFi 数据链路 (鹿小班 SDIO 接口给 wifi).

**Phase 8 (2026-05-08~09) 进展** (experiment/triangle-mesh 分支, 14 commits, 已 push):
- ✅ B 路径 mesh→angle slice 算法实现 (host + 板端): scanline fill, tri∩plane segments, x-crossings 排序配对填充, Gouraud lerp. 板端 1.5 ms/cell, 24 cell × 2fb = 71ms.
- ✅ Wire 协议 v1/v2/v3 演化:
  - v1: 9B vert (xyz+rgb)+ 6B tri idx
  - v2: 6B vert + 9B tri (idx+rgb), per-tri color flat shading
  - v3: 8B vert (xyz+uv) + 6B tri + texture block (256² RGB), 板端 per-pixel texture sample
- ✅ 颜色质量探索: per-vertex baking → dominant tri → sat-weighted dominant → per-tri centroid → 7-point bary median + KDTree top-K. 都 hit "碎片色块" 上限.
- ✅ Blender PBR bake: tools 完整 (host/blender/bake_pbr.py + run_bake.bat), 安装 Blender 4.2 LTS via winget. baked GLB 颜色跟 voxel path Option B 等价 (都没显著超过).
- ⚠️ QSPI 启动: BD 启用 PS QSPI peripheral (Vivado tcl 自动化 tools/bd_enable_qspi.tcl), BSP regen 含 XQspiPs driver, ps7_init.c patch 加 QSPI MIO config, 但 multi-byte PolledTransfer 仍只 first 4 byte data 写入 (PS QSPI controller manual mode + 多 entry CS deassert quirk). erase + JEDEC 通, page program 失败. 工具链全就绪 (tools/bd_enable_qspi.tcl, qfw_run.ps1, dl_qspi_flash_writer.tcl).

**Phase 8 关键结论 (架构等价确认)**:
HDMI 颜色匹配 3D viewer 的本质瓶颈是**离散表达** (256³ voxel 或 6K~20K mesh tri). 所有路径 (mesh per-tri / mesh+texture / voxel point cloud / Blender bake) 都 hit 颜色质量上限. mesh path 真正价值在 **POV slice 产品输出** (mesh 切平面 = 实体填充连续切片, 点云切片 = 离散点散布, LED 上不连续).

**Phase 8 路径分工**:
- HDMI 视觉调试 → voxel point cloud (test_send_one.py + Option B PBR), 颜色调到接近 anime 3D viewer
- 产品 LED matrix slice 输出 → mesh slice (实体填充)

**主线下一步 (Phase 9 候选)**:
1. **720 angle slice pipeline 整合** — 当前 RIGHT 24-cell 是 dev preview, 产品需要 720 slice × 30Hz. ARM 24 × 2 fb = 71ms = 14 FPS, 24 angle. 720 angle 30Hz 需 23 ms/24-cell-batch = 必须 PL HW 加速 (HLS IP 类比 pov_voxel_slice_batch 但用 mesh 切平面算法).
2. **WiFi 数据链路** — 当前 UART 921600 (~92KB/s), wire 满 v3 textured 256KB 上传 ~3s. 720 angle live 30Hz = 不可能走 UART. 必须接 wifi (鹿小班 SDIO 已留给 wifi 模块). ESP32 bridge code stub 已存在.
3. **LED matrix 接通** — PCB 未订, 物理硬件介入. 接通后真实 POV 物理积分能验证视觉效果 (单 angle 切片本身不漂亮, 720 angle 旋转积分才有 3D 立体像).
4. **QSPI 启动** continue — multi-byte transfer 问题需深 debug Xilinx XQspiPs driver 内部 batched-trigger 实现, 或 Vivado 配置进一步调整. Tools 全就绪 (commit 4d1a02a / ac8294f).

**已 push 远端 (2026-05-09)**: experiment/triangle-mesh 14 commits 全 push, 包含 mesh slice + Blender bake + QSPI infrastructure. master branch 没动.

**Phase 9.5 (2026-05-09) 全部完成 + QSPI standalone boot 通过**:
- ✅ **F: Vivado 4× IP 综合**: bit 4MB 生成, util LUT 56%, FF 38%, BRAM 22.5%, DSP 38%, Timing WNS +0.240ns 通过 (0 Failing). tools/bd_4x_pov_project_batch.tcl (5 轮 debug).
- ✅ **G: Mesh slice HLS 移植**: hls_proj/mesh_slice.cpp + IP zip, min 73μs/cell estimate (20× ARM), LUT 97% 单 IP (4× 不行).
- ✅ **H: HLS pov_project_batch_v2 dual-HP**: Iter latency 65→27 (-58%), Fmax 205 MHz, 4×@150MHz=48K slice/sec ≥ 21.6K 目标. IP zip povlab_user_pov_project_batch_v2_2_0.zip.
- ✅ **I: ARM dual-core (XAPP1078 AMP)**: CPU1 159μs boot, render 30ms+→8174μs (3.7×), 60.54 FPS vsync-locked. live repo branch phase9.5-task-I-dual-core commit f8f3468.
- ✅ **QSPI standalone boot 解锁** (Phase 9 D 真正完成): SW3 真 boot mode 拨码 (toggle1 控制 MIO[2..6], toggle2 控制 MIO[7,8]; 老 SW1/SW2 = PL_KEY 无关). SW3 切 QSPI mode → BOOT_MODE=0x1 → 重 build hello_world.elf + bootgen 新 BOOT.bin (4246188 byte) + 烧 flash → power-cycle 自动 boot. UART "frame=N dT=4228228us (60.54 FPS) render avg=8174us" 跟 JTAG dl 一致, dual-core 同时启用. 完全 standalone.

**Phase 9 (2026-05-09 同日并行) ABDE 完成** (LED 屏未到 → 软件代码 deliverable, 无远端 push):
- ✅ **A: HLS 4× IP 设计** (主工作树, 未 commit). 性能 gap 量化: 单 IP @ 150MHz 2.8K slice/sec, 距 21.6K 目标差 ~8×; 4× 并行 → 11K, 仍需 IP 内部优化 (II→1, dataflow, dual-HP) 才达标. 文件: `tools/bd_4x_pov_project_batch.tcl` (axi_smc_pov_hp NUM_SI 2→8 + sc_pov_axilite 1→4 fan-out + 地址 assign + run synth/impl/bit + write XSA), `02_hello_zynq/vitis_ws/hello_world/src/pov_project_batch_4x.h` (driver: 4 IP 通过 phase+ring_base 偏移分工 18/72 slot 各, pov_project_batch 没 slot_start). 老 `voxel_slicer_4ip.h` 是 voxel path 备选 (HLS 源在 pov_project.cpp 但未综合).
- ✅ **B: WiFi framework** (worktree experiment/wifi-framework commit f662ed0, 未 push). PWFR 24B header (magic+ver+msg_type+seq+payload_len+CRC32+ack), 三模式 FULL/ROTATE/DELTA. 关键洞察: 720×30Hz=186 MB/s 超 WiFi 必须板端 cache+delta. 产物: docs/wifi_protocol.md + host/wifi_stream.py (267 行 dual-mode passthrough/pwfr) + wifi_recv_stub.c (PWFR FSM + 64KB ring + weak hooks). lwIP 接入低难度 (Vitis 自带 lwip220 + reference apps), 真正硬障碍 gmii_to_rgmii TX hung 不在 scope.
- ✅ **D: QSPI multi-byte transfer fix** (worktree experiment/qspi-multi-byte-fix 1b80d6b + 主工作树 qspi_flash_writer.c, 未 commit, 未 push). 根因不是 CS-deassert 硬件问题, 而是 Xilinx `qspips_v3_13/src/xqspips.c` L912-948 PolledTransfer 当 RecvBufPtr != NULL 且 (RequestedBytes - RemainingBytes) > 4 时, TX 写 XQSPIPS_DUMMY_TX_DATA (0xFFFFFFFF) 而非 SendBuf. 修法: write-only 命令 (wren/erase_block/program_page/EX4B) 全传 NULL 给 RecvBufPtr. 待硬件 verify.
- ✅ **E: Blender warm bake** (worktree experiment/blender-bake-warm 964e152, 未 push). bake_pbr.py 改 sunrise.exr HDRI strength 1.2 + 3 sun (Key 5500K/Fill 4500K/Rim 7000K 弱化), view=Standard + Medium High Contrast, samples 512→256 ~30s, diffuse_bounces=4. 视觉: highlights p95 R235/G220/B193 (旧 231/201/179 更暖). 产物: host/anime_62459_baked.glb + baked_vs_raw.png 三视图.

**Phase 9 主线下一步 (LED 到 + 硬件 verify 后)**:
1. 跑 `bd_4x_pov_project_batch.tcl` 实测 4× 是否 ~3.5× 加速 (HP1 单端口争用估降级)
2. HLS IP 内部优化 II→1 + dual-HP (HP1+HP2 分流) → 配合 4× 攻 21.6K 目标
3. QSPI fix 板上 verify (BOOT.bin 经 JTAG 加载到 DDR + 跑 dl_qspi_flash_writer.tcl 看 post-prog readback)
4. Mesh slice HLS IP 移植 (产品 LED slice path, 当前只 ARM software 实现 1.5ms/cell)

**架构 limit (Phase 8 confirmed)**:
- 板端 ARM mesh raster ~36ms (>vsync 16.6ms), HDMI LEFT 撕裂. 产品 path 走 slice 不影响.
- Mesh tri 上限 ~32K (BSS DDR 容量), wire vert idx u16 限 65K vert.
- 颜色质量 6K-20K tri × per-tri RGB 拿不出 anime 大色块 (帽/甲/靴 等高对比 detail).
