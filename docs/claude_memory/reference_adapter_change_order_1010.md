---
name: reference_adapter_change_order_1010
description: 2026-10-10 给硬件同事的转接板改板单 (四项): ①UL_CLK 改接 GW5A B4_B33 ②JTAG 电平转换+下载座 ③桥转接板 FPC 尾部重排 ④SoC 转接板 FPC 尾部按契约核对; 本地独立版 docs/转接板改板单_四项_2026-10-10.html, 在线 artifact PDin6aPczGc9NR6uguDnVx
metadata:
  type: reference
---

- **本地独立版 (浏览器直接打开)**: `zynq_pov/docs/转接板改板单_四项_2026-10-10.html` —— 由下面的 artifact 源文件包上 doctype/charset 生成。
- **在线页 (私有, 要从 Share 菜单分享给硬件同事)**: https://claude.ai/artifact/PDin6aPczGc9NR6uguDnVx ; 源文件 `zynq_pov/docs/转接板改板单_三项必改_2026-10-10.html` (文件名沿用三项, 内容已是四项; 改它再 publish 同路径保持链接)。
- 四项: ① 桥转接板 `DR1V_TXCLKP/N` (FPC 29/30) 从 GW5A B5_B6 (球 R7/T7, CN4) 改接 B4_B33 (球 U10/V10, CN3, GCLKT_9A/BPLL_T_IN1), UL_D[17] 换到 B5_B6 —— **只改 GW5A 侧, DR1M90 不动**; ② 桥转接板 JTAG 加方向固定的 2.5↔3.3V 转换 (不用 TXS0108E) + 本地下载座与 SoC 二选一; ③ 桥转接板 FPC 64~72 按契约 v3 重排, 核 FPC 座 72 导体; ④ **SoC 转接板** FPC 尾部同按契约 v3 核对 (两头必须同一份脚序)。
- 这些是 09-18 改板结论第 7/8/9 条 + 10-10 跨板仿真 (转发时钟必须进 PLL) 和远程升级方案 (JTAG 灌 GW5A) 推出来的; SoC↔桥之间**不加 pin**。

相关: [[project_gw5a_xboard_rx]] [[project_remote_upgrade_x4]] [[project_validation_board_task_tree]]
