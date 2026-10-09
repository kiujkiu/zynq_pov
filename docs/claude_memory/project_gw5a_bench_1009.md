---
name: project_gw5a_bench_1009
description: 2026-10-09 gw5a_bench 单板上机 — 出货同源桥核心在 ACG525 上 22.5 万帧逐像素全对、寄存器表签名与仿真逐位相同、链0 300M 过 P6 跳线 0 错; 🔴 寄存器定时刷新(9045 帧≈1 s)每次坏 1 帧 + 上行重训练 4 次
metadata:
  type: project
---

# gw5a_bench 上机 (2026-10-09 晚, 计划 D11 提前做)

用户: 「没有 (别的器件), 你把单独 acg525 能做的都验证了, 然后记得保存, 阶段也保存吧」。
工程 `dr1v90/gw5a_bench/` (提交 `d0a77db`, 分支 feature/lvds-b2b), README 有串口行格式与结果表。
bit / 日志: `pov3d/GW5A/bench_bits/` (`sit_bench_verB_1009.log` 是 VID_OFS=99 那版)。

## 做了什么
- `gw5a_bridge_top` 机械拆成 clk + io + **`gw5a_bridge_core`** (§3~§10 逐字搬)。拆后整桥 BIT:OK,
  LUT 5944 vs 5942, dclk 151.0 —— 出货与 bench 用同一份核心。
- 片内 DR1: `tx_pattern_gen` + **`ul_tx_frame8`** (uplink_tx_frame 的 1:8 字宽版, 与 4:1 原版 31104 字逐字对拍)
  + `oct_skew` (lane L 推迟 2L bit, 逼 lane_align/deskew 真干活)。
- 片上校验: `vid_check` (tb_chain_e2e 解码器 + 图案公式搬成 RTL, 24 链全量), `cfg_mon` (广播一致 +
  WRITE_ALL 的 CRC32 签名), `wire_check` (链0 三 lane + 转发时钟走 gw5a_loop n4 那 4 条跳线回 IDDR, 扫 IODELAY)。

## 硅上 (25B)
| 项 | 结果 |
|---|---|
| 24 链视频 | 30 s **225,865 帧逐像素全对**, 9,041 fps |
| 空白帧 / 广播 | 64/64 全 0; 24 链 0 拍不一致 |
| 寄存器表签名 | `1ED7F783`/`ACEED86D` 与 iverilog **逐位相同** ⇒ regs pROM 初始化对 (gw5a_bridge README #6 关) |
| 链0 过跳线 300M | 4 lane 锁定 0 错, 眼图过渡带约 10 档 |
| 时序 | pclk 101.9 / dclk 150.2, 0 违例 (要 `create_generated_clock` + 异步组, 见坑) |

## 🔴 发现: 寄存器定时刷新
每秒恰好 1 坏帧 + 1 帧号跳 + 4 次上行 retrain; 周期 = REG_REFRESH_FR 9045 帧。上电 64 空白帧 (每帧带 WRITE_ALL)
期间约 500 次 retrain, `fifo_ovf` 粘滞位一上电就置。仿真 6 帧没碰到刷新所以没抓到。根因追查见本文件后续节。

## 坑
- **VID_OFS (握手→字0) = 99**, 不是 tb_chain_e2e 的 IDLE+24+8=96: 顶层门控/SLOT_PIPE 多两拍。第一次上板用 98,
  全部真帧判坏、空白帧却对 —— 坏字低字节 = 高字节 ^ {80,C0,00} 是"差一拍 2 bit"的指纹 (0x2DAD = 0xB6B6>>2)。
  靠 tb 同时挂 92..100 九个校验器定参数, 别手推。
- 两颗 PLL 吃同一颗 50M ⇒ 工具当同源相关时钟查跨域 (104 条 pclk↔dclk 违例)。出货顶层两路参考分脚进, 自动异步, 不需要。
  bench SDC 用 `create_generated_clock` 给 PLL/CLKDIV 输出起名再 `set_clock_groups -asynchronous`;
  直接 `get_clocks {u_clk/g_pll...default_gen_clk}` 会 TA2004 (自动派生名 SDC 里拿不到)。
- `ck_clr_q` (dclk→dclk90 1/4 周期) -0.853 ns, 准静态, false path 用 `get_regs {ck_clr_q*}` (实际名 ck_clr_q_s1)。
- 仪表第一版组合太深 (串口 ci/9 下标 28 级, 124 选 1 优先编码), dclk 只 64 MHz; 都改流水/移位后过。

相关: [[project_gw5a_bridge_firmware]] [[project_gw5a_loop_sit_0923]] [[project_pov3d_sw_plan_20d_2026_10_09]]
