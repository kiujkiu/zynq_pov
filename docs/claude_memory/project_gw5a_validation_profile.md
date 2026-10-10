---
name: project_gw5a_validation_profile
description: 2026-10-10 task 1.3.5 a/b — GW5A 桥验证板 profile (6 链/面 1串2 × 60 扫 × 40 列, 4800 字槽/链/帧, dclk 166.67) 仿真独立解码器逐像素 PASS @4,296 fps, 整桥 166.87 MHz 0 违例; 目标板逐位不变; 新发现 3 个只在验证板暴露的桥 bug/约束 (空闲判丢帧 / NPH=1 帧头字槽丢 / 迟到帧截断)
metadata:
  type: project
---

# GW5A 桥验证板 profile (2026-10-10, dr1v90 `f088f31`, 分支 feature/lvds-b2b)

详版: `dr1v90/gw5a_bridge/README.md` §验证板 profile。构建 `./build_gw5a.sh 25S "" VALID`; 仿真 `gw5a_bridge/sim/run_sim_valid.sh`。

## 推出来的参数
- 每面 12 颗 → **6 链** (链首 U奇 = 芯片一管行 0–29, SDO→SDI 到 U偶 = 芯片二管行 30–59), 18 数据対 + **6 対转发时钟** (每链 CLKI)。
- CASCADE=2 / LINES=60 / PIX_REAL=40 (不补黑) ⇒ **4800 字槽/链/帧**; 字槽 s → 颗 s/2400 (0 先发 = 芯片一), 行 (s%2400)/40, 列 s%40。
- 上行 1 beat = 1 字槽 (8 组/beat, 组 6/7 哑位) ⇒ 4800 beat ≈ 97.5 µs/帧。
- 寄存器表 = e104 P1 实测的 `icnd2260_regs_ext60.mem` (0x04=1E1E 0x08=5105); VHEAD rows=59 cascade=1。
- dclk 166.667 = VCO 1000/6。一帧 VSYNC+DISPLAY 38,640 拍 = 231.84 µs (自由跑 4,313 fps)。
- 用户 10-10 口径 24 Hz × 358 片 = **4,296 fps (232.8 µs)** ⇒ START_SLOTS=16 (仿真窗口 4..40 过, 64 隔帧跳), FIFO 3072 (峰值 2786, 链路比屏快 2.4 倍)。
  DR1 切片周期下限 ≈232.3 µs, 4,296 只余 0.2% —— 要余量就砍 IDLE_CLK (未做)。

## 🔴 验证板才暴露的三件事 (都已参数门控修, 目标板默认关)
1. 帧间训练码型空闲 > 4 个 SYNC 周期 (≈5 µs) 收端就判丢帧重训练 —— 目标板 9,045 fps 空闲 5.3 µs 恰好擦边。验证板每帧空闲 135 µs ⇒ `UL_IDLE_OK`。
   ⚠ 目标板降速/起转 (切片周期变长) 同样会每帧重训练, 待评估是否默认开。
2. ul_dispatch NPH=1 (1 beat/槽) 时对齐拍本身提交帧头字槽, 读侧晚一拍重对齐把它当残留丢 ⇒ 整帧错一槽 (种子非法) ⇒ 写侧晚一拍。
3. 屏排空只比切片周期短 1%: 带 WRITE_ALL 的帧 (上电空白 / 每秒刷新) 迟到 ⇒ 下一帧头截掉正在显示的帧 + FIFO 溢出, 级联坏帧 ⇒ `UL_SKIP_LATE` 整帧跳过 (刷新每秒干净丢 1 帧)。
另: tx 的 WORDS_PER_CHIP 原传每链字数 (CASCADE=1 恰好相等), 级联必须传每颗字数。

## 结果
- 目标板回归 `gw5a_bench/sim/run_sim.sh core` 输出与改前逐行相同 PASS; 目标板重综合 150.099 / LUT 6045 / BSRAM 49 同前。
- 验证板: 5 真帧逐字 + VCRC + 4 空白帧 + 6 配置包 6 链逐拍一致 PASS; REFRESH_FR=3 每次刷新干净跳 1 帧 PASS。
- 综合 25S: dclk **166.871 MHz**, pclk 126.2, TNS 0, LUT 5179 / BSRAM 48/56; 最差 25 条全在 ack_rx (死路径)。
  VALID 的 sdc 要 generated clock + 异步组 (否则 rx_fifo 格雷码跨域 -0.89)。
- eg4_bridge/sim/run_sim_chain.sh 用改前源码也 FAIL (等 ul_armed 超时) —— 既有问题, 非本次引入。

## 留给硬件 (1.3.5.c, D15)
2260 样板 1串2 出图; 真引脚 (1.3.7) 6 个链首 = 09-17 网名 链 0/2/6/8/5/10, U偶 连接器 lane 不驱动; DR1 侧 uplink_tx 按 1 beat/槽 4800 beat 满速突发。

相关: [[project_gw5a_bridge_firmware]] [[project_gw5a_bench_1009]] [[project_icnd2260_pairing_mode_bench_0921]] [[project_validation_board_task_tree]]
