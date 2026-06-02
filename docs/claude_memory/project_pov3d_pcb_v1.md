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

## 2026-06-02 status: 工程 KiCad 10 验证通过, power.kicad_sch Phase A done

用户装 KiCad 10.0.3 后用 kicad-cli (no GUI 需要) 全验证:
- 11 个 sch 文件 v10 格式 upgrade 成功
- XC7Z020 9 unit / 484 pin symbol 全部 SVG 导出 ✓
- BGA-484 footprint SVG 导出 ✓
- root sch ERC 0 violations
- **power.kicad_sch Phase A**: 35 symbols, ERC 8 残留 (全部 expected: 4 跨 sheet 信号 + 1 SCL 需 ZYNQ_MAIN I2C master + 3 缺 fp)
- 生成器 `kicad_sch_lib.py` + `gen_power_sch.py` 已建 (见 reference_kicad_sch_generator.md)

## 下一步
1. 填 zynq_main + ddr3 + 其他子页 (用同 lib 生成器, 已有 35 component pattern 参考)
2. 自制 sym/fp: MP2161 (×3) / TPS2553 / NCT75 / W25Q256 / RTL8211F / FT2232HL / USB3320C / CH340C / MT41K256M16 (后两个有 stock 但 fp 缺)
3. PCB layout

## 接下来 (用户验证 KiCad 工程能开后)
1. 生成其他自制 sym/fp: MT41K256, W25Q256, RTL8211F, FT2232HL, USB3320, CH340C, INA226, NCT75, MP2161, TPS54360 等
2. 逐子页填原理图 (power → zynq_main → ddr3 → ...)
3. PCB layout (floorplan → BGA fanout → DDR3 等长 → 关键信号 → 铺铜)
4. DFM + 嘉立创打样

## 工具选型
**KiCad 10.0.3** 选定 (放弃立创EDA, 工程骨架按 v9 格式写但 v10 兼容), 原因: 文本工程文件让 claude 直接 Edit/Write, 不依赖 GUI, git 友好。立创EDA 文件格式不开放, claude 帮不上文件层面。
