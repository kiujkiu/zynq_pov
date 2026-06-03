---
name: HUB75E FM6124 panel + v28 overlap+OE_PRE (2026-06-02)
description: 128×64 1/32 scan HUB75E, v28 runtime overlap_en 切换 serial (462 fps) vs overlap+OE_PRE (645 fps, +39%), BCM 6-bit 都保留, CTRL[6] runtime 切换
type: project
originSessionId: 37686ade-ae15-4bcf-a387-f01c094bd546
---
**分支**: `feature/hub75e-fm6124-12864` (zynq_pov 项目), HEAD = 9e697f0 "HUB75E v28: runtime overlap_en + OE_PRE delay"

## 硬件状态

- **Panel**: 128×64 由 **两块 128×32 物理拼接**, FM6124 cascade 8 颗 × 6 chain
- **物理拼接顺序反**: fb_top.bin (panel.0..31) → 写到 0x4002C000 (fb_bot bank)
  fb_bot.bin (panel.32..63) → 写到 0x40028000 (fb_top bank)
- **panel 厂家是 GRB 顺序**: panel.1=G chip, panel.2=R chip, panel.3=B chip (xdc R/G swap 修复)
- **接线**: 14 IO 全在 Zynq GPIO1 (BANK 33)
- **R >> G >> B** 亮度差 (FM6124 + LED 厂家特性), 单点 R 摄像头白爆
- **DCLK 实测**: DSLogic 测 19.23 MHz (75M aclk / DCLK_DIV=4, 理论 18.75 实测 +2.5% 余量)

## PL IP 状态 (v28, 2026-06-02)

- **File**: `02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v`
- **Module**: `hub75e_panel_seq_v2`
- **AXI base**: 0x4002_0000, range 64 KB (reg + 32K fb_top + 32K fb_bot)
- **CTRL**: [0]=en [3:1]=mode [4]=addr_sr [5]=use_fb **[6]=overlap_en** [12:8]=addr_bits
- **TUNIT (0x14)**: BCM T_unit cycles, 默认 8
- **BCM_PLANES**: 6 (默认 6-bit, 64 灰阶)
- **STATUS (0x0C)**: `{frame_count[15:0], plane[2:0], row_displayed[4:0], 7'b0, running}` ✓ frame_count 在 [31:16]
- **OE_PRE_CYC**: 8 cycles (107ns @ 75MHz), FM6124 OE-fall 缓存 setup time
- **BRAM**: 2 × xpm_memory_sdpram, 4Kx24, port-A AXI write port-B PL FSM read

## FSM 双路径 (v28)

CTRL[6]=overlap_en runtime 切换 (SR 模式 addr_mode_sr=1 始终走 serial):

**Serial path (CTRL[6]=0)**: 标准 HUB75
```
IDLE → SHIFT (128 col) → BLANK → LATCH → ADDR_ABCDE → DISPLAY (OE 低, TUNIT<<plane cyc)
     ↑                                                       ↓
     └───────── plane++/row++ ──────────────────────────────┘
```

**Overlap path (CTRL[6]=1)**: shift-while-display + OE_PRE 延迟
```
IDLE → SHIFT (初始 prime SR) → BLANK → LATCH (advance plane/row+snap disp_*)
                                              ↓
                                       ADDR_ABCDE (set ABCDE addr)
                                              ↓
                                       S_OE_PRE (drop OE, wait 8 cyc, NO DCLK)
                                              ↓
                                       S_PHASE (shift NEXT plane + display CURRENT plane 并行)
                                              ↓ 两者都完
                                       BLANK → LATCH → ADDR → OE_PRE → PHASE → ...
```

**关键**: OE_PRE 等 8 cycle 让 FM6124DJ 在 OE 下降沿缓存 SR 进 display latch. 之前 v27 没这个 delay → OE 跟 DCLK 同 clock 启动 → 缓存 setup time 不够 → BCM 塌. v28 加 delay → 解决.

## 实测性能 (2026-06-02 frame_count delta)

@ TUNIT=32, DCLK_DIV=4 (18.75 MHz spec 内):
| 模式 | fps |
|---|---|
| SERIAL  | 462 |
| OVERLAP | 645 |

@ TUNIT=8 sweet spot, DCLK_DIV=2 (DCLK=37.5MHz 超 spec 25%, FCLK1=75M):
| 模式 | fps |
|---|---|
| SERIAL  | **1122** |
| **OVERLAP** | **1424** |

@ TUNIT=8 sweet spot, DCLK_DIV=2 (DCLK=30MHz spec 内, FCLK1=60M):
| 模式 | fps |
|---|---|
| SERIAL  | 902 |
| OVERLAP | 1149 |

**当前 commit `ba34f62` 跑 75M FCLK1**: OVERLAP 1424 fps @ 6-bit BCM. 超 FM6124 datasheet spec 30 MHz 上限 25%, 实测 panel 完全稳定显示, 无掉色/抖动.

视觉对比: serial 跟 overlap mode grid 0-31 数字 + R→G→B 渐变完全一致, BCM 权重保留.

## ⚠ Mode 切换注意

CTRL[6] runtime 切换有 FSM 过渡态问题: serial 跟 overlap 路径里 plane/row advance 时机不同 (serial 在 DISPLAY, overlap 在 LATCH), 直接切会 latch 出错乱 pattern. **必须**:

```tcl
mwr 0x40020000 0   # disable, 让 FSM drain 到 IDLE
after 300
mwr 0x40020000 $new_ctrl   # 写新 CTRL (含新 overlap_en)
```

见 `tools/clean_grid.tcl`.

## Grid demo 验证 (2026-06-02)

- `tools/gen_grid_fb.py` 生成 fb_top.bin + fb_bot.bin (16KB each)
- `mwr -bin -file` 一次性写 fb BRAM
- TUNIT=32, CTRL=0x521 / 0x561
- 实拍 8×4 grid 32 cells, 数字 0-31 全清晰, R→G→B 渐变色按 cell_idx 排序 ✓

## v27 → v28 关键 diff

v27 (废弃): S_PHASE 直接 overlap, OE 跟 DCLK 同 clock 启 → BCM 塌
v28 (current):
1. 加 CTRL[6]=overlap_en runtime 切换
2. 加 S_OE_PRE state (4'd7) 跟 S_PHASE state (4'd8)
3. S_LATCH overlap 分支 advance plane/row + snapshot disp_row/disp_plane
4. S_ADDR_ABCDE → overlap 时跳 OE_PRE (不是 DISPLAY)
5. OE_PRE_CYC=8 cyc parameter
6. STATUS [31:16] 加 frame_count (之前漏接)

## ARM API (panel_hub75e.h, 暂未更新)

- `hub75e_init/enable/set_mode/set_color/set_tunit/set_color_bot`
- `hub75e_fb_set(x, y, rgb24)`, `hub75e_fb_fill(rgb24)`, `hub75e_use_fb(int)`
- `hub75e_frame_count()` 读 STATUS [31:16] ✓
- ⚠ overlap_en 切换需要 disable→wait→enable 流程, C 端需加 helper
- AXI 读 fb 地址永远返回 0 (verilog 第 192 行), debug 时别想 mrd fb 验证写入

## 工具 (tools/)

**Build**:
- `hub75e_bcm_build.tcl`: PL IP 改 only, BD 不动 synth+impl+xsa
- `refresh_bit.sh`: xsa 提 bit 拷到 vitis_ws (**必须先 cp xsa**, 见 feedback_refresh_bit_stale_xsa.md)

**Download + setup**:
- `dl_v28.tcl`: rst -system + dl bit + ps7_init
- `dl_serial_grid.tcl`: dl + 加载 grid fb + serial mode + 测 fps
- `clean_grid.tcl <ctrl>`: clean disable + 加载 grid fb + 写新 CTRL (serial 或 overlap)
- `clean_serial.tcl`: clean disable + mode 0 SOLID 0x3F3F3F serial

**测试**:
- `set_solid_v28.tcl <TUNIT> <RGB> <overlap_en>`: 单帧 SOLID 测试
- `bcm_ab_v28.py`: BCM 权重 sweep A/B (serial vs overlap), 噪声大不如视觉好用
- `grid_ab_v28.py`: 视觉 grid A/B, 更可靠
- `fps_ab.tcl`: 双模式 fps 对比测量 (frame_count delta)
- `dump_regs.tcl`: 读所有 PL reg
- `full_off.tcl`: panel 真黑 (CTRL=0 + COLOR=0 + ARM halt)
- `check_fb.tcl`: 重 load fb + 切 overlap mode

**Camera capture**:
- `cap_panel.py`: ffmpeg dshow icspring (USB external cam, low exp 控制差)
- `cap_any.py <exp>`: cv2 ANY backend idx 0 (laptop builtin, exp -8 到 -10 好用)
- `cap_panel_exp.py`: cv2 DSHOW + 锁曝光

⚠ 摄像头被 OBS / 应用占用时 ffmpeg dshow 直连会 fail, 用 cv2 ANY backend 绕开

## 升级路径 (排队)

按 ROI 排:
1. ✅ **DCLK 37.5 MHz (DCLK_DIV=2)**: 已完成. 超 spec 25% 实测稳, fps +38-43%
2. **8-bit BCM**: BCM_PLANES 6→8, 色深 64→256 灰阶, fps 降 ~40%
3. **MMCM 120M aclk + DCLK_DIV=4**: 精确 30 MHz spec 内 (vs 当前 37.5 MHz 超频), 速度跟现在差不多但更稳
4. **HDMI 桥/POV-3D 数据源**: 把 HDMI VDMA → fb 或 HLS slice → fb, 不再静态 fb
5. **多 panel 拼接**: 物理 chain 第二块, PANEL_WIDTH 改

## 教训

- panel pin 标签别信, sweep 单点亮各通道验
- panel 两块拼接顺序可能反, fb top/bot bank swap 修复
- 摄像头过曝: 降 TUNIT 或降 exposure (-10 = 1ms)
- mode 1/2 的 `idx / stripe_w` 除法器是 timing 隐性炸弹, 改成固定 shift 解决
- **HUB75E shift-while-display overlap 可以做**, 但**必须**给芯片 OE-fall setup time (≥100ns)
- **runtime mode 切换需要 clean disable**, 否则 FSM 过渡态出乱图
- panel 真关闭需要 CTRL=0 + COLOR=0 + ARM halt 三个都做
- AXI 读 fb 地址固定返回 0, 验证 fb 写要走显示, 不能 mrd
