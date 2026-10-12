---
name: project_adapter_sch_1010_review
description: 2026-10-10 审桥转接板原理图 SCH_GW5A to LED board V01_2026-10-10 (对比 09-23) — CN3/CN6 改成 AXK500137YG 与核心板同为母座插不上; UL_CLK 09-23 已改到 B5_B26 (改板单第①项过时); JTAG/FPC 尾部仍未改; 下行链号↔球位组整组换名
metadata:
  type: project
---

源文件 `C:\Users\wanqi.liu\Downloads\SCH_GW5A to LED board V01_2026-10-10.pdf` (1 页 A2, 标题 01_ICN2260_LED_V01_高云转接板_1010)。对比基准 09-23 版 (同目录)。

- 🔴 **CN3/CN6 (核心板侧, 原 CN4→CN6) 料号 AXK600337YG → AXK500137YG**, 且脚号整体镜像 (奇 n→100−n, 偶 n→102−n; 网络在符号上位置不变)。核心板 P1/P2 本身就是 AXK500137YG 母座, 官方底板配 LB3524-G100P 公座, 且底板脚号与核心板 1:1 (P1.20=B4_B45_N) ⇒ 09-23 的 AXK600337YG + 原编号才对; 10-10 版母对母插不上, 编号也对不上 (VCC3P3 从 1/3 跑到 99/97)。
- CN1/CN2 (灯板侧) 编号改成 1–50/51–100 (旧奇 2k−1→101−k, 旧偶 2k→k), 且网络重排 (P/N 同排相邻, 对应 09-18 "差分对改同排、两板同步重排")。须拿**同步改过的新灯板原理图**逐脚核, 目前手上最新灯板仍是 09-18。
- 下行球位组 (每链 CLK/D0/D1/D2 四对) 整组保持, 只是链号换名: 新1=旧11, 2=旧5, 3=旧SDI组(B6), 5=旧8, 6=旧7, 7=旧10, 8=旧2, 10=旧3, 11=旧1, SDI=旧6组(B2_R31 GCLKT_4); 4、9 不变 ⇒ .cst / RTL 链索引要跟着改。
- UL_CLK: **09-23 已改** FPC29/30 → B5_B26 (GCLKT_9B, M10/N9), UL_CHK → B4_B33, UL_D[17] → B5_B6。改板单第①项 ("B5_B6→B4_B33") 是按 09-18 写的, 已过时; B5_B26 只是 GCLK 不是 BPLL 专用输入, 需 Gowin 试综合确认 PLL 参考可用; adapter .cst 仍写 U10/V10。
- 09-23 起上行 20 対板上加了 100 Ω 差分端接 (R182–R201) ⇒ .cst 必须 DIFF_RESISTOR=OFF, 否则双端接。
- 已改好: 2.8V 改 TPS548A28 (33k+22k/15k=2.80V, 二极管问题消失)、3.8V TPS548A28 (53.6k/10k=3.82V)、新增 U15 STI3411A → VCC3P3 (33k+12k/10k=3.30V)、U1/U2 改 TXB0108 (VCCA 1.5V 合规)。
- 仍未改: JTAG 直连 FPC67–70 无电平转换无下载座; FPC 64–72 尾部同 09-23; 边带 ACK/RST/UART 仍在 bank4 (3.3V 打 DR1 2.5V); 链4 D0 仍 B4_B50 (R39/R40 NC/0Ω); RSTN 10k 下拉 + TXB0108 (≈4k 输出阻抗) 高电平只剩 ~2.7V; CN3/CN6 旁无去耦; OE 下拉位 NC; 5V 入口无保险/TVS。

相关: [[reference_adapter_change_order_1010]] [[project_gw5a_xboard_rx]] [[project_pov3d_led_board_pcb_v01_review]]
