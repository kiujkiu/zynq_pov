---
name: project-gw5a-integrated-bridge-review-1013
description: "10-13 Codex 画的 GW5A 一体桥板 V1.0 (核心板+转接板合一) 评审打回: 原生 ERC 显示核心三页不在网表, 203 单脚网; 返工单在工程 review 目录"
metadata:
  node_type: memory
  type: project
  originSessionId: 48dffb11-59e2-4e99-8576-f8f539c53750
  modified: 2026-10-13T09:21:20.394Z
---

工程 `D:\claude_workspace\pov3d\pcb\projects\POV3D_GW5A_Bridge_V1.0` (由 Codex 生成, 是 [[project-gw5a-adapter-kicad-v1]] 计划的第③步"两块合一")。
10-13 17:20 Claude 用 Windows kicad-cli 跑原生 ERC/网表: 365 条; U1/U2/U3 及核心页不在网表 ⇒ 203 个单脚网; 上行端接 R1000–R1019 两脚都没连。Codex 自写审计报 pass —— 自洽检查不独立。
返工单: `review/Claude评审_2026-10-13_返工单.md`。Codex 沙箱起不了 kicad-cli, 原生 ERC 由 Claude 侧复验。

**Why:** 生成器式原理图必须用原生工具验收。
**How to apply:** Codex 改完后重跑 `kicad-cli sch erc` + `sch export netlist`, 查单脚网为 0 再放行布局。返工改由 Claude 用 codex exec fork 直接派给 Codex (见 [[feedback-claude-review-codex-execute]])。

## 用户拍板 (10-13)
- 电源: 0.9/3.3V DC-DC, 1.2/1.5/2.5V 从 3.3V 取 LDO (GPA 估流, LDO >0.6W 退回 DC-DC); 上电顺序改 0.9→1.2→3.3→1.5→2.5 (PUDC_B 在 bank0=1.5V, POR 只监控 VCC/VCCX/VCC_REG/VCCIO4/5/7, UG714 表4-2)。
- VCC 抬到 0.937V (允许 0.87–1.0V)。
- 🔴 接口契约新增: **DR1 上行 TX 在桥报告进入用户态前保持三态** —— 软件 (DR1 侧上行驱动) 必须遵守; GW5A 的 SSPI 脚落在上行 lane 2/5/7。待高云 FAE 确认 use_sspi_as_gpio。
- 细审报告 `review/Claude细审_G1_2026-10-13.md`; 闸门表 `review/合作路线_闸门.md`。
- 🔴 **10-13 晚用户定原则: 合板 = 照抄两块已验证原板 (ACG525 原理图 + 桥转接板 epro2), 只改有手册依据的具体缺陷, 优化不做**。撤回 LDO 方案 (该方案还曾引出 1.2V←3.3V 启动闭环, 是"改出来的问题"的实例)。下一步难点在布局; 待问: 能否从核心板厂家要 PCB 源文件/BGA 扇出参考。
- ✅ 10-13 晚 G0 通过、G1 第 3 轮 (电源照抄原板) 原生 ERC 0 error 有条件通过。原板电源: 外部 3.3V(桥 U15 STI3411A) + BL8028(0.9/1.5) + RS3236 固定 LDO(1.2/1.8/2.5) 并行使能; 两路 2.5V (桥 PWR2V5→bank2/3+电平转换, 核心 VCC2P5→bank6/7) 不可合并。🔴 阻塞: FPGA 完整订货号 UG324 vs UG324S (固件 .cst 按 UG324S, 40 球差异) 待用户看丝印。FAE 待问: PUDC/POR 窗口、自动 SSPI、新版 UG987 上电建议。SSPI 冲突 4 对 8 球 N6/P7 R3/T3 R5/T5 U5/V5。
- ✅ 10-13 G2 器件冻结有条件通过: ERC 0 违规, 网名统一后拓扑与 r3 一致, BOM 448 行 (review/bom_g2.csv)。下一步 G3a 叠层 S2+约束。
- 10-14 用户给高云厂家资料 (D:\芯片资料\gowin, 解到工程 core/gowin_vendor/): 官方最小系统图证实 MIPI 未用脚悬空、PUDC_B 有内部弱下拉 ⇒ 两项 FAE 问题关闭; 官方开发板 .brd 是 Allegro 二进制 KiCad 导不了, 需人用 Allegro 导出 Extracts/ODB++。
- 🎯 10-14 芯片丝印确认: **GW5A-LV25 UG324C2/I1** (UG324, 非 UG324S) ⇒ 原理图球表正确, 阻塞关闭; 固件 .cst/Gowin device 须从 UG324S 改为 UG324C2/I1 并重跑 P&R。
- 10-14 官方开发板 DK_START_GW5A-EV25UG324S .brd 已用 KiCad 10 Python (PCB_IO Allegro 导入, kicad-cli import 不列此格式) 转为 core/gowin_vendor/dk_import.kicad_pcb, 12 层板, 作扇出/去耦参考。
- ✅ 10-15 上行块通过 (R11 补 1µF 9/10 路缺 VCC1P8; R12 修 TX3)。KiCad 10.0.3 差分 uncoupled 对跨层 gap 规则虚高 (源码 :209 只按 uncoupled 规则名合组), 验收改为 主板 gap 0 + 包络副本原生复算真实超预算 0 (verify.py --drc 自动做); 规则/预算不放宽。R13 新会话 01a13e69 在布下行。
- 🎯 10-15 用户批准: 下行 DL 差分整链未耦合预算 6.35→12.7mm (166.67MHz 灯板时钟; 上行 1Gbps 仍 6.35)。R13 下行 0/12 组卡在预算; R14 允许重摆下行串阻成行后成束布线。
- 🎯 10-15 用户批准下行换脚 (只在 48 对内部重排, 左右各 6 组)。R15 做完: 原生拓扑仅下行球归属变; Gowin 复核 (工程 firmware_check/: remap_cst.py + build_v1.sh, UG324C2/I1) P&R+位流 OK, dclk Fmax 173MHz。**固件交接: 用 firmware_check/gw5a_bridge_v1_valid.cst** (含 r9 上行换球 + r15 下行换脚)。R16 在布下行 (先摆串阻再成束)。
- 10-16: 并行 4 路 Codex (左右下行/PDN/灯电源) + Claude 按 UUID/整网合并 (scripts_claude/merge_added.py)。下行完成 O5/O9/O11 (3/12)。PWR_* 线宽 min 改 0.20 (原值=整网等效宽度, 逐段不适用)。F200 两脚同网 DNP = 照抄原板预留, 不改。
- 10-16 凌晨: 下行 4/12 (O5/O8/O9/O11) 后连续 3 轮 0 组 (含 astra 一轮); 根因 = 布局未留下行通道 + 自定源端预算分配过紧。R23: 每段未耦合上限 12.7, 整链和 ≤12.7 由 verify.py 原生实测求和验收。merge_added.py 必须带 @/+ 限定 (曾因旧副本重复加铜出 28 重叠孔)。灯电源/PDN 等下行完成后在最新主板重做 (试合并与下行短路 49)。
