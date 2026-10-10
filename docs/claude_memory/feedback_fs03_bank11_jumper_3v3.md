---
name: feedback_fs03_bank11_jumper_3v3
description: FS03 点 2047 屏前先查 CEP2 旁 Bank11 (ADJ_BANK11) VCCIO 跳帽必须在 3.3V; 10-10 DR1M90-02 首亮屏无反应就是它在 1.8V; 另: 换板还要先查启动拨码 OFF-OFF
metadata:
  type: feedback
---

2026-10-10 DR1M90-02 做 D4 首亮: PL 侧一切正常 (OE 翻转、STATUS、帧缓冲都对) 但 2047 屏**完全不亮**,
用户查出 **CEP2 旁的 Bank11 VCCIO 跳帽在 1.8V**, 改到 3.3V (用户确认 "对的")。2047 接口板信号是 LVCMOS33, 1.8V 电平到不了屏。

**Why:** FS03 上 CEP1 (Bank33, 跳帽 J2 = ADJ_BANK33) 和 CEP2 (Bank11, ADJ_BANK11, 手册正文没写位号) 的 VCCIO 都是跳帽选的;
做上行 LVDS18 时要求 J2=1.8V, 点 2047 屏要求 Bank11=3.3V —— 两个跳帽用途相反, 换板/换实验时很容易一起拨错。
同一天这块板还先遇到过启动拨码错 (PIN1/PIN2 不在 OFF-OFF ⇒ 蓝色启动灯不亮、串口全静)。

**How to apply:** 新板/换卡/换实验, 上电前按顺序核: ① 启动拨码 PIN1/PIN2 = OFF-OFF (SD); ② CEP2 Bank11 跳帽 = 3.3V (2047 屏);
③ CEP1 J2 = 1.8V (只在做 DR1→GW5A 上行 LVDS 时)。PL 自检全过而屏不亮, 先怀疑 ②, 不要先改 RTL/脚本。

相关: [[project_pov3d_dr1v90_board_inventory]] [[reference_fs03_cep_connector_pinout]] [[project_dr1m90_d1_display_bit]]
