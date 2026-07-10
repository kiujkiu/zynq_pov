---
name: dual panel 共享 DCLK/LAT/OE/ABCDE 让 panel 1 W 从白变橙
description: panel 2 接入 = panel 1 共享信号 fanout SI 降级, panel 1 chain 末端 B chip latch 失败 → W 缺 B. 74HC245 buffer 不完全解决
type: feedback
created_at: 2026-06-10 02:25 CST
updated_at: 2026-06-10 02:25 CST
originSessionId: 9191f0e2-0bfd-4c68-bb07-c85f057b8792
---
## 现象 (2026-06-10 reproducible)

panel 1 (FM6124, 内部 chain GRB) 行为依赖于 panel 2 是否接入:
- **panel 2 IDC 拔掉** → panel 1 单独, W (R+G+B all on) = **真白** ✓
- **panel 2 IDC 接回** → panel 1 W = **橙** (B 完全缺), Y 偏红橙, M 几乎纯红 (B 缺)

**关键事实**: panel 1 IDC 接线没动, FPGA build / verilog / XDC 全没改, 物理上只切换 panel 2 是否接入 → panel 1 显示就变。

## 根因

panel 1 跟 panel 2 共享 4 类信号 (8 根线): DCLK / LATCH / OE / ABCDE[5]. 共享方式 = panel 2 IDC pin 跟 panel 1 IDC pin 并联接到 J1 同 PIN (Y18 DCLK / Y19 LAT / AB20 OE / W18/W17/W16/AB19/AA18 ADDR).

panel 2 接入 → 这 8 根信号上 panel 2 chip input 当并联负载 → FPGA IO 看到的负载翻倍 → 边沿斜率变缓 + 反射加重.

panel 1 内部 chain GRB 顺序 (G chip → R chip → B chip cascade), B chip 在 chain 最末, **DCLK 边沿到 B chip 时已被 G+R 两段 chip 传输延迟**, 加上 panel 2 加入后 DCLK 边沿质量再降一点 → **B chip latch setup window 撞墙** → B 整体 fail → W 缺 B = 橙.

## 部分修法 — 74HC245 buffer 转接板

用户接 panel 2 时已加 74HC245 buffer 转接板物理隔离 panel 1/2 SI. **但实测仍然 W=橙**:
- 8 色循环 (panel_8c_0..6.jpg): R/G/B/M/C 都 OK, **W 仍橙 ✗**, Y 偏红橙 ✗
- chess 8×8 显示 panel 1 顶部 cell 偏橙 (B 弱), 大部分 cell OK

可能 74HC245 没 buffer 全部 8 根信号, 或 buffer 引入的延迟反而让 panel 1/2 latch 失同步.

## 完全修法 — panel 2 独立 8 pin (待做)

panel 2 不共享 DCLK/LAT/OE/ABCDE, 各自独立 FPGA pin:

| 信号 | J1 pin | FPGA pin | site |
|---|---|---|---|
| DCLK2 | J1.31 | Y14 | L22P |
| LAT2 | J1.34 | V14 | L19P |
| OE2 | J1.27 | AA17 | L17P |
| ADDR2[A] | J1.23 | V13 | L20P |
| ADDR2[B] | J1.24 | W13 | L20N |
| ADDR2[C] | J1.37 | T22 | L2P |
| ADDR2[D] | J1.38 | U22 | L2N |
| ADDR2[E] | J1.15 | AB16 | L18N |

verilog: `hub75e_panel_seq_v4` 加 4 个 output (`hub75e_dclk_out2`, `hub75e_lat_out2`, `hub75e_oe_out2`, `hub75e_addr_out2[4:0]`), driver 值跟 panel 1 同步.
XDC: 加 8 行新 pin assignment.
接线: panel 2 IDC 的 DCLK/LAT/OE/ABCDE 这 8 根从原 panel 1 共享 pin 拆下, 接新 pin.

**Why:** 48 SDI 方案下后续会有 24 panel 输入, 共享信号必然崩, **panel 2 独立** 是 48 SDI 必经之路.

**How to apply:** 任何 dual+ panel 设计先确认 DCLK/LAT/OE/ABCDE 各自独立 FPGA driver, 不能共享 IDC pin 并联.

## 排错踩坑

- 之前一开始怀疑 W=橙是 SSO (bank 33 同时翻转 IO 太多), 后来发现 fill 全 1 时 RGB pin 静态不翻, SSO 不成立 → 撤回 bank 35 方案
- 怀疑过 panel PSU 5V droop, 但 panel 1 单独时 W=白 → 排除
- 怀疑过 verilog byte-slice, revert 后表现一样 → 排除
- 怀疑过 XDC DRIVE 4 SLEW SLOW, 撤回后表现一样 → 排除
- 怀疑过 DCLK 超 FM6124 spec (36 vs 30 max), 降到 30 MHz 实测 W 反而**更红** (G 也跟着弱), 31.25 MHz panel 全黑 → 撤回 36M default
- 真根因是 panel 2 接入 → 共享信号 SI 降级 → panel 1 内部 B chip latch fail

## DCLK 频率扫描 (2026-06-10 03:05)

| DCLK | FCLK1 reg | FCLK1 | W 显示 | 备注 |
|---|---|---|---|---|
| 36 MHz | 0x00500500 (5,5) | 72M | 橙 (B 弱) | v34j default ✓ |
| 30 MHz | 0x00500600 (5,6) | 60M | **红** (G 也弱) | 恶化 ✗ |
| 31.25 MHz | 0x00400400 (4,4) | 62.5M | 全黑 | panel chip 崩 ✗ |

LXB IO PLL = 1800 MHz (PS_CLK 33.333 × FDIV 54). FCLK1 = IO_PLL / DIV0 / DIV1. DCLK = FCLK1 / 2 (DCLK_DIV=2).

mwr 0xF8000180 写 reg 后 SLCR 不需 unlock (ps7_init 最后 unlock 状态), 但要确保 _8color_cycle.tcl 没被旧值覆盖. 改 reg 立即生效, 不需要 reset.

**结论**: 36 MHz 是当前 sweet spot, 降频不修 W=橙. TUNIT/BCM plane 时序跟 DCLK 频率耦合, 降 DCLK 后 PWM 周期被拉长, panel 内 chip latch 进一步偏窗口边缘.
