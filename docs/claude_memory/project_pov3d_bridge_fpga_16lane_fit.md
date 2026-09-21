---
name: project_pov3d_bridge_fpga_16lane_fit
description: 2026-09-15 用户问"上行做 16 组数据哪些桥 FPGA 够" — 4 家族并行评估+逐家挑错; 16 lane 两种屏体布局都不零 mux 对齐(24 颗该用 18, 20 颗用 15+1 校验=16 物理线); 收端 FRAME_MISS/分发 FIFO/回读口三处必改; 推翻记忆 4 条(GW5A-60 UG324S VCCX 锁 1.8V / XC7S50 CFGBVS 接反 / EG4 仿真対能做输入 / ACG525 是 71+8 半対)
metadata:
  type: project
---

# 上行 16 lane 时的桥 FPGA 选型复核 (2026-09-15)

workflow `wf_a10cd54a-6a7`(9 agent), 汇总在会话 scratchpad `sel16_summary.txt`。纯技术判据, 供货不计(见 [[feedback_tech_eval_excludes_supply]])。

## 16 这个数本身的问题(需求复核代理, 有 RTL 行号)
1. **零 mux 对齐**: 每 beat 字节 2N 须被 3 整除且整除每字槽字节数。T24(24 颗, 72 字节/槽)可行 N∈{12,18}; T20(20 颗 40×48, 60 字节/槽)可行 N=15。**16 两边都不对齐**(要加桶形移位 ~0.6k~1.5k LUT4, 且 chk_late 相位字段扩宽后 T20 相位 13 会撞 0x35)。⇒ 24 颗用 **18 数据+1 校验+1 时钟=20 对**; 20 颗用 **15 数据+1 校验=16 物理线+1 时钟=17 对**(与现结构同构)。
2. **FRAME_MISS**: 占用率降下来空闲变长, `uplink_rx_top.v` 连丢 5 次帧头(约 639 字周期)就重训练 ⇒ T24@700/800、T20 全档、验证板(任意 lane 数)每帧掉链。改法 1~2 LUT(空闲不计 miss, 或 TX 空闲插 SYNC)。
3. **分发 FIFO**: 800M 突发峰值 396~702 字槽 > FIFO_SLOTS 384 ⇒ 深 512~1024(BRAM ≈650kb)或降 600~700M。
4. 端口表**没有回读通道**(rx_all_aligned/st_retrain_req), 单端 +1~4; 验证板单端实际 11 根(含 clk_ref/rstn)不是 9。

## 判定摘要(18 对上行, 拓扑 B; pad: T24-B 194 / T20-B 170 / V-B 121)
- **T24-B 过**: GW2A-LV55PG484、GW2A-LV18PG484(C)、GW2A-LV18UG484(原"避开"作废)、GW2AN-UV18XUG324(只订 UV 版)、GW2A-LV18UG324、PGL22G-6IMBG324(700M 解掉输入零余量)、XC7S50-CSGA324(余 7 対)、GW5A-LV60UG324A(余 8)、GW5A-LV138UG324A(余 6)。
- **T24-B 有条件**: GW5A-LV25UG324S(余 20)/GW5A-LV25UG324(余 8) 都要用左右 bank B2/B6 出下行 —— DS1103 表2-11 注[3]"25K Bank2/6 速率偏低"无数字, 剔掉 B2/B6 则 UG324 差 13 対; EG4S20CG324(余 4); PH1A60(余 7, 真 LVDS VOCM 不可设 + ELVDS 300Mbps 零余量); GW2AN-UV18XPG256(余 7 pad); GW5A-LV60UG324S(只能 600M, 见下)。
- **T24-B 不过**: **EG4A20BG256(差 2~3 対)**、EG4X20、GW5A-25 PG256S/UG256C/PG256C/PG256、GW5A-60 PG324C、GW2A-18 PG256(差 2 pad)、XC7A35T-FTG256、XC7S25、Ti60; Ti90 下行电气不成立(HSIO 无 2.5V, HVIO 2.5V 只 100Mbps); LFCPNX-100 差 2 対。
- **T20-B 额外能过**: EG4A20BG256(保留 JTAG 余 7 対)、EG4X20、GW5A-25 PG256S/UG256C/PG256C(依赖 B2/B6)、GW2A-18 PG256; LFCPNX-100 有条件。
- **验证板 ACG525-CORE-V2 ⚠**: 连接器实为 **71 完整対 + 8 半対**(记忆里"73 対"错); VCCIO01 给 DDR3(1.5V), VCCIO45 挂 3.3V flash; 下行 37 対要用 B2 13 + B6 6, 剔掉 B2/B6 只剩 30 < 37 ⇒ **核心板到手先测 B2/B6 跑 300 Mbps 仿真差分**。

## 共同未证项
- 仿真差分(互补 LVCMOS25+3R)300 Mbps: 高云/紫光/AMD 手册均无速率数字; 安路 EG4 有 166MHz; PH1A 300Mbps 零余量。146~160 根单端同翻 SSO 无人核。3R 共模对 VCCIO 公差敏感(2.625V 时 ≈1.31V 出窗)。
- FS03 LVDS18 VOCM 低角 0.3V: GW5A-25/60 VICM 下限 0.3 零余量; PGL22G 0.5、PH1A HR 0.9、PG2L50H LVDS 1.0 都不够(PG2L50H 可改 BLVDS 输入 0.3); GW2A/GW2AN 0.05~2.35、EG4@2.5V、GW5A-138 0.05~1.8、XC7S 0.3~1.5 覆盖。**AC 耦合不是免费兜底**: 上行不是直流平衡码。
- GW2A: TLVDS_IBUF 能否落 LVDS=NONE 対(GCLKT_0 就是 NONE)无文档直证, 后备 GCLKT_1。

## 🔴 推翻/更正的旧结论
- **GW5A-LV60UG324S 不是首选**: VCCX 与 VCCLDOADC 封装内短接(UG1101-1.2.7E 表2-5), VCCLDOADC 1.71~1.89V、绝对最大 1.98V ⇒ VCCX 锁 1.8V ⇒ 无片内 ODT、>600Mbps 超规格(DS1103 表3-5 注[1])。PG324C 同。推翻 [[reference_bridge_fpga_alternatives]] 国产首选。
- **XC7S50 CFGBVS 记反**: VCCO_0=2.5/3.3V 时 CFGBVS 必须接 VCCO_0, 只有 ≤1.8V 才接地, 接错可能损坏(UG470)。
- **EG4 仿真対能做 LVDS25 输入 800Mbps**(DS300 §2.7.2 / TN309 §4.2), 只是上下 bank 无片内 100Ω ⇒ `pcb/eg4_bridge_v1/01_设计要点/02_管脚与BANK预算.md §2`"仿真対只能做输出"错。
- GW2AN-18X 片内端接在 **Bank4/5** 不是 Bank0/1; LV/EV 版 VCCX 与 VCCIO0 短接, 必须订 UV 版。
- 3.3V bank 也能出下行(LVCMOS33D/LVPECL33E + 5R, EG4 现役先例), flash 电压不剥夺 bank 的输出资格。
- UG304-1.3.7: 25K 片内 100Ω 仅 Top/Bottom, 138K 仅 Bottom, 60K 全分区(旧版"所有分区"过时)。

## 🎯 09-15 用户确认: 目标板是 24 颗 ⇒ 模组间接口按目标板定 20 对/面
- 用户问"直接按目标板做接口可以吗", 答可以(模组间接口是永久契约, 本就该按目标板冻结); 用户确认**目标板 24 颗(192×216)** ⇒ [[project_pov3d_screen_body_cob_route]] 的分辨率 A(20 颗)不采用。
- 物理层 **20 对 = 18 数据 + 1 校验 + 1 转发时钟**(24 颗零 mux 对齐 N∈{12,18})。8-bit 占用 800/700/600M = 63.5/72.6/84.7%; 12-bit 只能 800M(95.3%), 且 12-bit 协议不存在(UL_WORDBITS=8)要重定。
- 可分步用: 8-bit 先用其中 **12+1+1=14 对跑现役协议(RTL 零改 lane 数)**, 其余 6 对留给 12-bit; 或直接 18 lane(要改 RTL lane 参数 + FRAME_MISS + 800M 加深 FIFO)。
- 契约还须含边带(回读/复位/桥片从串配置 5~6 根)、电平按 LVDS25(FS03 LVDS18 由 V3 适配, 先查 FS03 bank VCCIO 能否外供 2.5V)、连接器按目标板选型。
- 验证板代价: FS03 CEP1 24 対扣 bank33 上电劈开的 R9/R15/R16/R21 正好剩 20(零余量, 现役探针 A21/D22 要挪); GW5A 核心板上行放 B4/B5 余 2 対。
- 桥片 T24-B pad 194→198(+回读 1~4): EG4S20CG324 余 2 対、GW2AN-UV18XPG256 余 ~3 pad 变极紧, 其余候选结论不变。

相关: [[project_pov3d_screen_body_cob_route]] [[project_pov3d_uplink_rate_pin_budget]] [[project_gw5a_bridge_verification]] [[project_pov3d_eg4a20bg256_bridge_selection]]
