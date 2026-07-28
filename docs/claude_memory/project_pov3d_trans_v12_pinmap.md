---
name: 转接板 v1.2 引脚重映射 (2026-07-27, 已上板验证)
description: 屏侧转接板换 v1.2 后 P1 侧整体重排 → 19 个 FPGA ball 纯置换; 屏侧 J1 与电源脚均未变; 新表已上板点亮
type: project
---
屏侧转接板从 v1.1 换到 **v1.2**（图纸 `D:\工程项目\硬件\pov\zynq-mlp_pV1.2\SCH\LKS_FOC.pdf`，
sheet 名沿用了电机板，内容才是转接板：J1 40pin ↔ P1 30pin + 双 TPS565201 出 3.8/2.8V）。

## 变更性质：只有 P1 侧重排

三块板网表逐 pin 交叉核对的结论：
- **屏侧 J1 的 19 个信号脚，新旧完全一致**（一根没动）
- **电源脚也一致**：`VCC_3V8→J1.35-40` / `VCC_2V8→J1.17-20` / `GND→J1.1-6,21-24,41,42`
- 变的只有 **P1（30pin，接米联派那一侧）整体重排**
- 净效果 = **19 个 ball 的纯置换**：不新增引脚、不换 bank、RTL 端口名不变 → 除 XDC 外全设计零改动

用户的等价说法：「相当于把米联派 P1/P3 的线序换成新屏板那张」——两种说法算出同一组 ball。

## 新 ball（屏1；屏2 `_2` 组套用同一置换，见 led_panel_chain.md）

DCLK **Y10**(旧AB4) / LAT **AA9**(AB5) / GCLK=OE **AB9**(Y5) /
R1 AB5 / G1 W12 / B1 AA6 / R2 Y9 / G2 Y6 / B2 AB12 / R3 AA8 / G3 AA11 / B3 AA7 /
A行DCLK **AB4**(W12) / B行RCLK AA12 / C行SDI Y5

⚠ 注意 **DCLK 与 A(行驱DCLK) 对调**：旧序 P1.8 是 DCLK，新序 P1.8 变成 A。

## 副产品：解掉了老 SI 问题

v1.1 把 DCLK/LAT/OE 排在 **J12.22/21/20 三根相邻线**上，正是 2026-07-16 LA 实测
「CLK 2-4ns 振铃假沿 + 行边界像素错乱」的根因。v1.2 后 DCLK 落 J12.12，
两侧邻线 J12.11/13 = SPI_MOSI/MISO **均未使用** → 高速线被静默线天然隔离。

## 推导与验证

推导链 `ball ↔ J12 ↔ P1 ↔ 屏J1`，其中 **P1 = 30 − J12**、**P3 = 50 − J12**（接口板纯直连+10Ω）。
方法自检：用 v1.1 网表跑同一套推导能**逐 pin 复现旧 XDC** → 才认 v1.2 结果。
工具见 [[reference_sch_netlist_tools]]。实现后 31 个引脚 dump 出来与 XDC 逐条对过，已上板点亮。

回滚：`vivado/panel_pins_trans_v11.xdc` 替换 `panel_pins.xdc`。两块转接板可混插，各自独立。

**Why:** 这次重映射一开始被误判为「完全没反应」，真因是 [[feedback_oe_window_too_low_invisible]]，
不是映射错。别再因为屏不亮就怀疑这张表。
