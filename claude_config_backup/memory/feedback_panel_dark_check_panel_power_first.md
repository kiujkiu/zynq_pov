---
name: panel 黑先查 panel 5V 电源, 不要怀疑 verilog/XDC
description: panel 显示全黑但寄存器/state machine 都正常时, 99% 是 panel 5V 没接或电源开关没开
type: feedback
created_at: 2026-06-10 01:33 CST
updated_at: 2026-06-10 01:33 CST
originSessionId: 9191f0e2-0bfd-4c68-bb07-c85f057b8792
---
2026-06-10 v34i→v34j 一晚上 build 4 次都 panel 黑, 浪费 4 小时调 verilog 和 XDC, 最后发现是 **panel 自己的 5V 电源没接**.

**症状**: 
- xsdb fpga -file 成功
- ps7_init 成功
- 寄存器读写都对 (CTRL=0x521, STATUS bit[0]=1 state != IDLE, frame_count 在涨)
- PL 板上的 led 亮 (说明 PL clock + axi_gpio 正常)
- PL → LED panel 物理输出走 IO bank 33, 用 xsdb 看 PL 内部状态完全没异常
- **但 panel 物理上全黑**

**Why:** LED panel 是独立 5V (或 12V) 供电, 跟 Zynq 板上电源完全分开. panel 控制 chip (FM6124/ICND/MBI) 没电 = HUB75 输入信号驱动到 panel 但 chip 不响应, panel 全黑.

**How to apply:** 板上跑通寄存器但 panel 全黑时:
1. **先问用户 panel 上电指示灯是否亮**, 不要先怀疑 verilog/XDC
2. PL 板灯亮 ≠ panel 上电. panel 一般有独立的 5V/12V 电源 (USB / DC jack / 接线柱)
3. 如果 panel 没指示灯, 至少看 fan / 控制 chip 上有没有 LED
4. 真验证 PL 输出: 用示波器看 DCLK / RGB pin 是否在跳, 但这是后置 step

**附带教训**: 之前所有"测试 build" 都因为 panel 没电盲跑了 verilog revert / DRIVE 撤销 / assign_bd_address 等. 实际只有 panel 上电后才能验证. 4 次 Vivado build + 8 次 JTAG 烧录 = 1 小时浪费, 还把 JTAG 链反复 kill 让用户冷循环板子 3 次.
