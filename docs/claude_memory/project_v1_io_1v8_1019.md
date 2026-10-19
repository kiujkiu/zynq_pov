---
name: project-v1-io-1v8-1019
description: "10-19 最终: V1 主控 bank33 走 2.5V (底板 H7/H9 专供 J1/J2), 桥板不改; 1.8V 方案弃用; R82 2.2k"
metadata:
  node_type: memory
  type: project
  originSessionId: bfdb9ffe-1bd3-4cf5-919a-aad4e1567854
  modified: 2026-10-19T03:34:05.051Z
---

10-19 用户最终定：V1 主控 FS03 bank33（丝印 BK35/J2，面 A）走 **2.5V**（LVDS25/LVCMOS25），拔 J2 帽，从 SoC 底板 H7/H9（1=PWR2V5，2=GND，用户确认专供 J1/J2）飞线；桥板不改。中途曾定 1.8V+桥板改 U18/U19，已撤回。

**Why:** 1.8V 时桥板 U18/U19 (AVC4T774) VCCA=PWR2V5 会把 2.5V 倒灌进主控；整条桥板 PWR2V5 也不能改 1.8V，因为它经 L2 供 GW5A bank2/3，上面是 24 根 LVDS25 下行输出（DS1103 表2-6: LVDS 输出须 VCCIO 2.5/3.3）。2.5V 共模 1.25V 余量足、只两根飞线。
**How to apply:** 主控位流用 POV_IOV=25（D38 开关，task/d38-faceb b56a8f1），产物 pov_m90_pure_ul800_p1_b12_sb_io25.bin；R82 10Ω→2.2k；桥 R235/R223 推荐 2.2k；底板 R182–R201/R53–R72 空贴（已确认）。依据 dr1v90 d37_io18/REPORT.md；改板清单 zynq_pov/docs/progress/回板当天改板清单_2026-10-19.pdf。SoC 底板+桥转接板 10-19 当周到货，先验通信（D39）。相关 [[project-handoff-2026-10-16]]。

10-19 下午状态：主线 3ef6b06 已含 D33–D39 + V2-7。到板验通信用 `bash d39_comm/comm_check.sh --board <名> --bridge-load sram`（缺省位流在 /mnt/d/claude_workspace/pov3d/_work/v1_main_1019：主控 sb_io25 2b4f3311 / sb_prbs_io25 e7c33e78，桥 e60cp 6d5b3db3、面 B e60cb f919ea30）；到板页 zynq_pov/docs/progress/到板当天_通信验证.pdf。双面主控 TD hold 修复段错误崩溃，D40 在处理。D29 冷上电等 USB 继电器（LCUS-1 常闭串 24V+）。
