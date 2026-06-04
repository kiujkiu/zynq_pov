---
name: POV3D PCB v1 — 2026-06-03 v24 后待办清单
description: v23 + v24 完成的封装修正 + 仍待办的项, 含开源参考工程路径
type: project
created_at: 2026-06-03 14:28 CST
updated_at: 2026-06-03 14:50 CST
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---

工程: `D:\claude_workspace\pov3d\pcb\zynq7020_dev_v1\kicad\`  
最新 PDF: `_check\full_schematic_v24_2026-06-03.pdf` + `pcb_layers_v23_2026-06-03.pdf`

## ✅ v23 + v24 已完成

- 板 60×90mm 6 层 + M3(4,4) 孔
- 排针 2×55 1.27mm (sym 自制) — **当前是 SMD 贴片** ⚠ 待改插针
- 鹿小班 floorplan (HDMI/RJ45 顶, USB-C×3+JTAG 底, DIP+钮 内顶)
- TPS563210 → TSOT-23-8 + 自制 EP 1.6×2.1mm + 9 thermal via ×5
- 25M xtal HC49-SD → SMD-5032-2Pin
- 电感 → L_FTC303010D (SWPA3010S2R2MT 2.2µH/2.5A Isat) ×5
- FT2232HL → FT2232HQ QFN-64 9×9 ×1
- microSD J10 → BOT layer
- 14 颗电解/钽 → C_1210 MLCC (geometry 实际替换 + 符号 C_Polarized → C_Small)
- **v24 J1 USB-C: GCT USB4085 → HRO TYPE-C-31-M-12** (统一 J1/J22/J23 全 TYPE-C-31-M-12 C165948)
- **v24 11× 47µF/10V/1210 → 22µF/6.3V/0603** (LCSC C59461 Samsung) — **schematic 已改, PCB 未同步**

## ⚠ 关键: PCB ↔ Schematic 严重 out of sync

PCB 文件里 component 引脚 ref 跟 schematic 不一致 (e.g. schematic C4=47µF, PCB C4=100nF; PCB C1 是 mounting hole 不是 cap). **需用户在 KiCad GUI 里**:

1. 打开 `zynq7020_dev.kicad_pcb`
2. **Tools → Update PCB from Schematic** (快捷键 F8)
3. 勾选 "Update reference designators" 同步 refs
4. KiCad 会重新拉 ratsnest + 提示替换的 footprint

跑完后所有 v24 BOM 改动才会反映在 PCB 上 (含 47µF → 22µF 0603 + J1 TYPE-C 等)。

## ⏳ 待办 (优先级排序)

### 1. 排针 SMD → 通孔 THT (用户要求, 待澄清 pitch)
- 当前: `PinHeader_2x55_P1.27mm_Vertical` SMD 贴片
- 用户要插针。问题: **1.27mm pitch THT** vs **2.54mm pitch THT**?
  - 1.27mm THT 2×55: pad span 76.2mm 符合现板, 但 LCSC 2×55 同款少见 (2×40 为主), 焊接 drill+clearance 紧
  - 2.54mm THT 2×55: pad span 137mm > 60mm 短边, 板需扩大或拆 2×40 + 2×15
- 待用户决定再改

### 2. 47µF 拆成 2× 22µF 并联 (现 1×, 未完整)
用户要 "2个22µF并联". 现 schematic 每位置只有 1 个 22µF/6.3V/0603, 实际需 2 个并联做到 ~32µF effective 满足 TPS563210 ≥22µF 稳定要求 (DC bias 在 3.3V 下 22µF 6.3V → ~16µF, 单颗不够).

**做法**: 11 个 47µF 位置每个补 1 个并联 22µF (新 ref designator), 同 net
- C4 → C4 + Cnew_4b (parallel)
- C24 → C24 + Cnew_24b
- ...
- 共加 11 颗新 cap, 22µF 0603 6.3V

需脚本程序化复制 schematic 实例 + 加入 net 连接, 或用 Agent #24

### 3. J1 USB-C 加 CC 下拉电阻 (USB-C 规范必备)
- 现 J1 schematic 符号是 `Connector:Conn_01x02_Pin` (2 pin VBUS+GND), CC1/CC2 浮空
- 后果: 接 USB-C 充电器或标准 USB-C 线时, 充电器不会输出 5V (因为 CC 协议没握手成功)
- 改: J1 sym 换 `Connector:USB_C_Receptacle_USB2.0_14P` + 加 2×5.1kΩ 下拉到 GND (CC1+CC2)
- LCSC 5.1k 0402: C25905

### 4. FT2232HQ → FT232HQ QFN-48 7×7 (省 32mm² + ¥8)
- usb_uart.kicad_sch U21 lib_id FT2232HQ → FT232HQ
- footprint QFN-64 → QFN-48-1EP_7x7mm_P0.5mm_EP5.15x5.15mm (stock KiCad)
- 砍 ChB UART (闲置), JTAG MPSSE 保留

### 5. 330µF / 680µF 拆并联
- C700 (330µF) → 3× 100µF C_1210 并联
- C707 (680µF) → 6× 100µF C_1210 并联
- 同 Item 2 思路, 加新 ref

### 6. DDR3 重摆 (BGA 北并排 12mm)
- 参考 zynqPCB 实测: BGA (166,142) + DDR3 (160,116.5)+(172,116.5)
- 我们: BGA (30,51), DDR3 改 (24,29)+(36,29) rot=0

### 7. BOT 层激活
- 现 <5% 用率, 70 BGA decap + power 区 + 0402 阻容应全移背面
- 参考 Zynq-SoM/zynqPCB 实际密集 BOT 布局

### 8. H1/H2 排针 pin 顶 5 power 缩 + 中底加 GND ×4

### 9. 真布线 (用户 KiCad GUI 主导)

## 🗂 开源参考 (本地)

| 工程 | 路径 | 亮点 |
|---|---|---|
| zynqPCB (juliancoy) | `D:\claude_workspace\pov3d\refs\zynqPCB\` | 8层 120×60, 2 DDR3 北 BGA 12mm 间距 |
| Zynq-SoM (pinguz97) | `D:\claude_workspace\pov3d\refs\Zynq-SoM\` | 8层 SoM, eMMC 背面 |

## 立创/嘉立创 BOM (已锁)

| 项 | LCSC | 备注 |
|---|---|---|
| USB-C 3 个统一 | **C165948** HRO TYPE-C-31-M-12 | ¥0.6 |
| 22µF 0603 6.3V | **C59461** Samsung CL10A226MQ8NRNC | ¥0.05 |
| 5.1k 0402 (CC 下拉) | **C25905** | ¥0.01 |
| TPS563210ADDFR | **C545177** TI TSOT-23-8 | ¥3 |
| 电感 SWPA3010S2R2MT | **C98422** 顺络 3×3×1mm | ¥0.2 |
| FT2232HQ (现) / FT232HQ (待换) | TBD | ¥18 / ¥10 |
