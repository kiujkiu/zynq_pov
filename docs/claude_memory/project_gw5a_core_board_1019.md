---
name: project_gw5a_core_board_1019
description: 10-19 起自画 GW5A 核心板替代 ACG525 (去 DDR3 其余照抄); 原理图已出, 原生 ERC 0, 连接器 200/200 对上; 下一步等用户评审再定布局
metadata:
  type: project
---
10-19 用户把一体桥板 (电源卡住, 见 [[project_gw5a_bridge_handoff_1014]]) 先放一边, 改做简化任务: 自画 GW5A 核心板, 替代 ACG525-CORE-V2。
用户定: 替代 ACG525、**去 DDR3 其余照抄**、**本阶段只做原理图**。

- 工程 `pcb/projects/POV3D_GW5A_Core_V1.0/`; 脚本 `scripts/build_core_board.py` 一次生成 5 页 (沿用一体桥板 core/build_core.py, 网名用 ACG525 原名)。说明 `review/评审说明_原理图_2026-10-19.md`。
- 结果: 原生 ERC 0; P1/P2 200 脚与底板侧 ACG525 符号表逐脚一致。
- 关键事实: ACG525 的 VCC3P3、VCCIO23、VCCIO45 **由底板经 P1 送入**, 核心板只产生 0.9/1.5/1.2/1.8/2.5 V。JTAG 在 Bank10 (= VCCX = 3.3 V), 不是 2.5 V。
- P2.49–60 接 MIPI 专用球; PDF 上旁边的 B6_L23–31 字样在其他页不存在。
- 待办: AXK500137YG 封装按 Panasonic P5K 手册 p10 生成, 1 脚方向和插接镜像要在布局时对照底板封装核对; 安装孔径待核; 电感/晶振/Flash 暂用通用封装。

**Why:** 一体桥板布线难度大, 先做难度低的一步 (原"从易到难"计划的第 ② 步, 见 [[project_gw5a_adapter_kicad_v1]])。
**How to apply:** 恢复时先问用户评审结论, 再决定是否开始布局; 布局仍按"机器做、原生工具验收"。
