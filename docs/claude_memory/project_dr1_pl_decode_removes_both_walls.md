---
name: project_dr1_pl_decode_removes_both_walls
description: PL 直写帧 bank 把 DR1 的两堵墙(dec 慢 2.15x + cpy 162ms)一次消掉; 因为 cpy 的成因是"每帧回写 8.85MB", 而 PL 路径下 CPU 只回写压缩流(小 14-40 倍)
metadata:
  type: project
---

# PL 解码把 CPU 移出关键路径 ⇒ DR1 的两堵墙同时消失 (2026-08-26 推理)

## 背景: DR1 曾被判定"5 fps 封顶"

2026-08-10 板上实测 ([[reference_dr1_cache_and_frame_memory]]):
```
DIAG rx=3.53/s flip=3.53/s drop=0 | dec 262.3ms | cpy 162.1ms | wait 45.5ms
```
当时的判断: "即使把 lz4 搬进 PL 让 `dec` 降到 ~85 ms, `cpy+wait ≈ 197 ms` 会接管, 仍只有约 5 fps"。

`cpy=162ms` 的成因是硬的: DR1 无 Svpbmt ⇒ `pgprot_noncached()` 是空操作 ⇒
帧区**必须带 cache** ⇒ 每帧要显式回写 **8.85 MB** D-cache。
(Zynq 帧区是 write-combine, 同一件事只要 20-26 ms, 差 6-8×, 而 CPU 只差 2.15×。)

## 🎯 那个判断的前提被 Zynq 08-25 的做法删掉了

前提是 **"CPU 仍然要把解码结果搬进帧 bank"**。commit `7efe755` 的 `--pl-lz4` 路径:

```
旧: 收包 → comp 缓冲 → CPU 解码 → staging → memcpy 进 bank → 回写 8.85MB → 翻页
新: 收包 → comp 缓冲 → 回写(仅压缩流) → PL 引擎直写 bank → 翻页
                                      ^^^^ 没有 staging→bank 的 memcpy
```
commit 原话: "**没有 staging→bank 的 memcpy**"。

⇒ **CPU 只需回写压缩流。** 2026-08-26 离线实测的 lz4-HC9 比率
(见 [[reference_dr1_wifi_ceiling_unestablished]]) 是 12.3× ~ 35.5×
⇒ 7.85 MB 的 fold_a 帧压缩后 **221 ~ 638 kB**【推算】
⇒ 回写量是原来 8.85 MB 的 **1/14 ~ 1/40**。

## ⇒ "DR1 单核慢 2.15×" 不再致命

那个 2.15× 是 `dec×2 + cpy` 的**整帧**数字 (115.5 ms vs A9 53.7 ms,
[[project_dr1_riscv_verdict]] 2026-08-05 实测)。**这两项现在都不在 CPU 上了。**
剩给 DR1 单核的只有 **TCP 收包 + 一次小得多的 cache 回写**。

顺带解释了为什么 [[project_dr1_sku_decision]] 那句"选了 DR1V90 就等于承诺要把解码搬进 PL"
是对的 —— 但它当时低估了收益: 以为只是补 `dec`, 实际是**一次干掉两堵墙**。

## ⚠ 这是推理不是实测

DR1 上**从未跑过 PL 解码路径**。整条链在 DR1 上的验证还没做, 且要先过
[[project_dr1_hp_port_shortage]] 那一关(2 个 HP 口塞得下塞不下)。

还没有数的: DR1 上那 221-638 kB 回写要多久 (v1 遗留的 "量 musl memcpy 真实上限"
那件事的残余价值就在这里 —— `cpy 160ms` 里 memcpy 占 153 ms = **59 MB/s**,
是 DDR 上限还是 musl 通用 C 版的上限, 至今没判)。

相关: [[project_dr1_parity_plan]] [[project_dr1_riscv_verdict]] [[project_dr1_sku_decision]]
[[reference_dr1_cache_and_frame_memory]] [[project_lz4_pl_decoder]] [[project_dr1_hp_port_shortage]]
