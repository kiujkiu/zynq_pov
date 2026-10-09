---
name: project_gw5a_bench_1009
description: 2026-10-09 gw5a_bench 单板上机 — 出货同源桥核心在 ACG525 上逐像素全对、regs 签名=仿真、链0 300M 过跳线 0 错; 🔴 发现并修复 寄存器刷新坏帧+上行重训练 (反压顶爆 rx_fifo + 陈旧 armed 竞争), UL_DROP=1 后 0 坏帧 0 重训练
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

## 🔴 发现并修复: 寄存器定时刷新坏帧 + 上行重训练 (10-10 凌晨)
- 修前硅上: 每 9045 帧 (≈1 s) 恰 1 坏帧 + 4 次 retrain; 上电 64 空白帧约 500 次 retrain; fifo_ovf 一上电就置。
  仿真 6 帧碰不到刷新; `SIMDEF=-DREFRESH_FR=3` 复现。
- 根因① 链路无反向流控 (时基归 DR1), 但胶合把 ul_dispatch 的 afull 反压接给 16 深 rx_fifo; 带 WRITE_ALL 的帧
  (≈52 µs 配置 + 103 µs 显示 > 110.6 µs) 期间 DR1 照常突发 → 满 → 反压 → rx_fifo 溢出 → err_now → retrain,
  门控留着的旧帧头随后放行 → 显示截断帧。
- 根因② (修①后仿真才暴露): ul_dispatch 帧头那拍清 lvl, armed 寄存器晚 2 拍才落; 门控同拍置 fs_pending ⇒
  帧头时有残留就拿陈旧 armed 放行 DISPLAY, 未预存开播欠载 (991 字错)。
- 修法 `gw5a_bridge_core` 参数 **UL_DROP=1 (默认)**: rx_fifo 永不反压, 分发满就丢拍; 非显示期丢拍 ⇒ 冲刷分发块 +
  作废帧头 (干净跳一帧); 显示期丢拍只计数; 帧头延 2 拍置 pending。UL_DROP=0 = 原行为。ul_dispatch/uplink_rx 未改。
- 修后: 仿真常规/快刷新 0 坏帧 0 retrain; **硅上 36 万帧 0 坏 0 retrain**, 刷新帧每秒干净跳 1 帧 (0.011%), 冲刷 4 次/刷新。
  出货整桥重出 BIT:OK dclk 150.1 / LUT 6045 (+100)。
- ⚠ eg4_bridge_top 同一套胶合同样有这两条, 未改 (EG4 非目标)。⚠ 要刷新不丢帧得把 WRITE_ALL 拆进帧间空隙, 系统级取舍未做。
- phase_err 仿真/硅上都恒 1 (建链首次对齐), 不增长, 非问题。

## 收尾 (10-10 00:40)
- 长跑 (UL_DROP=1, `soak_bench_verB_uldrop_1010.log`): 自加载约 19 min **10,251,905 帧 0 坏 0 retrain**, 帧号跳 1133 ≈ 秒数;
  链0 跳线 4 lane 全程 0 错 (单 lane BER < 3e-12)。提交 dr1v90 `b2ad4fd`。
- 最终 bit `GW5A/bench_bits/gw5a_bench_verB.fs` (USERCODE 0x000010AE), 板子留在这版 SRAM 运行态 (掉电即失)。
- 🔴 **Flash 冷启动没做, 等用户点头**: Reprogram (--run 1) 能从外部 Flash 起, 但 Flash 里是 USERCODE `0x0000B3A5`,
  不是我们任何一版, 也不是资料包出厂固件 (`08_厂家固件/ACG525_Factory_Firmware_usb.fs` = `0xC8C4`), 覆盖后恢复不了。
  烧法: `--run 54` (exFlash Erase,Program,Verify Arora V) 然后 `--run 1` + 读 USERCODE + 抓串口。
- 单板剩下要动手的: 13 lane 物理上行 (P6/P11 加帽/线)、lane2 800M (换短绞线)。

## 坑
- 🔴 bench 时序余量薄 (BSRAM 88%): 默认布局下改一个计数器 dclk 就掉到 143; `set_option -place_option 2` 稳定过
  (build.sh 默认 PLACE=2)。出货整桥无仪表, 不受影响。
- **VID_OFS (握手→字0) = 99**, 不是 tb_chain_e2e 的 IDLE+24+8=96: 顶层门控/SLOT_PIPE 多两拍。第一次上板用 98,
  全部真帧判坏、空白帧却对 —— 坏字低字节 = 高字节 ^ {80,C0,00} 是"差一拍 2 bit"的指纹 (0x2DAD = 0xB6B6>>2)。
  靠 tb 同时挂 92..100 九个校验器定参数, 别手推。
- 两颗 PLL 吃同一颗 50M ⇒ 工具当同源相关时钟查跨域 (104 条 pclk↔dclk 违例)。出货顶层两路参考分脚进, 自动异步, 不需要。
  bench SDC 用 `create_generated_clock` 给 PLL/CLKDIV 输出起名再 `set_clock_groups -asynchronous`;
  直接 `get_clocks {u_clk/g_pll...default_gen_clk}` 会 TA2004 (自动派生名 SDC 里拿不到)。
- `ck_clr_q` (dclk→dclk90 1/4 周期) -0.853 ns, 准静态, false path 用 `get_regs {ck_clr_q*}` (实际名 ck_clr_q_s1)。
- 仪表第一版组合太深 (串口 ci/9 下标 28 级, 124 选 1 优先编码), dclk 只 64 MHz; 都改流水/移位后过。

相关: [[project_gw5a_bridge_firmware]] [[project_gw5a_loop_sit_0923]] [[project_pov3d_sw_plan_20d_2026_10_09]]
