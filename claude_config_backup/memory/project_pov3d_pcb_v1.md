---
name: POV3D 自制 Zynq 7020 开发板 v1 (2026-06)
description: 基于鹿小班 + 200 PL IO 全接出 + POV3D 工程化升级, KiCad 9 格式工程骨架已落盘, 用户装 KiCad 10.0.3 (向后兼容)
type: project
originSessionId: a0de8487-f937-42a3-9099-232556741253
---
工程位置: `D:\claude_workspace\pov3d\pcb\zynq7020_dev_v1\`

**目标**: 自制 Zynq 7020 开发板替代鹿小班, 把所有 200 PL IO 接出, 升级 POV3D 卡点 (DDR3 带宽 / WiFi / 调试效率)

## 关键设计决策
- **芯片**: XC7Z020-2CLG484I (LCSC C2913916, ~¥1200)
- **200 PL IO 全接出**: 4× 2×40 排针 (H1=BANK13 / H2=BANK33 / H3=BANK34 / H4=BANK35)
  - H2 **完整复刻鹿小班 GPIO1 pinout**, demo XDC 不用改
  - H3/H4 预留 POV3D LED 驱动子板接口
- **板载外设跟排针 pin 共享 net**: 用户接子板时避开已占用 IO, 板载外设照常工作, 不用 0Ω 跳线
- **升级 vs 鹿小班**: DDR3 16→32-bit 1GB (2× MT41K256M16), 板载 FT2232H (USB JTAG+UART), USB-OTG (USB3320), M.2 E-key WiFi 座, 100MHz diff XO, boot mode 升级 5-bit DIP, INA226+NCT75 监控
- **不集成 LED 驱动 IC** (90× MBI5264 + 12× ICND3019 走子板)
- **8 层 PCB, via-in-pad, ~120×100mm**, 嘉立创 5 片 ~¥2200/板

## 已完成 (KiCad 工程骨架)
- `zynq7020_dev.kicad_pro` — 工程 + DRC + net classes (DDR3 / HSPD_DIFF_100 / USB / PWR_HEAVY)
- `symbols/zynq7020_dev_local.kicad_sym` — XC7Z020 9 unit symbol, **484 pin 全部带 ball 编号+net 名** (从 Vivado IBIS .pkg 自动提取)
- `footprints/zynq7020_dev_local.pretty/XC7Z020-CLG484.kicad_mod` — 22×22 BGA, 0.8mm pitch, 0.4mm SMD pad
- `zynq7020_dev.kicad_sch` (root) + 10 子页骨架 (power/zynq_main/ddr3/qspi_sd/hdmi/ethernet/usb_uart/clock/headers_io/misc)
- 4 个 Python 脚本 in `kicad/scripts/`: parse_xilinx_pkg.py / gen_clg484_footprint.py / gen_xc7z020_symbol.py / gen_schematic_skeleton.py

## 顶层设计文档
- `block_diagram.md` — 顶层方块 + 物理布局
- `io_assignment.md` — 200 PL IO → 4 排针完整表
- `power_tree.md` — 电源树 + 17.5W 满载预算
- `BOM_v1.md` — 51 项 BOM 含 LCSC 编号 (~¥1520 元件/板)
- `STATUS.md` — 进度跟踪

## 2026-06-02 status: 10 sheet 全部完成 + PCB scaffold + 鹿小班 BOM 对齐

**全 schematic + PCB scaffold 由 11 个并行 subagent 完成**, 跨多轮 BOM 调整:

### 子页 (10 个 .kicad_sch, 共 ~290 component, 0 文字重叠)
- power: 5× **TPS563210ADDFR** (5V→1V0/1V8/1V5/3V3/VCCIO_ADJ) + TPS51200 VTT + INA226 监控 + PG 序列链
- zynq_main: XC7Z020 9 unit + 326 个 functional alias (physical pin name ↔ functional name 双标签)
- ddr3: 2× MT41K256M16HA (32-bit) + VREF + VTT 端接
- qspi_sd: W25Q256JVEIQ + microSD socket + **eMMC 8GB NCEMBSF9-08G** (Linux rootfs, SD1 via MIO 10-15)
- clock: 100MHz + 33.33MHz SMD osc + PS_POR_B/SRST_B 按键
- misc: LED + KEY + boot DIP + JTAG header
- hdmi: **直驱 TMDS** (8 cap + 8R 49.9Ω + 2 PUSB3FR4 ESD + MBR0520 +5V_HDMI), 无 IT66121
- ethernet: RTL8211EG-VB-CG + HR911105A magjack + 25MHz
- usb_uart: FT2232HL (JTAG + 备用 UART) + **CH340E** (PS UART) + 2 USB-C, 删 USB3320C
- headers_io: 4× 2x40 排针 (H1-H4 对应 BANK 13/33/34/35) + VCCO 跳线

### PCB scaffold (`zynq7020_dev.kicad_pcb`)
- 8 层 JLCPCB JLC8L stackup, 1.6mm, ENIG **(2026-06-02 用户改约束: 改 6 层, ≤100×100mm)**
- 120×100mm 板, R3mm 圆角, 4× M3 定位孔 **(改 ≤100×100mm)**
- DRC: 5mil trace/clearance, 0.4mm via, 0.2mm drill
- 6 net classes (DDR3 / HSPD_DIFF_100 / DIFF_90_USB / PWR_HEAVY 等)
- Floorplan hint 在 User.Comments 层
- 真实 footprint 还没导入 (annotation cleanup 后用 GUI Update PCB from Schematic 一键完成)

### 新增约束 (2026-06-02 用户)
1. **6 层 stackup** (替代 8 层): L1 sig / L2 GND / L3 sig / L4 PWR / L5 GND / L6 sig
2. **板尺寸 ≤ 100×100mm 越小越好** ("中间多余的地都去掉" — 紧凑 floorplan, 别留空)
3. **排针 1.27mm 双排针**, 改 **2x60 pin** (240 pin/排针, 给每 PL IO 配相邻 GND 提升 SI)
4. 4 个 2x60 排针 (H1-H4), 每根 76.2mm 长 (60×1.27), 4 根 ~ 304mm 周长占用. 100mm 边长可放 1 排针 + 23.8mm 给其他 conn (HDMI/USB-C/RJ45 都< 16mm).
5. **KiCad stock 没有 Conn_02x60 symbol** (max 2x40), 要 `define_chip` 自制 120-pin connector symbol + 1.27mm 2x60 footprint
6. 每 PL IO 旁邻 pin 接 GND: BANK 13/33/34/35 各 ~50 PL IO, 配 ~50 GND = 100 pin (剩 20 pin 留 VCC/控制信号)

### 关键经验固化到 memory
见 [`reference_kicad_sch_design_rules.md`](reference_kicad_sch_design_rules.md) 16 条规则:
- label 字号 1.0mm (不能 1.27mm, 跟 2.54mm pin pitch 撞)
- 跨 sheet 用 global_label (hier_label 需要根 sheet 接 sheet_pin, 太麻烦)
- zynq_main 用 physical hier_label + functional global_label 双标签 alias
- 自制 chip body_width / body_height 必须 1.27mm 倍数
- ref designator 全工程独立编号 (KiCad PCB 不接受 duplicate)
- 鹿小班 BOM 对齐 (TPS563210 / CH340E / 直驱 TMDS / RTL8211 / HR911130A)
- MIO 分配方案 (QSPI MIO1-6, SD1/eMMC 10-15, GEM0 16-27, UART0 30-31, SD0 40-45, I2C0 34-35)

### 下一步
1. ✅ Annotation cleanup (去 49 个 duplicate ref) — agent 跑中
2. 用 KiCad GUI 打开 `.kicad_sch` → File → Update PCB from Schematic, 288 个 footprint 按 floorplan hint 落位
3. **真布线**: BGA escape / DDR3 fly-by 等长 / diff pair (HDMI/USB/RGMII) / 铺铜 — 多日工作量, 分多次会话

### 关键文件
- 生成器: `kicad/scripts/kicad_sch_lib.py` (650+ 行)
- 自制 chip lib: `kicad/scripts/chip_library.py` (含 MP2161/TPS563210/eMMC 等)
- 工程: `kicad/zynq7020_dev.kicad_pro` + 10 sub-sheet + .kicad_pcb
- 验证: `_check/*.pdf` + `_check/board.step` + `_check/drc.rpt`
- Post-process: `scan_overlaps.py` + `shrink_label_font.py`

## 接下来 (用户验证 KiCad 工程能开后)
1. 生成其他自制 sym/fp: MT41K256, W25Q256, RTL8211F, FT2232HL, USB3320, CH340C, INA226, NCT75, MP2161, TPS54360 等
2. 逐子页填原理图 (power → zynq_main → ddr3 → ...)
3. PCB layout (floorplan → BGA fanout → DDR3 等长 → 关键信号 → 铺铜)
4. DFM + 嘉立创打样

## 工具选型
**KiCad 10.0.3** 选定 (放弃立创EDA, 工程骨架按 v9 格式写但 v10 兼容), 原因: 文本工程文件让 claude 直接 Edit/Write, 不依赖 GUI, git 友好。立创EDA 文件格式不开放, claude 帮不上文件层面。
