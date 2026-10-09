---
name: project_pov3d_sw_plan_20d_2026_10_09
description: 2026-10-09 用户定 — FPGA/板端/上位机 20 工作日计划（不算硬件）；主验收 DR1M90 对齐 7020 的 2047 双面体像，后半 GW5A+2260 软件路径封板；正文在 zynq_pov/docs/软件计划_DR1M90对齐与验证板固件_2026-10-09.md
metadata:
  type: project
---

# 软件 / FPGA 20 日计划 (2026-10-09)

用户原话：「整理一下下一步项目计划与实现，给一个参考完成时间，不考虑硬件，我理解应该是 20 天左右工作量」→ 随后「保存一些，然后落成一个计划文档」。

**正文（逐日 / 四门 / 不做清单）**：
`zynq_pov/docs/软件计划_DR1M90对齐与验证板固件_2026-10-09.md`

## 口径

- 只算 FPGA + 板端软件 + 上位机。灯板/转接板改版、转子、WPT、自研 SOC、回板等待 **全部不进这 20 天**。
- 主验收 = DR1M90 追上现役 Zynq-7020 **ICND2047 160×180 偏心双面体像**。
- 后 10 天把 GW5A 桥 + 2260 两模式（显示 503×60 扫 / 压测 603×48 扫）软件做完，回板只剩接线。
- 只做对齐 7020 ≈ 8–10 天；20 天是对齐 + 验证板固件封板。

## 四门

| 门 | 日 | 看见 |
|---|---|---|
| M1 | D5 | 2047 双面全白 |
| M2 | D10 | WiFi 推流体像，10–12 fps 档 |
| M3 | D15 | 主控↔桥环回或 2260 单板出图案 |
| M4 | D20 | 两模式 + 开机 + WiFi 远程 |

## 开工基线（写计划当天）

DR1M90 停在 09-22：GP0 探针 + WiFi 159，**没有 2047 显示位流，没接过屏**。
GW5A 桥 BIT:OK、冒烟 PASS、4lane@400M PASS，86 对全功能未接外部器件。
`pov_rxd_aarch64` 能编不能跑（缺 povmem + 显示 PL）。
ATF 放开 GP0 复位、PS 封装可沿用 RISC-V IP —— 这两条 09-22 已实测，差距表里「头号风险」作废。

## How to apply

问「下一步做什么 / DR1M90 还差啥 / 这 20 天包不包含硬件」先指这份计划。
改逐日内容改 docs 里那份 md，这里只留口径和门。
D1 开工 = 显示工程改 `DR1M90GEG484` 出 bit，与 `povmem` aarch64 重编并行，都不占屏。

相关：[[project_dr1m90_parity_2047_gap]] [[project_dr1m90_gp0_first_light]] [[project_dr1m90_jtag_port_checklist]] [[project_gw5a_bridge_firmware]] [[project_pov3d_final_target]] [[project_pov3d_trial_board_rotate_and_target_load]]

## 进度
- 2026-10-09 晚: 用户先接了 GW5A (ACG525, 无 DR1M90/2260), **D11 提前做完** —— gw5a_bench 单板验证,
  见 [[project_gw5a_bench_1009]]。顺带发现寄存器定时刷新的坏帧问题 (D15/D17 前要解)。
