---
name: project_gw5a_core_board_1019
description: 10-19 自画 GW5A 核心板替代 ACG525 (去 DDR3); 原理图完成 ERC 0; PCB 底板已生成, Codex 第 1 轮在摆放 (只交 csv, Claude 原生回填+DRC)
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

## 10-19 下午进展
- 原理图重排 v2 (电源/去耦/配置三页画实线, 网表与 v1 一致), PDF `review/POV3D_GW5A_Core_V1.0_原理图_v2.pdf`。
- 用户让转 Codex 做布局。Claude 先用原生 pcbnew 生成 PCB 底板 (`scripts_kicad/build_pcb.py`): 板框 50.55×35.56 R1.27 (ACG525 底板丝印外形镜像), H1–H4 孔距 46×31 钻 2.7 焊盘 4.0 接 GND, P1/P2 在 B 面按底板座镜像定死并锁定 (坐标对位已脚本核)。电源/Flash/晶振/电感封装换成一体桥板的已核封装。
- Codex 第 1 轮 (新会话 01a1523b-36cc-71e1-bda4-cfd17582ff0d, gpt-6.1-sol xhigh): 只交 `layout/r1/placement.csv` + check_placement.py + 布局说明.md, 不改 PCB。日志 /tmp/codex_rounds/run_core1.log, PID 文件 run_core1.pid, 回复 reply_core1.md。
- 收到后: `scripts_kicad/apply_placement.py <pcb> <csv> <输出>` 原生回填 → 原生 DRC (`kicad-cli pcb drc --schematic-parity`)。交接 `review/交接_当前状态.md`, 交互记录 `review/Claude-Codex交互记录.md`。
- 待用户拍板: 核心板下方 (B 面) 限高/底板该处有无元件; 安装孔焊盘离边 0.26–0.29 (<0.3, ACG525 原尺寸, 建议照抄); P5K 封装插接方向人工复核。

## 10-19 11:52 第1轮摆放已回填
- 143 件回填, 原生 DRC 无短路/重叠/间距问题; 余未布线、丝印、孔边 ×4、字段警告 30。下一步: 等用户看图, 再派布线/扇出轮。
