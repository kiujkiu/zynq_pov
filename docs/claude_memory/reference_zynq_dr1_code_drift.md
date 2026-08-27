---
name: reference_zynq_dr1_code_drift
description: 2026-08-26 逐文件量的两条线漂移 — RTL 只差 345 行且零新增 Xilinx 原语, lz4 核逐字节相同; 真正的落差在板端软件 +1421 行
metadata:
  type: reference
---

# Zynq ↔ DR1 两条线的实际漂移 (2026-08-26 逐文件量)

移植前先量, 别按感觉估。结论: **RTL 漂移很小, 软件漂移才大。**

## RTL: 三个文件共 345 行, 零新增原语

`diff -u dr1v90/td_pov/soc_prj/uisrc/01_rtl/<f> mlkpai_fs03/vivado/hdl/<f>`, 数 `^[+-][^+-]`:

| 文件 | 改动行 | 内容 |
|---|---|---|
| `icnd2047_panel_core.v` | **154** | 3-bit 行内 BCM 三平面 + half_scan |
| `pov_dual_top.v` | **138** | `0x0C` sub01 寄存器 / plane 地址 / fold_a / `frame_period` 引出 R0x28 |
| `panel_engine_2047.v` | **53** | |
| `angle_tracker.v` | **0** | 逐字节相同 |
| `row_drv_icnd1028.v` | **0** | 逐字节相同 |

🎯 **新增 Xilinx 原语 = 0**。grep `RAMB|BUFG|MMCM|PLLE|IDDR|ODDR|XPM_|DSP48|IOBUF|FDRE|SRL`
只命中 `ODDR` —— 而 ODDR 早就有 `oddr_dr1_shim.v` ([[project_dr1_rtl_port_step1]])。

## lz4 核: 逐字节相同

`diff -q mlkpai_fs03/vivado/hdl/lz4/lz4_decode_core.v dr1v90/lz4hw/rtl/lz4_decode_core.v` → 无差异。
`lz4_axi_top.v` 同样。
⇒ Zynq 08-25 上板跑通的**就是** DR1 那份核, 一行没改。
新东西只有 Zynq 侧新写的适配壳 `lz4_engine_axi.v`(498 行)。

## 板端软件: +1421 行, 这才是大头

| | 行数 |
|---|---|
| `mlkpai_fs03/stream/board/pov_rxd.c` | **3560** |
| `dr1v90/board/pov_rxd/pov_rxd.c` | **2139** |
| 差 | **+1421** |

(单次 commit `7efe755` 的 diff 就是 `pov_rxd.c | 1387 +++`。)
⇒ **建议从 Zynq 版重新 fork, 而不是往 DR1 那份上打补丁** ——
08-25 的改动都落在核心路径(收包/引擎调度/翻页定序)上, 手工合并风险高于重打 DR1 的几处已知差异。
DR1 那几处差异是可枚举的, 见 [[project_dr1_parity_plan]] C 线。

## 🔴 但"改动行少"不等于"移植容易"

三个反例, 都在 [[project_dr1_parity_plan]] 里展开:
1. `fb_lane_ram.v` 要重做 —— fb 深度 512→1024 + plane 进地址, 而
   **TD 不认 generate 块里的 RAM 推断**([[feedback_td_infer_ram_skips_generate_blocks]]),
   DR1 侧靠显式例化。
2. lz4 核虽然一样, 但**外围 HP 拓扑完全不同**(Zynq 4 口, DR1 2 口),
   见 [[project_dr1_hp_port_shortage]]。
3. 软件那 1421 行里有三个非显然点(看门狗起点 / done 新鲜度 / bank 定序),
   都是流水线引入的 bug 修复, 漏搬会在 DR1 上原样复现。

## ✅ 2026-08-26: "重新 fork"这条建议已执行, 结论是对的

`board/pov_rxd/pov_rxd.c` 从上游 `7efe755`(3560 行)**重新 fork**, DR1 差异当补丁重打:
**24 个 hunk, +339/-68**, 全部可枚举、无一条是意外(逐条对照表在 `board/pov_rxd/PORT_STATUS.md`)。
本机 12 项自检全过(x86 回归 22 帧+13 NAK+6 个 PL 场景 / riscv64 三条 / 上游能力 grep 计数)。

**重新 fork 比打补丁对**的实证: 上游那 +1596 行**全在核心路径**(收包/调度/翻页)上,
且其中三个非显然点(看门狗起点在 `pl_sched_wait` 而非 launch / done 新鲜度靠 start 后立刻读 /
bank 定序先发布 N-1 再认领 N)逐条往前追必漏。

🔴 fork 时**新挖出一条上游没有、DR1 独有且必需**的: `pl_stage_streams()` 里要
`frame_flush(comp_phys)` —— 上游没这句是因为 Zynq 帧区是 write-combine, 而 DR1 帧区**带 cache**
且 HP 口不 snoop D-cache ⇒ 不回写引擎就读到**上一帧的压缩流残留**,
而 lz4 解错不一定报错, 症状是"画面是旧帧/偶发花屏"不是干净的报错。
⇒ **"改动行少 ≠ 移植容易"这条本文的警告, 在软件侧兑现的方式是"多出你想不到的一条", 不是"多改几行"。**

相关: [[project_dr1_parity_plan]] [[project_dr1_rtl_port_step1]] [[project_lz4_pl_decoder]]
[[project_pov3d_3bit_color]] [[project_dr1_hp_port_shortage]] [[project_dr1_hp_topology_decision]]
[[reference_dr1_cache_and_frame_memory]]
