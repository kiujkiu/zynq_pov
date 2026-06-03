---
name: HLS pov_project_batch resynth 完整流程 (1024→32K 踩坑)
description: 改 HLS local_model 大小要清 impl/ 缓存, 增 IP 版本, BD 删冗余实例 (4×→1×), launch_runs 在 batch mode 不能 spawn 改用直接 synth_design
type: feedback
originSessionId: 25cdb314-8481-406a-9724-5d3798a00293
---
2026-05-13 把 `hls_proj/pov_project.cpp` 里 `MAX_BATCH_POINTS` 从 1024 改到 32768 让 HLS IP 能渲染完整 30803 个 anime voxel. 流程踩坑:

**1. HLS export 用 impl/ 缓存的旧 RTL**
- 改 cpp 后 `csynth_design` 生成新 syn/ RTL (AddressWidth=15 = 32768) ✓
- 但 `export_design` 从 impl/ 打包 IP, impl/ 没重 build → 还是旧 RTL (AddressWidth=10 = 1024)
- **解法**: 删 `proj_pov/solution1/impl/` 再 run_hls.tcl, 强制重 export

**2. Vivado upgrade_ip 同版本号不 pull 新代码**
- `update_ip_catalog -rebuild` 加载新 IP 进 repo, 但 IP 实例还锁旧版
- `upgrade_ip` 只在版本号变化时拉新 RTL
- **解法**: 改 run_hls.tcl 的 `export_design -version 1.0` → `1.1`

**3. Vivado batch mode `launch_runs` spawn 失败**
- `launch_runs synth_1 -jobs 8` 报 `ERROR: [Common 17-180] Spawn failed: No such file or directory`
- 同样 `-jobs 1` 也失败
- **解法**: 用 in-process `synth_design / opt_design / place_design / route_design / write_bitstream` 直接调, 不通过 launch_runs

**4. 32K × 4 个 IP 实例超 BRAM**
- 单实例 32K-deep × 6 ports = 144 BRAM, 4 实例 = 576 BRAM 超 Zynq-7020 的 280
- BD 里有 4 个 `pov_project_batch_{0,1,2,3}` 实例 (USE_PL_4X 用), 但当前 USE_PL=1 只用 IP 0_0
- **解法**: 写 tcl 删 IP 1/2/3 (`delete_bd_objs [get_bd_cells pov_project_batch_1]`), 保留 IP 0_0, 验证 BD + 重 synth, BRAM 降到 ~144 fits

**5. write_hw_platform XSA export 失败**
- 没经过 project run 不能 export XSA
- **解法**: 直接拷 bit 到 `hello_plat/hw/sdt/hello_zynq_wrapper.bit` 跳过 XSA, 因为 ARM #defines (寄存器 offset) 不变, hello_world.elf 不用重 build

**6. xsdb 加载 bit 后, JTAG mwr 注入 anime 数据**
- `dl_helloworld_with_anime.tcl`: rst -system + fpga -file + ps7_init + dow ELF + `dow -data anime_points.bin 0x1A000000` + 写 ANIME_MAGIC + con
- ARM helloworld.c 启动时检测 `*(0x1F000000) == 0xA11ECEC0` → skip build_model 直接用 JTAG-injected 数据
- model_n 从 BSS 在 0x0011c25c (用 nm 找)

**Why:** 调通 ESP32 WiFi 桥失败 (office AP 不让 TCP, Zynq UART COM 不知道哪个), 走 xsdb 直推路径, 把 anime GLB 用 voxelize_mesh → 16B PovPoint binary → 灌 DDR.

**How to apply:**
- 改 HLS local_model 大小: 删 `proj_pov/solution1/impl/`, 升 IP `-version` 号, 重 run_hls
- Vivado 同 process synth+impl: 用 `synth_design`/`opt_design`/`place_design`/`route_design`/`write_bitstream` 不要 `launch_runs`
- BRAM 紧张就删 BD 里未用的 IP 实例
- xsdb mwr 大量 binary 数据用 `dow -data <file> <addr>`, 别用 `mwr -bin -file` (那个语法在 Vivado 2024.2 xsdb 报 wrong-args)
