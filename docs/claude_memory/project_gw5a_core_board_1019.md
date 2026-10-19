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

## 10-19 孔径改 M2
- 用户定安装孔 M2: 钻孔 2.2 / 焊盘 4.0 / 孔距 46x31; 封装 MountingHole_2.2mm_M2_Pad4.0 (2.7 原取自底板封装, 无依据)。第1轮摆放最终版已回填, DRC 无短路/重叠。

## 10-19 12:40 第2轮(扇出+电源分割)部分完成
- layout/r2/core_r2.kicad_pcb 已由我原生生成; DRC 无短路; 324球扇出201, 123未解(NC 52 球其实不用打孔); 电源 15 端点未通。待用户/Opus 定: 跳过NC球、是否放宽净距到0.10或换更小过孔(需问板厂能力)。Codex 会话仍是 01a1523b (已 2 轮, 第3轮建议换新会话)。

## 10-19 第3轮派出 (Opus 判断)
- 加 kicad/POV3D_GW5A_Core_V1.0.kicad_dru: BGA_ESCAPE 区 0.10 / 过孔 0.20-0.45, 照抄桥板 G3a (同芯片同叠层, g4_fanout 171/171 全扇出原生过)。NC 球不打孔; B 面去耦可重排。
- Codex 新会话 01a15287-fec6-7142-a60b-b70b17a1eb31, pid 文件 /tmp/codex_rounds/run_core3.pid, 只写 layout/r3/; 结束后我原生跑 layout/r3/generate_native.py + DRC。

## 10-19 13:35 第3轮复验
- layout/r3/core_r3.kicad_pcb (我修了生成器 zone 多轮廓丢失 bug 后原生生成): DRC 无短路; 181 信号全逃逸; 电源 13 网全连通; GND 6 处缺陷。
- 待改 (第4轮): In3 过碎, VCC 核心需整块+宽颈; 单球电源改走线; GND dogbone 修; 然后连逃逸线到 P1/P2。Codex 会话 01a15287 已用 1 轮。

## 10-19 重启前存档 (第4轮进行中)
- 第4轮 (In3 重做+GND 6处修) 已派: Codex 会话 01a15287-fec6-7142-a60b-b70b17a1eb31, 只写 layout/r4/; 提示词存 review/codex_prompt_r4.txt。
- 重启会杀掉 Codex 进程。恢复: 看 layout/r4/ 是否有 generate_native.py+扇出说明.md; 没有就 cd 工程根, `codex exec resume 01a15287-fec6-7142-a60b-b70b17a1eb31 -m gpt-6.1-sol -c model_reasoning_effort=xhigh -c sandbox_mode='"workspace-write"' --skip-git-repo-check -o /tmp/codex_rounds/reply_core4.md - < review/codex_prompt_r4.txt` (先说明"上次被重启打断, 接着做"), 后台 while kill -0 等。
- 收到后: Windows 原生 python 跑 layout/r4/generate_native.py → kicad-cli pcb drc → 对照 r3 (review/drc_native_r3.rpt: 无短路, 电源全通, GND 6 处, 信号 208 未连为预期)。
- 之后第5轮: 逃逸线连 P1/P2。未决给用户: 孔焊盘 4.0 离边 0.26-0.29 是否缩到 3.6; B 面限高/底板对插。
