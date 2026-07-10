---
name: POV3D dual panel v34e Mirror MVP 通 (2026-06-08)
description: v34e bit + 物理换线后 panel 1 + panel 2 颜色完全同步 mirror, anime 显示通过, DCLK 37.5M (FCLK1=72M), 两 panel 横着拼接 mirror 状态 OK
type: project
created_at: 2026-06-08 15:30 CST
updated_at: 2026-06-08 19:55 CST
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
# v34e PL build (debug/fm6124-v29, commit 0aada63)

**Build 完成 Jun 5 20:09**:
- hub75e_panel_seq.v: module renamed v2 → v3, 加 hub75e_rgb_out2[5:0] output port (mirror panel 1)
- (* dont_touch = "true" *) 加在 rgb_out2 declaration, 防 synth merge 跟 rgb_out
- BD recreate (delete cell + delete IP cache + recreate with v3 ref)
- panel base 地址 0x40010000
- xdc 加 6 PACKAGE_PIN panel 2 SDI: AA19/AA13/Y13/AB15/AB14/Y16 (GPIO1 J1.13/31/32/33/34/30)
- bit: 02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit (Jun 5 20:08)
- xsa: hello_plat/hw/hello_zynq.xsa (Jun 5 20:09)

# Panel 2 wiring 设计表 (GRB swap 跟 panel 1 同款)

| panel 2 IDC | 标签 | 内部 chip | PL 信号 | Zynq pin | GPIO1 排针 |
|---:|---|---|---|---|---:|
| 1 | R1 | G | hub75e_rgb2[1] | AA13 | J1.31 |
| 2 | G1 | R | hub75e_rgb2[0] | AA19 | J1.13 |
| 3 | B1 | B | hub75e_rgb2[2] | Y13 | J1.32 |
| 5 | R2 | G | hub75e_rgb2[4] | AB14 | J1.34 |
| 6 | G2 | R | hub75e_rgb2[3] | AB15 | J1.33 |
| 7 | B2 | B | hub75e_rgb2[5] | Y16 | J1.30 |

panel 2 IDC 8-15 (E/A/B/C/D/CLK/LAT/OE) 共享 panel 1 同名 pin.

# 烧 v34e 流程 (2026-06-08 18:00 CST 已跑通)

1. `cmd.exe /c "taskkill /F /IM hw_server.exe"` (防止旧 hw_server 占 cable)
2. `xsdb tools/dl_minimal.tcl` — refresh_bit 已经把 v34e bit 同步到 vitis_ws/hello_plat/hw/sdt/, dow ELF + anime_points.bin 注入 + ARM con
3. `xsdb tools/test_solid_no_fb.tcl` — CTRL=0x501 (mode 0 SOLID, use_fb=0, no overlap) + COLOR=0x3F (pure RED)

读回: `CTRL 0x00000501`, `STATUS 0x01B8A101` ✅ PL 接收正常

# Mirror 实测结果 (panel 物理观察, 2026-06-08 18:00 CST)

- **Panel 1 (主): 全红** ✅ 按预期
- **Panel 2 (mirror): 一半蓝** ❌ 颜色错位

# CTRL bit 5 (use_fb) 注意

`use_fb=1` 时 panel 读 BRAM 不读 COLOR register. BRAM 没 init → 全 0 → 全黑. 验证 PL output 必须 **CTRL=0x501** 不要 0x561.

# 后续诊断方向

panel 2 显示蓝色 (chip "B" 亮) 而不是预期红色 (chip "G" 亮) — 怀疑 panel 2 SDI 物理 wiring 跟设计表对不上:
- 用户给的 wiring 表 R1 = AA13 = hub75e_rgb2[1] (mirror R), 但实际板上排线可能错位
- 或 PL synth 时 hub75e_rgb_out2 内部信号 routing 跟 mirror 假设不一致
- "一半蓝" 需要先问清楚是上半 (R1/G1/B1 三色组) 还是下半 (R2/G2/B2 三色组), 才能定位是 SDI[0:2] 还是 SDI[3:5] 错位

需要追加诊断:
1. 用万用表或示波器测 GPIO1 J1.13 (R1' AA19) / J1.31 (G1' AA13) / J1.32 (B1' Y13) 看 SOLID RED 时哪根高电平
2. 对比 panel 1 IDC 1/2/3 同位置 pin 信号
3. 如果 GPIO1 pin 信号对但 panel 显示错 = 排线接错; 如果 GPIO1 pin 信号本身不对 = PL hub75e_rgb_out2 routing 错

# 最终工作流 (2026-06-08 19:55 CST 调通)

1. `cmd.exe /c "taskkill /F /IM hw_server.exe"`
2. `xsdb tools/dl_minimal.tcl` (烧 v34e bit + dow ELF + anime 注入)
3. `xsdb tools/anime_load_v34e.tcl` (FCLK1=72M + 加 anime 到 panel BRAM + CTRL=0x561)
4. 两 panel 横着拼 = 同 anime 角色 × 2 mirror

# 最终接线 (panel 2 上下半 G/B 物理换位, panel 1 + panel 2 xdc 同款 GRB swap)

| panel 2 IDC | PL pin | GPIO1 排针 |
|---:|---|---:|
| 1 (R1) | AA19 | J1.13 |
| 3 (B1) | AA13 | J1.22 |  (G 信号到 B label, 因 panel 2 内部 BRG)
| 2 (G1) | Y13 | J1.21 |  (B 信号到 G label, 因 panel 2 内部 BRG)
| 5 (R2) | AB15 | J1.20 |
| 7 (B2) | AB14 | J1.19 |  (G2 信号到 B2 label)
| 6 (G2) | Y16 | J1.30 |  (B2 信号到 G2 label)

xdc 跟 panel 1 同 GRB swap 假设, 物理换线适配 panel 2 BRG 内部排布. 优点: 两 panel xdc 一致, 后续加 panel 3/4 只动 wiring.

# 路线图

Phase 1 ✅ MVP mirror 验证 wiring + PL (2026-06-08 完工)
Phase 2: 真 256×64 (panel 2 独立 BRAM + 扩 AXI segment 64K → 128K + ARM 写 fb 左右半各 128 列)
Phase 3: POV-3D 旋转 + 122 angle slice 切换 (anime_slices.bin 已生成)
