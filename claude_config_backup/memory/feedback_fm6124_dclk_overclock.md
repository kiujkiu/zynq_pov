---
name: FM6124 DCLK 超 spec 25% 实测稳 (37.5 MHz vs spec 30 MHz)
description: FM6124 datasheet max DCLK 30 MHz, 实测 37.5 MHz panel 显示完全稳定, BCM 6-bit + overlap 跑到 890 fps
type: feedback
originSessionId: cddd55be-5600-43d2-9b26-a291ffc28846
---
FM6124 datasheet 标 DCLK max 30 MHz (TWCLK ≥ 20 ns). 实测把 DCLK_DIV 从 4 改 2 (75 MHz aclk / 2 = **37.5 MHz DCLK**), 超 spec 25%, panel 显示完全稳定:
- grid demo 0-31 数字清晰
- R→G→B 渐变保留 BCM 权重
- 长时间运行无掉色/抖动/闪烁

**为啥能超**: 实际 panel chip 有时序余量 (TWCLK spec ≥20ns 是 worst-case 保证), 加上 LED panel 输出端没数据采样要求 (cascade 内部直接 SR 链接). 厂家 spec 30 MHz 大概率是工业品保守值.

**性能提升 (vs spec 内 18.75 MHz)**:
- SERIAL: 462 → 659 fps (+43%)
- OVERLAP+OE_PRE: 645 → **890 fps** (+38%)

**风险评估**:
- 短期: 实测稳, 用着没事
- 长期: 不同温度/电压下 timing margin 可能变, 极端条件下可能 corrupted shift
- 工业批量产品不推荐, 个人项目/原型 OK

**比较 spec-compliant 方案**:
- MMCM aclk 60M + DCLK_DIV=2 → DCLK = 30 MHz spec 内 (~860 fps 估算, 略低)
- MMCM aclk 120M + DCLK_DIV=4 → DCLK = 30 MHz spec 内 (~860 fps)
- 都需要加 MMCM IP + axi_clock_converter, BD 复杂度增加

**How to apply**: 改 DCLK 频率不要只改 verilog parameter:
1. 改 verilog `parameter integer DCLK_DIV = X`
2. 改 BD xci 文件: `sed -i 's/"DCLK_DIV": \[ { "value": "4"/"DCLK_DIV": [ { "value": "2"/g'`
3. **删 IP gen + mref dir** (`rm -rf .gen/.../ip/hello_zynq_hub75e_panel_seq_0_3 .gen/.../mref/hub75e_panel_seq_v2`)
4. Build 用 `hub75e_force_regen.tcl` (有 `reset_target all + generate_target -force all`)
5. 不删 gen + 不 reset_target → wrapper 用旧值 = synth 还是按旧 DCLK_DIV bind (踩坑确认: 普通 hub75e_bcm_build.tcl 改 xci 后 synth 仍 bind 旧值)

**验证步骤**: 看 `02_hello_zynq.runs/synth_1/runme.log` 里的 `Parameter DCLK_DIV bound to: X`, 跟期望对一致才算改成. 跟 `02_hello_zynq.gen/.../ip/hello_zynq_hub75e_panel_seq_0_3/sim/...v` 里的 `.DCLK_DIV(X)` 也要对.
