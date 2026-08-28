---
name: project_dr1_hp0_fetch_measured_ok
description: 🎯 2026-08-28 上板实测判决 — DR1 的 HP0 读通路满足面板取片, 占用 86.4%/余量 1.158x 与纸面 1.15x 精确吻合, ar_stall_max=0, pair_miss=0; "HP 带宽是卡点"这条对面板取片作废
metadata:
  type: project
---

# HP0 取片实测: 过了 (2026-08-28)

配置: 新 bit(含 0x2C-0x3C 取证寄存器) 串口部署上板, povmem 48 MB @`0x1a100000`,
`povboot.sh engine` 起 **3-bit / 142 槽 / 16 rev/s** 假转速(= 现役 969 RPM), 双面。

| 量 | 读数 | 寄存器 |
|---|---|---|
| `ar_stall_max` | **0** | R `0x2C[31:16]` |
| `r_gap_max` | 62 拍 | R `0x2C[15:0]` |
| `fetch_max_cyc` | **9502** 拍 | R `0x30[23:0]` |
| slot 预算 | **11003** 拍/次取片 | `fake_period=22007`/片 ÷ 双面 |
| **占用率** | **86.4% ⇒ 余量 1.158×** | |
| 等数据/忙碌 | **6.37%** | `0x38`÷`0x3C`, 同时钟域同口径, 无频率假设 |
| `err_cnt` / `pair_miss` / `wd_trip` | 0 / **0** / 0 | |

## 三条结论

1. 🎯 **1.158× 与纸面算的 1.15× 精确吻合** ⇒ 带宽账在硬件上被证实, 不再是推算。
2. 🎯 **`ar_stall_max = 0`**: HP0 每一笔 AR 都立即接受, 从不反压。唯一的停顿是等数据,
   只占忙碌时间 6.4%。**"HP 带宽是卡点"这条对面板取片作废。**
3. 而这个 1.15× **本来就不是 DR1 独有** —— `create_panel_proj_v6.tcl:153`
   `PCW_S_AXI_HP0_DATA_WIDTH {32}` ⇒ Zynq 的 HP0 也是 32 位 @50MHz, 同样的顶、
   同样的需求, 跑了几个月 drop=9。**不要为这 1.15× 改 RTL。**

## 🔴 撤掉一条判据

~~`r_gap_max > 43` ⇒ 必须降 `n_slices`~~ —— 实测 **62 > 43 但整体过**。
那个 43 是**延迟模型的外推**, 假设每笔突发都独立付一次首拍延迟;
而 `MAX_OUTST=2` 让一笔的延迟藏在另一笔的数据底下 ⇒ 模型系统性偏悲观。
⇒ **整笔事务的直接测量(`fetch_max_cyc` vs slot)压过延迟模型的外推。**

`n_slices` 142→98 仍是**白拿的优化**(帧 −31%, 余量 →1.67×, 零画质代价 ——
`icnd2047_panel_core.v:55,126-127` 给出 3-bit 整屏 31,590 拍 ⇒ 每圈只画得出 98 个角度),
但它现在是**优化不是必需**。

## ⚠ 别把这份结果读成"全通了"

- **lz4 三引擎的写洪水没跑** ⇒ 它们打 HP1 时对 HP0 的干扰**未测**。厂商说两个 HP
  不合流、读写缓存各自独立, 但 DDRC 侧争用仍在。**这是下一个要测的。**
- 假转速不是真传感器; 没接屏 ⇒ 面板输出通路零验证;
  DDR 里是未初始化内容 ⇒ **只测了搬运, 没测正确性**。

## 顺带两条

- **STATUS 里没有 bpp_mode**。组装原文 `pov_dual_top.v:531` 是
  `{14'b0, wd_trip, base_b_act, fold_a_en, mirror_a, ...}` —— `[17]` 是新加的 `wd_trip`。
  `:47` 那句"[17]=bpp_mode"的注释是过期的, 已经骗进过 `BRINGUP_TOMORROW.md`。
  **色深无法回读**, 只能信 `povboot.sh` 打印的 `sub01 <= ... bpp3=1`。
- 🔴 **卡上的 `povboot.sh` 是旧版**(usage 里没有 `mode`) ⇒ `BPP=3` 一直静默不生效。
  是用 [[project_dr1_serial_transfer_channel]] 把仓库版 43 KB 推上去才切成 3-bit 的。
  **卡上的东西不等于仓库里的东西, 先对版本再信行为。**

相关: [[project_dr1_hp_port_shortage]] [[project_dr1_hp_topology_decision]]
[[project_dr1_serial_transfer_channel]] [[feedback_pair_miss_sentinel_was_broken]]
