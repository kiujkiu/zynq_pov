---
name: project_dr1_parity_plan
description: DR1V90 对齐 Zynq 的完整差距清单与 7 步计划; 对齐目标是 15.00 fps 不是 10-11.4; 最大未知(PS/SoC)已找到厂商模板 HP0=64bit p2f_clk 6.25-200MHz
metadata:
  type: project
---

# DR1V90 → Zynq 功能/性能对齐: 差距与计划 (2026-08-07 盘定)

## 📍 进度 (截至 2026-08-10): 7 步走完 4 步

| 步 | 状态 | 实测 |
|---|---|---|
| 0 前置 | ✅ | 引脚补齐 `spin_sync_i=W6`; 板上取回真实内存图 |
| 1 SoC 骨架 | ✅ | GP0 窗 `0x8000_0000` 读写正确; HP0 写 DDR 返回 OKAY |
| 2 屏驱引擎 | ✅ 电气 | 50MHz SWNS +7.88ns; 假转 +181 片/100ms(理论 180) |
| 3 DDR 取片 | ✅ | **FETCH_ERR = 0 / 148,561 字**; 25.5 片/秒 |
| 4 转角追踪 | ✅ 假转 | `locked=1` |
| 5 推流闭环 | ✅ **08-10 上板跑通** | 端到端 PC→WiFi→pov_rxd→DDR, `drop=0` `rx==flip`; **zlib 3.5-3.75 fps**; 🔴 `cpy=162ms` 是新墙 |
| 6 PL lz4 | ⏸ | 3 引擎 @75MHz; 🔴 **必须直接写进帧 bank**, 见下 |
| 7 fps 对照 | ⏸ | 🎯 **flip 速率不需要接屏就能测** |
| — 接屏 | ⏸ | 🔴 **唯一需要动手的**: 50 针排线从 Zynq 挪到 DR1 的 J12 |

**功能侧 DR1 已全面对齐, 且在三处更好**: PL 资源更宽裕(slice 3.69% vs LUT 5.08%)、
HP 口 64 位(Zynq 只用 32)、bitstream 运行时重配(不用 JTAG 不用重启)。
**性能侧唯一硬缺口是 CPU 解码慢 2.15×**, 这正是 PL 解码器要补的。

## 📌 2026-08-10 收工时的在途状态 (DR1 窗口从这里接着做)

**板子当前是热的, 不用重来**: PL 已加载 / povmem 已 insmod(`phys_base=0x1a100000`) /
引擎开着假转 15 rev/s / WiFi `10.10.21.51` / `pov_rxd` 在跑。
重启后一条命令恢复: `tools/serial_run.sh board/cmds_restore_all.txt 300`。

**未提交的改动**(都在工作区, 已过 x86 回归 + 板上验证):
- `board/pov_rxd/pov_rxd.c` —— 给 `cpy` 加了 `flush` 分项计时(`cpy` 总数口径不变)。
  已重编 + 部署到板上 `/tmp` 与 TF 卡, 部署的 `pov_rxd` md5 = `7c6d07e2fab926ac4eb57e5293626f70`。
- `tools/stage_to_card.sh` —— 加了 md5 跳过(先问板上已有什么, 一致的不传)。
  WiFi 那两个 tarball 4.66 MB 因此免传, 重新 stage 从 ~12 分钟降到 ~1 分钟。
  MANIFEST 永不跳过, 且走 `.new`+`mv` 落地。
- `board/cmds_step5_run.txt` —— 删掉了 `MAGIC 0x44523156` 那条坏判据(那是 Step1 探针的,
  `td_pov/` 下 grep MAGIC 零命中), 换成 STATUS + 写 `0x10` 读 `0x24` 影子。

**下一步(未开始)**: 量 musl `memcpy` 的真实上限。
`cpy 160ms` 里 memcpy 占 153ms = **59 MB/s**。要判的是这是 **DDR 的上限**还是
**musl 通用 C 版 memcpy 的上限**(glibc 有 RISC-V 优化版但被 IFUNC/SIGILL 禁掉)。
若是后者, 手写展开的 64 位拷贝可能把 flip 从 5 fps 拉到 ~8 fps, **纯软件零硬件改动**。
🔴 这个数还会决定 Step 6 里 PL 写出通路的带宽指标怎么定 —— 若 CPU 侧 DDR 实际能到
120 MB/s 而非 59, 说明瓶颈在核不在内存, PL 直写的收益上限要按前者算。

**推流环境**(这台机没装 Windows Python, 见 [[reference_python_install]]):
```
python3 povstream.py render --anim palace --dual-face --out-dir <dir>   # 必须先预渲染
python3 povstream.py stream --dir <dir> --host <板IP> --fps 15 --codec lz4 --loop
```
WSL 已 `apt install python3-lz4`。🔴 `--fps` 必须等于转速。
🔴 **看 fps 要看板端 DIAG 的 `flip`, 不是 PC 报的 model fps** —— lz4 那次 PC 报 6.47
而板上 `flip=5.00/s` 且 drop 持续累积, 差 29%。

## 0. 两个入口性纠正

1. **现役 POV 系统在 `mlkpai_fs03/`，不在 `zynq_pov/`。**
   `zynq_pov/` 是更早的鹿小班/HDMI/HLS 阶段工程（但 `docs/claude_memory/` 记忆库在它下面）。
   `mlkpai_fs03/wt-recv/`、`wt-phase/` 是同仓库的 git worktree 副本，不是独立组件。
2. **对齐目标是 15.00 fps，不是记忆里旧的 10-11.4。**
   2026-08-06 修掉 `setsockopt(SO_RCVBUF)` 后达成（[[feedback_recv_setsockopt_rcvbuf_lock]]）：
   900 RPM 下 flip 中位 **15.00/s**，p5 11.14 / p95 15.00 / σ 1.36，**rx==flip 一帧不浪费**。
   演进：zlib 7.41 → lz4+三流 10-11.4 → **15.00**。

## 1. 已经对齐的

| 项 | 证据 |
|---|---|
| Linux / 串口 / TF | 自编 6.1.111-rt42 已上板 |
| WiFi (同一颗 MT7921AU) | wlan0 就绪, ch149 HE-MCS9, 26.7/28.4 Mbps, 与 Zynq 同量级 |
| PL bitstream 加载 | **比 Zynq 更好**: fpga_manager + configfs overlay, 秒级重配, 不用 JTAG 不用重启 |
| `icnd2047_panel_core.v` | md5 `955900ff…` **与 Zynq 版逐字节相同** |
| `row_drv_icnd1028.v` | md5 `28da5769…` 逐字节相同 |
| ODDR (4 例化/12 实例) | `oddr_dr1_shim.v`; `#pad reg 12` 全落 IOL; 时序 SWNS +12.09ns |
| bench_codec 跨架构基准 | riscv64(musl)/aarch64/arm/x86 |

## 2. 未移植的（按层）

**PL RTL**（现役工程实际入编只有 6 个文件，权威表 `mlkpai_fs03/vivado/create_panel_proj_v6.tcl:22`）：

| 模块 | 行数 | 障碍 |
|---|---|---|
| `panel_engine_2047.v` | 112 | 低难度。唯一风险: 9×`reg[31:0][0:511]`(`:57`) **必须回读综合报告确认推成 ERAM 而非散寄存器** |
| `pov_dual_top.v`（AXI-Lite 寄存器文件 + fb 直写窗 + 双引擎 + pair FSM + fold/mirror） | 805 | **最大一块**。障碍不在 RTL（零 Xilinx 原语），在它要挂的 PS |
| `ddr_slice_fetch256`（在 `pov_dual_top.v:641-805`） | 165 | 手写 AXI4 只读 master。Zynq 侧 32-bit，DR1 HP 是 64-bit |
| `angle_tracker.v` | 130 | **最容易**，纯 Verilog 零原语。真障碍只是引脚（已解，见 §4） |
| Xilinx IP: `processing_system7`/`smartconnect`/`proc_sys_reset` | — | 换安路等价物，见 §3 |

死代码**不要移植**：`ddr_slice_fetch.v`/`panel_engine_stub.v`/`icnd2049_panel_{fb,pov,seq}.v`（2274 行，均不在工程；`panel_engine_stub` 还与真模块**同名冲突**）。

**PL 资源不是约束**：现役 routed LUT 2701(5.08%) / FF 2894 / BRAM 9 tile / DSP 0；DR1V90 有 52480 LUT6 / 280 ERAM20K / 240 DSP。

**PS 侧**：`povmem.ko`（117 行源码在仓库里，材料齐，重编即可）、帧区内存保留、启动服务（DR1 是 **Buildroot/busybox 无 systemd**，且 rootfs 是 **initrd 重启即丢**）。

**板端 userspace**：`pov_rxd.c`(~1960 行) **完全未移植**、`pov_boot.sh`(python3 mmap，DR1 无 python3)。
⏸ `povwifi_watchdog.sh` **建议不要移植** —— 它自己就是 6 小时误判的元凶（[[feedback_wifi_throughput_bottleneck_isolated]]）。

**主机侧（PC）整层不需要移植** —— 全是 PC 上的 Python。
`tools/phase_ab.py`/`phase_bench.py` 这套**测量台在移植期间比什么都值钱，务必留用**。

## 3. 最大未知已经不是未知: DR1 SoC 模板就在仓库里

原判断"DR1 侧一个 PS 都没例化过"**属实**（`dr1v90/td_panel/soc_prj/fpga_prj.al` 只有 4 个 RTL 文件）。
但 **`dr1v90/_demo2/06_pl_fdma_video_1080P/` 和 `07_pl_fdma_cs500/` 是带 PS 的完整厂商 SoC 工程**，
路径 `soc_prj/uisrc/01_rtl/system/`（`system.xml` 块设计 + `hdl/system.v` 生成的接线 +
`ip/system_RISC_V_Processor_System_0/`）。从 `GuiFinal.xml` 挖出的关键参数：

| 参数 | 值 | 意义 |
|---|---|---|
| `HP0_DATA_WIDTH` | **64** | Zynq 侧只用了 32-bit ⇒ 同频带宽直接翻倍的空间 |
| `HP0_Interface` | 1 (使能) | PL→DDR 通路 |
| `master_gp0_axi_*` | PS 做主、PL 做从 | 正是寄存器文件需要的方向 |
| `clk0_Dot_Range` | **6.25 : 200 MHz** | p2f_clk0 频率范围。Zynq aclk 是 50 MHz ⇒ **余量很大**，且 lz4 要的 100 MHz 也在范围内 |
| `clk0_Dot_Actual_IO_Frequency` | 199.98 (demo 取 200) | |

PS 接口信号名：`slave_hp0_axi_*` / `master_gp0_axi_*` / `p2f_clk0` / `p2f_rst0_n`。
`uiFDMA_0` 是现成的 AXI master 范例。

**PL slave 地址窗大概率 = `0x8000_0000`**：demo 里该地址出现 214 次，`tfboot/system.dtb`
的 PL 外设模板（`serial@80020000` / `gpio@0x80010000` / `axidma@80000000`）也在这个域。
⚠ **但这算一条证据不是两条** —— 两者都出自厂商，且那份 dtb 已证明不是运行中的那份（见 §5 Step 0b）。
运行中的 DT 里**一个 PL 外设节点都没有**（`ls /proc/device-tree/` 只有 aliases/chosen/cpus/
memory@0/model/name/reserved-memory/soc），PS 外设全在 `0xf8xx_xxxx`。
⇒ 必须靠 Step 1 在板上读回 magic 才能确认。

## 4. DR1 的 2 个 HP 够不够: 够, 但余量结构不同

Zynq 现役**只用 1 个 HP0、且只用 32-bit**（`create_panel_proj_v6.tcl:39-41`）。
DR1 有 2 个 64-bit HP ⇒ 数量够。
🔴 **真正的差别**：Zynq 有 4 个 HP，lz4 的读/写各占一口、不与 `ddr_slice_fetch` 抢；
DR1 上 `fetch` + lz4 读 + lz4 写三条流量要挤进 2 个口 ⇒ **需要一层 AXI 互联做仲裁**。
而 Zynq 有过 [[feedback_pov_4x_ip_breaks_hdmi]] 那种"并发仲裁把画面搞坏"的前科
⇒ 集成后**必须实测 `pair_miss`(读 0x1C)**，不能只看带宽账。

## 5. 计划 (7 步, 判据即验收)

**Step 0 前置**（已做完 a，b/c 待办）
- ✅ **0a** `xdc2adc.py` 现在接受多个 XDC，已把 `panel_pins_v5.xdc` 的
  **`spin_sync_i` = ball W6**（DR1 CEP2.23 与 Zynq 一致）纳入 → `constraints/panel_pins_dr1.adc` 31 脚。
  ⚠ 故意**未**同步进 `td_panel/…/fpga_pin.adc`：那个顶层 `panel_core_synth_top` 没有这个 port。
  ⚠ `set_false_path -from [get_ports spin_sync_i]` 是**时序**约束，脚本单独列出提醒搬进 `.sdc`。
- ✅ **0b 已做（2026-08-07 板上取证）**，结果推翻了资料包里的 dtb：

  | 来源 | memory@0 | 结论 |
  |---|---|---|
  | `dr1v90/tfboot/system.dtb` | `0x3fe00000` ≈ 1022 MB | ❌ **不是卡上跑的那份** |
  | **运行中的 `/proc/device-tree`** | base `0x0` size **`0x2000_0000` = 512 MB** | ✅ 权威 |

  ```
  reserved-memory/linux,dma/reg = 0x1000_0000 + 0x0100_0000 (16 MB), no-map
  /proc/iomem:
    00400000-0fffffff : System RAM
    10000000-10ffffff : Reserved        <- linux,dma
    11000000-1fffffff : System RAM      <- Linux 正在用
    f8801000-f8801fff : fpga-mgr        <- PL 配置口
  ```
  MemTotal 468 MB 与之自洽（两段 System RAM 合计约 492 MB 减去内核占用）。

  🔴 **`pov_rxd` 的 bank 地址在 DR1 上是致命的**：
  bank A `0x1000_0000` 撞 `linux,dma` 保留区；
  **bank B `0x1100_0000` / C `0x1200_0000` 落在正在使用的 System RAM 里** —— 会直接踩内核内存。
  ⇒ **DDR 地址图必须重规划。**

  ⚠ **2026-08-10 更正：原来这里建议的「加 no-map 节点，放 `0x1D00_0000`–`0x1FFF_FFFF`」是错的，已作废。**
  它建立在"no-map 能让内存变非缓存"这个假设上，而 DR1 无 Svpbmt ⇒ `pgprot_noncached()` 是空操作；
  更致命的是 **no-map 不进线性映射，而 `arch_sync_dma_for_device()` 靠 `phys_to_virt()` 拿 VA
  去回写 D-cache** ⇒ 加了这个节点等于把唯一能用的回写通路弄坏。完整论证见
  [[reference_dr1_cache_and_frame_memory]]。
  ✅ **正解：帧区走 CMA(48 MB) + 带 cache 映射 + 显式回写 ioctl，早就实现好了，改动量 = 0。**
  🔴 **地址是运行时的，不是常量**：`bank[i] = /sys/class/misc/povmem/phys_base + i*0x1000000`。
  任何写死 bank 地址的代码/脚本/判据都是错的。
- **0c** 确认 PL AXI-Lite 窗口（见 §3，已有强证据，Step 1 板上收口）

**Step 1 — DR1 SoC 骨架**（照 §3 的 demo 模板搭；PS + GP0 slave + HP0 + p2f_clk0=50MHz + 复位；PL 端先只挂一个读回 magic 的寄存器）
判据：`busybox devmem <PL基址>` 读到 magic；写入再读回一致；dmesg 无 bus error。
顺带解掉 aclk —— 现在板载 PL 时钟只有 25 MHz，生产设计的 aclk 必须由 p2f_clk 给。

**Step 2 — 静态点屏**（`panel_engine_2047` + `pov_dual_top` 的寄存器文件 + fb 直写窗(`0x8000-0xFFFF`) + 双引擎，**先不带 AXI master**；用 `gen_chess_obs.py`/`gen_orient_f.py` 的图经 AXI-Lite 直写 BRAM）
判据：屏上图案与 Zynq 上同一张**逐区域对得上**（不是"亮了"就算）；综合报告确认 fb 推成 ERAM；
这一步同时**首次验证 aclk 50 MHz 下 50 Mbps/lane 全速时序**（目前只在 12.5 MHz 测过）。
🔴 上板安全：**别加载 `td_panel` 的 `panel_core_synth_top`** —— 输入全 LFSR，会把 OE 驱成伪随机。

**Step 3 — `ddr_slice_fetch256` + HP0**
判据：写一帧进保留区 → 写 `slice_base(0x18)` → `fake_en` 假转 → 屏上连续切片；**`pair_miss`(0x1C) 恒 0**。

**Step 4 — `angle_tracker` + 光电**
判据：读 `0x14` 的 `rev_period` 换算 RPM 与掐表一致；`at_locked=1`；电机停则 `slice_idx` 不变。

**Step 5 — `pov_rxd` + `povmem.ko` 上板 = 最短闭环终点**
🔴 五个必须做的改动：musl 静态链（glibc IFUNC 在 6.1 内核上 SIGILL）/ `--regs` 指新基址 /
bank 地址避开保留区 / `--decode serial`（单核；且 Zynq 上双核并行也只值 1.06×）/
**绝不要抄 `setsockopt(SO_RCVBUF)`**（正是刚修掉的那个 bug）。
判据：`grep -a DIAG pov_rxd.log | grep -av 'dec 0.0/0.0ms'` 看到 `FRAME → FLIP` 交替
（`dec 0.0` 是空闲动画不是推流，这个坑错过三次）。
~~**预期只有 6-7 fps**（CPU 解码 115.5ms vs 一圈 62-66.7ms）~~

### ✅ 2026-08-10 已跑通，但"6-7 fps"这个预期口径是错的

实测 zlib **3.5-3.75 fps**，`drop=0`、`rx==flip`、`BRIDGE_ST=0`（misalign_err 干净 ⇒
CMA 运行时基址没破坏 8 字节对齐）。分项：`dec 262ms` / **`cpy 162ms`** / `wait 35ms`。
dec 与 cpy 在不同线程重叠，所以帧周期 ≈ max(dec, cpy+wait)。

🔴 **`cpy = 162ms` 是此前没人算到的第二堵墙，比解码那堵更高**（Zynq 只要 20-26ms，
差 6-8×，而 CPU 只差 2.15×）。根因：DR1 帧区必须带 cache ⇒ 每帧显式回写 8.85 MB。
⇒ **即使 Step 6 把 dec 打到 ~85ms，`cpy+wait≈197ms` 会接管，仍只有约 5 fps。**
详见 [[reference_dr1_cache_and_frame_memory]]。

⇒ **Step 6 的设计要求因此被钉死：PL 解码器必须直接写进帧 bank，不能只是"解码快"。**
"PL 片上历史顺带消掉 memcpy"从附带好处升级为**主要收益** —— 一次干掉两堵墙。

**Step 6 — PL lz4 接入 = 从 6.8 fps 拉到转速上限**
🔴 **改用 3 引擎 @ 75 MHz，不要抄 Zynq 的 2 引擎 @ 100 MHz**：
DR1 上核的 Fmax 实测约 100 MHz（余量≈0），而单引擎只吃 eram 10%/slice 1%。
3×75 = 214 MB/s > 门槛 143，时序余量从 0% 变成 33%。理由见
[[feedback_changed_instrument_and_design_together]]。吃 `PVS_FLAG_MSTREAM`（协议零改动）。
🔴 集成后**必须重测 Fmax**：见 [[project_lz4_pl_decoder]]，且现设计是 50 MHz 单域，
加 100 MHz 域是**新的跨时钟域问题**。顺带 memcpy 也会消失（PL 片上历史不回读 DDR）。

**Step 7 — 收尾**：翻页搬 PL / crc32+delta 折进 PL 写出通路 / 重打 rootfs 持久化 / init 脚本 / OE 最终收口。

## 6. Zynq 侧待澄清 (不影响 DR1，但影响"对齐到什么")

🔴 **`pov_boot.sh:38` 写 `0x0C = 0xB8366F01`，bit29=1**。
而 `panel_engine_2047.v:74` 是 `.ddr_slow(dclk_fast)  // 位改义: 1=25Mbps 降级`
（RTL 自己在 `:10` 写明"位复用改义"）。⇒ **现役 Zynq 可能跑在 12.5 MHz DCLK / 25 Mbps 降级模式**，
与同文件注释宣称的 4748 Hz（需 195 拍快速行周期）自相矛盾。
旧脚本 `pov_boot_v3fs03.sh:29` 用的是 `0x9836C001`（bit29=0）。
**未在板上验证，不要当结论。** 但若属实，则"每圈只显示 316 片/0.88×"那笔账要重算。

## ✅ 2026-08-10 结案（离线，仍未上板）：属实，账已重算

证据链逐跳核过：`pov_boot.sh:38` 的 `0xB8366F01` bit27=1(cfg_we) ⇒
`pov_dual_top.v:280` `dclk_fast <= wdata[29]` ⇒ `panel_engine_2047.v:74`
`.ddr_slow(dclk_fast)` ⇒ `icnd2047_panel_core.v:125` `tick = ~ddr_slow | slow_ph`
⇒ 192 bit 从 192 拍变 384 拍。仿真 `sim/run_tb_2047.log:74-78` T5 独立印证。
成因是**位语义反转**，不是手误，详见 [[feedback_reg_bit_semantics_reversed]]。

重算结果：2D 刷新 **4748 → 2393 Hz**；每圈显示切片 **316 → 160**；
面板一级余量 **0.88× → 0.44×**；08-03 那次 oe 优化收益 **+39% → +18.3%**。
见 [[project_pov3d_refresh_vs_rpm]] / [[project_pov3d_link_budget_status]]。

🔴 **对 DR1 移植的三条影响**：
1. **现在"对齐"的是一个降级基准。** §5 Step 2 判据写着"验证 aclk 50 MHz 下 50 Mbps 全速时序"
   ⇒ **按计划做完，DR1 面板刷新会是 Zynq 现役的 2 倍**。任何两边画面对比都会被这个不对等污染
   （DR1 会莫名其妙更好看）。对齐前必须先声明对的是 2392 还是 4748。
2. **15.00 fps 这个对齐目标不受影响**，照用（内容帧率由翻页和解码锁死，面板刷新不在那条链上）。
3. 🔴 **别把这个 bug 一起移植过去**：DR1 照搬 `pov_dual_top.v` + `panel_engine_2047.v`，
   寄存器语义一并继承。板端脚本若照抄 `0xB836…` 会原样复现同一个降速。
   移植清单里应显式写死 **`bit29 = 0`**。

**顺带一个更大的杠杆**：既然每圈只显示得了 ~160(改 fast 后 ~316)片，现在渲 360 片是
**多传了 2.25×(改后 1.14×)的数据**。把 `n_slices` 匹配到面板真实能力，链路/解码/memcpy
全线成比例减负。这对 DR1（CPU 解码慢 2.15×，Step 5 预期只有 6-7 fps）意义比对 Zynq 大得多。

## 7. 诚实的空白

- DR1 HP 口**实际可用带宽** —— 无任何记录或实测
- DR1 上 50 Mbps/lane 的**边沿质量/眼图** —— 需 ≥100MHz 示波器；已测的只有 12.5 MHz 下半拍延迟 19.75ns
- **DR1 带载（屏刷新抢 DDR）下的 CPU 解码数字** —— 未测。A9 上带载比空载差约 2×
  ⇒ **115.5 ms 那个数是空载数**，跨平台对比必须同工况
- `ddr_slice_fetch256` 的**实际达成带宽** —— 只有理论账(185 MB/s @92%)，且 **outstanding=1**
  的 AR 往返延迟没被计入那个账 ⇒ DR1 上建议实测而非照抄
- **电机怎么控制/调速** —— 整个系统 RTL+软件+文档里**查不到任何电机控制代码**，
  PL 纯粹是转子的被动观察者，调速在系统外

相关：[[project_dr1_riscv_verdict]] [[project_dr1_sku_decision]] [[project_dr1_rtl_port_step1]]
[[project_lz4_pl_decoder]] [[reference_panel_oe_no_pullup_anywhere]]
