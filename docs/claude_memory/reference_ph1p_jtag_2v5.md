---
name: reference_ph1p_jtag_2v5
description: 2026-09-16 核查 — 安路 PH1P 的 JTAG 可直接 2.5V (bank 0 专用脚, 独立 VCCIO_0 只要求 ≥1.8V, VCCAUX 固定 1.8V, 全系无必须 3.3V 的电源/配置脚) ⇒ 桥片若换 PH1P100 可省 2.5↔3.3V 电平转换器; PH1P50 手册未收录判 unknown; 代价: 跨 bank 配置脚电压一致 → bank12(PH1P100)/bank22(PH1P35) 也取 2.5V, TCK 要 4.7k 上拉 (与现 GW5A 约定的 TCK 下拉相反), JTAG 专用脚热插拔能力未查到
metadata:
  type: reference
---

# 安路 PH1P: JTAG 能否 2.5V (2026-09-16, workflow 调查 + 反驳复核)

资料: **DS1300 PH1P Datasheet v1.2 (2025.08, 官网 OSS 至 09-16 仍是这版)** 与 DS1301 FamilyOverview v1.1, 已存 `dr1v90/docs/vendor/anlogic/ph1p/`。页码为 DS1300 印刷页码 (= PDF 页 − 6)。PH1P 官网没有公开的硬件设计指南 / 配置用户手册。

## 结论
| 型号 | 结论 | 依据 |
|---|---|---|
| PH1P100SBG484 / SBG676 / SBG677(旧名 PH1X100SBG676) / GEG324 | **A: JTAG 可直接 2.5V** | 手册原文 |
| PH1P35 全部封装 (MBG484 / MDG324 / MHG324 / MEG324/A) | **A** (但 HR 真差分只有 24 对, 不适合做桥) | 手册原文 |
| PH1P50 全部封装 (GEG324 / SBG484 / MBG484 / MEG324A) | **unknown** | DS1300 v1.2 全文不含 PH1P50, 只有 TD 工具行为 + 类比; 反驳代理指出 PH1P50 有 HD=1 与 DDRIO bank, 更像 PH1P35 而不是 PH1P100, 类比不成立 |

## 原文依据
- §2.8.6 p.36: "使用 5 个 JTAG 专用管脚: TCK、TMS、TDI、TDO 及 TRSTN" (SBG484/GEG324 引脚表里没有 TRSTN 球)。JTAG 在 **bank 0**, 由独立的 **VCCIO_0** 供电 (SBG484: F12/T12; GEG324: R9 单球)。
- 表 3-6~3-12 (p.51-54): **"VCCIO0 ≥1.8V, 与 JTAG 相连, 必须供电"** (注 1: POR 上电检测)。
- 表 3-5 p.49: HR VCCIO 3.3/2.5/1.8/1.5/1.35/1.2, HD 3.3/2.5/1.8/1.5; VCCAUX / VCCAUX_IO 1.71~1.89V。§3.1.5 p.56: 无上下电时序要求。
- 表 2-6 p.29: TMS/TCK/TDO/TDI 配置前 "Pull-up to Vccio"。JTAG 专用脚无单列 VIH/VIL ⇒ "阈值跟随 VCCIO0 (LVCMOS25: VIL 0.7 / VIH 1.7, 表 3-20/3-21)" 是**推断**。
- 表 3-56 p.79: JTAG 最高 PH1P100 25 MHz / PH1P35 40 MHz。

## 代价与坑
1. **跨 bank 配置脚电压一致** (表 3-6~3-12 注): 手册没说"纯 JTAG 加载时不生效"; M[2:0] 选不出 JTAG 模式 (表 2-5), 悬空 = 111 = SS 模式, DIN / D0 / D1 / SPICSN / HSWAPEN 在 **bank 12 (PH1P100) / bank 22 (PH1P35)** ⇒ **保守: 该 bank 也接 2.5V**。在全 2.5V 契约下不增加成本, 只是这个 bank 不能跑 1.8/3.3V。
2. **TCK 上下拉冲突**: 表 4-2 p.91 "TCK 需要通过 4.7k 电阻上拉", DONE/INITN 4.7k 上拉到 VCCIO; 而 [[project_pov3d_hw_pack_dr1v90_gw5a]] 按 GW5A 定的是 TCK 静止低 + 下拉 ⇒ 换 PH1P 要重定, 两种桥片共用 TCK 时要求相反。
3. **去掉转换器 = 去掉 Ioff 隔离**: 手册只写 HR I/O 支持热插拔 (p.25, 表 3-16 DC 300µA/IO), HD/DDR 不支持; JTAG 专用脚类型标 "-", 热插拔能力**未查到** ⇒ 建议 JTAG 四根串 33~100Ω 并规定上电顺序, 或问 FAE。
4. TD 2026.1 SP2 **不检查 VCCIO0 下限** (CCLK 约束 LVCMOS15 也出位流), 也不检查跨 bank 配置电压一致; 同 bank 混用 25/33 才报 USR-8001 ⇒ 工具接受不能当手册依据。临时工程 `C:\temp\ph1p_jtag_probe\`。
5. PH1A 对照 (DS900 v1.6.1): 同架构, JTAG bank 0 专用, VCCIO 1.2~3.3V, "POR 监测 JTAG 端口所在的 VCCIO*电平"。

**How to apply:** 桥片选型比较 JTAG 电平时, PH1P100 可以记"JTAG 2.5V 直连 (需 bank12 同 2.5V、TCK 4.7k 上拉、热插拔待 FAE)"; PH1P50 别写成可以, 要等新版手册或 FAE 确认。
