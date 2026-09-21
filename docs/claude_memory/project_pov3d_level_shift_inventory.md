---
name: project_pov3d_level_shift_inventory
description: 2026-09-16 全系统电平转换清点 (3 路清点 + 挑漏复核) — 验证板插 ACG525-CORE-V2 时 JTAG 转换器去不掉; 自画桥板 JTAG 电平可直连但要换成隔离/上拉/TDO 保护三件事 (GW5A/GW2A 桥侧可直连, PG2L 必须、PH1x 暂按需要加单电源 Ioff 缓冲, 目标 SoC 板 TDO 加 Ioff 缓冲, TMS 22k 上拉+片内上拉会超 DR1 350µA 反灌); 与 JTAG 无关仍要处理的是灯板侧 2.8V 域 (ACK_D 2.8V 进 2.5V bank 要缓冲、PANEL_RSTN 在 VDDR 域、I_SYNC/ACK_S 余量 0.1~0.2V、EN 下拉、扇出器件反灌) 与光电传感器; 上行 20 对 LVDS 与边带 4 根直连不用转换
metadata:
  type: project
---

# 去掉 JTAG 转换器后, 系统里还有哪些要电平转换 (2026-09-16)

workflow `wf_d55ea42d-0ea` (契约面 / 灯板 2260 侧 / 桥板本地 三路 + 挑漏复核)。原始输出存 `zynq_pov/docs/level_shift_inventory_20260916_raw.txt`。
情景 X = 自画 GW5A-25 UG324 桥板 VCCX 降 2.5V; 情景 Y = 换 JTAG 可 2.5V 的桥片。

## JTAG 本身
- **验证板 V2 只要插 ACG525-CORE-V2, 2.5↔3.3V 带 Ioff 转换器去不掉** (核心板 VCCX=VCCIO10 硬接 3.3V)。
- 自画桥板时"电平"可直连 (DR1 VOH≥2.1 > VIH 1.7, ≤2.8V), 但转换器原来兼任的三件事要另外解决:
  1. **桥片未上电时 SoC→桥 TCK/TMS/TDI 的隔离**: GW5A/GW2A JTAG 脚 IHS ≤120µA (DS1103 表3-8 / DS102 表3-4) 可直连; **PG2L50H 专用配置 IO 明文不支持热插拔 (DS04001 表2-8 注3) ⇒ 必须加单电源输入带 Ioff 缓冲 (74LVC3G34 类, VCC=桥片 JTAG bank 2.5V)**; PH1P/PH1A 专用脚热插拔未查到 ⇒ FAE 书面确认前也加。
  2. **上拉反灌预算**: 外部 22kΩ 上拉与桥片片内上拉直接挂契约线, 两面共用 TMS 193µA + 2×片内 (GW5A Medium 150 ⇒ 493µA; PH1P 125 ⇒ 443µA) > DS1200 表3-8 的 350µA ⇒ 去掉 22kΩ 或 ≥100kΩ 重算。PH1x 要 TCK 4.7kΩ 上拉 (单面 449µA 超) ⇒ 放到缓冲器 FPGA 侧; PH1x TCK 静止高, 与 v3 "TCK 静止低"相反, 两面共用时不能混插两种桥片。
  3. **TDO 保护 (两种情景都要)**: JTAG 访问中 SoC 岛掉电 ⇒ TDO 驱高 mA 级注入, 原计划 D29 (转换器 OE) 无处落地 ⇒ **目标 SoC 板在 SoC 侧加单电源 Ioff 缓冲 (74LVC1G34/1G125 类, VCC=DR1 该 bank 2.5V, 输入 ~100kΩ 下拉)**; 验证期接受残余风险; TDO 10kΩ 下拉与 DR1 PULLUP 组合要重定; V3 闸门 TP_TDO_A 判据作废改以 SENSE33 为主; ADC 复用球摆率 (>3.3V/ns) 要求转到桥片 TDO。
- ⇒ "去掉转换器" 实质是 **双电源转换器 → 0~2 只单电源 Ioff 缓冲** (GW5A/GW2A: 桥侧 0 只 + SoC 侧 TDO 1 只)。

## 与 JTAG 无关、仍要处理的 (灯板 2260 侧 2.8V 域为主)
- **ACK_D[1:0]**: 2260 ACK_O 与 mux 在 VDDD 2.8V, 灯板还有 10kΩ 上拉到 2.8V ⇒ 进桥片 2.5V bank 超 VCCIO+0.3 (GW5A/PH1A/PH1P 都没有输入耐压条目) ⇒ **V2 加单电源、输入耐压、带 Ioff 缓冲 (74LVC2G34 @2.5V)**, 上拉放缓冲器输入侧。分压方案与上拉冲突不可用; V2 没有空闲 3.3V 脚。
- **I_SYNC**: 灯板 74LVC244 @VDDD 2.8V 转三路, 2.5V 驱动余量按 GW5A VOH 最坏只有 ~0.175V (前提 VDDD 正式定 2.8V)。
- **ACK_S[2:0]** → 8:1 mux (CMOS 门限 0.7×VCC): 余量 0.1~0.2V ⇒ 走 74LVC244 空余通道或选 TTL 门限选择器, mux VCC 标注"必须 2.8V"。
- **PANEL_RSTN**: 2260 手册把 RSTN 标在 **VDDR 域 (2.8~5V)** ⇒ 走 74LVC244 空余通道、输入下拉 ≤2.2kΩ; VDDR>2.8V 时缓冲器 VCC 接 VDDR 或开漏。
- **EN_3V8 / EN_2V8**: GW5A 配置期弱上拉 (PUDC_B 低时, Medium ≤150µA) 会把 100kΩ 下拉顶高提前开灯板电源 ⇒ 下拉 ≤2.2kΩ (自画 GW5A 板可 PUDC_B 接高让配置期高阻); V3V8_FPGA / V2V8_FPGA 不能是 EN 控制的轨 (自锁)。
- **灯板断电 (soft_rst 2000ms) 期间反灌**: 下行对 ELVDS_TBUF 在 PG 到齐前三态; CDCLVD1212 扇出的 LDO EN/输出使能跟随灯板 PG (TBUF 管不到扇出器件输出); 灯板 74LVC244 与 mux 选带 Ioff; I_SYNC/ACK_S/PANEL_RSTN 电源稳定前保持 0。
- **扇出器件 CDCLVD1212**: 只能 2.5V 供电 (VCC 绝对最大 2.8V) 要单独 LDO; 输出 Voc 最大 1.375V 超 2260 VIC ⇒ 保留分裂端接 + AC 耦合 + VBIAS 逃生位。🔴 **A1 文档 VBIAS 分压自相矛盾 (正文 200/150Ω=1.2V, BOM 行 4.7k/2.7k≈1.02V 出窗), 下单前统一**; A1 表12 "mux#1 余 4 路接地" 与表5 更正 "接高" 也冲突。
- 灯板内所有上拉接本颗 VDDD (2.8V), 不沿用参考板 3.8V (VDDD=2.8V 时 VIN 绝对最大 3.2V)。
- **光电索引** → FS03 K18 (bank32 固定 3.3V, R172 2.2k 上拉): 开集电极直接接 / 推挽 3.3V 串 100Ω / 推挽 5V 加 74LVC1G17@3.3V / 12~24V 或 PNP 分压+施密特或光耦; 目标 SoC 板要落 3.3V bank 或 PS MIO。传感器型号仍未知。
- **FS03 台架**: CEP1 上 CB-V2 JTAG 飞线 (GW5A 3.3V TDO) 与 CEP bank 改 2.5V 互斥 ⇒ 改板前物理拆除, 或线上加转换器 / J2 回 3.3V。
- **调试 USB 串口**: CH340 无 VIO 不能直接接 2.5V bank ⇒ 用 CH9102F / CH342 / CH343 (VIO=2.5V)。
- **下载器插座** VREF/VCC 与 ESD 阵列电源接桥片 JTAG bank 电压, 不照抄 CB-V2 的 3.3V; 高云线 1.2~3.3V、AL-LINK-FT 1.5~3.3V 自带转换。
- V2 验证板 VCCIO45 必须与 VCC3P3 同源 (照 CB-V2 FB4), 否则核心板 3.3V 晶振/上拉灌进未上电 bank4/5 (非转换项)。

## 情景特有
- **X (VCCX=2.5V 自画 GW5A)**: 片内 ODT 只有 Vccx=3.3V 规格 ⇒ 上行 20 对外加 100Ω 或 FAE 确认; VCCX 2.5V −5% 正好压下限 2.375V 且这条轨驱动 TDO ⇒ 按 ≤±3.3% 含纹波; VCCX(2.5)/VCCIO45(3.3) 上电顺序高云三份文档冲突; VCCIO>VCCX 是否允许未查到。配置 flash/MODE/READY/DONE/RECONFIG_N 在 bank4/5 保持 3.3V 不用转换。
- **Y**: 配置 flash 跟 JTAG 走 2.5V (GW5A-25 UG256C/PG256C bank4; PH1P100 bank12; PH1A60 bank0+12; PG2L50H VCCIOCFG+VCCIOL5); GW2A-55 JTAG bank2 与 flash bank3 分开可保持 3.3V。**上行 LVDS 收端窗: PH1A HR VICM 0.9~1.4 与 DR1 输出窗两端零余量, PH1P 上沿零余量, GW5A/GW2A 宽裕** (数据 lane 非直流平衡不能 AC 耦合 ⇒ 只能靠选型)。边带/LVDS 接收脚要落支持热插拔的 bank (PH1A HP 不支持且禁止 PAD 早于电源)。

## 不需要转换
上行 20 对 LVDS25 (GW5A VICM 0.3~2.35 直连); 边带 4 根两端 2.5V 直连 (SB_ALIGNED/B2S 由 V3 串 8.2kΩ 限流); FS03 CEP bank 改 2.5V 后板上不留 3.3V 负载; 连接器无电源脚; 2260 其它脚 (SDO/L_CKO 已删, SCL/SDA/LVDS_EN 只上拉到 VDDD) 不接 FPGA; VDDD 3.8→2.8V 不影响 mini-LVDS 输入; 晶振/按键/LED 按 bank 电压接; 转子跨界只有无线供电 24V、WiFi、光电索引。

## 待 FAE / 待定
高云: DS1103 表3-8 IHS 在 VCCIO=0 时的定义; GW5A JTAG 脚片内上拉档位 (TCK 有无上拉文档冲突); VCCX=2.5V 下 ODT/800Mbps/上电顺序。安路: PH1P/PH1A JTAG 专用脚热插拔 DC 限值、TCK 4.7k 能否放大。集创北方: ICND2260 RSTN 真实供电域与门限、单端 VIH/VIL、VIC 是推荐值还是硬限、端接 100/200Ω。硬件: VDDD 是否定 2.8V、VDDR 定多少、灯板 3.8/2.8V 与 V3V8_FPGA/V2V8_FPGA 是否同网受 EN 控制 (自锁)。ACG525-CORE-V2 的 PUDC_B (D4) 是否确接 DDR3_A8。光电传感器型号。
