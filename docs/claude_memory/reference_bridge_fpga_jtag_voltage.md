---
name: reference_bridge_fpga_jtag_voltage
description: 2026-09-16 普查 (每家调查 + 反驳复核) — 高云/安路/紫光桥片 FPGA 的 JTAG 能否直接 2.5V (省掉 V2 的 2.5↔3.3V 电平转换器): 现用 GW5A-25 UG324 不行 (JTAG bank 与 VCCX 共球, 要 2.5V 得整条 VCCX 降压且 ODT 无规格); 干净可以的: PH1A60/90/180、PH1P100/35、Logos2 PG2L25H(50H/100H 推定); 小代价可以: GW2A-18 PG256 系/GW2A-55/GW2AN-UV、GW5A-25 UG256C/PG256C、GW5A-60 UG324A、GW5A-138 UG324A、EG4A20/EG4X20 BG256; 锁死: GW5A-60 UG324S 与 GW5AT-60 UG324S 锁 1.8V, EG4S20(内嵌 SDRAM)/PGL25G/GW2A-18 UG484/GW2AN-LV/EV 锁 3.3V; PGL22G/12G 手册互相矛盾待 FAE
metadata:
  type: reference
---

# 桥片 FPGA 的 JTAG 能否直接 2.5V (2026-09-16)

判定: **A** 可以 2.5V 无代价 / **B** 可以但有代价 / **C** 不能 2.5V / **?** 待确认。每家一个调查代理 + 一个反驳代理逐页核对原文; 工具 (TD / gw_sh) 行为只作旁证。PH1P 细节见 [[reference_ph1p_jtag_2v5]]。

## 高云
| 器件/封装 | 判定 | 原因 (出处) |
|---|---|---|
| **GW5A-25 UG324 (现用 ACG525-CORE-V2)** | **B (实际不可行)** | JTAG=Bank10, 电源球 `VCCIO10_VCCX_VDDXM` 12 球共用 (UG985-1.9.4 p45, UG1101-1.2.7 表2-3) ⇒ 要 2.5V 必须整条 VCCX 降到 2.5V (VCCX 允许 2.375~3.465, DS1103 §2.3 "支持 2.5V, 3.3V"); 代价: 小梅哥核心板硬接 3.3V 要自画板; 片内 LVDS ODT 只有 Vccx=3.3V 规格 (DS1103 表3-26; 60K 表3-5 注[1] 明写 ODT 要 Vccx≥3V, 25K 未写); gw_sh 设 -vccx 2.5 能出位流 (旁证) |
| GW5A-25 UG324S / PG256S / PG256 / MG196S / UG225S / LQ100 / LQ144 | B | 同上, VCCIO10 与 VCCX (或 +VCCLDO) 共球 |
| GW5A-25 UG256C / PG256C | B (轻) | VCCIO10 与 VCCIO4 共球, VCCX 独立 (ODT 不受影响); Bank4 有 MSPI/RECONFIG_N/READY ⇒ 挂 flash 要 2.5V 规格 (UG985 p84-102; 旧版 UG1101-1.1.9 写错成 VCCIO10/VCCIO5) |
| GW5A-25 PG196S / UG324F | A | VCCIO10 独立出球; 但 PG196S 仅 110 IO, UG324F 与 UG324 不脚对脚兼容 |
| **GW5A-60 UG324S** | **C (锁 1.8V)** | `VCCIO12_VCCX_VCCLDOADC` 共球, VCCLDOADC 1.71~1.89V ⇒ JTAG 只能 1.8V, 且 ODT 不可用 (UG1229-1.1.8 p8, p27-28) |
| GW5A-60 UG324A | B | VCCIO3_12 共球 ⇒ Bank3 配置脚 (CCLK/READY/MODE/DONE/RECONFIG_N) 同 2.5V |
| GW5A-60 PG324C | B | VCCIO11_12 共球; 另 VCCX 锁 1.8V ⇒ 无 ODT、>600Mbps 超规格 (与 JTAG 无关的器件级问题) |
| GW5A-138 UG324A | B (轻) | Bank10 含全部配置脚, CFGBVS 接高 |
| GW2A-18 PG256 / PG256S / SF / E / C / CF / MG196 | B (对 2.5V 契约等同 A) | JTAG 是 Bank2 复用 IO (IOR25A/B、IOR26A/B), VCCIO2 独立 ⇒ 只是 Bank2 用户 IO 同 2.5V; MODE/RECONFIG/READY/DONE/MSPI 在 Bank3 (UG111) |
| GW2A-18 UG484 / QN88 / EQ144 | C (3.3V) | JTAG bank 电源 = VCCX, 下限 2.7V |
| GW2A-55 PG484 / UG324 / UG324D / UG324F / UG484S / UG676 | B (≈A) | Bank2 复用 IO (IOR42A/B、IOR43A/B), VCCIO2 独立; GW2A-55 没有 UG484, 只有 UG484S |
| GW2AN-UV18X (各封装) | B (≈A) | Bank0 复用 IO, VCCIO0 独立; **只能订 UV 版** |
| GW2AN-LV18X / EV18X | C (3.3V) | JTAG bank 电源 = VCCX ≥2.7V |
| GW5AT-60 UG324S | C (锁 1.8V) | VCCIO12/VCCX/VDDHAQ0 共球, VDDHAQ 1.71~1.89V (DS981 表3-7); 其它 GW5AT 封装未核 |
- 高云原理图指导 (UG987-1.3.3 文档页11 / UG206-1.9.3 / UG980-1.2.2 文档页5) 明写 JTAG 插座参考电压跟随 JTAG 所在 bank ⇒ "JTAG 电平跟随 bank VCCIO"是厂商定性明示 (无数值 VIH/VIL)。

## 安路
| 器件/封装 | 判定 | 原因 |
|---|---|---|
| **PH1A60GEG324 / PH1A90 (SEG324/325, SBG484) / PH1A180SFG676** | **A** | bank0 专用配置 bank; 只有启用 MSPI flash 时要求 CCLK 所在 bank 与数据脚 bank 电压一致 (UG905) |
| **PH1P100 (SBG484/676/677/GEG324) / PH1P35** | **A** | 见 [[reference_ph1p_jtag_2v5]] (PH1P50 ?) |
| EG4A20BG256 (EG4A15 同引脚推断) | B | JTAG 在 bank1 ⇒ bank1 整体 2.5V (含从串 CCLK/DIN/PROGRAMN/INITN); DONE/MSEL 在 bank6 另核; 挂 flash 要 2.5V 型号。记忆里"bank1 被逼 3.3V"是当时板级选择, 不是器件限制 |
| EG4X20BG256 (EG4X15 推断) | B | JTAG 跨 bank0 + bank1, 两个都要 2.5V; E104 评估板 bank0 焊死 3.3V (板级) |
| **EG4S20BG256 / EG4S20CG324 (内嵌 SDRAM)** | **C (3.3V)** | TMS/TDO 所在 bank1 在封装内接 SDRAM 电源与 VCCAUX, 手册写"只能接 3.3V" |
| EG4A20NG88 / EG4S20NG88 | C | bank3 "必须 3.3V" (IO 太少, 仅对照) |
| DR1V90 (主控自身 JTAG 口) | A | 但 DR1 驱动桥片 JTAG 用的是 PL 用户 IO, 电平看那几个球所在 bank |
- 安路下载器 AL-LINK 的 VREF 1.5~3.3V (UG009 v1.3 OneCable, TD doc/Tools_UG), 台架调 2.5V JTAG 有官方依据。
- 反驳代理补的推断: 即使 EG4 的 JTAG 阈值固定为 LVCMOS33, VIH 1.9V (DS300 表3-1-13) 对 2.5V 驱动 VOH≥2.1V 仍有 0.2V 余量。

## 紫光同创
| 器件/封装 | 判定 | 原因 |
|---|---|---|
| **PG2L25H (Logos2)** | **A** | JTAG 在 VCCIOCFG 专用 bank + SCBV 选档, 手册明文 (UG040005 V1.3); 只用 JTAG 时 MODE 建议 101, 000 禁用 |
| PG2L50H / PG2L100H MBG324 | A (推定) | 同家族文档 + FBG484 封装文件, MBG324 封装文件没拿到 |
| **PGL22G / PGL12G** | **?** (反驳改判) | DS02001 V3.0 表2-4 VCCIOCFG 1.425~3.465V 覆盖 2.5V, 但现行 IO 用户指南 UG020006 V1.8 p.10 点名"PGL12G and PGL22G download banks"建议 3.3V ⇒ 文档互相矛盾, 要 FAE 书面确认 |
| PGL25G | C (3.3V) | JTAG 参考 = VCCAUX, 手册只允许 3.3V |
| PGL50G / PGL50H (PGL100H 同规则) | B (重) | 要整条 VCCAUX 降 2.5V; VCCEFUSE 另留 3.3V; VCCAUX=2.5V 下 LVDS VOD/VOCM/VICM 与 HSST 规格未查到 —— 对 LVDS 桥是实质风险 |
| Titan1 (PGT30G/PGT180H) | ? | 手册要登录下载, 未拿到 |

## 对项目的结论
- **现用 GW5A-25 UG324 (小梅哥核心板) 不改板就不可能 2.5V JTAG** ⇒ 验证板 V2 的电平转换器必须保留。
- 若桥片选型把"省转换器"算进去, 干净的 A: **PH1A60/90、PH1P100、Logos2 PG2L50H/100H**; 对 2.5V 契约几乎无代价的 B: **GW2A-55、GW2A-18 PG256 系、GW2AN-UV、GW5A-25 UG256C/PG256C、GW5A-60 UG324A、EG4A20BG256**。
- 坑: GW5A-60 UG324S 与 GW5AT-60 UG324S 锁 1.8V (2.5V 主控照样要转换); EG4S20 (内嵌 SDRAM)、PGL25G、GW2A-18 UG484、GW2AN-LV/EV 锁 3.3V。
- PH1P 要求 TCK 4.7k 上拉, 与现 GW5A 约定的 TCK 下拉相反, 换芯片要重定上下拉约定。
