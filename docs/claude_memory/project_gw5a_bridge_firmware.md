---
name: project_gw5a_bridge_firmware
description: 2026-09-22 WS4 — 把已时序收敛的 eg4_bridge(EG4A20, dclk150 整机0违例) 移植到 GW5A25 桥片; 工程 dr1v90/gw5a_bridge/; 新写两个器件层文件(bridge_clk_gw5a/bridge_io_gw5a) + 移植顶层, 其余(ul_dispatch/tx_array/icnd2260_seq/ack_rx/tx_shared_ctrl/tx_lane_dp)直接引用真源不改字; 综合/映射/布局布线全跑通(LUT 28%), 只卡最后IO引脚放置(37 IOBUF unPlaced, 抢配置复用脚冲突, 不是真装不下); 上行改IDES8(已验证, IDES4在GW5A零余量)
metadata:
  type: project
---

# gw5a_bridge — EG4 桥片固件移植到 GW5A25 (2026-09-22, WS4)

用户目标口径②近期验证板定桥片器件 = **GW5A**(不是之前先做出来的 EG4)。已有一份
**时序收敛**的桥片全功能固件 [[project_eg4_bridge_firmware]](EG4A20, dclk150 整机 0 违例,
24 链驱 ICND2260 + DR1 上行分发), 本轮把它移植过去, 工程 `dr1v90/gw5a_bridge/`。

## 🎯 关键判断: 不是从零写, 是移植 + 复用

先查现状避免重复劳动 (用户 09-22 提醒过), 发现两块已经做完不用重做的活:
- **上行 IDES8 改造已在 09-11 做完** ([[project_pov3d_lvds_b2b_bench]] 相邻工作,
  `uplink_rx/rtl_x8/`): 800M 下三颗 GW5A 全 0 违例, 余量 20~27% (IDES4 在 GW5A 上
  规格零余量, 见 `uplink_rx/README_gw5a.md`)。
- **EG4 全功能桥片固件已在 09-07 做完并时序收敛** (`eg4_bridge/`)。

⇒ 真正要做的只是移植: eg4_bridge_top.v 只有两个文件碰厂家原语
(`bridge_io.v` / `bridge_clk.v`, SPEC §3.2 明文规定), 其余 (`ul_dispatch.v` / `tx_array.v` /
`icnd2260_seq.v` / `icnd2260_ack_rx.v` / `tx_shared_ctrl.v` / `tx_lane_dp.v`) 逐个 grep 核过
**零厂家原语**, 直接引用真源, 一个字不改。

## 新写的两个器件层文件 (未上机验证)

- **`bridge_clk_gw5a.v`**: 两颗 PLLA。上行 fclk/pclk (IDES8, 参数照抄
  `uplink_rx_synth_top_gw5a_x8.v`, 已验证 800M 档); 屏侧 dclk/dclk90 (150MHz, 90° 相位公式
  逐条照抄 `gw5a_port/rtl/icnd2260_clk_gw5a.v`, 那份已在 gw5a_port 首光验证过 150MHz 档)。
- **`bridge_io_gw5a.v`**: 上行 TLVDS_IBUF+IDES8×13 (oct 口, 8:1); 下行 ODDRC+TLVDS_OBUF×72+1
  (映射逐条照抄 `gw5a_port/rtl/xil_shim_gw5a.v` 的 XIL_ODDR 壳: D0=上升沿/D1=下降沿/CLEAR)。
  IDES8 位序照抄 `uplink_rx_synth_top_gw5a_x8.v` 文件头 (已逐行核 GW5A simlib 的 prim_sim.v)。
- **`gw5a_bridge_top.v`**: 除时钟/IO 两层外**逐段照抄** `eg4_bridge_top.v` (§4~10 分发/门控/
  tx/ACK/LED 一字未改)。两个关键判断:
  ① 上行改 IDES8 后 **beat 率不变** (50M beat/s, 见 `uplink_rx/README_x8.md`) ⇒
    `START_SLOTS=90` / `dclk=150` 那组下游时序预算**不用重算**, 直接照抄默认值。
  ② 差分端口从 EG4 的"每対一根、N 脚自动配对"改成 GW5A 的"物理 P/N 两根显式端口"
    (GW5A 差分是原语级 TLVDS_IBUF/OBUF, 不是约束级)。

## 🎯 结果: 综合/映射/布局布线全跑通, 只卡最后 IO 引脚放置

```
LUT 6294 (28%)   Register 6494/23736 (28%)   I/O Port 191/239 (80%)
ERROR (PR0003): Failed to place with '37 IOBUF(s) unPlaced'
```
🔴 **不是资源真的装不下** (LUT/Register 都只占 28%, I/O Port 还有 20% 空), 是自动布局
在抢配置复用脚 (D11/D13/D14/MODE1/GCLKT 等) 时冲突。旁证: `gw5a_oser8/results/` 里同样
"只给 IO_TYPE、不给 LOCATION" 的纯 LVDS 対约束风格, 测过 **96 対、109 対都布局成功**
(`gw25S_T_800_n96` / `_n109`), 我这版只要 86 対 + ~16 单端, 数量上远没到那两个测试的上限。

## 下一步 (未做)

1. **手工排 LOCATION** (或先砍掉几个非关键单端信号如 dbg_st, 腾配置复用脚) 解决布局冲突。
   参照 [[project_gw5a_bridge_verification]] 09-11 核过的 "UG985 UG324 104 个完整差分対" 表。
2. `run.sdc` 里 `ck_clr_q` 的 false_path 因层次路径 (在 `u_io` 子模块里) 被裸名找不到,
   本轮先删掉过关, 收敛前要按真实例化层次名 (查 `bridge.rpt.txt`) 补回。
3. 尚未做时序收敛 (本轮卡在布局, 没到 STA)、未上机验证。
4. `icnd2260_regs_vendor.mem` (238 条供应商实测表, 与 eg4_bridge 共用) 未按 GW5A 特有的
   BSRAM 初始化写法核过。
5. 上行 DR1 侧 `uplink_tx` 仍是 LFSR 探针 (见 `uplink_rx/README_x8.md` §五), 真联调前要
   按 `uplink_rx_defs.vh` 的帧结构实现。

相关: [[project_eg4_bridge_firmware]] [[project_pov3d_bridge_logic_need]] [[project_gw5a_bridge_verification]]
[[project_pov3d_lvds_b2b_bench]] [[project_pov3d_bridge_architecture]]
