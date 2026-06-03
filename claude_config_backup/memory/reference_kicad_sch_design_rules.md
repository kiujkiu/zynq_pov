---
name: KiCad 原理图设计规则 (POV3D Zynq 7020 dev board 经验)
description: 用 kicad_sch_lib.py 生成 KiCad 10 schematic 的硬规则, 避免 label/text 重叠 + 跨 sheet 连接失败 + ref 冲突
type: reference
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---
POV3D Zynq 7020 自制板用 Python (`kicad_sch_lib.py` + `chip_library.py`) 批量生成 schematic 时踩过的所有坑, 后续画原理图必须遵循。

## 1. Label 字号必须 1.0mm 不能 1.27mm

KiCad 默认 hier_label / global_label 是 1.27mm 字号, 渲染出来 pentagon arrow box 视觉高度 ≈ 2.54mm。chip pin pitch 也是 2.54mm。**直接 1:1 撞上**, 任何两个相邻 pin 的 label 都会视觉重叠。

**fix**: `_emit_glabel` / `_emit_hlabel` 用 `(font (size 1 1))`, pentagon 视觉高度 → ~2.0mm, 跟 2.54mm pin pitch 留 0.5mm clear。

**已实现**: `kicad_sch_lib.py` 已经 1.0mm 字号。

## 2. Label justify 必须跟 rotation 配对

global_label / hier_label 的 `(justify ...)` 决定 text 从 anchor 朝哪边延伸:
- rotation **0 / 90** → `(justify left)`: text 朝右/下
- rotation **180 / 270** → `(justify right)`: text 朝左/上

**目的**: text 永远朝远离 chip body 的方向。否则 text 压回 chip 里跟 pin name 撞。

## 3. Reference / Value 文字位置自动算

不要硬编码 (+2.54, ±2.54). 按 symbol pin bbox 计算:
- 2-pin **垂直 passive** (pins 上下): Ref 在 right, Val 在 left (左右两侧)
- 2-pin **水平 passive** (pins 左右): Ref 在 top, Val 在 bottom (上下)
- **chip (3+ pins)**: Ref 上方 (min_pin_y - 7.62mm), Val 下方 (max_pin_y + 7.62mm)
- **passive long value** (>6 chars 如 "100uF_25V"): 不能 side placement, 改成同侧上下错开

`_emit_symbol` 用 `_ref_val_positions(s, pin_worlds)` 自动算。

## 4. PWR_FLAG / GND value 文字隐藏

GND 三角图标本身够明确, value text "GND" 是冗余且会跟相邻 label 撞。同理 PWR_FLAG 的 "PWR_FLAG" 文字。

```python
_HIDE_VAL = {"power:PWR_FLAG", "power:GND", "power:GNDA", "power:GNDD", "power:Earth"}
```

`_emit_power_sym` 和 `_emit_symbol` 都已加 hide 列表。

## 5. PWR_FLAG 只 flag 真正没驱动的 rail

陷阱: 多 sheet 各自 PWR_FLAG 同一个 rail → KiCad 报 `pin_to_pin: Power output vs Power output`。

规则: rail 是被 buck/LDO 的 SW pin (power_out type) **真正驱动**就 NOT 需要 PWR_FLAG。只对 input-only rail 用 PWR_FLAG (e.g. 工程没接 +12V 物理输入但有 +12V 占位时)。

## 6. 自制 chip symbol 的 sub-symbol 名不带 namespace

lib_symbols 里 leaf 是 `"Lib:Name"`, 但内部 sub-symbol (_0_1 graphics / _1_1 pins) 必须 **bare 名 "Name_0_1"**。加 namespace 前缀 KiCad load 失败。

```python
bare_name = lib_id.split(":")[-1]
graphics_sub = f'(symbol "{bare_name}_0_1" ...)'
```

## 7. body_width / body_height 必须 1.27mm 倍数

`define_chip` 的 body 尺寸如果不是 1.27 倍数, pin 端点会落到 1.27 网格外, KiCad 报 endpoint_off_grid + 后续 wire snap 把 wire 断开。

例: IT66121 用 `body_height=71.12` (=56×1.27), 不能用 70。

## 8. 跨 sheet 用 global_label, 不要 hier_label

KiCad hier_label 必须配根 sheet 的 sheet_pin 才能跨 sheet 连通。但 sheet_pin 都得手画。

**实战做法**: 所有跨 sheet 信号在 sub-sheet 用 `global_label` (相同名字自动 namespace-match)。仅在主芯片 (zynq_main) 物理 pin 上用 hier_label, 同时旁边加 functional 名字的 global_label 做 **alias 双标签**。

agent I 报告: 824 → 118 isolated label (86% reduction) 用这个 alias 方案。

## 9. font shrink 工具 + overlap scan 工具

工程 `kicad/scripts/` 里有 2 个 post-process:
- `scan_overlaps.py` — 扫所有 sheet 算 text bbox 找重叠 (忽略 same-anchor alias pair)
- `shrink_label_font.py` — 把所有 sheet 的 label 字号 1.27→1.0mm

每改完 schematic 跑一遍 `scan_overlaps.py`, 必须 0 重叠。

## 10. Ref designator 全工程独立编号

KiCad PCB 不接受 duplicate ref。每个 sheet 必须分配不重叠的 ref 范围:

```
power      : U1-U9, C1-C99, R1-R49, L1-L9, D1-D9, F1, J1
ddr3       : U10-U11, C100-C199, R50-R99, RR1-RR21
qspi_sd    : U12-U13, C200-C249, R100-R119, J10
clock      : U14, C250-C259, R120-R124, SW1-2
misc       : LED1-9, KEY1-9, SW3, J11, C260-C279, R125-R139
hdmi       : C300-C349, R200-R229, D70-D79, J70
ethernet   : U20, RJ1, Y1, C350-C449, R230-R279
usb_uart   : U21-U22, J22-J23, Y2, C450-C549, R280-R329
headers_io : H1-H4, JP1-JP4
zynq_main  : U30, C700-C719
```

PWR_FLAG (`#FLGxx`) 和 GND power symbol (`#PWRxx`) 不算 duplicate, 不用管。

## 11. 模块框 + 加粗标题

每个功能块 (DC input / TPS563210 buck / AMS1117 LDO 等) 用 `b.module_box(name, start, end)` 画矩形 + 左上角加粗标题。视觉上当 block diagram 看。

## 12. 配套 BOM 跟鹿小班 (HelloFPGA_XC7Z020) 对齐

我们板是鹿小班升级版。除非必要不要换芯片型号:

- **5× TPS563210ADDFR** (8-pin SOIC PowerPAD) 替换所有 buck/LDO; 5V 单级输入降到 1V0/1V8/1V5/3V3/VCCIO_ADJ
- **CH340E** (10-pin) 替代 CH340C, USB → PS UART
- **HDMI 直驱 TMDS** (无 IT66121), Zynq BANK34 通过 8 颗 100nF AC-coupling + 8 颗 49.9R 终端 + 2 颗 PUSB3FR4 ESD + MBR0520 +5V_HDMI
- **W25Q256JVEIQ** QSPI flash (32MB SOIC-8)
- **RTL8211E-VB-CG** ethernet PHY (stock 库是 EG 后续版本, pin 兼容)
- **HR911130A** RJ45 magjack (鹿小班用, 14 pin)
- 时钟用 **50MHz + 33.33MHz SMD 4-pin osc**, 不用差分

详见 `/mnt/d/claude_workspace/pov3d/lxb_sch.pdf` (8 页完整鹿小班原理图)。

## 13. 我们升级版差异 (跟鹿小班不同的部分)

- **32-bit DDR3** (鹿小班 16-bit): 2× MT41K256M16HA 并联, 加 TPS51200DRC VTT termination + VREF 分压
- **eMMC 8GB** (鹿小班无): Foresee NCEMBSF9-08G 153-FBGA, 接 PS SD1 via MIO 10-15 (不占 PL)
- **200 PL IO 全接出**: 4× 2x40 排针 H1-H4 各对应 BANK 13/33/34/35
- **保留 FT2232HL JTAG** (鹿小班无): USB-C 主调试口
- **删 USB OTG ULPI** (USB3320C, 不要), 用 PS USB OTG 不要 PHY

## 14. MIO 分配 (按 Zynq 7020 UG585 + 鹿小班实战)

```
MIO 1-6   QSPI (CS_N / DQ0-3 / CLK)
MIO 7-9   free / boot mode strap (post-boot 释放)
MIO 10-15 SD1 → eMMC (CLK/CMD/DAT0-3, 4-bit)
MIO 16-27 GEM0 RGMII (TXC/TXD0-3/TX_CTL/RXC/RXD0-3/RX_CTL)
MIO 28-29 free
MIO 30-31 UART0 (TX/RX) → CH340E
MIO 32-33 free
MIO 34-35 I2C0 (SDA/SCL) → INA226 + NCT75 + EEPROM (可选)
MIO 36-39 free
MIO 40-45 SD0 → SD card socket
MIO 46    SD0 CD (card detect)
MIO 47    SD0 WP 或 NC
MIO 48-49 free
MIO 50-51 MDIO / MDC (ethernet 管理总线)
MIO 52-53 free
```

## 15. Pin pitch 选择: 5.08mm 比 2.54mm 安全

对密集 pin 的 connector / chip (e.g. 2x40 header), 1.27/1.0mm font label 也勉强 fit (0.5mm clearance)。**更安全**: label 隔 pin 放 (5.08mm pitch), 留 2.5mm gap, 视觉清晰。或 alternate left/right。

实战: 4× 2x40 header (H1-H4) 用了 left+right 交错 + 2.54mm 紧贴, 字号 1.0 后勉强 OK, 但 5.08mm pitch 更稳。

## 16. footprint 库映射坑

stock KiCad fp 库一些命名差异 (我们踩过):
- `VSSOP-10` → 实际叫 `MSOP-10_3x3mm_P0.5mm` (alias)
- `WSON-8` (TPS51200DRC 用) → 实际叫 `VSON-10-1EP_3x3mm_P0.5mm_EP1.65x2.4mm`
- `L_7x7mm` → 实际叫 `L_7.3x7.3_H3.5`
- `RJ45_Hanrun_HR911105A` → 完整名 `RJ45_Hanrun_HR911105A_Horizontal`
- `Connector_RJ45:...` → 实际 library 名 `Connector_RJ:...` (没 45)
- `Button_Switch_THT:SW_DIP_SPSTx05_Slide_9.78x12.34mm` → 实际 `..._9.78x14.88mm` (尺寸)

下次自制 chip 选 footprint, 先 `ls "C:\Program Files\KiCad\10.0\share\kicad\footprints\<Lib>.pretty/"` 验证存在。
