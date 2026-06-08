---
name: POV3D 双 panel 128×128 v33 dual panel 改造 (2026-06-04)
description: 鹿小班 GPIO1 BANK 33 加 6 IO 给 panel 2 SDI, 共享 CLK/LAT/OE/ABCDE, MVP mirror 阶段验证 wiring, 后续加独立 BRAM 真 128×128
type: project
created_at: 2026-06-04 19:00 CST
updated_at: 2026-06-04 19:00 CST
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
# 决策

panel 1 (128×64 FM6124) + panel 2 (128×64 同型号) **垂直堆叠** = 128×128。
两 panel 共享 CLK/LAT/OE/ABCDE (8 信号), 只 RGB SDI 独立 (每 panel 6 SDI)。

总 IO: 14 (panel 1) + 6 (panel 2 新 SDI) = **20 IO**, 全在 GPIO1 BANK 33 (34 IO 余 20)。

# Panel 2 SDI 引脚分配 (GPIO1 BANK 33, 6 IO)

| panel 2 信号 | PACKAGE_PIN | GPIO1 Pin | site |
|---|---|---:|---|
| R1' (panel2 IDC 1) | AA19 | 13 | IO_L11N_T1_SRCC_33 |
| G1' (panel2 IDC 2) | AB16 | 15 | IO_L18N_T2_33 |
| B1' (panel2 IDC 3) | AA16 | 16 | IO_L18P_T2_33 |
| R2' (panel2 IDC 5) | AA17 | 27 | IO_L17P_T2_33 |
| G2' (panel2 IDC 6) | AB17 | 28 | IO_L17N_T2_33 |
| B2' (panel2 IDC 7) | Y16  | 30 | IO_L14N_T2_SRCC_33 |

panel 2 IDC pin 8-15 (E, A, B, C, D, CLK, LAT, OE) 共享 panel 1 同名信号 (1 拖 2 IDC 或 jumper)。

# 改造步骤 (v33 MVP)

**Phase 1 (MVP, 当前)**: panel 2 SDI = panel 1 SDI (mirror), 验证 wiring 信号到达

1. **xdc**: `hub75e_pins.xdc` 加 6 行 `hub75e_rgb2[0..5]` PACKAGE_PIN
2. **verilog**: `hub75e_panel_seq.v` 加 `output reg [5:0] hub75e_rgb_out2;`
   - 复制 panel 1 `hub75e_rgb_out` 所有赋值到 `hub75e_rgb_out2` (4 处: 全局 reset / S_IDLE reset / S_SHIFT / S_PHASE)
3. **BD 改造** (`tools/build_v33_dual_panel.tcl`):
   - `update_module_reference [get_bd_cells hub75e_panel_seq_0]` 让 Vivado 重新 elaborate 新 port
   - `create_bd_port -dir O -from 5 -to 0 hub75e_rgb2`
   - `connect_bd_net [get_bd_pins hub75e_panel_seq_0/hub75e_rgb_out2] [get_bd_ports hub75e_rgb2]`
4. **build**: `make_wrapper -force` + impl_1

**Phase 2 (待 wiring 验证 OK)**: 加独立 BRAM 实现真 128×128

- AXI awaddr 扩到 17-bit (从 64KB → 128KB), panel 2 BRAM 在 addr[16]=1 region
  - 0x40028000-0x4002FFFF: panel 1 fb (现有)
  - 0x40030000-0x40037FFF: panel 2 fb (新, 16 KB top + 16 KB bot)
- 加 `fb_top2 + fb_bot2` 两块 xpm_memory_sdpram (各 4Kx24)
- FSM read panel 2 BRAM, drive `hub75e_rgb_out2`
- BRAM 占用: 现 73% → 加 6 BRAM36 估到 78% (8K pixel × 24 = 192 Kbit ≈ 6 BRAM36)

# BD 改造关键

memory `feedback_vivado_bd_module_ref_update.md` 说 module_ref port 改了需要 `update_module_reference`. 我们 verilog 加新 output port, 必须显式 update reference, BD cell 才会出现新 pin.

如果 `update_module_reference` 失败 (memory: `feedback_vivado_bd_addr_width_cache.md` ADDR_WIDTH 顽固缓存教训), 备选: rename module + 删 ip cache + recreate cell. 本次因为是加 port 不是改 port width, 应该走得通.

# 测试方法

build 完 dl 后:
- panel 1 跑现有 anime (HDMI bridge or QSPI flash slice)
- panel 2 物理接 RGB SDI 到新 6 IO, 共享 CLK/LAT/OE/ABCDE
- panel 2 应该显示 **跟 panel 1 完全一致** 的图像 (MVP mirror)
- 如果一致 → wiring OK, 进 Phase 2 加独立 BRAM
- 如果错乱 → 检查 IO 接线 / panel 极性 / 共享信号 timing

# 不动

- panel 1 现有 14 IO 完全不动 (兼容现有 xdc)
- AXI 寄存器 layout 不动 (Phase 1 MVP)
- ARM bridge 代码不动 (panel 2 数据来自 panel 1 mirror, 无需 ARM 改)

# 文件

- `02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v` (output port + 4 mirror 赋值)
- `02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc` (6 新 PACKAGE_PIN)
- `tools/build_v33_dual_panel.tcl` (BD update_module_reference + create port + connect + build)
