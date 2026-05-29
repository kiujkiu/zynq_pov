# HUB75E FM6124 panel Phase 1 bring-up

128×64 1/32 scan, FM6124 cascade, PL 端完整驱动, ARM 只切 mode.

分支: `feature/hub75e-fm6124-12864`. 旧 ICND1069 状态 stash 保存.

## 文件清单

| 文件 | 说明 |
|---|---|
| `02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v` | PL IP, 380 行, AXI-Lite + FSM + 8 test pattern |
| `02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc` | 14 个 GPIO1 引脚约束 |
| `02_hello_zynq/vitis_ws/hello_world/src/panel_hub75e.h` | ARM C API |
| `02_hello_zynq/vitis_ws/hello_world/src/hub75e_bringup.c` | ARM 测试入口 (循环 8 mode) |
| `02_hello_zynq/vitis_ws/hello_world/src/UserConfig.cmake` | 加 `ENABLE_HUB75E_TEST` 编译开关 |
| `tools/hub75e_bd_integrate.tcl` | Vivado BD 集成脚本 |

## 工作流

### 1. 接线 (你已经做)

14 信号 + 2 GND, 见之前对话表格. ADDR mode 接好后选:
- 普通 HUB75E panel (排针标 A/B/C/D/E) → `ENABLE_HUB75E_TEST=1` 默认 ABCDE OK
- multivox vortex panel (排针只 3 个 ADDR) → 改 `hub75e_bringup.c` 顶部 `HUB75E_USE_SHIFT_REG_ADDR=1`

### 2. PL: BD 集成

```bash
# WSL → Windows Vivado
cd /mnt/d/claude_workspace/pov3d/zynq_pov/02_hello_zynq
powershell.exe -Command 'cd D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq; & "D:\Xilinx\2024.2\Vivado\bin\vivado.bat" -mode batch -source ..\tools\hub75e_bd_integrate.tcl'
```

Tcl 做了:
- 删旧 `led_panel_seq_0` cell + 7 个 `panel_seq_*` 外部 port
- 加 `hub75e_panel_seq_0` (module_ref)
- 连 AXI-Lite → ps7_axi_periph 新 master port (base `0x40020000`)
- 暴露 5 个新 panel port: `hub75e_rgb[5:0]` / `dclk` / `lat` / `oe` / `addr[4:0]`
- 加 `hub75e_pins.xdc` 进 constraints
- 重生成 wrapper

⚠ Tcl 完后**手动操作**:
1. **Disable 旧 `led_pins.xdc`**: Sources panel 右键 → Disable (跟新 xdc 抢同 pin)
2. **PS7 FCLK_CLK1 改 120 MHz** (Block Design 双击 PS7 → Clock Configuration), 这样 DCLK = 30 MHz. 暂不改也行, FCLK_CLK0 100 MHz → DCLK 25 MHz, FM6124 更稳.

然后 **Generate Bitstream** + **Export Hardware (Include bitstream)** → 出 `.xsa`.

### 3. Vitis: BSP + ELF rebuild

```
hello_plat → Regenerate
hello_world → Clean → Build
```

`UserConfig.cmake` 改:
```cmake
"ENABLE_HUB75E_TEST=1"
```

### 4. 板端跑

```bash
# WSL
cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\vitis_ws && dl_helloworld.tcl"
```

串口 (COM4 @ 921600) 看到:
```
[hub75e] === Phase 1 bring-up @ 0x40020000 ===
[hub75e] target: FM6124 128x64 1/32 scan, DCLK=30 MHz
[hub75e] ADDR mode: ABCDE 5-bit
[hub75e] phase A: solid colors
[hub75e]  solid 0: COLOR=0x09 (R1G1B1=100 R2G2B2=100) frame=N
... 6 solid colors, 3s each
[hub75e] phase B: built-in patterns
[hub75e]  mode 1 (HSTRIPE 8 color) ...
... 7 patterns, 3s each
[hub75e] done. holding FULL WHITE. STATUS poll every 5s.
```

肉眼应看到:
- 18 秒红/绿/蓝/白/顶红底蓝/顶绿底红 单色全屏
- 21 秒 8 色横条 / 竖条 / 棋盘 / 单行扫描动画 / 单列扫描动画 / 渐变 / 全白
- 最终停在全白烤机

### 5. 不亮 / 异常排查

| 症状 | 排查 |
|---|---|
| 全屏不亮 | (a) panel 5V 电源到位? GND 共地? (b) 串口看 `STATUS running=1`? (c) 万用表 OE 引脚电平: 应为 0V 显示中 |
| 只闪一条横线 | ADDR 没扫起来. 试 mode 4 ROW_WALK 看走没走 |
| 颜色错位 (R 显示绿) | RGB 接错. 看 mode 0 6 种 solid 颜色对应是否一致 |
| 整片亮但只显示一种花纹 | DCLK 跑了, ADDR 没动. 检查 W18/W17/W16/AB19/AA18 5 根接线 |
| 闪烁明显 | 刷新率不够, 调 `DISP_CYCLES` 参数往下减 |
| panel 部分行不亮 | shift register ADDR mode 的 panel 没正确选 mode. 改 `HUB75E_USE_SHIFT_REG_ADDR=1` 重 build |

### 6. 寄存器手动调试 (xsdb)

```tcl
# xsdb 连上板子
mwr 0x40020004 0x09   # COLOR R1=1 R2=1 (顶底全红)
mwr 0x40020000 0x01   # CTRL: enable + mode 0 (solid)
mrd 0x4002000C 1      # STATUS frame_count
```

## Phase 2 预告

Phase 1 跑通后:
- 拆 daisy → 48 SDI (panel PCB 飞线)
- 加 BCM 8-bit 灰度
- 加 framebuffer (BRAM 或 m_axi DDR 读)
- 跨 BANK 33 + 35 走 56 IO

详见 `MEMORY.md` → `project_multivox_zynq_port.md`.
