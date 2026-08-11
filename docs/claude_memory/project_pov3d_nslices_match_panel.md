---
name: project_pov3d_nslices_match_panel
description: 面板每圈只画得出 ~89 个角度而在渲 360 ⇒ 载荷/解码/memcpy 3/4 是白付的; PC 侧 --n-slices 已做好并实测 4x, 但板端双面拆分把 360 写死, 单面路径可用
metadata:
  type: project
---

# 把 `n_slices` 匹配到面板真实能力 (2026-08-10)

## 为什么

面板实测 2D 刷新 **~1340 Hz**([[project_pov3d_refresh_vs_rpm]] 的 oe 扫描),
15 rps 下每圈只画得出 **~89 个不同角度**, 而现在渲 **360** 片。
⇒ **3/4 的片根本没机会上屏, 但链路/解码/memcpy 为它们付的代价是实打实的。**

⚠ 这**不是**画质取舍: 面板画一屏要 749 µs, 期间转子已经转过 4.04°,
所以比 4° 更细的角度**物理上分辨不出来**。降到 90 片是去掉纯浪费, 不是降质。

## 已完成: PC 侧 `--n-slices` (`stream/pc/povstream.py`)

`N_SLICES=360` 原本是模块级常量, 12 处引用。改法: 加 `_apply_slot_count()`
在 `main()` 解析完参数后落到全局(**必须在任何渲染/打包之前**, 因为 `FRAME_RAW` 按它算)。
`--render-slices` 默认改成 `0` = 跟 `--n-slices` 走(每槽一个真实角度)。
关键: `render_packed_frame()` 里 `d_step = 2π/render_slices` —— **角度本来就是参数化的**,
`N_SLICES` 只决定槽数布局, 所以改动很浅。

**实测**(palace, 双面):

| | 360 槽 | 90 槽 |
|---|---|---|
| 帧长 | 8,847,360 B (720 片) | **2,211,840 B (180 片)** = **÷4.00** |
| PC 渲染 | 1.3 s/帧 | **0.3 s/帧** = ÷4.3 |

✅ 默认 360 路径回归过: 帧长与改动前逐字节同尺寸。

## 🔴 板端**不是**零改动 (我先说错了, 被板子当场否掉)

`protocol.h:37` 写的"头里的 n_slices 是权威, 不再硬校验 == PVS_N_SLICES"
**只管长度, 不管几何组合**。`pov_rxd.c:1391`:
```c
n_a = (h.flags & PVS_FLAG_FOLD_A) ? PVS_N_SLICES_FOLD : PVS_N_SLICES;  /* 360 写死 */
if (n_slices != n_a + PVS_N_SLICES) { NAK; }   /* 双面只认 720 或 540 */
```
⇒ 推 90+90=180 片双面帧, 板子**当场 NAK**。

**但单面路径没这个约束**(`n_a = n_slices` 直接放行)
⇒ **单面 90 片今天就能跑通, 已实测**(帧长 1,105,920 B, 板子正常收下)。

**要支持双面 90 需要改板端**: 把 `:1391` 那两个 `PVS_N_SLICES` 换成从帧长/头里推
(如 `n_a = n_slices / 2`), 或在头里显式带 `n_a`。改动很小, 但要重编重部署 FS03。

## ⏸ 端到端显示收益**未验证**: 电机没转

板端 DIAG: `eng=0.0rev/s rx=8.12/s flip=0.45/s drop=53446 | dec 0.0ms | wait 2001.0ms`
—— 转子不转 ⇒ `slice_idx` 不动 ⇒ **翻页窗永远不来**, flip 每 2 s 被强制一次。

🔴 **PC 报的 15.02 fps 是假的**: RX 线程收到就 ACK, 与上不上屏无关。
**看 fps 永远要看板端 DIAG 的 `flip`。** (DR1 上同一个坑: PC 6.47 / 板上 5.00。)

⇒ 要验证真实收益, **需要电机转起来**。而电机控制不在本系统里
(RTL+软件+文档全查不到, PL 只是转子的被动观察者), 得人工介入。

## 对 DR1 的意义可能比对 Zynq 更大

Zynq 已经达标 15 fps, 降 `n_slices` 换来的是余量(`dec+cpy` 从 1.39× 到 ~5.6×)。
而 **DR1 卡在 5.0 fps, 墙是 `memcpy 153ms` + `dec 145ms`** ——
**载荷 ÷4 就是这两项 ÷4**, 有可能直接把 DR1 推到转速上限,
**比 memcpy 微优化和 PL lz4 都便宜**。见 [[project_dr1_parity_plan]]。

相关：[[project_pov3d_refresh_vs_rpm]] [[project_pov3d_link_budget_status]]
[[feedback_verdict_design_before_blaming_dut]]
