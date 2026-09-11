---
name: feedback_tech_eval_excludes_supply
description: 芯片技术评估不掺供货/价格 —— 用户自己综合采购信息, 我只给纯技术排序与依据 (2026-09-11)
metadata:
  type: feedback
---

评桥片/主控候选时, **技术结论里不要把供货、货期、价格当判据或当"最大风险"压轴**。

**原话 (2026-09-11)**: 我答"GW5A 技术上优于 EG4, 但最大风险是散片供货"后, 用户: 「供货问题不考虑，我会综合给采购的信息出来」。

**Why:** 用户把技术与采购两条线分开, 采购信息由用户自己汇总后做最终决策; 我把供货混进技术结论会稀释技术判断, 也和用户的分工重复。

**How to apply:** 回答"X 是否优于 Y"时, 只按技术轴 (IO/gearing、真差分对数与 bank 电压、时序余量、LUT/BRAM、共模、工具链成熟度) 给排序和实测依据, 并指出决定排序的未验项; 供货最多一句"不在本评估内", 不展开。
注意与 [[project_pov3d_hw_delivery_package]] 里"给硬件的选型交付要附采购价格货期"区分 —— 那是**下发给硬件同事的任务要求**, 不是我的技术评估口径。
相关: [[project_gw5a_bridge_verification]] [[project_pov3d_chip_selection_unlocked]]
