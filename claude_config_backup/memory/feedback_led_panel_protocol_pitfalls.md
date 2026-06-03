---
name: LED panel 协议踩坑总结 (ICND1069 + ICND3019)
description: 6 个关键协议错误 — DCLK 不能停 / ICND3019 DCLK ≥500ns / cascade LATCH 是 N×16-bit / EN_OP 首帧后 / ROW 宽度精 / 每个 LE cmd 前要 ≥16 DCLK + LE/SDI 在 DCLK 下降沿换
type: feedback
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
调 ICND1069 + ICND3019 panel bring-up 一周, 协议层踩了 4 个关键坑, 列出避免重复.

**1. ICND1069 DCLK 不能中断, 否则 PLL 失锁 → 无 GCLK → 无 PWM**
- Why: 手册 page 4 "正常工作时，DCLK 一直存在，不能中断"
- How to apply: per-frame ARM GPIO 操作 (chain clear/load 等) 期间, PL DCLK 必须并行跑 keepalive burst, 不能让 DCLK 静止超过几 µs. 我曾让 ICND3019 chain clear 70µs 阻塞 ARM, DCLK 停 246µs gap → 完全不亮.

**2. ICND3019 DCLK 高电平宽度建议 ≥500ns (datasheet page 8 "DCLK 脉宽为消影时间")**
- Why: ARM `gpio_set + gpio_clr` 紧贴一起只 ~40ns, chip 采不到
- How to apply: ARM bit-bang 必须中间加 busy-loop delay 凑到 ≥500ns. 实测 `for(volatile int i=0; i<300; i++);` 出 ~1µs HIGH 够用

**3. Cascade LATCH 协议: 每个 DATA_LATCH 应 shift N×16 bits (N=cascade 颗数) + 1 LE=1, 不是每 16-bit 都 LE=1**
- Why: 手册 page 6 + 8 cascade 写指令同样格式, 一颗 chip 16 channel → 一行 16 LATCH, 不是 N×16 LATCH. 官方波形 LATCH:ROW ≈ 16:1
- How to apply: 实现上每个 LATCH = (N-1)×panel_seq_word(data, 0) + 1×panel_seq_word(data, LE=1). 否则 chip channel counter 绕圈, 行为未定义

**4. EN_OP 必须在首帧 LATCH 数据之后发**
- Why: 手册 page 7 "芯片上电后通道默认关闭, 在完成第一帧数据接收后, 要先发送 EN_OP 指令开启通道输出"
- How to apply: 用 static flag 标首帧, init 阶段只 PRE_ACT + WR_CFG, EN_OP 推迟到首次 LATCH 完成后. 之后 EN_OP 状态一直保持

**5. ROW 信号宽度必须精确 (12 = 第1组第1行, 4 = 后续行)**
- Why: ARM bit-bang 套 panel_seq_word(16 DCLK) 周围, 拿到 16 DCLK ROW 宽度 — 偏差太大 chip 可能拒绝
- How to apply: 加 PL IP `marker_ROW` 模式让 PL 按 DCLK 计数精确 12/4 个 DCLK 高 ROW. 不能用 marker_LE(12) 替代, 因为 LE=12 = DIS_OP 会关闭输出

**6. 每个 LE 命令前必须有 ≥16 个独立 DCLK shift (cascade × 16)**
- Why: 手册 page 6 + 官方 KingstVIS bin 反解: 即使 marker 类型命令 (VSYNC/EN_OP/PRE_ACT/SOFT_RST), 也要前面有 16 DCLK 把垃圾 shift 出去, LE 只是落在最后 N 个 DCLK 上. 早期我用 marker mode (只 N DCLK + LE 高) 不带 16 shift 是错的
- How to apply: `le_marker(N)` 实现成 `(cascade-1) × panel_seq_word(0, 0) + 1 × panel_seq_word(0, N)`, 即 word mode 全 0 数据 + 末尾 N 个 DCLK LE 高

**7. PL IP 内 LE/SDI 必须在 DCLK 下降沿更新, 不能上升沿**
- Why: chip 在 DCLK 上升沿采样, 上升沿同时换 SDI/LE = 0 setup time. 应该下降沿换, 让信号稳定半个 DCLK 周期再被采
- How to apply: led_panel_seq FSM S_DCLK_HI 的 div_tick 那拍既 falling-edge DCLK 又写 SDI/LE next bit
