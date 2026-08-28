---
name: project_dr1_parity_plan
description: v2 (2026-08-26 重写) DR1V90 对齐 Zynq 的六线计划 A-F, 含 08-27 进度(A/B/C/D 离线部分全完成、排线还没插); 对齐目标改为 969RPM 下 10-12 fps; PL 解码一次消掉 dec+cpy 两堵墙
metadata:
  type: project
---

# DR1V90 → Zynq 功能/性能对齐 **v2** (2026-08-26 重写)

> **v1 (2026-08-07 盘定 / 08-10 更新) 的七步计划已归档在文末 §9。**
> 重写原因: 08-20 ~ 08-26 这六天 Zynq 侧连续落了 **3-bit 色深 / half_scan / PL 硬件 lz4 /
> fold_a / 整卡镜像** 五件事, v1 的对齐目标、载荷账、Step 6 前提**同时**失效。

---

## ⏱ 进度 (2026-08-27 更新, 全部已提交到 `dr1v90/`, 该仓无远端)

**一句话: 不占板子的 A/B/C/D 四条线离线部分全做完了; 从 D 的"插排线"往后一步没走。**

| 线 | 状态 | commit |
|---|---|---|
| **A** RTL 追平 | ✅ **离线完成**。TD syn→place→route→bitgen 全过: `#eram 36/280`(判据要的 18→36) / `SWNS +6.490ns` / `HWNS +0.024ns` / Fmax 74.0 MHz / `Constraint File` 非空且非 DeriveClock。⚠ **一次都没上板** | `9cff1c4` |
| **B** HP 拓扑 | ✅ 设计定案 + RTL + 仿真, 见 [[project_dr1_hp_topology_decision]]。✅ **08-27: `axi_hp_arb` 过了 TD**(N=2 @100MHz 余量 43%, 0.35% slice) ✅ **HP1 与 p2f_clk1 已接出**(不用重新生成 PS IP, 排期 +2~3 天那条**取消**)。🔴 剩 PS 侧四个寄存器**一个都没在板上写过** —— 不写就是"综合全过、上板静默不应答" | `70c0dde` `451888f` `ba0cbbb` |
| **C** 板端软件 | ✅ 按建议**重新 fork** 完成, 24 hunk / +339-68, 本机 12 项自检全过。⏸ `--pl-lz4` 整条路径本机一条都证不了 | `e5cfeb9` |
| **D** 电气收口 | 📄 检查表写完: **OE 复位态已收口可以接屏**; ⛔ 撤回"焊 4.7kΩ 到 J12.1"那条旧建议(做过 5V 灌入改法后它是背供电通路), 见 [[reference_panel_oe_no_pullup_anywhere]]。⏸ **排线还没插**, 50 Mbps 全速 SI 仍未验 | `905ce46` |
| **E/F** | ⏸ 未开始。F 的**材料**做完了(整卡流程 + `povboot.sh`), 且 §F 那个"静默换掉整个 userland"的雷**已修**(默认基底改对 + md5 硬断言 + `AUTOBOOT` 闸门), 但**一条判据都没上板验过** | `f0f1f47` |
| **测量台** | ✅ 新建 `dr1v90/measure/` 三套件, 见 [[project_dr1_measure_bench]] | `78c81cf` |

🎯 **下一步就是 `measure/03_wifibw`** —— 15 分钟, 不需要任何新 bitstream, 现役系统就能跑,
且结果可能改写 B 线的目标。前置只有一台**有线**服务端。
板子一到位, `measure/01_hpbw` 的**阶段 2(双口并发)也已经能跑**了(`hpbw dual`),
上板第一件事是 `hpbw portalive` —— HP1 全 0 而 HP0 非 0 就说明 PL 侧对了、PS 侧没使能。
⚠ 板子距上次通电已久, 别假设它是热的。

## 0. 一句话现状

**DR1 停在 2026-08-10 的 Step 5**(zlib CPU 解码, 板上实测 3.5-3.75 fps, **屏从来没接过**);
**Zynq 已经在 2026-08-25 走到 3-bit + fold_a + PL 三引擎解码, 969 RPM 下 10-12 fps**。
移植不再是"追平一个静止的靶子", 而是**把六天的架构变更一次性搬过去**。

---

## 1. 对齐目标: 15.00 fps 作废, 改为 **969 RPM 下 10-12 fps**

| | v1 写的 | **v2 现役实测** | 出处 |
|---|---|---|---|
| 转速 | 900 RPM / 15 rps | **969 RPM / 16.15 rev/s / 圈周期 62 ms** | commit `970edce` (08-25) |
| 内容帧率 | 15.00 fps (中位) | **10-12 fps**, `flip == rx`, **drop 9** | 同上, 板端 DIAG |
| 色深 | 1-bit | **3-bit 行内 BCM** | commit `65686aa`/`ff003fd` (08-20) |
| 载荷 | 720 片双面 8.85 MB | **213 片 7.85 MB** (面A 71 + 面B 142, fold_a) | `970edce`; 未折叠态 10.47 MB 与 `frames_cube142d/meta.json` 的 `frame_raw` 逐字吻合 |
| 解码 | CPU zlib/lz4 | **PL 三引擎 55.5 ms/帧** | `970edce` |
| 瓶颈 | 解码 | **翻页相位** (`wait` 24-38 ms/帧) | `970edce` |

🔴 **"对齐"这个词的含义因此变了。** v1 时代两边都是"CPU 解码 + 1-bit", 比的是同一件事跑多快;
现在 Zynq 已经把 CPU 移出关键路径, **DR1 要对齐的是这个新架构, 不是那个旧数字**。

⚠ v1 里 "15.00 fps 是靠修 `setsockopt(SO_RCVBUF)` 拿到的" 这条**仍然成立且必须继承** ——
[[feedback_recv_setsockopt_rcvbuf_lock]], DR1 侧板端软件**绝不要抄那个 setsockopt**。

---

## 2. 🎯 最重要的结论: PL 解码一次消掉 DR1 的**两堵**墙

v1 §Step5 的实测把 DR1 钉死在 3.5-3.75 fps, 分项 `dec 262.3ms` / **`cpy 162.1ms`** / `wait 45.5ms`
(2026-08-10 板上实测, [[reference_dr1_cache_and_frame_memory]])。当时的判断是:
"即使 Step 6 把 dec 打到 ~85ms, `cpy+wait≈197ms` 会接管, 仍只有约 5 fps"。

**那个判断的前提是"CPU 仍然要把解码结果搬进帧 bank"。Zynq 08-25 的做法把这个前提删掉了:**

```
旧 (两边都是):  收包 → comp 缓冲 → CPU 解码 → staging → memcpy 进 bank → 回写 D-cache → 翻页
新 (Zynq 08-25): 收包 → comp 缓冲 → 回写 D-cache(仅压缩流) → PL 引擎直写 bank → 翻页
                                                        ^^^^ 没有 staging→bank 的 memcpy
```
出处: commit `7efe755` —— "`--pl-lz4`: 收包 → comp 缓冲 → PL 直写 bank → 翻页, **没有 staging→bank 的 memcpy**"。

⇒ **DR1 上 `cpy=162ms` 的成因(帧区必须带 cache ⇒ 每帧显式回写 8.85 MB)随之消失。**
CPU 只需回写**压缩流**。压缩流有多大, 见 §6 的实测比率:
【推算, 按今天离线实测的最坏比率 12.3× 算】7.85 MB ÷ 12.3 ≈ **638 kB**, 是原来 8.85 MB 的 **1/13.9**;
按中间比率 35.5× 算则是 **221 kB**, 1/40。

⇒ 🎯 **"DR1 单核比 A9 慢 2.15×"这件事不再致命** —— 那个 2.15× 是
`dec×2 + cpy` 的整帧数字([[project_dr1_riscv_verdict]]), 而这两项现在都不在 CPU 上了。
剩给 DR1 单核的只有 **TCP 收包 + 一次小得多的 cache 回写**。

⚠ **但这是推理不是实测。** DR1 上从未跑过 PL 解码路径, 上面整条链在 DR1 上的验证在 §Step E。

---

## 3. 🔴 新的头号架构问题: **DR1 只有 2 个 HP, Zynq 现役用满了 4 个**

这是 v1 完全没有的问题 —— v1 时代 Zynq 也只用 1 个 HP。

| | Zynq-7020 现役 (08-25) | DR1V90 |
|---|---|---|
| HP slave 口 | **4 个** | **2 个** (64-bit) |
| 分配 | HP0 = 面板 `ddr_slice_fetch256` **纯读** ~~110.8~~ → **约 160 MB/s** (32-bit)<br>HP1/HP2/HP3 = 三个 lz4 引擎**各独占一口** | 面板占 1 个 ⇒ **三个引擎的读+写全挤进剩下那 1 个** |
| 出处 | `vivado/create_panel_proj_v6.tcl:73-105`, `set NENG 4` / `HP_ORDER {3 1 2 3}` | [[reference_anlogic_dr1_fs03_eval]] §3: "DR1 PS = 2×GP master + 2×GP slave + **2×HP slave(64bit)**" |

**"每个引擎独占一口"在 Zynq 侧是被写进设计理由的, 不是随手分的**
(`create_panel_proj_v6.tcl:65-67`): 前车之鉴是 **NUM_SI=8 挤在一个 axi_smc 上打 HP1,
单独跑每个都对, 一起跑 HDMI 变噪点** —— [[feedback_pov_4x_ip_breaks_hdmi]]。
DR1 上被迫回到的正是那个被否决过的拓扑。

~~**带宽账**【推算】: 三引擎 142 MB/s **写** + 面板 110.8 MB/s **读** ≈ 253 MB/s。~~
🔴 **08-27 重算**: 面板取片 **110.8 是 1-bit / 360 槽 / 780 RPM 的旧账**。现役口径
(3-bit 三位平面 × 双面 × **142 槽/面** × **969 RPM**)是
`142 × 2 × 3 × 11664 B = 9.94 MB/圈 ÷ 61.9 ms ≈ **160 MB/s**`
⇒ 三引擎 **142.5 写** + 面板 **160 读** + 压缩流 6-7 读 ≈ **约 300 MB/s**, 全压在 2 个 64-bit 口上。
🔴 而面板那条通路的硬顶是**上游 32 位 @50 MHz = 200 MB/s**(仿真实测 176-185, 桥把一个
64 位拍拆成两个 32 位拍还给上游 ⇒ 每 2 拍才收一个, `rtl/axi4_to_axi3_hp.v:118-120`)
⇒ **余量约 1.15×, 不是注释写的 1.7×**。

~~🔴 **DR1 的 HP 口实际可用带宽零实测** —— 见 §7。~~
🔴 **08-27 收口**: 厂商值 **1600 MB/s**(DS1200 **V1.0** 表 3-36, 我们看的 3-34 是 0.4 草稿),
且 **XMON 自带带宽计数器(0xF8440000)可在板上实测**。

**Zynq 那边为什么没炸(而且 `pair_miss` 实测 0.0/s)**, 以及这个理由**在 DR1 上还剩几分**:

| Zynq 成立的理由 (`7efe755` 实测印证) | DR1 上还成立吗 |
|---|---|
| 面板在 **HP0 独占口**, 且是**纯读** | ❌ 面板仍纯读, 但只剩 2 个口, 拓扑余地小得多 |
| DDRC 入口有 3 个: {HP0}/{HP1,HP2}/{HP3} ⇒ 引擎写流量能 2:2 摊开 | ~~❓ 没查过~~ ✅ **08-27 查实, 比 Zynq 类比更好**: 两个 HP **不合流** —— 两路各有独立 HP Bus + 各自独立的读缓存与写缓存 + 各自独立的 OCM 出口(M0/M1), 公共缓存内**读/写/OT 三者相互独立** ⇒ 🎯 **lz4 的写洪水吃不掉面板的读缓存条目**。⚠ 但 **M2/M3 按地址还是按 master 未决**(UG1214`:7275-7280` 按 master vs 厂商答复按地址, **直接冲突, 不选边**) |
| DDRC 拥塞时**读优先于写** ⇒ 面板是被偏袒的一方 | ~~❓ 没查过~~ 🔴 **08-27 厂商确定否认**: "不是简单固定读优先或写优先", 并主动点名读写方向切换/写队列批量排空/Bank-Row 冲突**仍可能造成读延迟尖峰**; 且**没有最小带宽/最大延迟保证**, 只有超时防饥饿(**防饿死 ≠ 保时限**) ⇒ **Zynq 那个 pair_miss=0 的两条支柱, 在 DR1 上只剩一条** |

⚠ 还有一条工具链缺口: **TD 没有 `smartconnect` / `axi_protocol_converter` 的对等 IP**。
Zynq 上白拿的 N:1 汇聚和位宽转换, DR1 上要么用安路自家 IP(未查证有没有), 要么手写。
现有的 `dr1v90/rtl/axi4_to_axi3_hp.v` (231 行, 已过 11 档仿真回归) **是只读的**,
lz4 的**写**通路要新写一份。

**若挤不下的三条出路**(按代价排序, 都没验证过):
1. 降 `n_slices` / 继续用 fold_a ⇒ 载荷小了, 引擎数可以从 3 降到 2 甚至 1
2. 引擎输出不落 DDR, 改由面板直接从 PL 片上取 ⇒ 架构改动大, 但把写流量整个干掉
3. 接受更低 fps

---

## 4. 六条线 A-F (取代 v1 的七步)

**并行/串行结构** —— 这是排期的关键:

```
A RTL 追平   ─┐
B HP 拓扑     ─┼─→ 都不占板子, 可并行推进 (综合/仿真为主)
C 板端软件   ─┘        │
                        ↓
D 电气收口 (接屏) ──→ E 联调 ──→ F 系统化
   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ 这三条串行, 且全部卡在同一块板子上
```
🔴 **A/B/C 三条线互不依赖, 是唯一能真正并行的部分。D 之后全是独占板子的串行段。**
⚠ 前置未决问题: **排线 + 米联派接口板 + 双屏 + 光电传感器有没有第二套?**
只有一套的话 D-E-F 期间要拆现役 Zynq 系统(08-26 已装出第二台 Zynq, 但接屏那套是否配齐未确认)。

---

### A — RTL 追平 3-bit / half_scan / fold_a  ⏱ 1.5-2 天

**好消息: 漂移比想象中小得多。** 2026-08-26 逐文件 diff 实测:

| 文件 | 改动行数 | 内容 |
|---|---|---|
| `icnd2047_panel_core.v` | **154** | 3-bit 行内 BCM 三平面 + half_scan |
| `pov_dual_top.v` | **138** | `0x0C` sub01 寄存器 / plane 地址 / fold_a / `frame_period` 引出 R0x28 |
| `panel_engine_2047.v` | **53** | |
| `angle_tracker.v` | **0** | 逐字节相同 |
| `row_drv_icnd1028.v` | **0** | 逐字节相同 |
| **合计** | **345** | |

🎯 **新增 Xilinx 原语命中 = 0** (grep `RAMB/BUFG/MMCM/PLLE/IDDR/ODDR/XPM_/DSP48/IOBUF/FDRE/SRL`,
只命中已经 shim 过的 `ODDR`) ⇒ [[project_dr1_rtl_port_step1]] 的 `oddr_dr1_shim.v` 继续管用。

🔴 **唯一真改动: `fb_lane_ram.v` 要重做。** `panel_engine_2047.v:19` 注释:
"fb 深度 512→1024 (BRAM 9 tile RAMB18 → 18 tile RAMB36)", 且 3-bit 加了 plane 字段进地址。
DR1 侧 fb 是靠 `fb_lane_ram.v`(39 行)显式例化的, 因为
[[feedback_td_infer_ram_skips_generate_blocks]] —— **TD 不认 generate 块里的 RAM 推断**。
⇒ 深度翻倍 + 地址加位, 这个文件必须跟着改, 且要**回读综合报告确认仍落 ERAM 而非散寄存器**。

**判据**: TD 综合报告 `#eram` 从 18 涨到约 36 (深度翻倍, 两个引擎)；
50 MHz `SWNS > 0` 且 `HWNS ≥ 0`(记得 `set_param place fix_hold on` + `set_param route fix_hold on`,
两条都要, 见 [[project_dr1_rtl_port_step1]] §5)；时序报告 `Constraint File:` 非空且
`Clock-Name` 是自己起的名而不是 `DeriveClock`(约束没绑上的症状, 撞过一次)。

⚠ **移植清单里显式写死 `bit29 = 0`** —— 别把 Zynq 那个降速 bug 一起搬过去。
(该 bug 已于 08-20 在 Zynq 侧翻正, commit `ac4948e` 实测 2.07×, 见 §8。)

---

### B — HP 拓扑与仲裁 (PL lz4 接进 DR1)  ⏱ 4-6 天  🔴 风险最高

**核本身零风险**: 2026-08-26 `diff -q` 实测 ——
`mlkpai_fs03/vivado/hdl/lz4/lz4_decode_core.v` 与 `dr1v90/lz4hw/rtl/lz4_decode_core.v`
**逐字节相同**, `lz4_axi_top.v` 同样。且核早就在 DR1V90 上综合收敛过
(eram 28/280 = 10%, slice 436 = 0.83%, **@100 MHz Fmax 113.4 MHz**, [[project_lz4_pl_decoder]])。

**要新做的是外围三件**:
1. **`lz4_engine_axi.v` 过 TD** (498 行, Zynq 侧 08-25 新写的适配壳)。
   它里面有一条**必须继承的修复**: 原 `lz4_axi_top` 的 AXI-Lite `awready` 恒 1 且写只在
   `awvalid && wvalid` **同拍**生效 ⇒ AW 先到就被吃掉且永不回 B ⇒ **挂死 GP0**。
   原 tb 总是同拍拉两个 valid 所以从没暴露 (commit `7efe755`)。
   🔴 DR1 上 GP0 挂死 = 面板寄存器全挂 = 整板失联, 比 Zynq 上更痛
   (同类风险见 [[feedback_dr1_pl_probe_must_be_hang_proof]])。
2. **N:1 汇聚器 + AXI4→AXI3-64 写桥** (§3), TD 无对等 IP。
3. **HP 口分配决策** (§3 的三条出路)。

**判据**: 先在 `dr1hw_sim/` 补一档"多主抢一个 HP 口"的回归(现有 11 档是单主只读);
上板后 **`pair_miss`(读 `0x1C`) 必须保持 0** —— 且注意
[[feedback_pair_miss_sentinel_was_broken]]: 那是 **16 位计数器, 只有 PL 复位能清**
⇒ **只能冷启动后测增长率**, 不能读绝对值。

⚠ 时钟域: Zynq 侧三个引擎**跑 50 MHz 单域, 没有新开 BUFG 域**(`create_panel_proj_v6.tcl:221` 的理由)。
DR1 生产配置 aclk 也是 50 MHz 且实测 `SWNS +7.881 ns @20 ns` / Fmax ≈ 82.5 MHz / 余量 39%
([[project_dr1_soc_step1_done]]) ⇒ **可以照抄单域做法, 不引入跨时钟域**。
但 lz4 核那个 113.4 MHz 是**核单独综合**的数, 集成后必降, 集成后重测。

---

### C — 板端软件追平  ⏱ 2-3 天

2026-08-26 实测: Zynq `stream/board/pov_rxd.c` = **3560 行**,
DR1 `board/pov_rxd/pov_rxd.c` = **2139 行** ⇒ **+1421 行**, 全是这次要的东西。
(commit `7efe755` 单次 diff 就是 `pov_rxd.c | 1387 +++`。)

🔴 **建议从 Zynq 版重新 fork, 而不是往 DR1 那份上打补丁。** DR1 那份落后 1421 行,
且 08-25 的改动都在核心路径(收包/调度/翻页)上。DR1 的差异只有可枚举的几处, 当补丁重打:

| DR1 必须的差异 | 出处 |
|---|---|
| musl 静态链 (glibc IFUNC 在 6.1 riscv 内核上 SIGILL) | [[feedback_riscv_glibc_ifunc_sigill]] |
| `/dev/povmem` (CMA) + **运行时** `phys_base`, 不是常量 bank 地址 | [[reference_dr1_cache_and_frame_memory]] |
| `--decode serial` (单核; 且 Zynq 上双核并行也只值 1.06×) | [[feedback_lz4_onboard_reality_check]] |
| **绝不设 `setsockopt(SO_RCVBUF)`** | [[feedback_recv_setsockopt_rcvbuf_lock]] |
| 寄存器基址 `0x8000_0000` (不是 Zynq 的 `0x4001_0000`) | [[project_dr1_soc_step1_done]] |

**08-25 引入的、必须一起搬的三个非显然点** (全部出自 `7efe755` / `970edce`):
- **看门狗时钟起点在 `pl_sched_wait()` 而不是 launch** —— 起点设在 launch 会被 WiFi 的
  55-80 ms recv 吃光预算, 首次 poll 就把健康引擎判死, **而引擎无软复位 = 不可逆**
  ([[feedback_watchdog_clock_started_too_early]])
- **done 新鲜度靠 `pl_start()` 写完 CTRL 立刻读 STATUS 确认 `done=0`**, 不靠目击瞬态
- **bank 定序: 先发布 N-1 再认领 N** + `BANKGUARD` 断言
- **默认 `--no-pipeline`** —— 流水线在这个系统里有害, 见 §5

发送端 `povstream.py` 也要跟上: **`--stream-split even --stream-workers 3`**,
否则 fold_a 的收益**全丢且无任何报错** ([[feedback_fold_a_needs_even_stream_split]])。

⚠ 顺带把 `povctl` / `povboot.sh` / 8 色屏幕自检图一并移过来。

---

### D — 电气收口 + 首次接屏  ⏱ 1-2 天  (DR1 从没点过屏)

- **50 针排线 + 米联派接口板 + 双屏 + 光电传感器**从 Zynq 板挪过来。
  CEP2 球位 100% 一致, XDC 已用 `xdc2adc.py` 1:1 转成 `.adc`(30 引脚, 5 处通配覆盖全生效, 0 行未识别)
  ⇒ 这一步是**插拔**不是设计 ([[reference_anlogic_dr1_fs03_eval]] §2 / [[project_dr1_rtl_port_step1]] §5)。
- 🔴 **OE 复位态 —— 这是接真屏前的硬闸门, 至今未收口。**
  安路 ODDR **没有置位端**, 复位只能拉到 0 ⇒ **复位期间 OE=0 = 屏被点亮**。
  shim 当前把 INIT=1 的实例改成 `ASYNCRST("DISABLE")` 交回 fabric, **稳态正确**,
  但"配置完成→第一个时钟沿"那个窗口的残余风险还在。
  两条路(都还没做): `.adc` 加 `PULLTYPE = PULLUP`, 或走 `DR1_LOGIC_IOTRIBUF` 复位期间高阻。
  代价: OE 与 DCLK 的 pad 延迟不再严格匹配, 需重核 OE 相对时序窗口。
  ⚠ 结合 [[reference_fs03_board_access]] 的"5V 轨余量紧、热插拔屏会让板子重启", 不能忽略。
- **5V 灌入改法**(磁珠 L16/L17/L18/L19 + 跳帽 `ADJ_BANK11`)要在 DR1 板上重做一遍。
- ⚠ **50 Mbps 全速的边沿质量至今未测。** 已验的只有 12.5 MHz 下的半拍延迟
  **19.75 ns**(理论 20.00, 误差 1.3%, 用逻辑分析仪抓包反算)。全速时数据眼只有 20 ns,
  边沿若很慢会吃裕量 —— 需 **≥100 MHz 带宽示波器 + 短地线探头**, 目前没有。
  ⚠ 注意那次"占空比 60%"是**测量假象**(门限偏置), 别再被它误导。

---

### E — 联调  ⏱ 3-4 天

顺序照 Zynq 08-20~08-24 走过的路 (那边花了 5 天, 坑清单可抄):
静态点屏(**逐区域对得上**, 不是"亮了"就算) → 3-bit 目视(`rgbcube`) → half_scan →
传感器真转 → 推流闭环 → fps。

**可以直接抄的坑**(全部来自 [[project_pov3d_3bit_color]], 每条都在 Zynq 上真撞过):
- 🔴 **运行时切 `bpp_mode`/`half_scan` 会让引擎死锁在 `EG_IDLE`** ——
  现象是 `auto_en=1`、STATUS 一切正常、`frame_period` 冻在残留值, 但 **`oeprobe` 的 edges = 0**。
  **判据只能看 edges, 看 STATUS 和 frame_period 会被骗。** workaround: 切换后 `auto_en` 关再开。
- 🔴 **改 `row_cfg`(行驱时序) 必须先 `auto_en=0`**。
- `0x24` 读写不同义(写=`row_cfg`, 读=`POV_CTRL` 影子) ⇒ **row_cfg 无法回读确认**。
- half_scan 三件必须同时做(两个引擎都接 / `adv_high` 压到 25 / 地址每行补跳 3), 缺一不可。
- 权重与位序是一体的: MSB-first + **184/92/46**, 改一个就是坏的。

⚠ **看 fps 永远看板端 DIAG 的 `flip`, 不是 PC 报的数** —— DR1 上撞过一次
(PC 报 6.47 / 板上 `flip=5.00/s` 且 drop 持续累积, 差 29%)。

---

### F — 系统化 / 装机  ⏱ 2 天

| | Zynq 现状 | DR1 现状 |
|---|---|---|
| rootfs | Debian + systemd, **整卡镜像一条命令** `make_card_image.sh` (commit `d97049c`, 08-26) | **initrd, 重启即丢**; Buildroot/busybox 无 systemd, **无 python3** |
| 开机自启 | systemd drop-in 入库 | `povboot.sh` 写好了但 **一条判据都没上板验过** |
| 上电内容 | 固化彩虹螺旋管 3-bit 动画 (commit `a9e0abb`) | 无 |

DR1 要做: rootfs 持久化(**A-lite 方案**: 只往 `rootfs.bin` 加 `/etc/init.d/S95pov` +
一份 `povboot.sh`, 约 10 KB, 已评估未动手) + 冷启动固化。

🔴 **落地前必修的雷** —— ✅ **2026-08-26 已修**(commit `f0f1f47`: 默认基底改对 + md5 硬断言 + `S95pov` 加 `AUTOBOOT` 闸门), 以下保留说明成因: `tools/mkrootfs.sh:44` 默认基底是
`tfboot/uInitrd.lz4`(md5 `ca0b0467…`, 5,422,770 B, 带 strace), 而 `:36-43` 注释说"这就是卡上那份"
—— **不是**。卡上跑的是 `boot/rootfs_card_orig.bin`(md5 `0e685550…`, 4,984,832 B, 无 strace)。
**下一个人重跑就会静默换掉整个 userland。** 建议: 默认值改对 + 硬断言 md5 +
`S95pov` 加开关文件闸门(只有 `/mnt/mmcblk0p1/pov/AUTOBOOT` 存在才执行)。

⚠ 装第二台时的三样重置(hostname / **machine-id** / ssh host keys)在 DR1 上同样适用,
`machine-id` 那条最致命(DHCP 拿它当标识 ⇒ 两台抢同一个 IP), 见 commit `d97049c`。

---

## 5. 顺带继承的两条反直觉结论 (别在 DR1 上重新走一遍)

1. 🔴 **收发流水线在这个系统里是有害的。** Zynq A/B 实测 (`970edce`):

   | | rx | flip | drop |
   |---|---|---|---|
   | 流水线 | 15-17/s | **4-8/s** | **1600** |
   | **串行** | 10-12/s | **10-12/s** | **9** |

   串行下 `flip == rx`, 一帧不丢。**收得更快, 上屏反而更少。**
   ⚠ 但这条**只在"解码比一圈快"时成立** —— fold_a 把解码压到 55.5 ms < 62 ms 才翻的案。
   **DR1 上若解码更慢, 要重新评估**([[feedback_pipeline_breaks_flip_window_sync]])。
2. **圈级 BCM 别再走一遍**: 技术上全赢(角分辨率不掉, `dec+cpy` 295→35 ms), 但 11 rps 下
   图像重复率仅 3.7 Hz, **用户实看闪烁不可接受**, 要可用需 ≥150 rps, 机械上封死。

---

## 6. 🔴 隐形天花板: DR1 的 WiFi 吞吐**从未确立**, 而载荷正好压在那个数上

| | 数字 | 口径 |
|---|---|---|
| DR1V90 实测 | **26.7 / 28.4 Mbps** | ⚠ **这个数不作数** |
| Zynq-7020 同一测法 | 18 / 47 Mbps | 同上 |
| Zynq 现役真实收包 | ~~24.7 MB/s ≈ 198 Mbps~~ → **110-125 Mbps 持续** | 🔴 **08-27 更正: 198 是突发窗口速率, 不是持续吞吐**(峰值当持续)。板端 DIAG, 修完 `SO_RCVBUF` 之后 |

**为什么 26.7/28.4 不作数**: 那是 Windows 上单线程无 sendfile 的 Python `http.server`
+ **两端都在 WiFi 上共享空口**, 同一测法把 Zynq **也**卡在 18-50
([[project_dr1_wifi_modules]] 自己写了 "绝对吞吐数字仍未确立")。

**当前载荷要多少**【今天离线实测比率 + 推算】。
2026-08-26 在 WSL 用 `python3-lz4` `mode='high_compression', compression=9` 单流实测:

| 素材 | 槽数/色深 | raw | comp | 比率 |
|---|---|---|---|---|
| `frames_3bit_dual50` | 100 槽 3-bit 双面 | 3,686,400 | 298,730 | **12.3×** |
| `frames_bonsai_max` | 564 槽 3-bit | 20,791,296 | 585,315 | **35.5×** |
| `frames_cube142d` (rgbcube 合成图案) | 284 槽 3-bit | 10,469,376 | 104,196 | 100.5× |

⚠ **比率高度依赖内容, 跨 8× 区间。** 合成测试图那个 100× 别当参考。
⚠ 板端走**三流切分**, 切分会略降比率, 这里测的是单流。

⇒ 7.85 MB 的 fold_a 帧 @ 11 fps 需要【推算】:
- 最坏 12.3× ⇒ 638 kB/帧 ⇒ 7.0 MB/s ⇒ **56 Mbps**
- 中间 35.5× ⇒ 221 kB/帧 ⇒ 2.4 MB/s ⇒ **19 Mbps**

🔴 **DR1 那个未确立的 26.7/28.4 正好落在这个区间中间。**
⇒ **用 iperf + 有线服务端 + 多次取分布复测 DR1 WiFi, 应该是整个计划里第一个做的事**
—— 半天成本, 但它决定 §4 的排期是否成立。

---

## 7. 诚实的空白 (v1 的这一节仍然全部有效, 且新增两条)

**v1 留下的, 一条都没被解决:**
- ~~**DR1 HP 口实际可用带宽** —— 无任何记录或实测。§3 整条论证都悬在这上面。~~
  🔴 **08-27 已收口**: 厂商 **1600 MB/s**(DS1200 **V1.0** 表 3-36) + **XMON 硬件带宽计数器
  (0xF8440000)可实测**。仍缺的是**两口并发行为**的板上数, 不是单口上限。
- **DR1 上 50 Mbps/lane 的边沿质量/眼图** —— 需 ≥100 MHz 示波器; 已测的只有 12.5 MHz 下
  半拍延迟 19.75 ns。
- **DR1 带载(屏刷新抢 DDR)下的解码数字** —— 未测。A9 上带载比空载差约 2×
  ([[feedback_decode_bandwidth_halves_under_display_load]]) ⇒ 跨平台对比必须同工况。
- **`ddr_slice_fetch256` 在 DR1 上的实际达成带宽** —— 只有理论账。
  🔴 记住 `MAX_OUTST = 2` 不是可选项: 单笔在途时 HP0 首拍延迟 25 周期就只剩 106 MB/s
  < ~~双屏需求 109.2 MB/s~~。
  🔴 **08-27: 109.2 是 1-bit/360 槽/780 RPM 的旧口径, 现役是约 160 MB/s** ⇒ 这条**更紧**:
  按 160 重判, **1 笔在途在延迟 ≥10 周期就已经不够**(141 < 160), 而 **2 笔在途在延迟 40 周期
  也只有 150 < 160**。⇒ `MAX_OUTST=2` 从"选个默认值"升级成"**可能还不够**",
  上板要按 [[reference_dr1_hp_backpressure_and_ot]] 把它往上提(面板侧计数器是 3 位、上限 7,
  现在只用 2, **改一个参数即可**), 但注意 **HP 口 outstanding 硬上限是 8 读/8 写**(UG1214`:3523`)。
- **电机怎么控制/调速** —— 整个系统 RTL+软件+文档里**查不到任何电机控制代码**,
  PL 纯粹是转子的被动观察者, 调速在系统外。

**v2 新增:**
- ~~**DR1 的 DDRC 入口拓扑与读写仲裁策略** —— 安路侧**两者都没查过**。~~
  ✅ **08-27 两条都查了, 结论方向相反**:
  ① **入口拓扑比预想的好** —— 两个 HP **不合流**(独立 Bus + 独立读/写缓存 + 独立 OCM 出口 M0/M1,
     公共缓存内读/写/OT 三者独立)。
  ② 🔴 **仲裁策略比预想的差** —— "拥塞时读优先于写"**厂商确定否认**, 且**没有最小带宽/
     最大延迟保证**。⇒ Zynq 那个归因的一半在 DR1 上没了。
  ⚠ **仍未决**: DDRC 端口 **M2/M3 按地址还是按 master**(UG1214`:7275-7280` 与厂商答复直接冲突)。
  详见 [[reference_dr1_hp_backpressure_and_ot]] [[reference_dr1_ug1214_ps_facts]]。
- **TD 有没有 SmartConnect 的对等 IP** —— 没查证。没有就得手写 N:1 汇聚器。

---

## 8. 一条已经在 Zynq 侧结案、但影响"对齐到什么"的旧悬案

v1 §6 说"现役 Zynq 可能跑在 12.5 MHz DCLK / 25 Mbps 降级模式"(bit29 位语义反转),
并据此警告"DR1 照计划做完会比 Zynq 现役好 2 倍, 两边画面对比会被污染"。

✅ **该悬案 2026-08-20 在 Zynq 侧翻正了** (commit `ac4948e`: "bit29 翻 fast 上板验证通过(2.07x)"),
并顺带结掉了 aclk 到底是 25 还是 50 MHz 的争议 —— **是 50 MHz**
([[project_pov3d_3bit_color]]: `oeprobe` 采样率不足导致漏沿, 算出 26 MHz 是测法 artifact;
edges 只会被低估不会被高估, 这一条就能排除 25 MHz)。

⇒ **v1 那条"对齐的是一个降级基准"的警告作废** —— 现在两边对的是同一个 fast 基准。
⇒ 面板 1-bit 刷新 **4748 Hz**、3-bit **1583 Hz**; DCLK = aclk/2 = 25 MHz(手册上限), 线速率 50 Mbps。

🔴 **但由此浮出一个新的、没人算过的账**【推算, 需要板上确认】:
3-bit 整屏 1583 Hz, 而 `970edce` 跑的是 **16.15 rev/s** ⇒ 每圈只画得出
`1583 / 16.15 ≈ 98` 个角度, **而配置是 142 槽/面**。
(142 这个数对应的是 `7efe755` 那次的 **11.06 rev/s**: `1583 / 11.06 ≈ 143`, 精确吻合。)
⇒ **08-25 提速到 969 RPM 之后, 142 槽里可能有约 1/3 没机会上屏。**
这不影响帧率(面板不满足只掉角分辨率, 不掉 fps, 见 [[project_pov3d_link_budget_status]]),
但**影响"该渲多少片"**, 对 DR1 意义更大(载荷直接按比例减)。
⚠ **纯算术推断, 没有板上实测。** 别当结论用, 但值得在 E 阶段顺手量一次。

---

## 9. 归档: v1 的七步计划 (2026-08-07 盘定, 08-10 更新)

保留供追溯。**Step 0-5 已完成并全部上板验证**, 结论已并入上文各节:

| 步 | 状态 | 实测 |
|---|---|---|
| 0 前置 | ✅ | 引脚补齐 `spin_sync_i=W6`; 板上取回真实内存图(512 MB, `linux,dma` 占 `0x1000_0000`+16MB) |
| 1 SoC 骨架 | ✅ | GP0 窗 `0x8000_0000` 读写正确; HP0 写 DDR 返回 OKAY |
| 2 屏驱引擎 | ✅ 电气 | 50 MHz SWNS +7.88 ns; 假转 +181 片/100 ms(理论 180) |
| 3 DDR 取片 | ✅ | **FETCH_ERR = 0 / 148,561 字**; 25.5 片/秒 |
| 4 转角追踪 | ✅ 假转 | `locked=1` |
| 5 推流闭环 | ✅ 08-10 上板 | `drop=0` `rx==flip`; **zlib 3.5-3.75 fps**; `cpy=162ms` |
| ~~6 PL lz4~~ | → **v2 的 B 线** | 前提全变: 核已在 Zynq 上board, DR1 侧变成"换 HP 拓扑接进去" |
| ~~7 fps 对照~~ | → **v2 的 E 线** | |

**v1 时代的在途状态**(2026-08-10 收工): 板子当时是热的(PL 已加载 / povmem 已 insmod
`phys_base=0x1a100000` / 假转 15 rev/s / WiFi `10.10.21.51` / `pov_rxd` 在跑),
恢复命令 `tools/serial_run.sh board/cmds_restore_all.txt 300`。
⚠ **距今已 16 天, 别假设板子还是热的。**

**v1 遗留的未提交改动**(`dr1v90/` 工作区里仍是 modified 状态, `git status` 可见):
`board/pov_rxd/pov_rxd.c`(给 `cpy` 加 flush 分项计时) / `tools/stage_to_card.sh`(md5 跳过) /
`board/cmds_step5_run.txt`(删掉 `MAGIC 0x44523156` 那条坏判据 —— 那是 Step1 探针的,
`td_pov/` 下 grep MAGIC 零命中)。
⚠ **C 线若按建议"从 Zynq 版重新 fork", 这份 `pov_rxd.c` 的改动会被丢掉 —— 那个 flush 分项计时值得保留。**

**v1 里那个"下一步: 量 musl `memcpy` 的真实上限"**(`cpy 160ms` 里 memcpy 占 153ms = 59 MB/s,
判断是 DDR 上限还是 musl 通用 C 版的上限)——
⇒ **§2 之后这件事的优先级大幅下降**: PL 直写 bank 之后 CPU 侧不再有 8.85 MB 的 memcpy。
但它仍有残余价值: 决定压缩流那 200-600 kB 的回写成本。

---

相关: [[project_dr1_riscv_verdict]] [[project_dr1_sku_decision]] [[project_dr1_rtl_port_step1]]
[[project_dr1_soc_step1_done]] [[project_lz4_pl_decoder]] [[project_pov3d_3bit_color]]
[[reference_dr1_cache_and_frame_memory]] [[reference_anlogic_dr1_fs03_eval]]
[[reference_panel_oe_no_pullup_anywhere]] [[project_dr1_hp_port_shortage]]
[[project_dr1_pl_decode_removes_both_walls]] [[reference_dr1_wifi_ceiling_unestablished]]
[[reference_zynq_dr1_code_drift]]
