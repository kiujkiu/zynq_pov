---
name: project_pov3d_eg4_200mhz_solved
description: EG4 上 200MHz+160ps抖动收敛了 ⇒ 800Mbps 成立(SWNS +0.106, 0违例); 病根不是高扇出复位而是 lane_align 的 lock_cnt 扇入过宽/逻辑深度; phys_opt=ultra 必须常开; 天花板 200~215MHz
metadata:
  type: project
---

# EG4 200 MHz + 抖动 收敛了 —— 800 Mbps 成立 (2026-09-04, commit 3e13b1b)

```
UNCERT=0.16 PHYS_OPT=ultra ./build_v3.sh 200
→ SWNS +0.106 / HWNS 0.000 / setup 与 hold 违例端点都是 0 (3181 端点) / Fmax 204.3
基线同条件 (rtl/ v2): −0.056 / 13 个违例端点
```
⚠ TD 实际按 **0.260 ns** 查 —— 默认 0.100 与 sdc 的 0.160 **叠加**。

## 🔴 病根不是高扇出复位 —— 我给错了方向

我在任务书里写"最差路径 = `rt_cnt → u_dsk/rst`(扇出 433~533)",
**那是 PH1A60 报告里的结论, 错拿来当 EG4 的**。EG4 基线的实情:
- 13 个违例端点里 **12 个是 `lane_align` 的 `lock_cnt`**, 第 13 个是 `rx_fifo` 的 `wr_full` 自环
- 最差路径 `Max Fanout` 只有 **15**; `prst|retrain` 那张大网**一次都没进过最差 10 条**
- ⇒ **是扇入/逻辑深度问题**: `lock_cnt` 下一状态同时依赖 13 个来源
  (`any_s` 8 位或、`lock_cnt==LOCK_CNT` 5 位比较、`wd_cnt==LOSS_WORDS` **10 位比较**…),
  在只有 LUT4/LUT5 的 EG4 上必然铺成 4 级
教训: **别把 A 器件的最差路径结论迁移到 B 器件**, 各自看各自的报告。

## 各手段前后 (200 MHz / UNCERT=0.16)

| 手段 | SWNS | 违例端点 |
|---|---|---|
| 基线 rtl/ v2 | −0.056 | 13 (5 级) |
| **A** `lane_align` 状态锥压扁 + **B** `rx_fifo` 拆自环 | −0.194 | **1** (剩的是 synth/ 里的 LED 探针 `st_any`) |
| A+B + **D** `phys_opt -effort ultra` | **+0.113** | **0** |
| A+B + **C** `rt_cnt` 复制 ×5 | +0.111 | 0 (**直接收益 ≈ 0, 在布局噪声内**) |
| **E** retiming 属性 | −0.056 | 13 (**与基线逐字相同 ⇒ EG4 上完全无效**) |

A1/A2/A3、B、C 都是**逐拍恒等**改写(区间证明+归纳法, 写在各文件头);
只有 A4(优先编码器输出寄存一拍)改变行为, 对齐用时 1175→1185 ns。
`sim/run_sim_v3.sh` 三项全过(1000 beat × 208 bit 逐 bit 全等)。

## 时钟方案的账

| 方案 | v2 | v3 | pclk skew |
|---|---|---|---|
| 3 = PLL→BUFIO (现役) | −0.056 (13) | **+0.111** (0) | 0.326 |
| 1 = PLL 直出两路 + CPHASE=DIV | −0.303 (22) | **+0.101** (0) | 0.326 |

- **换方案对 v2 净亏 0.25 ns, 对 v3 只亏 0.01 ns** ⇒ **换时钟方案的钱必须先由 RTL 侧挣出来, 单换更糟**
- 🎯 **CPHASE 对 fabric 时序零影响**(PCPHASE=0 与 1 的 SWNS/HWNS/Fmax 逐位相同, 路径预算仍 5.000 ns)
  ⇒ **选相位不用付 fabric 的钱**, 可放心用它把 IOL 相位调到 180°
- 🔴 **skew 与扇出/方案/seed 全无关**: 29 次跑 pclk skew **都是 0.326**
  (同报告里 rclk/fanout 149 是 0.480、sclk/fanout 13 是 0.100 ⇒ skew 确实按网算)
  ⇒ 我担心的"13 lane 让 skew 更大"在 TD 模型里看不到; 相位实验那边 0.254 vs 0.408 **不能外推到本设计**

## 三条写进流程

1. **`PHYS_OPT=ultra` 必须常开** —— `PLACE_SEED=3` 不开掉到 −0.310, 开了回 +0.132 (4/4 seed 全过)
2. 🔴 **`phys_opt -post_route` 让 TD 2026.1 SP2 coredump**
   (`Stage 7.4 | Run Abnormal Path Checker` → `Oops! coredump minidump-*.dmp`), 默认关
3. **天花板 200~215 MHz** —— 225 档 −0.322 / 54 违例, phys_opt 救不回来
   ⇒ **800 Mbps 就是这颗 55nm 片子的上限**

⚠ `PLACE_SEED=2` 那 40 个 hold 违例是**方法学假象** —— 把 160 ps **周期**抖动加到**同沿** hold 检查上
(`Budget: 0.000ns { pclk rising@0.000 − pclk rising@0.000 }`)。
`UNCERT_HOLD=0` 复算: **HWNS +0.024 / 0 违例, 所有 seed 都过**。

## ⇒ 对方案的影响: 800M 成立, 引脚账回到 87

| 口径 | 需求対 | BG256 可用 88 | |
|---|---|---|---|
| **8-bit @800M** | **87** | 88 | ✅ **余 1** |
| 8-bit @700M | 89 | 88 | ✗ |
| 12-bit @800M | 93 | 88 | ✗ 要 CG324(104) |

🎯 **顺带把 FS03 救回来了**: 8-bit@800M 双面 62 根, 剩 34 根做地 = 1.2 根/対 ✅
(700M 那个 0.81 破线的问题不存在了)

## 没试的
`create_bound` 区域约束(命令在 `doc/cmd/help_comment_phy.json`, 写法只在**没装的 SWUG202** 里);
`max_fanout` 属性(SWUG106 自警"可能导致逻辑级数增大", 而本次病根正是级数); `st_any` 探针本身没改。

产出: commit **3e13b1b** on `feature/uplink-tx-probe`(未 push) —— `rtl_v3/`×5、`build_v3.sh`、
`sim/run_sim_v3.sh`、`synth/uplink_rx_synth_top_v3.v`、README 新增一节(12 小节+汇总表+资源对照)。
`rtl/`、原 `synth/`、`build.sh`、`build_ph1.sh`、`build_jitter.sh`、`sim/run_sim.sh` **经 git diff 确认一字节未动**。
报告备份 scratchpad `eg4_200m/` (26 份 final_timing.rpt + .timing/.sdc + 32 份 stdout)。

相关: [[project_pov3d_eg4a20bg256_bridge_selection]] [[reference_eg4_iol_phase_measurable]]
[[project_pov3d_uplink_rate_pin_budget]]
