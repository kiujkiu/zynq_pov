---
name: POV3D v34g Phase 2 dual BRAM (128×128 拼接)
description: v34e mirror MVP → v34g Phase 2: panel 2 独立 BRAM, 两 panel 竖拼显示完整 128×128 anime
type: project
created_at: 2026-06-08 20:10 CST
updated_at: 2026-06-08 20:10 CST
originSessionId: c65586d5-1bd7-42fb-bf7e-7a8b7f63582c
---
# 设计

两 panel 竖着拼 128×128:
- panel 1 (上): image rows 0-63
- panel 2 (下): image rows 64-127

每个 panel 内部上下半 mux 复用:
- panel 1 fb_top (BRAM): image rows 0-31
- panel 1 fb_bot (BRAM): image rows 32-63
- panel 2 fb_top (BRAM): image rows 64-95
- panel 2 fb_bot (BRAM): image rows 96-127

总 4 个 16KB BRAM, 共 64KB.

# PL 改动 (v3 → v4)

hub75e_panel_seq.v 改:
- module rename `hub75e_panel_seq_v3` → `hub75e_panel_seq_v4`
- `s_axi_awaddr/araddr` 16-bit → 17-bit, `cur_aw_addr/aw_addr_q` 同步
- 加 `u_fb_top2` + `u_fb_bot2` XPM SDPRAM (跟 v3 同模板, 16KB each)
- 加 `fb_top2_we_main` / `fb_bot2_we_main` write enable, decode `cur_aw_addr[16]`
  - addr[16]=0 + [15]=1 + [14]=0/1: panel 1 fb_top/fb_bot
  - addr[16]=1 + [15]=1 + [14]=0/1: panel 2 fb_top/fb_bot
- 加 `pattern_24_top2/bot2`, `r1_bit2/g1_bit2/.../b2_bit2`, `plane_rgb2`
- `hub75e_rgb_out2 <= plane_rgb2` (替换 plane_rgb, 让 panel 2 独立数据源)

BD 改:
- AXI ADDR_WIDTH 16 → 17 (3 处 xci/bd.json/bd.bd)
- `SEG_hub75e_panel_seq_0_reg0` range 64K → 128K
- module_ref vlnv hub75e_panel_seq_v3 → hub75e_panel_seq_v4 (rename, 跟 memory feedback 一致)
- 删 IP cache + .gen/ ip/hdl/synth/sim 强制 regen

# 地址 map (v34g, base 改到 0x40020000)

128K 地址段需要 128K 对齐, 0x40010000 不对齐, base 改 0x40020000:

| Region | Addr | Size |
|---|---|---|
| 控制 reg | 0x40020000-0x4002001F | 32B |
| panel 1 fb_bot | 0x40028000 | 16K |
| panel 1 fb_top | 0x4002C000 | 16K |
| panel 2 fb_bot | 0x40038000 | 16K (bit[16]=1) |
| panel 2 fb_top | 0x4003C000 | 16K (bit[16]=1) |

**注意**: 老 v34e 脚本仍用 0x40010000, 跟 v34g 不兼容. 用 v34g 必须切 anime_load_v34g_phase2.tcl.

# 工具

- `tools/anime_to_fb_128x128.py` — 生成 128×128 anime → 4 个 fb_anime_128_{top1,bot1,top2,bot2}.bin
- `tools/anime_load_v34g_phase2.tcl` — xsdb 加 4 BRAM + FCLK1=72M + CTRL=0x561
- `tools/build_v34g_phase2.tcl` — Vivado batch build (regen BD + reset synth/impl + write xsa)

# 状态 (2026-06-08 20:10 CST)

- ✅ Verilog edits done
- ✅ BD edits done
- ✅ IP cache 清掉
- ✅ Anime bin 4 个生成 (各 16KB)
- ✅ Load tcl 写好
- 🚧 Vivado batch build 跑 (background, ~30 min, agent will notify)

# 启动流程 (build 完后)

1. `cmd.exe /c "taskkill /F /IM hw_server.exe"`
2. `bash tools/refresh_bit.sh 02_hello_zynq` 同步 v34g bit 到 vitis_ws
3. `xsdb tools/dl_minimal.tcl` (烧 v34g bit + dow ELF)
4. `xsdb tools/anime_load_v34g_phase2.tcl` (加 4 BRAM + FCLK1=72M + CTRL=0x561)
5. 验: panel 1 显示 anime 上半, panel 2 显示下半, 竖拼成完整 128×128

# 风险

- 删 IP cache 后 BD regen 可能报错 (DRC fail, parameter mismatch) → 需要在 Vivado batch 里 fix
- xparameters.h 里 panel base/range 改, ELF 可能要重 build (但寄存器地址不变, 只 BRAM 写区域改)
- ARM `dl_minimal.tcl` 注 anime_points.bin 到 0x1A000000, 这是 HDMI path, 跟 panel 不冲突
