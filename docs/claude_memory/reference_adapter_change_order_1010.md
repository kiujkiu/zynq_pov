---
name: reference_adapter_change_order_1010
description: 2026-10-10 晚按 SCH 10-10 版的转接板改板单 (七项): ①CN3/CN6 改回 AXK600337YG+原编号 ②VCCIO45 回 3.3V (L3 贴 L7 NC) ③JTAG+边带 8 根用 2 片 SN74AVC4T774 全放桥转接板+下载座+OE 跳线 ④FPC2 尾部重排 ⑤UL_CLK 留 B5_B26 待试综合 ⑥灯板侧 CN1/CN2 对插核对 ⑦SoC 转接板 FPC 核对; 本地 七项 html+pdf, 在线 PDin6aPczGc9NR6uguDnVx v5
metadata:
  type: reference
---

- **本地**: `zynq_pov/docs/转接板改板单_七项_2026-10-10.html` (独立版) 和 `.pdf` (Edge headless 打印, 7 页)。
- **在线页 (私有, 要从 Share 菜单分享给硬件同事)**: https://claude.ai/artifact/PDin6aPczGc9NR6uguDnVx (v5) ; 源文件 `zynq_pov/docs/转接板改板单_七项_2026-10-10_artifact.html`, 改它后带 `url` 重新 publish 保持链接。
- 下午那版 (四项, 源 `转接板改板单_三项必改_2026-10-10.html` / `转接板改板单_四项_2026-10-10.html`) 按 09-18 版写, **已作废**, 傍晚六项版 (`转接板改板单_六项_*`) 也已被七项版替代: 其中"UL_CLK B5_B6→B4_B33"在 09-23 版已改成 B5_B26。
- 我们这边的跟进: Gowin 按 M10/N9 试综合 UL_CLK 作 PLL 参考; .cst 关片内端接 (板上 R182–R201 已 100Ω); 拿到新灯板图后按新链号更新 .cst/RTL。
- 用户定的目标: 桥 FPGA 永远能起来 = flash 存保底 (本地 JTAG 下载座烧) + 每次上电 DR1 经 JTAG 灌 SRAM; 电平转换全放桥转接板 (契约 D5: FPC 单端 2.5V), SoC 转接板不加器件。
- 依据见 [[project_adapter_sch_1010_review]]。

相关: [[project_gw5a_xboard_rx]] [[project_remote_upgrade_x4]] [[project_validation_board_task_tree]]
