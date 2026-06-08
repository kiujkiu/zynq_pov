---
name: POV3D dual panel v34e 状态 + 已知卡点 (2026-06-08)
description: 128×128 dual panel MVP mirror PL build (v34e) 已 build OK, panel 1 lit 但 panel 2 SDI 死, JTAG driver 卡 enumerate
type: project
created_at: 2026-06-08 15:30 CST
updated_at: 2026-06-08 15:30 CST
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
# 当前 PL 状态 (debug/fm6124-v29 branch, commit 0aada63)

**v34e build done Jun 5 20:09**:
- hub75e_panel_seq.v: module renamed v2 → v3, 加 hub75e_rgb_out2[5:0] output port (mirror panel 1)
- (* dont_touch = "true" *) 加在 rgb_out2 declaration, 防 synth merge 跟 rgb_out
- BD recreate (delete cell + delete IP cache + recreate with v3 ref)
- panel base 地址 0x40010000 (BD assign_bd_address -force 选了新位置, 不再 0x40020000)
- xdc 加 6 PACKAGE_PIN panel 2 SDI:
  AA19/AA13/Y13/AB15/AB14/Y16 (GPIO1 排针 J1.13/31/32/33/34/30)
- bit: 02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit (Jun 5 20:08)
- xsa: hello_plat/hw/hello_zynq.xsa (Jun 5 20:09)

# Panel 2 wiring (确认表)

panel 2 IDC pin ↔ GPIO1 排针 (跟 panel 1 同款 GRB swap 处理):

| panel 2 IDC | 标签 | 内部 chip | PL 信号 | Zynq pin | GPIO1 排针 |
|---:|---|---|---|---|---:|
| 1 | R1 | G | hub75e_rgb2[1] | AA13 | J1.31 |
| 2 | G1 | R | hub75e_rgb2[0] | AA19 | J1.13 |
| 3 | B1 | B | hub75e_rgb2[2] | Y13 | J1.32 |
| 5 | R2 | G | hub75e_rgb2[4] | AB14 | J1.34 |
| 6 | G2 | R | hub75e_rgb2[3] | AB15 | J1.33 |
| 7 | B2 | B | hub75e_rgb2[5] | Y16 | J1.30 |

panel 2 IDC 8-15 (E/A/B/C/D/CLK/LAT/OE) 共享 panel 1 同名 pin.

# 已发现 root cause

**CTRL bit 5 (use_fb)** = 1 时 panel 读 BRAM 不读 COLOR register, BRAM 没 init → 全 0 → RGB IO 死. 修复: 用 **CTRL=0x501** (mode 0 SOLID, use_fb=0, no overlap) 验证 PL output, 而不是 0x561.

# 待验证 (下次开机后)

1. dl v34e bit (refresh_bit + dl_minimal.tcl)
2. 跑 tools/test_solid_no_fb.tcl (CTRL=0x501 + pure RED)
3. 测 GPIO1 J1.13/30 (panel 2 R1' B2') 是否有信号
4. 物理看 panel 1 + panel 2 都亮红色 = mirror 工作 ✓

# 当前卡点 (2026-06-08)

**JTAG cable enumerate 失败** - hw_server 看不到 USB JTAG:
- Device Manager: "USB Serial Converter" VID 0403/PID 6014 (FT232H) Provider=FTDI generic
- xsdb `jtag targets` + `targets` 全空
- 之前 dl 过 OK, 现在不行 — Windows update 可能把 driver 还原成 FTDI generic

memory `reference_hardware.md` 写: **"JTAG via same/separate USB; occasionally drops, fix is physical USB replug"** 
→ 简单物理拔插 USB 解决, 不用 Zadig / 装 Digilent Adept Runtime

如果物理拔插不行, 备选:
- USB 换口
- 重启 PC
- 最坏: Zadig 强制绑 libusbK

# 路线图

Phase 1 (当前): MVP mirror 验证 wiring + PL ✓ build done, 待 JTAG 恢复 dl + 测
Phase 2: 真 128×128 (panel 2 独立 BRAM + 扩 AXI segment 64K → 128K + ARM 写 fb 上下半各 64 行)
Phase 3: POV-3D 旋转 + 122 angle slice 切换 (anime_slices.bin 已生成)
