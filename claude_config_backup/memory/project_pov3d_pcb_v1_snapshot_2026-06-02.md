---
name: POV3D Zynq dev board v1 — 2026-06-02 大段进度快照
description: 一整天 16 个 subagent 推进的完整状态: schematic 全完成, PCB scaffold + GND/PWR zone done, 4 排针缩 2 排针 + 板 75mm 进行中, 真信号布线未做
type: project
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---
工程: `D:\claude_workspace\pov3d\pcb\zynq7020_dev_v1\`

## ✅ Schematic 100% 收工

10 个子页 + 288 component + 70 UG933 decoupling cap + 0 文字重叠 + 0 duplicate ref

| Sheet | 内容 |
|---|---|
| power | 5× **TPS563210ADDFR** (5V→1V0/1V8/1V5/3V3/VCCIO_ADJ) + TPS51200 VTT + INA226 + PG 链 |
| zynq_main | XC7Z020 9 unit + 70 cap + 326 alias (physical pin ↔ functional name 双 label) |
| ddr3 | 2× MT41K256M16HA (32-bit) + VREF + VTT 终端 |
| qspi_sd | W25Q256JVEIQ + microSD + **eMMC 8GB** (PS SD1 via MIO10-15) |
| clock | 100MHz + 33.33MHz SMD osc + reset 按键 |
| misc | LED + key + boot DIP + JTAG header |
| hdmi | **直驱 TMDS** (8 cap + 8R 49.9Ω + 2 PUSB3FR4 + MBR0520), 无 IT66121 |
| ethernet | RTL8211EG-VB-CG + HR911105A magjack + 25MHz |
| usb_uart | FT2232HL (JTAG) + **CH340E** (PS UART) + 2 USB-C |
| headers_io | **4× 2x60 1.27mm** 排针 → **改 2× 2x60** 进行中 |

## ✅ PCB scaffold 完成

- **6 层** stackup (L1 sig / L2 **GND** / L3 sig / L4 PWR / L5 **GND** / L6 sig), 1.6mm
- 板 **95×95mm** R3mm 圆角 + 4× M3 定位孔
- DRC 5 mil trace/clearance, via 0.4/0.2mm (嘉立创 6L 标准)
- 6 net classes (DDR3 / HSPD_DIFF_100 / DIFF_90_USB / PWR_HEAVY 等)
- **288 footprint 全部 import + 摆位** (粗摆按 floorplan hint)
- **L2 + L5 GND 铺铜** zone (全板)
- **+5V**: 11 个 via 跨 F.Cu↔B.Cu, L4 PWR plane zone (替代 trace 因 SOIC-8 pad 间距太密 trace 会 short)

## 🚧 进行中 (agent #17)

**2 排针化 + 板缩 75×75mm**:
- 4× 2x60 → **2× 2x60** (H1=BANK13+33, H2=BANK34+35)
- 每排针只 2 GND 靠近 power (不再每 IO 配 GND), pin 6-120 全 IO (115 slot)
- 板 95×95 → **75×75mm**
- 重摆 footprint + 重画 GND/PWR zone

## ❌ 未做

| 项 | 工作量 |
|---|---|
| 真信号布线 (DDR3 / HDMI / USB / RGMII / QSPI / eMMC / I2C / GPIO) | 多日, KiCad GUI |
| BGA 484 ball escape routing | 重头戏, 多天 |
| DDR3 fly-by + 等长 ±10ps | KiCad length tuning |
| HDMI/USB diff pair (100Ω/90Ω) | KiCad diff router |
| 元件 placement 微调 (31 short, 0402 cap 列重叠) | GUI 手动 |
| Gerber + DFM 出板 | DRC clean 后 |

**DRC 数字**: 892 → 703 (-189), 剩 499 unconnected + 31 short + 一些 courtyards_overlap (placement)

## 工具链产出 (kicad/scripts/)

- `kicad_sch_lib.py` (700+ 行 SchBuilder) — define_chip + label / power / wire / module_box + bbox overlap detector
- `chip_library.py` — 9 自制 chip (MP2161 / TPS563210 / NCT75 / TPS2553 / IT66121 / USB3320C / eMMC / Conn_02x60_P1.27mm)
- `gen_*_sch.py` (10 个 sheet 生成器) + `gen_pcb_scaffold.py` + `gen_local_footprints.py` + `resize_pcb_6L.py`
- post-process: `scan_overlaps.py` (检测 text 重叠) + `shrink_label_font.py` (1.27→1.0mm font)

## Memory 索引相关条目

- `reference_kicad_sch_design_rules.md` — 16 条 KiCad 原理图生成器硬规则
- `reference_zynq_ug933_pcb_rules.md` — UG933 cap 数量 + DDR3 layout
- `feedback_kicad_subsym_namespace.md` — KiCad lib_symbols 子符号命名坑
- `reference_kicad_sch_generator.md` — kicad_sch_lib.py 使用文档

## 关键文件

- 工程: `kicad/zynq7020_dev.kicad_pro`
- root sch: `kicad/zynq7020_dev.kicad_sch`
- PCB: `kicad/zynq7020_dev.kicad_pcb` (1.08 MB, 6L 95×95mm 含 GND/PWR zone)
- 备份: `*.kicad_pcb.8L_backup` (8 层 120×100mm) + `*.kicad_pcb.4hdr_95mm_backup` (4 排针 95mm)
- 验证: `_check/full_erc.rpt` + `_check/drc.rpt` + `_check/board.step` + `_check/board_3d_top.png` + 10 个 `*.pdf`

## 17 个 subagent 历程

1-5. 初始 10 sheet 生成 (zynq_main / ddr3 / qspi_sd / clock / misc / hdmi / ethernet / usb_uart / headers_io / power)
6-8. BOM 改鹿小班 (power TPS563210 / hdmi 直驱 TMDS / usb_uart CH340E + 删 USB3320C)
9. footprint 验证 + 自制 BGA-153 eMMC
10. 根 sheet 整合 + alias 326 个
11. Annotation cleanup 去 duplicate ref
12. UG933 cap 70 颗
13. 2x60 排针自制 sym/fp + headers_io 重写
14. PCB scaffold 8L→6L 95×95mm
15. zynq_main alias 更新 2x60 pin range
16. PCB Phase 2 (GND zone + PWR plane + via)
17. **运行中**: 2 排针 + 板缩 75mm
