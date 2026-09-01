---
name: feedback_phase_b_must_follow_n_slices
description: 🔴 改 n_slices 必须同时改 PHASE_B(0x1C) — RTL 复位 180 且 idx_b_live 只做一次条件减不取模, PHASE_B >= n_slices 时面 B 读野地址且无任何报错; 360 槽时 360/2=180 恰好等于复位值所以从没人写过它
metadata:
  type: feedback
---

# `PHASE_B` 必须跟着 `n_slices` 走 (2026-08-31 查 n_slices 优化时挖出)

## 事情

偏心双屏的面 B 比面 A 差半圈, 相位由 `PHASE_B`(寄存器 `0x1C`) 给。
**RTL 复位值是 180**(`pov_dual_top.v:322`), 而 `idx_b_live` 只做**一次条件减,
不取模**(`pov_dual_top.v:272-274`)。

⇒ **`PHASE_B >= n_slices` 时面 B 的片索引跑出帧尾 = 读野地址, 而且哪儿都不报错。**

🔴 **为什么至今没人踩到**: 现役配置 `n_slices=360`, `360/2 = 180` **恰好等于复位值**
⇒ 这个寄存器**从来没有被写过也不需要写**。
⇒ 一旦把 n_slices 降下来(94 槽的生产几何、或任何 `n_slices <= 180`),
**立刻踩**, 且症状是"面 B 显示垃圾"而不是任何一条判据 FAIL。

## How to apply

1. **写 `0x10`(n_slices) 的地方必须同时写 `0x1C = n_slices/2`。**
   已在 `board/povboot.sh:729` 的 `stage_engine()` 里补上,
   **在 `N_SLICES=360` 下逐位无变化**(所以这个修复本身零风险)。
2. `pov_rxd` 每帧会重新落同一个值(`pov_rxd.c:2783` `half_eng = n_eng/2`,
   `n_eng` 从 `0x24` 影子读回) ⇒ 上面那条只覆盖 **"引擎开"到"第一帧到"** 的窗口 ——
   但**每一次没有 PC 的 bring-up 都整个落在这个窗口里**。
3. ⚠ 同族的另一条: **`FOLD_A=1` 要求 `n_slices` 是偶数**。RTL 在
   `half_slices = n_slices>>1` 折叠(`pov_dual_top.v:283`, **截断移位**), 主机端渲
   `1.5*N` 片再按 `/3` 切(`pov_rxd.c:2926`) ⇒ 奇数 N 两半差一片且无人报告。
   已加守卫(`povboot.sh` stage_engine)。
4. 🎯 教训与 [[feedback_only_synthesis_catches_it]] 同族: **"复位值恰好正确"是一种
   会到期的运气** —— 它让一整条配置通路在多年里看起来是活的, 而其实从没被行使过。
   换参数时要专门找这类"从来没写过的寄存器"。

相关: [[project_pov3d_nslices_match_panel]] [[project_pov3d_v31_dualface_geometry_solved]]
[[feedback_criterion_must_not_contain_its_answer]]
