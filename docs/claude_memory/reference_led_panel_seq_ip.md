---
name: led_panel_seq PL IP 接口
description: 0x40010000 PL IP, AXI-Lite slave. 3 modes (word/marker_LE/marker_ROW) + 16-bit burst counter. driving DCLK/LE/ROW/SDI×9 panel signals
type: reference
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
PL 端 led_panel_seq IP, 解决 ARM bit-bang DCLK 1.67 MHz 跑不动 chip 4 MHz min DCLK 的问题. 跑在 FCLK_CLK1 = 75 MHz (实测 sysclk ~83 MHz), DCLK_DIV=10 → DCLK = 7.5-8.3 MHz.

**Register map** (base 0x40010000):
- `0x00 CMD` (W trigger, R status):
  - `[15:0]` data word (MSB first shift)
  - `[20:16]` le_count (0..31)
  - `[25:24]` mode: `00`=word (16 DCLK shift, LE 高在最后 le_count 个), `01`=marker_LE (le_count 个 DCLK, LE 高), `10`=marker_ROW (le_count 个 DCLK, ROW 高), `11`=reserved
  - R: `[0]` = busy
- `0x04 BURST` (W): repeat_count for next CMD write (PL 自己再发 N 次), 写完 CMD 自动清零

**C API** (`panel_seq.h`):
- `panel_seq_word(u16 data, u8 le_count)` — 16 DCLK shift, LE 高最后 N
- `panel_seq_marker(u8 le_count)` — N DCLK + LE 高 (用于 PRE_ACT/EN_OP/VSYNC 等 LE 命令)
- `panel_seq_row_pulse(u8 n_dclks)` — N DCLK + ROW 高 (用于 ICND1069 行 marker, 12 = 第1行 / 4 = 后续行)
- `panel_seq_burst_word(u16 data, u8 le_count, u16 n_extra)` — PL 重发 n_extra+1 次, 消 ARM AXI 抖动
- `panel_seq_dclk_keepalive(int n_dclks)` — burst 包装版, 让 PL 持续跑 DCLK 不停 (chip PLL 不失锁)
- `panel_seq_wait_idle()` — 阻塞读 busy

**Pin map** (XDC `led_pins.xdc`):
- Y18 = DCLK (panel_seq_dclk)
- Y19 = LE (panel_seq_le)
- AA19 = ROW (panel_seq_row)
- AA22/AB22/AA21/AB21/Y20/Y21/AB19/AA18/AB20 = SDI[0..8] = R1/G1/B1/R2/G2/B2/R3/G3/B3

**Verilog** (单文件 module_ref, 不是 packaged IP): `02_hello_zynq.srcs/sources_1/imports/hdl/led_panel_seq.v`

**改 IP 端口流程**: 见 feedback_vivado_bd_module_ref_update.md (手动改 xci JSON)
