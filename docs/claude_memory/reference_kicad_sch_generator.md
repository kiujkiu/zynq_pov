---
name: KiCad 10 schematic 生成器 (kicad_sch_lib.py)
description: 自建的 KiCad 10 .kicad_sch 生成器, 解决了 extends symbol / 1.27 grid / label 连接 / lib_id 命名空间几个坑
type: reference
originSessionId: 37aa49b2-ddd9-4c38-a89f-2bf1258edd1c
---
工程位置: `D:\claude_workspace\pov3d\pcb\zynq7020_dev_v1\kicad\scripts\kicad_sch_lib.py`

## 用法

```python
from kicad_sch_lib import SchBuilder, snap_pt
b = SchBuilder("Title", "2026-06-02", "v1", "claude+user", paper="A3")
u1 = b.place("Regulator_Switching:TPS54360DDA", "U1", "TPS54360DDA", "fp_name", at=(60, 80))
b.power("GND", b.pin_pos(u1, "7"))                    # GND symbol on pin 7
b.global_label("+12V", b.pin_pos(u1, "2"), rotation=0)  # label on pin 2
b.save(Path("out.kicad_sch"))
```

跟 `kicad-cli sch erc` + `kicad-cli sch export svg/pdf` 配合就能完整流程跑通无需 GUI。

## 几个关键坑 (我已经在 lib 里修好了, 但下次重写注意)

### 1. extends symbol 必须 flatten
KiCad 标准库里 `AMS1117-3.3 (extends "AP1117-15")`, 单纯把两个 symbol block 都塞 lib_symbols 不够 — KiCad ERC 会报 `lib_symbol_mismatch` 然后所有 pin 都识别失败. 必须把 base 的 body 复制进 leaf, 改 sub-symbol 名 (`AP1117-15_0_1` → `Regulator_Linear:AMS1117-3.3_0_1`), 删 `(extends ...)`. 见 `flatten_extends()`.

### 2. 坐标必须 snap 到 1.27mm 网格
不在 1.27mm 倍数上的 pin 端点 ERC 直接报 `endpoint_off_grid`. SchBuilder.place/wire/power 全自动 snap. 注意 `40 mm → 39.37 mm` (round half-to-even).

### 3. label 必须在 pin 端点 (零 stub)
原来给每个 pin 接 5.08mm stub + label, 相邻组件的 stub overlap 把两个 net merge 成一个 (multiple_net_names). 改成直接 label_at_pin_endpoint, 没 stub 没 wire, KiCad 仍能识别连通.

### 4. pin_pos 旋转换算
KiCad symbol 内 Y-up, world 内 Y-down. 旋转是屏幕视觉 CCW. 实现见 `pin_pos()`:
- rot 0:   (sx + px, sy - py)
- rot 90:  (sx - py, sy - px)
- rot 180: (sx - px, sy + py)
- rot 270: (sx + py, sy + px)

### 5. PWR_FLAG 驱动 net
GND 是 power_input 类型, 没 PWR_FLAG 就 "not driven". 任何 input-only 的 power rail (没 power_output pin 实际驱动) 都得加 PWR_FLAG.

### 6. 库引用查 pin number 不要靠想象
TPS51200DRC / INA226 / AMS1117 pin numbering 我连续猜错三次. 用 `awk '/(symbol "NAME"/{flag=1} flag{print; if (/^\t\)$/){exit}}' lib.kicad_sym | grep -E '(pin |\(number'` 拉真实 pin map.

### 7. KiCad 标准库位置
`C:\Program Files\KiCad\10.0\share\kicad\symbols\*.kicad_sym` (Device / Connector / Regulator_Switching / Regulator_Linear / Sensor_Energy / power / Interface_USB / Interface_Ethernet / Memory_RAM 等)

## 验证流程

```bash
# 跑生成
/mnt/c/Users/.../Python312/python.exe gen_xxx_sch.py
# ERC 校验 (Windows path)
"/mnt/c/Program Files/KiCad/10.0/bin/kicad-cli.exe" sch erc \
    --output "D:\...\_check\xxx_erc.rpt" \
    "D:\...\sheets\xxx.kicad_sch"
# 导出 PDF/SVG
"/mnt/c/Program Files/KiCad/10.0/bin/kicad-cli.exe" sch export pdf ...
```

## 已写的生成器

- `gen_clg484_footprint.py` — XC7Z020 BGA-484 footprint
- `gen_xc7z020_symbol.py` — XC7Z020 9-unit symbol (484 pin)
- `gen_schematic_skeleton.py` — root sch + 10 子 sheet 骨架
- `gen_power_sch.py` — power 子页 (Phase A: DC input + TPS54360 + 2× AMS1117 + TPS51200 + INA226). ERC 8 残留 violations 全部 expected (跨 sheet 信号 + 缺 fp)
