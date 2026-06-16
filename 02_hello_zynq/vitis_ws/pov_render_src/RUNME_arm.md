# RUNME_arm — ARM 板端点云→切片渲染 集成手册

把原来 PC 做的切片生成搬到 Zynq-7020 ARM Cortex-A9 裸机。ARM 读 DDR 里的
点云 + transform LUT，体素化 + 逐角度切片 + compact 打包，写 `0x18000000`，
配 HUB75E IP 起 panel。**计算逻辑已 host gcc 逐字节验证 == PC 管线**。

> 工具链 (Vivado/Vitis/xsdb) 与板子是共享资源，本手册只给命令，由主进程执行。

---

## 0. 文件清单 (本目录 pov_render_src/)

| 文件 | 作用 |
|---|---|
| `pov_render.h` / `pov_render.c` | 纯计算 (voxelize / gen_slice / gen_all)，无硬件依赖，可移植 Linux |
| `pov_platform.h` | 平台层：DDR 基址 + map + cache flush + HUB 寄存器/FCLK1。**Linux 只换这个** |
| `main_render.c` | 裸机入口 |
| `host_render.c` | host gcc 驱动 (验证用，不进板端 build) |
| `RUNME_arm.md` | 本文件 |

配套 tools/：`_verify_arm.py` (逐字节验证)、`_make_pts_hdr.py` (点云加头)。

DDR 内存图 (裸机，定义在 `pov_platform.h`)：

```
0x16000000  点云: [u32 magic='PPC0'=0x30435050][u32 count] + count×16B point_t
0x16400000  transform_lut.bin (64 KB = 16384×2×int16)
0x16800000  vox scratch (128³×3 = 6 MB)，main 启动清零
0x18000000  slice 输出 (720×8 KB = 5.76 MB) = HUB_SLICEBASE
```

---

## 1. host 逻辑验证 (无需板子，先做)

```bash
cd /mnt/d/claude_workspace/pov3d/zynq_pov
python3 tools/_verify_arm.py
```

预期输出：

```
[FLOAT] BYTE-EXACT MATCH (5898240 bytes, 720 slices)
[FIXED] DIFFERS: 265/5898240 bytes ... 0.0010% of all bits
```

FLOAT 后端 (裸机默认) 与 PC 管线 `anime_slices_720_compact.bin` **逐字节全等**。
FIXED 是可选纯整数后端 (`-DPOV_USE_FIXED`)，仅亚像素差异 (见末尾)。

---

## 2. 用 Vitis CLI 建 app

参考 `vitis_ws/build_pov_boot.py`，改 SRC + import 多个文件。在 **Windows** 跑
(Vitis 在 Win，WSL 走 `cmd.exe /c`)：

```python
# build_pov_render.py  (放 vitis_ws/)
import vitis
WS   = r"D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\vitis_ws"
XPFM = r"D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\vitis_ws\hello_plat\export\hello_plat\hello_plat.xpfm"
SRC  = r"D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\vitis_ws\pov_render_src"
client = vitis.create_client(); client.set_workspace(path=WS)
try: client.delete_component(name="pov_render")
except Exception as e: print("no old:", e)
comp = client.create_app_component(name="pov_render", platform=XPFM,
        domain="standalone_ps7_cortexa9_0", template="empty_application")
comp = client.get_component(name="pov_render")
comp.import_files(from_loc=SRC,
        files=["main_render.c","pov_render.c","pov_render.h","pov_platform.h"],
        dest_dir_in_cmp="src")
comp.build()
print("POV_RENDER_BUILD_DONE")
vitis.dispose()
```

跑 (从 WSL)：

```bash
cmd.exe /c 'cd /d D:\Xilinx\Vitis\2024.2 && call settings64.bat && vitis -s D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\vitis_ws\build_pov_render.py'
```

产物 ELF：`vitis_ws/pov_render/build/pov_render.elf`。

> 注意 (memory `feedback_new_machine_setup_gotchas` / `refresh_bit_stale_xsa`):
> 平台 .xsa 由 Vivado 写到 `hello_plat/hw/`，若换了 PL IP 先 regen platform。

---

## 3. 注入数据 + 烧 bit + 跑 (xsdb)

先生成带头点云 (一次)：

```bash
cd /mnt/d/claude_workspace/pov3d/zynq_pov
python3 tools/_make_pts_hdr.py     # -> tools/anime_points_hdr.bin (1600008 B)
```

xsdb 脚本 (参考 `tools/_run_720_sensor.tcl` 的烧 bit 序列，把 720 compact
注入换成点云 + LUT，slice 由 ARM 自己算)：

```tcl
# _run_arm_render.tcl
set bit   "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
set elf   "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/pov_render/build/pov_render.elf"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
connect
after 800
# 停 DMA + 两核再烧 (避免烧 bit 瞬间 AXI 飞事务挂 DAP)
targets -set -nocase -filter {name =~ "APU*"}; configparams force-mem-access 1
mwr -force 0x40020000 0x0; after 400
targets -set -nocase -filter {name =~ "ARM*#0"}; catch { stop }
targets -set -nocase -filter {name =~ "ARM*#1"}; catch { stop }
targets -set -nocase -filter {name =~ "APU*"}
fpga -file $bit; after 500
source $psinit; ps7_init; ps7_post_config
mwr 0xE0000018 0x12; mwr 0xE0000034 0x05   ; # UART baud (可选)
configparams force-mem-access 1
# 注入点云 + LUT (slice 由 ARM 现算, 不再 dow 5.76MB)
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/anime_points_hdr.bin" 0x16000000
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/transform_lut.bin"     0x16400000
# 跑 ELF (main_render 体素化+切片写 0x18000000, 配 FCLK1+HUB 寄存器)
targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
con
after 2000
puts "CTRL=[format 0x%X [mrd -force -value 0x40020000]]"
exit 0
```

跑：

```bash
cmd.exe /c 'cd /d D:\Xilinx\Vitis\2024.2 && call settings64.bat && xsct D:\claude_workspace\pov3d\zynq_pov\tools\_run_arm_render.tcl'
```

UART (115200) 应打印 `point cloud: 100000 points` → `voxelized.` →
`generated 720 slices @ 0x18000000` → `HUB started, CTRL=0x0000c5e1`，panel 出
anime。

> ELF 也可由 FSBL 从 QSPI 自启 (替换现 pov_boot)，点云+LUT 同样按 BIF 数据
> 分区预加载 (`[load=0x16000000]` / `[load=0x16400000]`)，参考 pov_boot 的 BIF。

---

## 4. DAP 挂死兜底

(memory `feedback_jtag_dl_reflash_loop_dead`) 一 session 内 `fpga -file` 5+ 次
或多次 kill hw_server → DAP sticky 锁死，`rst -dap` 救不了，必须用户**冷循环板子**。
`xsdb jtag targets 空` → 先 `taskkill /F /IM hw_server.exe` + 板子冷循环。

---

## 5. Linux 移植影响 (计算零改)

切 PetaLinux 时**只改 `pov_platform.h`**，`pov_render.c` / `main_render.c` 不动：

1. **reserved-memory**：device-tree 给 `0x16000000`、`0x16800000`、`0x18000000`
   划 `reserved-memory` 节点 (`no-map` 或 `shared-dma-pool`)，避免 kernel 占用。
2. **指针**：`pov_map()` 改 `mmap(/dev/mem, phys)` (头里已有 `POV_PLATFORM_LINUX`
   stub)。reserved-memory 推荐 `/dev/mem` + `O_SYNC`，或走 `/dev/uioN`。
3. **cache**：`pov_cache_flush()` 改 `msync(MS_SYNC)`；若 reserved-memory 标
   non-cacheable 可直接 no-op。
4. **寄存器**：`pov_reg_wr/rd` mmap HUB_BASE 一页 + SLCR (FCLK1 改由 device-tree
   `fclk` 或 `/sys/.../fclk` 设，可不在 userspace 写 SLCR)。

`pov_render.c` 是纯 ISO C (只用 `stdint`/`stddef`/`math`)，host gcc 与
arm-none-eabi / aarch64 linux gcc 都已验证编译通过。

---

## 6. 性能 (ARM Cortex-A9 @ 666 MHz)

- 工作量：720 片 × 16384 采样 = **11.8M 次**投影+采样+pack。
- 每次约：2 次乘 (d·cos/d·sin) + 2 次 round/clip + 1 次 vox gather (cache miss
  风险) + 3 次阈值 + shift/or。乐观 ~20–40 cyc/采样 (gather 主导)。
- 粗估：11.8M × 30 cyc ≈ **354M cyc ≈ 0.53 s @666 MHz** (单核，含 cos 表已建)。
  vox 6 MB 远超 L1/L2，gather 随机访问 → 实测大概率 **1–2 s** 量级。
- **可接受**：静态内容**算一次**即可 (非实时环)，开机/换模型时跑一遍。

优化方向 (按性价比)：
1. **double 投影只算 16384 次/片的 d·cos** — 已是最简；cos/sin 每片 2 次。
2. **dual-core**：把 720 片按角度劈成两半给 core1，近 2×。memory
   `feedback_dual_core_uart_desync` 提醒别和 UART rx 抢；这里 core1 纯算无 IO，安全。
3. **vox 访问局部化**：按 wy 外层、d 内层可提升 cache 命中 (当前 fwi 顺序已由
   LUT 固化，不能重排否则破坏 compact 布局 → 留作 scratch 中转优化)。
4. **Q15 定点** (`-DPOV_USE_FIXED`)：省 VFP，但 A9 有 VFP，浮点不是瓶颈
   (gather 才是)，且定点有亚像素差异 → 不推荐。

---

## 附：FLOAT vs FIXED 后端

- **默认 FLOAT** (`pov_render.c` 无宏)：double cos/sin + C99 `rint`
  (round-half-to-even)，与 numpy `np.rint` **逐字节全等**。A9 带硬件 VFP，
  静态算一次，选最精确。
- **FIXED** (`-DPOV_USE_FIXED`)：Q15 cos/sin 表 + 整数乘 + 显式 half-even。
  实测仅 489 lit-bit / 10 片不同 (0.001% bits)，1-bit 显示下亚像素不可见。
  残差源于 cos 表量化让极少数样本在 `.5` 边界偏 1 像素；提到 Q30 仍剩 128 个
  数学固有半整数 tie，非 bug。无 FPU 平台才用。
