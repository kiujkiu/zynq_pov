---
name: POV3D PCB 改动后必跑 audit_pcb.py (3 检查机制固化)
description: 每次改 PCB 必跑 audit, 看 3 类问题 (lib mismatch / 件重叠 / off-board), 不要相信 "改了" 直接走
type: reference
created_at: 2026-06-03 18:35 CST
updated_at: 2026-06-03 18:35 CST
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---

## 教训 (2026-06-03)

我多次只查"footprint 名字改了 / 几何 pads 对了"就报告"完成", 用户实际打开 PCB / 看渲染发现:
- v29 加的 J24 USB-A 跟 J11 JTAG IDC + SW3 boot DIP 三者在 (50, 84-85.5) 全堆一起, 用户看不到 USB-A
- "audit 339/339 OK" 只检查了单件 vs library 库一致性, 没检查**件之间是否打架**
- 不能假装"加了就完成"

## 流程: PCB 改完必跑 audit_pcb.py

工具: `D:\claude_workspace\pov3d\pcb\zynq7020_dev_v1\kicad\scripts\audit_pcb.py`

```bash
cd /mnt/d/claude_workspace/pov3d/pcb/zynq7020_dev_v1/kicad
python3 scripts/audit_pcb.py zynq7020_dev.kicad_pcb
```

## 3 类检查

| # | 检查 | 触发条件 | 修法 |
|---|---|---|---|
| 1 | LIBRARY SYNC | footprint pads 数/位置/尺寸 ≠ 库文件 | `geom_sync` 用 library template 替换 pads + silk + fab |
| 2 | OVERLAP | 同 layer 两件 bbox 相交 (±0.2mm courtyard) | 移件 (改 at 坐标) 或换更小封装 |
| 3 | OFF-BOARD | 件中心不在 edge.cuts 内 | 移到板内 |

## 退出码
- 0: 全 OK 可继续
- 1: 至少 1 issue, 必须修

## 假阳性 (会出现但不算 bug)
- `MH1 ↔ MH1 self-overlap` — 工具 bug, 同 ref 出现两次没去重
- `C... ↔ C... 0.05x0.05mm 微 overlap` — 大量 0402 cap forest 在 BGA 周围, placer 排得密但 manufacturable
- 关键看 IC ↔ IC, 接口 ↔ 接口, 接口 ↔ MH 这类**显眼大件**重叠

## 集成位置

每次 `swap_geometry` / 加新 footprint / 移件后, **下一步**:

```bash
python3 scripts/audit_pcb.py zynq7020_dev.kicad_pcb
```

报错就修, 不要直接渲染说"完成"。
