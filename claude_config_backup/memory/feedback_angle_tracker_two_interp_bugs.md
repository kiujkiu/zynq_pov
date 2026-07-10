---
name: angle-tracker-bug-stable
description: "POV 光电开关角度跟踪 angle_tracker 串行除法器抓了被 pulse 复位的 rev_cnt=1 → slice 死锁0; 修后 div_start 又被 stable 门控 → 变速时 slice_period 永卡 boot 垃圾初值, 周期全错. 两个都要修"
metadata: 
  node_type: memory
  type: feedback
  created_at: 2026-06-15 22:15 CST
  updated_at: 2026-06-23 CST
  originSessionId: 241cce13-9bee-40a1-a353-d0f7b04250fa
---

## ✅ 2026-06-23 用户确认生效 (POV 显示验证通过)
两 bug 修完 + v8 集成 + 部署 CTRL=0xC5E1(sensor_en=1) → **转动下 POV 转速自动跟转, 用户确认验证通过, 不再"待验证"**. 此前唯一待办的"看 POV 显示验"(line29)已完成. 里程碑见 [[project_pov3d_lxb_pov_milestone]].

## 症状链 (用户分两次精确定位)
hub75e_panel_seq_v8.v 内联 angle_tracker, 光电开关 1脉冲/圈, 圈内 720 片靠插值. CTRL bit15 sensor_en=1.
1. **bug1 现象**: 转起来 slice 恒为 0, 角度永不更新.
2. **bug1 修后 bug2 现象**: 每个上升沿后 slice 确实从 0 扫到 719 (脉冲复位 OK), 但**扫的周期完全不对** (差几十倍), 跟电机实际转速无关.

## bug1: 串行除法器抓了被复位的 rev_cnt (跨时钟块 off-by-one-cycle)
`div_start` 是 reg, pulse_ok 那拍(T)同时调度 `rev_cnt<=1`(复位) 和 `div_start<=1`. 除法器是独立时钟块, 下一拍(T+1)才看到 div_start=1 → 此时 rev_cnt 已是 1 → `div_dividend <= rev_cnt` 抓到 1 → `1/720=0` → div_quot<2 → **slice_period_valid 永不置位** → 实模式 `track_en=slice_period_valid&~stalled=0` → slice 永不步进, 每脉冲又复位0.
**修**: 除法器用已锁存的 `rev_period`(cycle T 已置正确周期, T+1 读到对的): `div_dividend <= rev_period;`

## bug2: div_start 被 stable 门控 → 变速时永不更新周期
原 `if (!have_pulse || stable) begin rev_period<=rev_cnt; div_start<=1; end`. stable=连续两圈周期差<12.5%. 后果: ① 第一个脉冲用 boot→首脉冲时间(垃圾)算 slice_period; ② **变速时(手转/电机加减速) stable 永不成立 → div_start 不触发 → slice_period 永卡那个垃圾初值** → 扫得动但速率全错.
**修**: 每个有效脉冲都更新: `rev_period<=rev_cnt; div_start<=1;` 无条件. stable 只留给 `locked` 状态指示, 不再卡 slice_period.

## 关键数学 (修对后为什么周期一定准)
slice_period = rev_period/720, 测量(rev_cnt)和插值累加(acc)都用同一 s_axi_aclk → 时钟频率自动抵消. 一圈 rev_period 周期内步进 rev_period/slice_period=720 次, slice 正好 0→719 扫满一圈, 下个脉冲到时归0. 所以 CLK_HZ 参数(75M vs 实际FCLK1 85.7M)不影响速率, 只影响去抖/最小圈门限(粗门限无所谓).

## 调试手段 (转动中 JTAG 读不到, 见 [[feedback_sensor_const0_panel_spi_miso_workaround.md]])
读必停转, 停转 slice 被 stall 复位. 加了 0x30 RO {locked_ever[31], slice_max[15:0]} 锁存峰值. 但 boot 期 panel_spi_miso 异步毛刺会被 angle_tracker 同步器当 1 个幻象脉冲(sens_cnt 那个独立2FF 却没抓到 → 亚稳态两同步器判不同), 让 slice_max 一次性冲到719 污染锁存. 最可靠 readout 还是**电机连续转时直接看 POV 显示**: 周期对=anime转速跟电机一致+图像稳定锁住; 错=转速不符/漂. 关联 [[project_pov3d_dual_panel_v34g_chess.md]] [[project_pov3d_48sdi_io_plan.md]].
