---
name: feedback_load_map_locates_flying_leads
description: 飞线台架读 JTAG 全 1 时, 别让人去量通断 —— 把排针上所有 IO 做成可独立驱动的探测脚, 逐脚"驱 0 再放开数几次读到 1", 空脚与插了线的脚分得极清楚 (FS03: 2 格 vs ≥3 格), 直接画出线实际插在哪; 再暴力搜 TCK/TMS 同时读全部脚找 TDO
metadata:
  type: feedback
---

2026-09-16 DR1V90→GW5A JTAG 台架: 按规程脚读 IDCODE 恒 0xFFFFFFFF。用户要求"尽量别让我介入"。

有效路径 (全程没让人动线, 约 1.5 小时, 大头是造工具):
1. 先证明量具: PINTEST (球上驱动回读)、降速、两写/三写时钟、IR capture、显式 IDCODE 指令 —— 全 1 且写后回读 0 不一致 ⇒ 不是时序/双拍/指令, 是物理层。
2. **现有位流只有 4 个固定脚且都开了片内上拉 ⇒ 软件看不出线的另一头有没有东西**。旧位流上对三根输出做"放开测上升"已经露出 TDI 那根空载 (1 格 vs 5 格)。
3. 造找脚位流: 排针上 48 个 IO 全部做成独立 OE/OUT/IN + 角色映射寄存器 (旧地址语义不变, 旧软件照用)。
4. **48 脚负载图 = 决定性证据**: 空脚 2 格, 插了飞线 3~5 格, 400 次重复分布几乎无方差; 一眼看出线插在 CEP1.3/4/5/9 而不是 4/5/15/18。
5. 暴力搜 (48×47 对 TCK/TMS, 每一位同时读全部脚当 TDO 候选) 0.3 s 唯一命中, 再用 32 位延迟图样定 TDI, `--apply` 写角色映射, 原版 jtag_idcode 立刻 PASS。

**Why:** "断电量通断"需要人, 而且人数排针很容易数错同一处; 电容负载是物理事实, 软件测得又快又准。静态审计 (原理图/约束/网表) 能排除量具问题, 但定位不了飞线。
**How to apply:** 以后任何飞线/排针对接的台架 (FS03 CEP1/CEP2、桥板验证板), 位流里预留"全脚探测 + 角色映射"模式; 链路不通时先跑负载图再跑找脚, 最后才请人动手。只读扫描读 0 的脚 (可能插着地线) 永远不驱动; 同时驱动 ≤3 脚。工具在 `dr1v90/jtag_load/pl_pinfind/`、`sw_pinfind/`, 负载图源码 `sw_pinfind/pf_rise.c` (产物 `sw_pinfind/out/pf_rise_riscv64`, 板上 `/mnt/mmcblk0p1/jtag_pinfind/pf_rise_riscv64`) —— 见 [[project_pov3d_jtag_load_bench]]。
