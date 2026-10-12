---
name: project_adapter_sch_1012_review
description: 2026-10-12 审桥转接板 SCH_GW5A to LED board V01_2026-10-12 (对比 10-10) — 七项改板单只动了两项: CN3/CN6 料号改回 AXK600337YG 但脚号变成 101−n (≠09-23 的 n→n); JTAG 加了 U18 SN74AVC4T774 (接法对) 但无上下拉/无下载座/OE 直接接地; VCCIO45/FPC 尾部/边带等其余全未改
metadata:
  type: project
---

源文件 `C:\Users\wanqi.liu\Downloads\SCH_GW5A to LED board V01_2026-10-12.pdf` (1 页, 创建 10-11, 更新 10-12, 标题栏仍写 `_1010`)。文字集合与 10-10 版相比只多了 U18、R211–R218、C55/C56、DR1_* 四个网名; 其余文字逐字相同 ⇒ 除下列各项外没有改动。

- 🔴 **CN3/CN6 脚号 = 101−n** (09-23 是 n→n, 10-10 是奇 100−n/偶 102−n)。网络在符号上的位置没变, 第 1 脚标记移到右下角 ⇒ 等价于座子转 180°。实例: VCC3P3 在 97–100、B4_B33_N/P 在 82/80、B4_B45_N 在 81、FPGA_TCK 在 1 (对接表 v3 是 1/3、19/21、20、100)。只看原理图判断不了: 封装第 1 脚如果和 09-23 / 官方底板 LB3524 在同一物理位置, 就是 3.3V 打到核心板 JTAG/IO 上; 必须看 PCB (核心板 P1 第 1 脚对准转接板的哪一个焊盘)。
- ✅ U18 SN74AVC4T774PWR: 脚序已对照 TI SCES693I 核过 (1=DIR1, 15=VCCB, 16=VCCA, 9=OE, 10=GND, **我原来记成第 1 脚是 VCCA, 是记错了**); VCCA=PWR2V5 (FPC 一侧), VCCB=VCC3P3; DIR1=GND (B→A, TDO 回 DR1), DIR2–4=PWR2V5 (A→B) 方向全对; 各脚串 0Ω, 两侧各一只 100nF。
- 🟠 U18 欠缺: OE# 直接接地 (改板单要跳线; TI 要求上电期间 OE 上拉到 VCCA); A 侧 TCK/TMS/TDI 没有上下拉 → FPC 没插时 CMOS 输入悬空, B 侧输出不确定; FPGA_TDO 平时是高阻, 也没有上拉; 没有本地下载座 (B 侧被 U18 推挽驱动, 想外接下载器也接不上)。
- 🔴 仍未改: VCCIO45 仍是 L7 (PWR2V5) 贴片、L3 标 NC ⇒ bank4/5 = 2.5V, flash 自动加载有风险; FPC2 尾部 64–72 顺序与 10-10 相同 (64 UART_RX / 65 UART_TX / 66 GND / 67–70 TDO,TDI,TMS,TCK / 71、72 画在列外接地 ⇒ 仍只有 70 导体); 边带 ACK/RST/UART 仍直连 bank4 不经转换; 链4 D0 B4_B50 (R39/R40 NC/0Ω); RSTN R171 + TXB0108; CN3/CN6 旁无去耦; 5V 入口无保险丝/TVS。
- 未变且已认可: UL_CLK 在 B5_B26; 2V8/3V8/3V3 三路 DCDC; CN1/CN2 与 10-10 相同 (仍需对新灯板)。

相关: [[project_adapter_sch_1010_review]] [[reference_adapter_change_order_1010]]

## 用户提议 (10-12): VCCIO45 用 2.5V + 换宽电压 flash — 核过, 要动的是核心板
核心板原理图 p4: bank4/5 的启动电路**全部挂在核心板自己的 VCC3P3 上** —— U2 GD25Q128ESIG 的 VCC、CS/MISO/WP/HOLD 四只 4.7k 上拉、READY(R1)/RECONFIG_N(R4) 4.7k 上拉、MODE0/1 的 1k 上拉位(R55/R56)、DONE 灯(R10 330R)、U3 50M 晶振 VCC (输出经 R12 22R 进 T9)。VCC3P3 同时供 VCCX/JTAG bank10, 不能整轨降。
⇒ 只换宽电压 flash 不够: 它的 VCC 还在 3.3V, MISO 照样是 3.3V; 要把上面这一组全部从 VCC3P3 改到 VCCIO45 才成立 = 核心板改版 (小梅哥成品模组)。依据: DS1103 表 3-21 LVCMOS25 VIH max = VCCIO+0.3 = 2.8V; UG714 §3.2 配置脚 "4.7k 上拉到对应 bank 的 VCCIO"; 表 4-2 GW5A-25 POR 监控 VCCIO4/5/7 (2.5V 本身可以做 MSPI)。
备选 (只改转接板): VCCIO45 回 3.3V + 边带 4 根加第二片 AVC4T774 (U18 已有, 同型号)。等用户定。

## 定案 + 工具实测 (10-12)
用户定 **VCCIO45 回 3.3V** (不走 2.5V+宽压 flash)。Gowin 探针 (dr1v90 `gw5a_bridge/adapter/probe_vccio45_33/`, 合并提交 befc387, 原分支 task/vccio45-lvds33 @1d386b4): 3.3V 下上行 20 对 LVDS25 入 + B4_B50 TLVDS_OBUF(OSER8 333M) + 边带 LVCMOS33 出 bit 0 ERR 0 WARN, 26 端口/47 球 0 差异; 反向对照 ELVDS@3.3V 报 CT1108/CT1136 被拒, ELVDS@2.5V 能过 ⇒ 工具按电压查。电气表现 (共模/眼图) 待上板。
改板单在线页 PDin6aPczGc9NR6uguDnVx 已更新到 v6 (按 10-12), 源 `zynq_pov/docs/转接板改板单_按10-12_2026-10-12_artifact.html`。
