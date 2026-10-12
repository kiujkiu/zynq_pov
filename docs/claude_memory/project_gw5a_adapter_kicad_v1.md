---
name: project-gw5a-adapter-kicad-v1
description: 2026-10-12 起用 KiCad 自画 GW5A 桥转接板 (与硬件同事 Altium 版并行练手, 底稿 10-12 SCH + 七项改板单); 板框 144x52.65 已出; 用户定的四条约束 + 下一步 3 agent 并行计划
metadata:
  type: project
---

# GW5A 桥转接板 KiCad v1 (2026-10-12 开工)

用户起因: 看到有人用 Opus 5.5 做 8 层板 layout, 问我们能不能做 ⇒ 定"从易到难": ① 转接板 (KiCad 重画) → ② GW5A 核心板自画 (去 DDR3, BGA324) → ③ 两块合一。
用户定 (10-12): **并行练手** (同事继续改 Altium 版, 最后两版对照) + **底稿 = SCH 10-12 版 + 七项改板单** ([[reference_adapter_change_order_1010]], [[project_adapter_sch_1012_review]])。

## 已完成: 板框
工程 `pcb/gw5a_adapter_v1/kicad/gw5a_adapter.kicad_pro` (KiCad 10.0.3, Windows `C:\Program Files\KiCad\10.0\bin\kicad-cli.exe`), 生成脚本 `kicad/scripts/gen_outline.py`, 说明 `pcb/gw5a_adapter_v1/README.md`, DRC 0 错。**pcb 是独立 git 仓 (无远端)**。
- 144.0 x 52.65 mm, 坐标 = 灯板 09-21 Gerber 原点 (KiCad kx=100+x, ky=-y)。上沿 -88.0 (LED 区下沿 ≈-84.4), 下沿 -140.65 齐灯板, ±72 避开 4.2 mm 铜柱孔 (±78.475,-135.65)。
- F 面朝灯板 LED 面: CN1/CN2 同心灯板 CN1(+50,-112.908 rot90)/CN2(-50 rot270), 灯板封装原点=焊盘中心; H1-H4 M2.5 同心灯板 JP1-4 (±60, -92.908/-132.908)。
- B 面插 ACG525-CORE-V2: 安装孔 46x31 (2.7 mm, 官方底板钻孔表), 外形 50.55x38.48, 两只 LB3524 中心距 26.64, 孔心 (0,-114.3)。
- 数据来源: `Downloads/ICN2260_LED_V01_260921*` (Gerber GM/TXT + PcbDoc `Components6` + PcbLib) 与 `ACG525-CORE_NEW260310` PcbLib; olefile 解析脚本当时在会话 scratchpad (plib2.py: PcbLib Data 流, pad=6 块, 其余记录 1 块; 坐标单位 1e-4 mil)。

## 用户定的约束 (10-12)
1. **FPC (到 SoC) 在灯板的 LED 那一面**。
2. **桥接部分 (转接板+核心板) 的高度不能挡灯**: 灯在上、桥在下; 要按 LED 可视角 (`docs/P0.9375COB规格书Z.doc`) 画遮挡线, 分区限高, 核心板等高件往下沿挪; 灯板 CN 对插高度先核。
3. 灯板 09-21 已改 AXK 封装 (此前中心距 4.445 vs 5.00 的问题), **转接板侧照改好的配对**。
4. 板宽 144 mm 就行。

## 下一步 (D 盘 EIO 换 WSL 前停在这里)
工程迁 WSL 本地盘 `~/pcb_work` 干, D 盘只做同步。3 个 agent 并行: ① 灯板 09-21 CN1/CN2 逐脚网络 + 配对封装 ② 10-12 SCH PDF 机读成网表 + 叠七项改动 = 目标网表 ③ 器件 KiCad 库 (LCSC) + 可视角限高表; 然后合成原理图 + ERC 给用户看。可复用 `pcb/zynq7020_dev_v1/kicad/scripts/kicad_sch_lib.py` 等生成器。
缺口: 新灯板原理图 CN1/CN2 脚位 (09-21 版 schdoc 在 Downloads, 未核是否与转接板 10-10 起的灯板侧重排一致)。

相关: [[project_pov3d_adapter_board_and_uplink_bank]] [[feedback_kicad_vs_lceda]] [[project_pov3d_led_board_pcb_v01_review]]
