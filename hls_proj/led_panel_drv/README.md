# led_panel_drv -- POV-3D LED panel driver IP

Verilog hardware driver IP that pushes RGB frame data into the POV-3D LED
panel each angular slice. Takes the panel-side electrical protocol off the
PS so the slice cadence (720 angle x 30 Hz = 21 600 slice/s, **46 us/slice**)
is met deterministically.

## 1. Files

| file                   | purpose                                                  |
|------------------------|----------------------------------------------------------|
| led_panel_drv.v        | top module: AXI-Lite + AXI-Stream + 4-chain shift FSM    |
| led_panel_drv_tb.v     | self-checking testbench (timing assertions)              |
| run_sim.tcl            | xsim batch tcl                                           |
| run_sim.bat            | one-shot xvlog/xelab/xsim wrapper for Windows            |

## 2. Panel target

* 160 x 180 RGB pixels
* Row driver  : ICND3019 x 24 cascade (16ch x 24 = 384 row signals)
* Col driver  : ICND1069 x 108 = **4 chain x 27 cascade**, 4 parallel SDI
* DCLK        : <= 25 MHz (panel limit)
* Per-channel : 16-bit PWM intensity (panel internal 96 MHz GCLK PLL)

The panel is split into four 80 x 90 quadrants, each fed by one SDI lane;
the row-scan driver advances rows in lock-step with all four chains.

## 3. AXI-Lite register map

| addr | name        | r/w | bits  | meaning                                       |
|------|-------------|-----|-------|-----------------------------------------------|
| 0x00 | CTRL        | rw  | [0]   | enable                                         |
|      |             |     | [1]   | soft_reset                                     |
|      |             |     | [2]   | loop_mode (auto re-trigger after frame_done)   |
| 0x04 | STATUS      | rw  | [0]   | busy (RO)                                      |
|      |             | w1c | [1]   | frame_done (write 1 to clear)                  |
|      |             | rw  | [2]   | cfg_done                                       |
| 0x10 | FRAME_ADDR  | rw  | 32    | reserved (DMA pointer if external)             |
| 0x14 | TRIGGER     | wo  | [0]   | write 1 -> kick one slice                      |
| 0x18 | STATUS2     | ro  | 32    | alias of STATUS                                |
| 0x20 | CFG         | rw  | [7:0] | scan_ratio (rows per slice, default 90)        |
|      |             |     | [15:8]| pwm_bits   (1..16, default 8)                  |
|      |             |     |[31:16]| brightness gain (Q1.15)                        |
| 0x24 | LE_CMD0     | rw  | [7:0] | DCLK count for DATA_WRITE LE pulse (default 1) |
| 0x28 | LE_CMD1     | rw  | [7:0] | DCLK count for CFG1 LE pulse (default 3)       |
|      |             |     | [15:8]| DCLK count for CFG2 LE pulse                   |

Trigger is sticky : the FSM consumes the request the next time it's idle,
so writes are not lost across cfg-init.

## 4. AXI-Stream ingress

`s_axis_fb` accepts one 24-bit RGB pixel per beat (in low 24 bits of a
32-bit word, layout `{8'h00, R[7:0], G[7:0], B[7:0]}`).
PIXEL_W * PIXEL_H beats followed by `tlast=1` writes one full frame.
The DUT keeps `tready` always asserted post-reset; the host pre-loads the
next frame while a slice transmits.

## 5. State machine

```
                  +----------+
       reset ---> |  IDLE    | <----------------------------+
                  +----------+                              |
                       | first time after reset             |
                       v                                    |
                  +----------+ for each cfg seq entry       |
                  | CFG_GO   |---> CFG_LE  ---+             |
                  +----------+                |             |
                       ^----------------------+             |
                       | done -> cfg_done                   |
                       v                                    |
                  +----------+   trig_request               |
                  |  IDLE    |---------------+              |
                  +----------+               |              |
                                             v              |
                                      +-------------+       |
                                      |   LOAD      |       |
                                      +-------------+       |
                                             |              |
                                             v              |
                          +---->  +-------------+           |
                          |       |   SHIFT     |  4 SDI    |
                          |       +-------------+           |
                          |              | end of row       |
                          |              v                  |
                          |       +-------------+           |
                          |       |  LE_HI      |  twLE     |
                          |       +-------------+           |
                          |              |                  |
                          |              v                  |
                          |       +-------------+           |
                          |       |  ROW_HI     |  twROW    |
                          |       +-------------+           |
                          |              |                  |
                          |              v                  |
                          |       +-------------+           |
                          |       |  NEXT_R     |           |
                          |       +-------------+           |
                          |        | not last |             |
                          +--------+          v last        |
                                      +-------------+       |
                                      |   DONE      |-------+
                                      +-------------+
```

Each FSM step advances by one **dclk_tick** (one rising edge of the 25 MHz
DCLK). All ICND1069 / ICND3019 timing constraints are derived from this.

## 6. 4-chain quadrant mapping

```
       0...79   80...159
      +--------+--------+
   0  |chain 0 |chain 1 |   each 80 x 90 quadrant
   .. |        |        |   served by one SDI lane
   89 |        |        |
      +--------+--------+
   90 |chain 2 |chain 3 |
   .. |        |        |
  179 |        |        |
      +--------+--------+
```

Within a chain, lane = chip*16 + ch maps to (col, comp) by
`col = lane / 3 ; comp = lane % 3` (R=0, G=1, B=2). With 27 cascade chips
each chain has 432 lanes, of which 80*3 = 240 are pixels; the remaining
192 lanes carry zeros (datasheet permits unused channels at 0).

## 7. LE-encoded commands

ICND1069 differentiates writes by the number of DCLK cycles LE is held
high. The IP exposes the lengths via `LE_CMD0` / `LE_CMD1` so the operator
can match the lot-specific table in the connector handoff:

| LE high cycles | meaning                         |
|----------------|---------------------------------|
| 1              | DATA_WRITE (latch payload)      |
| 2              | soft RESET                      |
| 3              | WRITE_CFG1 (gain / scan ratio)  |
| 4              | WRITE_CFG2 (PWM depth, blank)   |
| 5              | WRITE_CFG3 (vendor specific)    |

After reset the FSM walks `CFG_SEQ_LEN` cfg writes once (currently issues
length-3 then length-3 again with zero data; final cfg is a TODO).

## 8. Timing budget vs 46 us slice

| pwm_bits | row shift = 27*16*pwm_bits / 25 MHz | full slice (90 row) |
|----------|--------------------------------------|----------------------|
| 16       | 276.5 us                             | 24.9 ms              |
| 8        | 138.2 us                             | 12.4 ms              |
| 6        | 103.7 us                             | 9.3  ms              |
| 4        |  69.1 us                             | 6.2  ms              |

None of these hit the **46 us slice budget** by themselves. POV-3D therefore
relies on:

1. **Panel-internal PWM** (96 MHz GCLK): the FPGA delivers low-bit-depth
   intensity codes; the panel's own 16-bit PWM PLL handles sub-frame
   dithering. Effective FPS to the panel >= 21 600.
2. **Multi-slice update** : one FPGA "slice" updates a fraction of rows
   (`scan_ratio` is the number of rows shipped per trigger). The remaining
   rows hold their last values, exploiting the human eye's POV blur.
   Default `scan_ratio = 90` is a placeholder until panel testing.
3. **Two-bank ping-pong** (TODO): while shifting bank A, AXIS fills bank B,
   so frame compose latency is hidden behind shift latency.

These knobs are exposed via `CFG`. Final tuning waits until panel boards
arrive and connector pinout is confirmed.

## 9. Resource estimate (lint-level, before P&R)

| resource          | usage                                        |
|-------------------|----------------------------------------------|
| BRAM18            | ~12 (frame buffer 28800 x 24 bit = 691 kbit) |
| LUT               | ~ 800   (FSM + 4 shift logic + AXI-Lite)     |
| FF                | ~ 600   (regs)                               |
| DSP               | 0                                            |
| fmax (estimate)   | > 200 MHz at 100 MHz aclk                    |

## 10. Testbench results (xsim 2024.2)

Scaled-down panel (`PANEL_W=16 PANEL_H=18 CHIPS_PER_CHAIN=4
DEFAULT_SCAN_RATIO=4 DEFAULT_PWM_BITS=8`) runs in ~85 us sim time:

```
[PASS] CFG readback
[PASS] DCLK period >= 40 ns (twCLK)
[PASS] twLE >= 10 ns
[PASS] twROW >= 160 ns
[PASS] tb slice within sanity window
========== ALL 4 ASSERTIONS PASSED ==========
```

Measurements:

| signal     | value          |
|------------|----------------|
| DCLK period| 40.00 ns       |
| twLE (min) | 80.00 ns       |
| twROW (min)| 160.00 ns      |
| slice time | 83.31 us       |

## 11. Build / sim

```bat
cd hls_proj\led_panel_drv
run_sim.bat
```

Or manually:

```bat
xvlog led_panel_drv.v led_panel_drv_tb.v
xelab -debug typical led_panel_drv_tb -s led_panel_drv_sim
xsim led_panel_drv_sim -tclbatch run_sim.tcl -log xsim.log
```

Pure RTL with no Xilinx primitives. Should also run under iverilog /
verilator without modification.

## 12. TODO (post-panel-arrival)

* Confirm 4-chain physical pinout mapping (which chain serves which quadrant).
* Capture real ICND1069 cfg seq from panel vendor; populate `CFG_SEQ_LEN`
  and `LE_CMD*` registers, then bake into firmware init.
* Tune `scan_ratio` after measuring panel internal-PWM refresh stability.
* Add ping-pong frame buffer (currently single, ingest must finish before
  trigger).
* Wire a real DMA path (FRAME_ADDR -> AXI-master read) to bypass AXIS for
  zero-copy from PS DDR.
* Synthesise into the BD once HDMI pipeline + connector are confirmed.
* Replace `for (ci=...)` style task call with a generate-block pre-load
  pipeline once chain count is final.
* Add CRC monitor on returning SDO from each chain (not yet routed).
