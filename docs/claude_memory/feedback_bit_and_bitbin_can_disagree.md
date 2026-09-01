---
name: feedback_bit_and_bitbin_can_disagree
description: 🔴 TD 输出目录里 fpga_prj.bit 与 fpga_prj.bit.bin 可能是**不同两次综合**的产物 — 拿 .bin 部署会静默装上旧 bit, 而现有每一条判据都照样 PASS
metadata:
  type: feedback
---

# `.bit` 与 `.bit.bin` 会不同步 (2026-08-31 核对 HP1 上板序列时发现)

`td_pov/.../fpga_prj_Runs/phy_1/` 里:

| 文件 | 内容 |
|---|---|
| `fpga_prj.bit` | `450a7f18` — **含 HP1 的新 bit**(与 commit `ad6e3d9` 一致) |
| `fpga_prj.bit.bin` | `62431443` — **08-28 00:09 的 known_good 旧产物, 无 HP1** |
| 卡上 `pov/pl.bin` | `62431443` — 也是旧的 |

成因: `.bit` 由 TD 每次综合覆盖, 而 `.bin` 要另跑一步
(`bootgen -arch dr1v90 -process_bitstream bin`, 见 [[feedback_dr1_load_bit_without_jtag]])
—— **忘了跑那一步, 目录里就留着上一轮的 `.bin`**, 时间戳还很新(被别的操作 touch 过)。

## 🔴 为什么危险: 每一条现有判据都会 PASS

部署的是**能正常工作的旧 bit** ⇒ 屏亮、取片正常、`POVBOOT: PASS`、
MANIFEST 8/8 —— 只有"新加的那个功能没有效果", 而那恰恰是最难归因的一类现象。
(同族教训: [[project_dr1_hp0_fetch_measured_ok]] 的"**卡上的东西不等于仓库里的东西,
先对版本再信行为**"。)

## How to apply

1. **部署前对 md5, 别看时间戳。** `.bit` 和 `.bit.bin` 各算一次, 与仓库/卡上三方对齐。
2. 🎯 **上板判据要能区分新旧 bit, 且不含答案字面量。** 本例用的是**别名差分**:
   新 bit 的 `0x80004014` 是常数 `NENG`, 旧 bit 那里别名到 `FETCH_CNT`
   ⇒ **取片进行中连读两次 —— 新 bit 必须不变, 旧 bit 必然递增**。
   (读一次读不出来; "变不变"这个判据本身不泄露任何一边的数值。)
3. 🔴 **td_pov 至今没有 BUILD_ID 寄存器。** 有它就不需要上面这些花招 ——
   值得补(`0x8000402C` = `4'd11` 还空着)。

相关: [[feedback_dr1_load_bit_without_jtag]] [[project_dr1_hp0_fetch_measured_ok]]
[[feedback_criterion_must_not_contain_its_answer]] [[project_dr1_hp_topology_decision]]
