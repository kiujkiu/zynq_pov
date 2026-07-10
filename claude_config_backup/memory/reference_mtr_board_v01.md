---
name: MTR_BOARD V0.1 转子转接板 (鹿小班 GPIO1 → 2×HUB75E + 风扇 + 光电开关)
description: LKS_FOC.SchDoc 信号映射全表 (网络级 trace) + 投板前 review 结论 + 插板前必须先换 XDC 的安全红线
type: reference
created_at: 2026-06-12 13:20 CST
updated_at: 2026-06-15 17:00 CST
---
SCH: `D:\工程项目\硬件\pov\MTR_BOARD_V0.1_451\SCH\LKS_FOC.pdf`。P2(20×2) 与鹿小班 GPIO1 排针排座 1:1 对插。4× **74AHCT245** (VCC=5V, 3.3V→5V 电平转换, v0.1 初版是 hc245 已改) + 每线 10Ω 串阻。panel 信号是 5V 电平。

**信号映射 (J1 pin / site / FPGA pin)**:
- Panel1: R1=20/L24N/AB15, G1=19/L24P/AB14, B1=22/L23N/AA13, R2=21/L23P/Y13, G2=24/L20N/W13, B2=23/L20P/V13, A=25/L13N/W18, B=28/L17N/AB17, C=27/L17P/AA17, D=30/L14N/Y16, E=26/L13P/W17, CLK=29/L14P/W16, LAT=32/L22N/AA14, OE=31/L22P/Y14
- Panel2: R1'=6/L9P/Y20, G1'=5/L9N/Y21, B1'=8/L7P/AA22, R2'=7/L7N/AB22, G2'=10/L8P/AA21, B2'=9/L8N/AB21, A'=11/L10P/AB19, B'=14/L11P/Y19, C'=13/L11N/AA19, D'=16/L18P/AA16, E'=12/L10N/AB20, CLK'=15/L18N/AB16, LAT'=18/L12N/AA18, OE'=17/L12P/Y18
- **SPIN_SYNC (光电开关) = J1.34 / L19P / V14**, 10Ω+100nF RC + 10k 上拉 3.3V (配开集 NPN 输出), 传感器供电 3.3V (P4)
- P5 = 5V 风扇. U1 DIR 经 10Ω 上拉 3.3V 且引到 **P2.33 (V15/L19N)**

**⚠ 安全红线**: 插转接板前必须先烧"转接板版 XDC"的 bit — 现役直连 XDC 里 V15=OE2 输出, 驱低会跟 U1 DIR 的 10Ω 上拉打架 (~330mA 灌 FPGA 脚). 新 XDC 里 V15 不约束 (高阻) 即安全. 转接板 XDC 待做: hub75e_pins_mtr_v01.xdc (照上表), sensor_pulse=V14.

**GPIO1 两端二次纠正 (2026-06-12 SCH P8 渲染实锤)**: 电源 GND=35/36 VCC3V3=37/38 +5V=39/40; pin 1=L2N(U22) 2=L2P(T22) 3=L3N(W22) 4=L3P(V22). 我的旧表两端全反 (用户的图和转接板才是对的), reference_lxb_gpio1_pinout.md 已修. 现役 XDC 的 C'/D' 注释 "J1.37/38" 是错标, 物理在板 pin 2/1, PACKAGE_PIN (T22/U22) 本身无误.

## 上板踩坑: stale led_pins.xdc 抢脚 (2026-06-15)
转接板 bit 烧上后两屏竖条纹/乱屏. **逐根验证 FPGA→site→245→面板网络→P1/P3(标准HUB75E) 全链一根不差** (P1脚序=标准 HUB75E: 1R1 2G1 3B1 4G 5R2 6G2 7B2 8E 9A 10B 11C 12D 13CLK 14LAT 15OE 16G; 4×245 A_k↔B_k 映射已渲染核对). 时序也排除 (DCLK 42.9M/25M/6.25M 条纹一模一样).
**真凶**: io_placed.rpt 查出 `hub75e_dclk2→AB5` (应 AB16!) + sensor_pulse 未放置. 旧 `led_pins.xdc` (ICND/SPI LED 实验遗留) 占了 mtr 用的 **19 个脚**, 其中 `panel_spi_miso_tri_i[0]`@AB16 是真实存在的 port → 抢走 AB16 → dclk2 被踢 AB5 → **panel 2 无 DCLK**. 其余 18 脚的 led_pins port 不存在(约束失效)所以没影响.
**修复**: `set_property is_enabled false led_pins.xdc` + 重 build. 教训: **换引脚映射前先 `get_files -filter {FILE_TYPE==XDC}` 列出所有 enabled XDC, grep 目标脚有没有被别的文件占**. 新建 XDC 不冲突 ≠ 安全, 要查全部 enabled.

## 转接板方向标定 (2026-06-15) — 棋盘验证 ✅
转接板 + 面板物理摆放 vs 直连不同, 需重标 (display_128x128.py 两个新标志):
- **PANEL_BANK_SWAP=True**: 左右屏输出物理接反. write_panels 里 top1/bot1↔top2/bot2; 切片生成器 _gen_anime_slices.py 同步 `out=t2+b2+t1+b1`.
- **PANEL1_ROWSWAP=False**: 右屏不再需要 transform_for_panel1 的 top/bot row-swap (否则屏上 [5,6]/[7,8] 子半幅对调).
直连时代值: BANK_SWAP=False ROWSWAP=True (代码注释保留两套).
棋盘金标准: 左屏 1-4/9-12.. 右屏 5-8/13-16.. 整屏 1→64 左到右上到下, 数字正立 = 对.
标定工具链: chess_8x8_src.png → _regen_chess_rot180.py (rotate180+swap-halves) → write_panels → 拼 chess_1slice.bin → _v6_chess1.tcl (DMA N_SLICES=1, 6-bit 静态) → 拍照读数字.

## sensor_pulse (角度) 集成受阻 — BD 综合缓存 (2026-06-15, 暂缓)
转接板 SPIN_SYNC=V14 (J1.34/L19P). angle_tracker.v 集成进 IP 后, sensor_pulse 端口被综合 trim, V14 放不上. **显示不受影响, 已完工**.
- 排查链 (全部确认): .bd 连接对 (net sensor_pulse_1 = external port + IP脚) / wrapper 对 (.sensor_pulse) / v8.v IP 内 sensor_pulse→angle_tracker.sensor_in→trk_slice→slice_idx_live→DMA / angle_tracker 模块写法对
- 综合 probe (open_run synth_1): **IP sensor 脚 net = hello_zynq_i/<const0>**, 顶层无 sensor_pulse port. = BD 结构综合把 IP 输入 tie 0.
- 7 次 build 无效: ① led_pins HDMI 抢 V14 修复 ② reset_target+generate_target ③ v7→v8 rename+recreate cell ④ angle_tracker inline 进 v8.v 同文件 ⑤ dont_touch port+keep wire+dont_touch 实例. 全失败.
- "Synthesizing module" 在 2024.2 synth log 不出现, 别靠它判断模块有没有综合.
- **下次思路**: (a) Vivado GUI 打开 → 检查 module_ref cell 是否 GENERATE_SYNTH_CHECKPOINT(OOC) + 有无 cached .dcp; (b) 删 02_hello_zynq.gen + .runs/synth_1 + .runs/impl_1 全部, 从头 generate+synth (核); (c) 换个简单验证: 把 sensor_pulse 直接反映进 STATUS 寄存器某 bit (绕过 angle_tracker), 先验电路通断.
- **转子未就位前不阻塞**. 显示链 bit (含 v8 IP) 已 commit fa92a09, 可上转子.

## sensor_pulse 集成 — 真根因 (2026-06-15, 10 build 后破)
**根因**: BD 加 external port 后, 连接(connect_bd_net) + generate_target + make_wrapper 分散在不同 build 脚本里做 → **BD 结构网表 (`.gen/.../sim|synth/hello_zynq.v`) 没重生成 sensor_pulse** → 综合读的 BD HDL 里 IP sensor 脚是 const0 (auto tie-off) → 顶层 sensor_pulse 无驱动被 trim → V14 放不上.
之前误判成 module_ref 依赖/综合优化, 加了 rename/inline/dont_touch/保命计数器全是白搞 (RTL 没错, 是 BD HDL 没含端口).
**正解 (一个脚本一次做全)**: open_bd → delete 旧 net+port → create_bd_port -dir I → connect_bd_net → validate_bd_design → save_bd_design → reset_target all → generate_target all → make_wrapper -force → 再 synth. 验证: `grep sensor_pulse .gen/.../sim/hello_zynq.v` 必须出现 `.sensor_pulse(sensor_pulse)` 接到 IP (不是无此文件/const0). 脚本 tools/_bd_sensor_verify.tcl.
**附带正确 RTL** (v8b, 也是对的): angle_tracker 做唯一 slice 源 (slice_idx_live=trk_slice, fake_en=~CTRL[15]), 不用外部 mux (避免 sensor_en 被常量折叠). 0x2C=sensor 脉冲计数 (保命+调试).
