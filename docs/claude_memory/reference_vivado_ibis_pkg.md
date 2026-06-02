---
name: Vivado IBIS .pkg 是 Xilinx BGA 全 pin 映射的权威源
description: Vivado 安装目录的 IBIS pkg 文件含 ball→net 完整映射, 比 datasheet UG865 手工查更可靠, 可脚本提取
type: reference
originSessionId: a0de8487-f937-42a3-9099-232556741253
---
**位置**: `C:\Xilinx\Vivado\<ver>\data\parts\xilinx\zynq\public\ibis\pkg\<part>_<pkg>.pkg`

例: `C:\Xilinx\Vivado\2024.2\data\parts\xilinx\zynq\public\ibis\pkg\xc7z020_clg484.pkg`

## 格式 (text, IBIS 4.2)
```
[Pin Numbers]
|[Pin Name]  Net Number    Net Name   Net's All Pins
K11           | 1          VCCADC_0                           K11
L10           | 2          VCCAUX                             L10
                                                             |N10
                                                             |P11
                                                             |R10
```
- 主行: `BALL | net_num  net_name  first_ball`
- 续行: `       |continuation_ball` (列出该 net 上其余球)
- 续行不以 `|` 开头, 是 whitespace + `|BALL`, 解析时容易漏

## 覆盖范围
- IBIS .pkg 列出**信号 + 电源**球 (有 IO 驱动模型的)
- **不列 GND 球** — 必须从 (484 全 ball 列表) - (IBIS 列出球) 推断
- CLG484: 420 named (200 PL IO + 133 PS + 9 config + 4 XADC + 5 other + 69 VCC) + 64 inferred GND = 484 ✓

## 用法
工程 `D:\claude_workspace\pov3d\pcb\zynq7020_dev_v1\kicad\scripts\parse_xilinx_pkg.py` 是参考实现, 输出 ball_map.csv (ball, net, group, category)。续行解析容易出 bug, 看 parse_pkg() 函数。

## 其他 part 同位置可找到
- xc7z010_clg400.pkg
- xc7z020_clg400.pkg / xc7z020_clg484.pkg
- xc7z020i_clg484.pkg (工业级)
- 其他 Zynq/7-series 都在 `Vivado\<ver>\data\parts\xilinx\<family>\public\ibis\pkg\`

BSDL 文件 `<part>.bsd` 在同目录附近, 包含 IEEE 1149.1 boundary scan info, 不如 IBIS .pkg 直接。

## 22-letter BGA row 命名 (CLG484)
JEDEC 跳 I/O/Q/S/X/Z: A B C D E F G H J K L M N P R T U V W Y AA AB (22 行 × 22 列 = 484)
