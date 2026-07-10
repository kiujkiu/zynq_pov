---
name: POV3D v34j dual panel 128x128 chess 完整跑通 + W=橙根因锁定
description: dual panel 全历程. 最新 2026-06-11 晚: v6 DMA 自取帧 + multivox 360切片端到端 + 左屏修线闭环 (1-bit 全彩) + 8205fps=22.8rev/s, 待办 v7 紧凑格式/angle_tracker 接入
type: project
created_at: 2026-06-09 18:50 CST
updated_at: 2026-06-15 14:20 CST
originSessionId: c65586d5-1bd7-42fb-bf7e-7a8b7f63582c
---

## v7 紧凑格式 ✅ 24Hz×360 硬指标达成 (2026-06-11 22:45, commit 33bfc42)

**hub75e_panel_seq_v7** (agent 起草一次 build 上板): CTRL[14]=compact_en, **8px=24bit BRAM word**, 8KB/slice (DMA 8×1KB burst, DDR stride 0x2000). lane_q 按 READ_LATENCY_B=1 打 1 拍对齐 (⚠ 改 READ_LATENCY 必须跟改); fetch_compact 启动时原子 latch; compact=0 与 v6 全兼容. compact 只配 dma_en=1+use_fb=1 用.

**验收全过**: slice **8640/s 零跳片** (8KB 取帧 26µs 余量 4.4×) / panel **9860 fps** / err=0 / 画面无 8px lane 错乱. FCLK1=85.7M (SLCR 0x300700 运行时设).

**运行配方 (v7 全速)**: `tools/_v7_fullrate.tcl` — anime_slices_360_compact.bin (2.9MB, `_pack_compact.py` 从全格式转) @ 0x18000000, ANGLE_PERIOD=9920 (85.71M/8640), CTRL=**0x45E1**, TUNIT=0x108. **任务硬指标 [硬件改造前 1-bit, 360 slice × 24Hz] 达成**, 剩: 转子 + angle_tracker 接入 + (可选) 85.7M 正式收时序.

**⚠ v7 compact lane 打包契约 (commit de13c35 修过通道轮转)**: RTL 读序 c_r1=lane+1 / c_g1=+2 / c_b1=+0, 等效 v6 要求打包 **word.bit0(B-LED数据)→lane bit1, bit8(R-LED)→lane bit2, bit16(G-LED)→lane bit0**. 别按物理色名直觉排 (那样金发→青绿/蓝披风→红). _pack_compact.py 已是正确位序, 新写打包工具照抄它.

## 任务约束 (用户定, 2026-06-11 22:15) + FCLK 提速 9829fps

**硬约束: 屏幕硬件改造前全程 1-bit BCM, 硬指标 24Hz × 360 slice = 8640 片/秒独立内容.**

**FCLK1 运行时提速** (SLCR 0xF8000180, 不用 rebuild): 0x500500=72M / 0x400600=75M / **0x300700=85.7M (当前)**. 实测 **9829 fps @ DMA 并发** = 27.3 rev/s ✓ 超标 14%, err=0 画面正常. DCLK=42.9M 超 panel spec 43% (新线扛住, 留观坏点). ⚠ 85.7M 超 75M 时序约束, v7 rebuild 正式收. 注: DMA 并发吃 ~4% fps.

**残余缺口 → v7**: 64KB/片 DMA 只够 ~4800 取帧/s, 360 片仅 ~200 独立. v7 紧凑格式: 3bit/px (bit0=B bit1=R bit2=G), **8px = 24bit BRAM word 整除**, 8KB/片 (DDR 用 32-bit word 低 24 位), 取帧 ~30µs, 360 片共 2.9MB. RTL: dma_en=1 时显示读侧加 lane 选择 (raddr=px>>3, dout[lane*3+:3]), lite 路径不动.

## 左屏修线 ✅ 1-bit 全彩恢复 (2026-06-11 22:00)

**用户修线后实测**: 同样 1-bit @ 8271fps 切片扫掠, 左屏从"只剩红" → **金/蓝/白/品红全亮** (两帧抓拍验证). G/B 刷新率边际失效随修线消失. 左屏暗/色差系列问题 (间歇接触不良) 至此闭环. 上转子的硬件阻塞项清除.

## multivox 式 360 切片端到端 ✅ + 1-bit 左屏判别 (2026-06-11 21:45, commits cd24bce/b1c6275)

**切片生成 (`tools/_gen_anime_slices.py`)**: 体素化 128³ + 面板像素逐点采样 (slicemap 几何; **不抄 colscatter 径向补偿 — Voxon claim 2-5 红线**). 360 slice × 64KB = 23MB @ DDR 0x18000000. 模型静止, 切片=面板角度; 静态屏看是扫掠, 转子上角色凝固.

**生成器踩坑 3 个**: ① 散点放大 >1 倍漏行 ("2行少1行" = ×1.5 每 3 行空 1), 倍率必须 ≤1 ② pack 增益 0.95/0.85 → LUT 输出 56/44 bit0=0 → **R/B 在 1-bit 模式隐身只剩绿**, 1-bit 数据必须增益旁路 (dm.R_GAIN=1.0 monkeypatch) ③ Windows python 写不了 /mnt 路径

**判别结论**:
- 棋盘经 DMA (chess_1slice.bin, N_SLICES=1) 双屏完美 → v6 bank 路由/映射无罪
- **左屏 1-bit@8.5kfps 只剩红, 6-bit@1.1kfps 全彩** → 左屏 G/B 刷新率相关边际失效 (接触老毛病新形态), 修线后应消失
- 左屏切片"镜像异步"是**物理正确**: d<0 半 = θ+180° 侧内容, 转子上才对位; 桌面预览嫌怪可做 --preview 镜像版 (转子上不能用)

**当前运行参数 (用户认可)**: CTRL=**0x5E1** (enable|use_fb|overlap|dma_en|abits5) TUNIT=0x108 (1-bit) ANGLE_PERIOD=1041667 (**72 slice/s = 5s/圈**) N_SLICES=360 SLICE_BASE=0x18000000. 实测 8271 fps.

**1-bit 全速带宽欠账**: 360×24Hz=8640 slice/s 需 553MB/s 超 32-bit HP2, DMA 自动跳片 (~每 2-3 片更新). **v7 待做: 1-bit 紧凑格式 3bit/px = 6KB/slice = 52MB/s**.

## v6 PL 自主取帧 ✅ POV 数据通路心脏跑通 (2026-06-11 21:00, commit a5f8061)

**hub75e_panel_seq_v6** (multi-agent 并行产出, 1 次 build 全绿上板):
- AXI4 读 master: 1KB burst ×64 = 64KB/帧, m_axi→smartconnect→**S_AXI_HP2** (独占口避开 HP1 4×IP 仲裁坑)
- BRAM 双缓冲: 4×8192 word 乒乓, 显示读 disp_buf / DMA 填 ~disp_buf, frame_tick (frame_count 变化) 才翻
- 新寄存器: 0x18 SLICE_BASE / 0x1C ANGLE_PERIOD (aclk cycles per slice) / 0x20 N_SLICES / 0x24 只读 {err[31:28],dma_state[27:24],slice_idx[15:0]}; **CTRL[7]=dma_en, =0 时与 v5 完全兼容**
- DMA FSM: D_IDLE/D_AR/D_R/D_WAIT_FR/D_DRAIN (中途 dma_en 掉走 DRAIN 收完 outstanding, AXI 不弃事务)
- 文件: hub75e_panel_seq_v6.v (新文件, v5 保留共存); BD 重建 tools/build_v6_recreate.tcl (rename+删cache+recreate 全套一次通过)

**bring-up 实测 (ARM 全程 halt, 纯 PL)**:
- 8 测试 slice @ **0x13000000** (空闲段; 0x18000000 是 voxel grid 别用!), slices_test.bin + tools/_v6_dma_bringup.tcl
- 1 slice/s: slice_idx 稳推进, 屏逐秒换色, err=0 ✓
- **全速 2931 slice/s = 188MB/s HP2 持续流: err_cnt=0, panel fps 1098 (6-bit 正常值) 无拖慢 ✓**

**angle_tracker.v 已写好待接入** (multivox 式: 2FF同步+去抖+8深度思路中值+每转一次32拍串行除法+余数保留插值+丢脉冲locked保护+fake模式). 接入点: v6 内 "ANGLE SOURCE" 注释块, sensor_pulse 端口已预留 (BD xlconstant 0 占位).

**timing**: WNS -0.075ns ×2 路径在 pov_batch HLS IP 内 150M 域 (布线随机非 v6), 可换 seed 重跑.

**Linux 迁移评估** (agent 报告): 72% 可移植 (mmap/UIO) / 21% 直接扔 (ESP32 SDIO/UART) / 6% 重写 (dual_core→pthread), ~8-10 人日. v6 的 DDR 取帧正是 Linux 化前提 (Linux 只写 DDR + 配寄存器).

**下一步**: ① 真切片数据进 DDR (HLS 渲染 122 slot → v6 格式转换) ② 接 angle_tracker + 光电开关 XDC ③ panel fps 与 slice rate 匹配 (3-bit 2862fps ≈ 2931 slice/s Phase-1 设计点)

## POV 切片模拟 MVP ✅ (2026-06-11 19:00, commit 9edf698)

**假角度 + 切片显示链跑通**: phase (每 3 帧+1, 72 角 5° 步) → HLS `pov_voxel_slice_batch` slice_mode=1 z 截面 → HDMI fb → 桥接 → LED 1-bit 8613fps. 相机实拍两帧完全不同截面 (薄带 vs 头部轮廓) ✓.

**实现 = 2 行寄存器**: 单 batch IP (0x43C20000) 同 kernel 本就有 slice 参数, `BATCH_SLICE_MODE=0x50` `BATCH_SLICE_THICK=0x58` (4X 头文件 P4X_SLICE_MODE 同 offset). `POV_SLICE_DEMO` 宏开关, thick=8.

**MVP 证明的是几何/渲染正确性, 不是速度路径**: ARM-in-loop 渲染 ~10-30 slice/s; 真 POV 要 2900 slice/s → 必须下一步 **预渲染 122 slice 进 DDR + PL 按角度自取** (AXI master 改造 hub75e IP, ~183MB/s @3-bit, 双缓冲 BRAM). 之后接真霍尔传感器替换假角度.

**相机驱动挂修复**: `_snap_check.py` 加 DSHOW idx=2 快速路径, 跳过 MSMF ~5s 失败探测 (反复长占用是把 Insta360 虚拟相机搞挂的原因).

## v34p 提速三件套 ✅ + 孤立点过滤撤回 (2026-06-11 18:20)

**提速 (commit 0e2c5ed)**: DCLK_DIV 3→2 (37.5MHz) + TUNIT 运行时切 BCM 位深 + overlap(CTRL=0x561 本来就开). 实测: **1-bit 8585 fps / 3-bit 2862 fps** (Phase 1 目标 2931 命中). TUNIT 值: 0x108=1bit / 0x308=3bit / 0x608=6bit, bits[11:8]=planes bits[7:0]=t_unit.
- 1-bit LUT 必须阈值化, **阈值 sRGB 128** (186 时蓝披风/金发全被切, 转侧面人物消失); ELF 里 LUT 是按位深生成的, 切位深要换 LUT 重编
- 人物大小 = LED_CROP/LED_SRC (HDMI 中央方形裁切): 400→570→**712** (~56% 屏高), 改一行重编 ~2min

**孤立点过滤试验撤回 (commit c79d969)**: 8 邻域单点清除实测净负收益 — 点云人物本身是稀疏单点, 过滤吃本体留 2+ 像素噪点簇. **散点根因 = 点云 + 1-bit 阈值 + depth-fade, 非渲染 bug**, 用户看到的"飞点/红色竖线"大多是这个 (竖线未单独深查, 嫌疑 = 武器/红边转到侧面的细线 or 37.5M R 通道移位串扰 [v34h 有 R 漏出前科], 判别法 = 冻结帧读 BRAM 对比).

**dl_minimal.tcl 已加固**: 先 stop ARM 两核再 fpga -file (防 AXI 事务卡死 DAP). DAP 0x30000021 时**先拔插烧录器 USB** (当天 3 次实测有效), 不行再板子断电.

## v34o 旋转 anime 双屏显示 ✅ 颜色用户确认 (2026-06-11 15:45)

**用户原话 "ok，颜色对了，我确认的颜色对了"** — 旋转金发武士同时上 HDMI + LED 双屏, 颜色链定稿:

**定稿颜色链 (LED 显示必用, 全部相机/用户验证)**:
1. **gamma 2.2 LUT**: LED BCM 是线性占空, 图片/HDMI fb 是 sRGB 编码. 不做 sRGB→线性转换所有中间调冲白 (发色金 187,165,88 显示成粉白 — 黄卡实测). HDMI 显示器自带解码所以 HDMI 路径不用.
2. **byte→LED 映射: byte0=蓝 byte1=红 byte2=绿** (RGB 测试卡验证, 当前 v34m bit)
3. **通道增益 R0.95/G1.0/B0.85** (右屏单色满值 camera R228/G183/B218, G 最弱, R/B 压到 G)
4. HDMI fb 字节序 GBR (p[0]=g p[1]=b p[2]=r)
5. 方向: 源 rot180 + 左右半幅 swap

**蓝斑头发根因**: `anime_crop.png` 是 **UV bug 时代 RAW 渲染** (glb-texture-flowerspot-postmortem.md Bug③ V轴双重翻转的花斑), 头发里的蓝色是采样错位, **不要再用它做显示源**. 正确颜色源 = `anime_points.bin` (UV 修复后, HDMI 旋转渲染用的).

**v34o 实现** (`helloworld.c`):
- `DISABLE_HUB75E_BRIDGE` 注释掉 = 桥接启用
- 桥接重写: HDMI fb 中央 400×400 → 双屏 128×128, 3×256 gamma LUT (增益折叠), 坐标闭式解:
  `panel2(row,col) = src(63-row, col)`, `panel1(row,col) = src(127-((row+32)&63), col)`,
  fb 采样 fx=CROP_X+sx*SRC/128, fy=CROP_Y+sy*SRC/128
- banks: p1 top/bot=+0x8000/+0xC000, p2=+0x18000/+0x1C000
- ELF build: `tools/build_app_v34o.py` 走 `vitis.bat -s` (路径已修 claude_workspace)
- 部署: `tools/dl_minimal.tcl` (bit+ELF+anime_points.bin@0x1A000000+MAGIC, no rst-system)
- 验证: 连拍 diff=57 (旋转在动) + 用户确认颜色

**静态路径同步**: `display_128x128.py` pack_panel_bin 也已带同套 gamma LUT + byte map + 增益.

## 进度存档 (2026-06-11 13:40) — 等用户修线

**当前板上状态**: 原版引脚 bit (DCLK_DIV=3, 25MHz) 已烧回 (io_placed.rpt 验证 rgb[1]=AA22 / dclk=Y18 原位), 屏上点着**绿场 0x3F0000 两屏同数据** = 修线前后对照基准 (基准值 L/R=0.57). 无残留 JTAG 进程.

**下一步 (按序)**:
1. 用户重压/换左屏 G 两根飞线 **J1.22 (G1'→AA13) + J1.19 (G2'→AB14)**
2. 绿场拍照复测 (`_set_one_color.tcl 0x3F0000` + `_snap_check.py` + 固定 ROI `tools/_roi_one.py`), 目标 0.57→0.9+
3. G 通了 → B 两根 J1.21/J1.30 照做 (基准 0.80), R 基本健康不动 (0.91)
4. 残差 <10% 用软件细调: `display_128x128.py` 已有 PANEL1_BRIGHT/PANEL2_BRIGHT 钩子 (当前 0.90/1.00, 是按旧绿场数据设的, 修线后要重标), 需要时扩成 per-channel
5. 拉平后重推 chess/anime 验证 (注意 bins 当前是 halfsplit 测试图, 要重新生成)

**本日资产**: build_v34m_dclkdiv3.tcl (DIV3) / build_v34n_pinswap.tcl (impl-only 快速 build 模板, ~5min) / hub75e_pins_orig_backup.xdc / tools/_set_one_color.tcl / _hold_loop_color.tcl / _panel1_only.tcl / _roi_one.py (固定 ROI 量左右) / _chan_measure.py / _fixed_roi.py

## 左屏暗 ⚠ 翻案: 间歇性接触不良 (2026-06-11 17:20)

**当天下午暗象自行消失**: 同条件绿场 L/R 今早 0.57 (稳定复测) → 下午 **1.04** (37.5M 更苛刻时钟下反而相等). 中间只有 3 次断电 + 烧录器拔插 + 线缆被碰, 颜色链软件没变.

**最终结论: 左屏接插件间歇性接触不良** (IDC 排线 / 飞线压接 / 电源插头之一). 自洽解释全部线索: 时好时坏 / 跟位置走 / 逐通道不对称 (哪根接触差哪个通道损) / 频率敏感 / 1-bit 满驱动也有差 (接触电阻 = 模拟层).

**处置**: 再出现左屏暗/偏色 → 先重插左屏 IDC + 电源, 不用怀疑代码/面板. 根治 = 重新压接左屏那组线. 供电压降假说的占空判别实验已无对象 (当天暗象消失), 不必再做.

## 左屏暗 ✅ 三角定位完成: 物理飞线, 非代码非面板 (2026-06-11 13:30)

**三步判定 (全部实测)**:
1. 用户交叉面板 IDC → 暗不跟面板 → 不是面板
2. **XDC pin-swap 实验 (v34n)**: panel1↔panel2 全部引脚互换 (纯 XDC, impl-only rebuild ~5min), io_placed.rpt 确认 swap 生效 → **绿场 L/R=0.57 分毫未动, 暗不跟逻辑** → 不是代码
3. 唯一剩下: **J1→飞线→左屏 IDC 物理路径**

**逐通道实测 (固定 ROI, 全屏单色填充)**: G 掉 43% (L/R=0.57) / B 掉 20% (0.80) / R 只掉 9% (0.91), 白 0.56-0.66. 通道差异巨大而 DCLK/LAT/OE 共享 → 必然是 per-channel 数据线问题:
- **最差 G**: J1.22 (AA13), J1.19 (AB14)
- 次差 B: J1.21 (Y13), J1.30 (Y16)
- R 健康: J1.13 (AA19), J1.20 (AB15)
这组线为适配 panel2 BRG 色序手工换过线.

**测量方法坑**: 白色饱和度低, mask 法选区会把背景算进去出假数据 (绿曾量出 1.06 与照片矛盾); 必须用固定 ROI (相机不动时 L=x[780:1140] R=x[1320:1680] y[150:850]). 模式 0x521/0x561 已排除 (两模式差不多).

**修复选项**: (a) 硬件: 重做/缩短左屏飞线, 优先 G 两根, 信号间加 GND 回流; (b) 软件: panel1 按通道压暗 G×0.57/B×0.80/R×0.91 拉平 (牺牲整体亮度).

**XDC 已恢复原版** (backup: hub75e_pins_orig_backup.xdc), v34n swap 仅为实验.

## 左屏暗根因: DCLK 超频 + panel2 时钟走普通脚 (2026-06-11) — DCLK_DIV 3 部分修复

**根因链** (源码实锤):
- IP `hub75e_panel_seq_v5` 第 88-91 行: panel 2 的 DCLK2/LAT2/OE2/ADDR2 全是 `= panel 1` 的复制 (同一内部信号, 不同物理脚), 只有 RGB data (plane_rgb2) 独立. → 亮度由共享 OE 占空比决定, 逻辑上两屏必然相同, **14% 差不可能来自逻辑/颜色映射**.
- XDC: panel1 DCLK=**Y18 (MRCC 时钟专用脚)**, panel2 DCLK2=**Y14 (普通 IO L22P)**. LAT 同理 (Y19 SRCC vs V14 普通).
- `DCLK_DIV=2` parameter → 75MHz/2 = **37.5MHz DCLK, 超 FM6124 spec 30M**. 超频下 panel1 在好时钟脚撑得住, panel2 在 Y14 marginal → 整片均匀暗. 共享 OE 时代 (v34e) panel2 用 panel1 的好时钟, 所以那时不暗 → 对上"独立 8 IO 后才有".

**DCLK_DIV 是 BD/xci 设的 (不是模块默认), 改要 `set_property CONFIG.DCLK_DIV {3} [get_bd_cells hub75e_panel_seq_0]` + 重 build**. build 脚本 `tools/build_v34m_dclkdiv3.tcl` (含 assign_bd_address 0x40020000 128K 必备 fix).

**实测 DCLK_DIV 2→3 (37.5→25MHz)**: L/R 0.86 → **0.92**, 拼缝台阶 180/215 → 228/252. **差距 14%→8%, 砍掉接近一半**. 证明 DCLK 超频是原因之一, 但有 ~8% 残留 (25M 对 Y14 还略 marginal, 或剩余是硬件供电/面板档). 下一步候选: DCLK_DIV=4 (18.75M) 再验, 或挪 DCLK2 到 MRCC 脚, 或量 panel2 5V.

**bit/xsa**: impl_1/hello_zynq_wrapper.bit @ 2026-06-11 12:00, 已 cp 到 vitis_ws/.../sdt/hello_zynq.bit, `_dl_bit_only.tcl` 烧.

## 左屏(panel 2)整片暗 14% (2026-06-11) — 均匀台阶非视角

**实测**: 填均匀绿场拍照, 绿通道均值 左屏 185 / 右屏 216, **L/R=0.86 (左暗 14%)**. 横向 profile `178 177 180 185 | 202 225 220 213 208 209` 在拼缝处**台阶跳变**(非平滑渐变).
- 排除相机/视角 (斜拍是渐变, 这是突变)
- 排除内容 (均匀绿场)
- = 真硬件, 整片均匀差一档 (非局部坏点)

**头号嫌疑**: panel 2 (左) 5V 偏低 (供电压降). 待万用表量左右 5V 确认. 若 5V 正常 → 面板出厂亮度档不同, 可软件补偿: `display_128x128.py` `pack_panel_bin` 给 panel2 乘 ~1.16 增益 (但若是供电问题别加驱动, 会加重压降).

**注**: 测亮度时 word 0x3F0000 这次出绿 (上次静态出蓝) — 再次印证 byte→色映射 SI 态相关不稳定. 测亮度不受影响 (只要均匀场).

## 棋盘/图像方向修正: rotate180 + 左右半幅交换 (2026-06-11 00:xx) — 拍照验证

**现象**: `display_128x128.py` 现有 transform 直接出图, 物理屏上**上下颠倒**(数字倒). 用户报"上下颠倒".

**踩坑过程 (各试一次, 每次 reload ~几分钟)**:
- `rotate(180)` 源图 → 数字正立 + 1→64 上下顺序对, **但左右两半对调** (左屏出 5-8, 右屏出 1-4, 每半内部顺序对). 关键认知: 每 panel 有 `rotate(-90)`, **源图水平翻 ↔ 显示垂直翻** (90° 把横竖轴对调).
- `FLIP_TOP_BOTTOM` 源图 → 又变上下颠倒 (更糟), 排除.
- **正解 = `rotate(180)` + 左右两个 64 宽半幅整块交换 (不内部镜像)**: 1-4 那半走 panel2 变换上左屏. 拍照确认完全正 (左屏 1-4 / 右屏 5-8, 数字正立, 1→64 上下对). 脚本 `tools/_regen_chess_rot180.py`.

**适用范围**: 这是物理挂载方向决定的, **anime 同样要 rotate180+swap-halves**. 还没 bake 进 `display_128x128.py` 的 write_panels (怕动了 v34e "verified" mirror 路径); 下次推 anime 直接在源图上加这两步, 或考虑固化进 write_panels.

**相机假帧坑 (重要)**: `_snap_check.py` 锁 idx=2 DSHOW, **会返回冻结帧** (连拍两张 diff=0.0, 连背景都一样). 验证显示是否更新前, 必须连拍两张 diff: diff≈0 = 冻结帧不可信, diff>20 才是新帧. 别拿单张 snap 下结论 (这次差点误判 rotate180 没生效).

## 8 色循环通道映射修正 (2026-06-10 23:10) — 用户实时确认

**现象**: `_8color_inner_loop.tcl` 原 word 映射 (byte0=R byte1=G byte2=B) 跑循环, 用户肉眼看到顺序 = **蓝红绿白粉青黄**, 即一个干净的通道轮转: **byte0→屏蓝, byte1→屏红, byte2→屏绿**.

**修正**: 把每个名色放进真正点亮它的字节, `_8color_inner_loop.tcl` 的 colors list 已改为:
`R=0x003F00(byte1) G=0x3F0000(byte2) B=0x00003F(byte0) W=0x3F3F3F Y=0x3F3F00 M=0x003F3F C=0x3F003F`
→ 用户确认现在按 R→G→B→W→Y→M→C 标签发, 屏上真出 **红绿蓝白黄粉青** ✅

**对 anime/chess 的影响**: `display_128x128.py` 的 `word = r|g<<8|b<<16` 需同步改成 **`word = b | (r<<8) | (g<<16)`** 才能正确显示, 否则整图通道轮转偏色.

**⚠ 未解矛盾 (别盲信, 用前先验)**:
- 静态单色定住拍照 (`_set_one_color.tcl`) 实测是 **identity**: R字(0x00003F)→红, B字(0x3F0000)→蓝 (照片实证 _test_RED/BLUE.jpg)
- 之前 chess 也是用 identity 打包显示正确
- 但**循环里**用户看到的是 rotation. 静态 identity / 动态 rotation 矛盾 → 怀疑 OVERLAP(CTRL=0x561) 双缓冲 + 共享信号 SI 在快速换色时让通道 latch 错位 (同 W=橙 根因). 即此 remap 可能是 SI 态相关, 不是稳定的硬映射. 推 anime 前务必单测当前条件下的真实映射.

**多 xsdb 孤儿坑**: TaskStop 只杀 WSL 侧 cmd.exe, Windows `rdi_xsdb.exe` 成孤儿仍连 ARM. 反复起停后 `tasklist | grep rdi_xsdb` 发现 4 个一起抢屏. 清法: `taskkill /F /IM rdi_xsdb.exe & taskkill /F /IM hw_server.exe` 再起单个 (FPGA bit 不受影响, panel 停最后一帧不黑).

## v34L SOLID 寄存器 poke 方案 (跳过 BRAM, 最简切色) — 新增 (2026-06-10 22:30)

**用途**: 不动 BRAM, 直接 CTRL=0x501 (SOLID + enable + 1/32 scan) + COLOR/COLOR_BOT 寄存器换色. 优点: 不用 4096 word mwr, 切色 <1ms; 缺点: 只能整片同色, 不能 chess/anime.

**寄存器 (hub75e_panel_seq_0 @ 0x40020000)**:
- 0x00 CTRL = 0x501 (enable | mode=SOLID | abits=5)
- 0x04 COLOR     = 24-bit RGB top half. **layout R[7:0] G[15:8] B[23:16]**
- 0x10 COLOR_BOT = 24-bit RGB bot half (跟 top 同色就两个都写)
- 0x08 PARAM = 0 (默认)
- 0x14 TUNIT = 96 (默认)
- 0x0C STATUS bit 0 = running, bits 31:16 = frame_count

**8 色 (R/G/B 各 0xFF)**: BLACK 0x000000 / RED 0x0000FF / GREEN 0x00FF00 / YELLOW 0x00FFFF / BLUE 0xFF0000 / MAGENTA 0xFF00FF / CYAN 0xFFFF00 / WHITE 0xFFFFFF

**文件**:
- `red_panel.tcl` — halt ARM + CTRL=0x501 + COLOR/COLOR_BOT=0xFF (单色红停留)
- `cycle8_panel.tcl` — halt ARM + 5 reps × 8 colors × 600ms, 最后 BLACK

**跑法**: `cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov && C:\Xilinx\Vitis\2024.2\bin\xsdb.bat -interactive cycle8_panel.tcl"`

**验证 2026-06-10 22:21**: 5 reps 跑完, STATUS=0xC020AF01 (frame_count 在加) IP 一直 running. ARM halted at 0xffffff28. 实际颜色对错用户肉眼验证 (本次没拍照).

**vs `_8color_inner_loop.tcl` 区别**: inner_loop 走 use_fb=1 + CTRL=0x561, mwr 4096 word 填 4 BRAM, 能 chess/anime; SOLID poke 不碰 BRAM, 整片单色, 最适合纯 panel 通断/色序快速验证.

---

## v34L 状态 + 8 色循环不黑屏方案验证 ✅ (2026-06-10 22:15)

**v34L commit fb13e65**: panel 2 独立 DCLK2/LAT2/OE2/ABCDE2 8 pin + 6 RGB pin, 不再跟 panel 1 共享 SI. XDC 见 `02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc`. panel 2 GPIO1 J1.x 表:
- R1'/G1'/B1' = J1.13/22/21 (AA19/AA13/Y13)
- R2'/G2'/B2' = J1.20/19/30 (AB15/AB14/Y16)
- E'/A'/B'/C'/D' = J1.32/23/24/37/38 (AA14/V13/W13/T22/U22)
- CLK'/LAT'/OE' = J1.31/34/33 (Y14/V14/V15)

**切色不黑屏方案 (验证 12+ 圈)**: `tools/_8color_inner_loop.tcl`
- 单 xsdb 连接 + 内部 `while {1}` 不退出
- 一次性设 OVERLAP CTRL=0x561, 之后只 `mwr 4096` 填 4 BRAM (0x40028000/4002C000/40038000/4003C000)
- panel state machine 一直 running, 颜色直接换不重启
- 实测 R→G→B→W→Y→M→C 每 ~2.3s 切一色, 后台 id `b6d6bfrrm` 跑超过 30 min 没断
- cam 0 (Insta360) 验证 panel 1+2 都亮, 不闪 (panel 1 R / panel 2 C 中间态因 4096 word mwr 几百 ms 延迟)

**踩过的"切色黑屏" 坑**: 之前 `_8color_cycle.tcl` 单色每次启动新 xsdb session → 重 connect → 重写 CTRL=0x501 → panel reset → 切色之间黑屏. 同时多 xsdb 抢 ARM 控制 → 反复 reset 更糟.

**用户报告"两个屏幕对不上"** (未解决, 等下次会话验证):
- panel 1 红 / panel 2 青 — 摄像头中间态, 不是真的不同步 (BRAM 内容相同)
- 但物理颜色是否对得上还得 panel 2 单色 R/G/B 验证 (panel 2 内部 BRG vs panel 1 GRB, 物理换线后)
- 下次开机第一步: 跑 panel 2 only 单色测试 (只填 0x40038000/4003C000), 验 panel 2 RGB 顺序

## v34j 最终状态 (2026-06-10 02:27)

**Build**: tools/build_v34i.tcl (verilog revert + XDC 撤 DRIVE 4 + assign_bd_address fix)
- XDC: panel 1 R2/G2 swap Y20↔AB21 保留 (v34h 验证有效)
- verilog: BCM bit slicing 用 `pattern_24[plane_ext + 5'd16]` (v34h 写法, byte-slice 改无效已 revert)
- assign_bd_address: `panel_seq 0x40020000 128K` 必须显式 assign (BD 41-1356 fix)

**bit**: `02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit` (4.0 MB, 6-10 11:51)
**xsa**: `hello_plat/hw/hello_zynq.xsa` (1.08 MB, 6-10 11:51)
**sdt**: cp 到 `vitis_ws/hello_plat/hw/sdt/hello_zynq.bit`

**烧 + 测试流程**:
1. `xsdb.bat tools/_dl_bit_only.tcl` (烧 bit + ps7_init, ARM 不启动)
2. `xsdb.bat tools/_8color_cycle.tcl <0-6>` (R/G/B/W/Y/M/C, BCM 全 panel 单色)
3. `xsdb.bat tools/anime_load_v34g_wordloop.tcl` (load chess 8x8 4 BRAM bin, CTRL=0x521 启动)
4. `python tools/_snap_check.py` (Insta360 idx=1 MSMF snap → `panel_low_exp.jpg`)

**验证结果** (照片 tools/panel_8c_*.jpg + panel_chess_retry.jpg):
- 8 色循环 R/G/B/M/C 都 ✓, **W 仍橙 ✗** (B 弱), Y 偏红橙
- 8×8 chess 64 cell + 1-64 数字 + HSV 渐变完美显示, 只有 panel 物理坏 chip 区域有色斑

## W=橙 根因 ✅ 锁定 (2026-06-10 02:05)

**关键现象**:
- panel 2 IDC 拔掉 → panel 1 单独 W = **真白** ✓
- panel 2 IDC 接回 → panel 1 W = **橙** ✗

panel 1 接线没动 / build 没变 / FPGA 没改, 只切换 panel 2 是否接入就反复重现.

**根因**: dual panel 共享 DCLK/LAT/OE/ABCDE 8 根信号. panel 2 接入 → 这 8 根线上 panel 2 chip input 并联负载 → 边沿斜率变缓 + 反射 → panel 1 内部 chain GRB 末端的 B chip latch setup 跨墙失败 → W 缺 B. 详见 `feedback_dual_panel_shared_signal_interference.md`.

**74HC245 buffer 转接板**: user 自做了 74HC245 buffer 物理隔离 panel 1/2 SI, 但实测 W 仍橙 → buffer 没完全解决.

**真完全修法 (待做)**: panel 2 独立 DCLK2/LAT2/OE2/ABCDE2 8 个 FPGA pin (GPIO1 有空 pin), verilog 加 4 个 output, XDC 加 8 行, 接线把 panel 2 的 8 根线从 panel 1 共享 pin 拆下接新 pin. 这是 48 SDI 方案必经之路.

## panel 物理坏 chip 已知缺陷 (跟 v34j build 无关)

- panel 1 顶 2 row 接触不良 (B 单色顶部 2 条黑) — 排线 reseat 可改善
- panel 1 hw col 96-111 B 死区 (chess cells 9-14 黑/绿 stuck)  
- ~~panel 2 cells 49-52 G+B 卡 ON~~ → **翻案 (2026-06-10 04:00)**: 那条不是 stuck on, 是 **panel 2 中段那一列 chip 物理 R/G 输入接反**. 验证: R 命令时中条出 G, G 命令时中条出 R, B 命令时中条 B 跟整 panel 一致. panel 1 单独时没这问题 (中条在 panel 2 区). FPGA 调不了, 软件 hack 可那一列单独 swap R/G byte. panel 厂出厂 PCB / 内部走线缺陷.
- panel 2 内部 BRG vs panel 1 GRB → 物理换线已处理

## v34h build + 烧录 + 摄像头验证 (2026-06-09 22:21)

- bit: `02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit` (4.0 MB)
- xsa: `hello_plat/hw/hello_zynq.xsa`
- 用 `tools/build_v34h.tcl` 跑, ~7.5 min
- bit 已 cp 到 `vitis_ws/hello_plat/hw/sdt/hello_zynq.bit` 走 `_dl_bit_only.tcl` 烧好
- 之前以为 "batch spawn fail" 其实是 vivado.exe 不在 PATH, 见 feedback_vivado_batch_needs_settings64.md

### 8 色循环 + Insta360 snap 结果 (照片 tools/panel_v34h_*.jpg)
| 颜色 | 期望 | 实际 | v34g 对比 |
|---|---|---|---|
| W (R+G+B) | 白 | 橙 | 跟 v34g 一样, B 仍被压 |
| M (R+B) | 品红 | 大部分品红 + 中间 cyan stuck 条 | **改善** (v34g M 几乎纯红) |
| B 单色 | 全蓝 | 蓝 + 左下品红块 | **新 bug**: R2 路径漏出 R |

### 判读
- XDC swap Y20↔AB21 让 M 出品红 → 证明 v34g R+B 串扰确实在 panel 1 R2-B2 DQS 差分对耦合 (Y20=L9P, Y21=L9N)
- 但 W 还是橙 → B 在 R+G 共存时仍被压制, **DRIVE 4 SLEW SLOW + 单 pin swap 不够**
- B 单色出现 R 漏出 → AB21 (新 R2 pin) 跟周边线还有串扰, 或 panel 1 R chip 在 B-only 时不该亮的 timing 边沿被触发
- 中间 cyan 条是已知 panel 2 cells 49-52 区 hw col 16-31 stuck (memory 已记)

### v34h 结论
**Partial fix**, 不可发版. 下一步候选:
1. ~~verilog byte-slice 重写~~ (2026-06-10 实测无效, 撤回)
2. 再把 panel 2 R2/B2 也 swap (AB15/Y16, 不共差分对但也 fail)
3. 改 DCLK 频率减 SI
4. PCB / IDC 排线物理改

## v34i/j 一系列尝试结论 (2026-06-10 01:30)

**踩了一晚上坑, 主要结果**:
1. **verilog byte-slice 改 (v34i) 无效** — revert 回 plane_ext + 5'd8/16 三色一样, B 还是被压
2. **XDC DRIVE 4 SLEW SLOW 无影响** — 撤回也一样亮 (v34j W=橙, M 品红, B 蓝 + R 漏)
3. **`assign_bd_address` 必须显式加** — `reset_run` 后 BD `validate_bd_design` 会丢 panel_seq 的 0x40020000 segment (BD 41-1356), 不加 fix DAP-AHB 必 hang
4. **唯一有效改动: XDC R2/G2 pin swap (Y20↔AB21)** — 让 M 出品红 (vs v34g 几乎纯红)
5. **panel 5V 没接 = 静电流但显示全黑** — 寄存器读写 / state machine / PL LED 全正常, panel 黑 ≠ FPGA bug, 先检查 panel 电源

**残留真问题** (不在 verilog/XDC 这一层, 需要硬件改):
- W 永远是橙 (B 在 R+G 共存时被压)
- B 单色左下漏 R 块 (AB21 R2 跟 Y21 B2 仍有 cross-talk)
- panel 2 中间 cyan stuck 条 (已知 cells 49-52 hw chip 坏)

**Vivado batch 烧录踩坑细则** (新增 memory `feedback_vivado_batch_needs_settings64.md` 已写):
- `vivado.exe` 不在 PATH, 必须用 `C:\Xilinx\Vivado\2024.2\bin\vivado.bat` 绝对路径
- xsdb 报 `DAP status 0x30000021` 或 `0xF0000021` = JTAG 链路状态错乱, 必须冷循环板子 (软件 rst -dap / kill hw_server 都救不回)
- 反复 fpga -file + ps7_init + taskkill hw_server 会让 JTAG 链断, 烧 5 次内必请用户重启板子

## 状态 (2026-06-09 晚)

**v34g Phase 2 双 panel 128×128 拼接 — 8×8 渐变棋盘验证基本通过**:
- Panel 2 (viewer 左): cells 1-4, 9-12, ..., 57-60 ✓ 顺序正确
- Panel 1 (viewer 右): cells 5-8, 13-16, ..., 61-64 ✓ 顺序正确
- 8 行渐变贯通 (红→橙→黄→绿→青→蓝→紫)

## display_128x128.py 关键 transform (实测验证)

```python
# panel 1 (右): rotate(-90) + hw row 32 偏移 swap (panel ADDR 跟 panel 2 差 32)
def transform_for_panel1(img_half):
    hw = img_half.rotate(-90, expand=True)
    top = hw.crop((0, 0, 128, 32))
    bot = hw.crop((0, 32, 128, 64))
    swapped = Image.new('RGB', (128, 64))
    swapped.paste(bot, (0, 0))
    swapped.paste(top, (0, 32))
    return swapped

# panel 2 (左): 物理 BRG vs panel 1 GRB, 已物理换线
def transform_for_panel2(img_half):
    return (img_half
            .transpose(Image.FLIP_LEFT_RIGHT)
            .rotate(-90, expand=True)
            .transpose(Image.FLIP_TOP_BOTTOM))

# BCM 6-bit scaling + 色彩补偿 (必须):
r8 = min(255, int(r * 0.35))   # R 太亮要砍
g8 = min(255, int(g * 0.9))
b8 = min(255, int(b * 1.3))    # B 偏暗要升
r6, g6, b6 = r8 >> 2, g8 >> 2, b8 >> 2   # 8-bit → 6-bit BCM
word = r6 | (g6 << 8) | (b6 << 16)
```

## 左侧 viewer 位置 3 个固定缺陷 (反复 swap test 确认非面板)

| viewer cell 区 | hw col 条带 | 症状 |
|---|---|---|
| cells 57, 58 区 | hw col 0-15 | dim / 颜色异常 |
| cells 49-52 区 | hw col 16-31 | G+B 卡 ON (cyan blob 横带) |
| cells 11, 12 区 | hw col 96-111 | B 死 / dark patch |

**已排除**:
- ❌ Panel hardware: 用户物理交换两块 panel 后缺陷仍留在左侧 viewer 位置 (2026-06-09 测)
- ❌ BRAM 数据: SWAP test (panel 1 BRAM ↔ panel 2 BRAM 互换数据) 缺陷不跟数据走, 留在左侧
- ❌ Verilog 对称性: 逐行 grep panel 1 和 panel 2 路径, plane_rgb / pattern_24 / xpm_memory_sdpram 完全对称, 只是 BRAM 索引位 cur_aw_addr[16] 不同

**剩余怀疑**:
- IDC 排线 (panel 2 的 16 pin 数据线特定几根接触不良?)
- FPGA hub75e_rgb_out2 输出 pin 上的 SI/drive 问题 (AA19/AA13/Y13/AB15/AB14/Y16 中某根在特定 col_idx 时序下 drive 不动)
- BD 布线 / Vivado 实现时 panel 2 路径 critical path violation (需要查 timing report)

**Why:** 这 3 个 hw col 条带 (0-15, 16-31, 96-111) 落在特定 col_idx 区间, 不是连续 → 不是单根线坏, 更像 SI 或路径 timing.

**How to apply:** chess 已能识别 64 cell + 顺序 + 渐变正确. anime 可以推, 但这 3 个位置会有色斑. 想彻底修需要 Vivado timing report + 可能 PCB 改连接 + 或者改 IP routing constraint.

## W (R+G+B 全亮) 显示橙色 bug — 关键发现 (2026-06-09 晚)

8 色循环用 BRAM 验证:
- R/G/B 单色 ✓
- C (G+B) ✓ 完美青色 — **G+B 共存 OK**
- Y (R+G) 偏红橙 — G 部分弱
- M (R+B) 几乎纯红, B 整体消失 — **R 开 B 整掉**
- W (R+G+B) 橙色 — B 整掉

**结论: B 出不出取决于 R 是否同时 ON**. G+B 共存 OK, R+B / R+G+B 时 B 整体消失.

**怀疑 1 — panel 1 IO 差分对耦合**:
- panel 1 R2=Y20 (L9P DQS), B2=Y21 (L9N DQS) — **共差分对**
- 差分对 PCB 走线耦合让 R2 持续 HIGH 时把 B2 拉低
- panel 2 R2=AB15 (L24N), B2=Y16 (L14N) — 不共对, 但也表现 R+B fail

**怀疑 2 — DRIVE/SSO**:
- 默认 DRIVE 12 SLEW SLOW 对 36MHz DCLK 可能 SSO overshoot
- 多 RGB pin 同时 HIGH 时 bank 33 Vccio 瞬时 droop, B chip 阈值最敏感

## 准备好的 v34h 修复 (XDC + Verilog 等 build)

**XDC** (`hub75e_pins.xdc` 已改):
- panel 1 R2 ↔ G2 pin swap: R2 from Y20 (L9 DQS) → AB21 (L8), G2 from AB21 → Y20
- 所有 12 个 RGB pin 加 `DRIVE 4 SLEW SLOW`

**Verilog** (准备好但已 revert 等 build 验证 XDC):
- BCM bit slicing 从 `pattern_24[plane_ext + 5'd16]` 改成 byte slice + 3-bit plane indexing
- 防 Vivado synth 在多通道路径上奇怪优化

## Vivado batch ✅ 已通 (2026-06-09 22:09 翻案)

之前以为 batch 卡死, 实际是 `vivado.exe` 不在 PATH 里. 用 `C:\Xilinx\Vivado\2024.2\bin\vivado.bat` 绝对路径 + 前置 `call settings64.bat` 就行. 见 `feedback_vivado_batch_needs_settings64.md`.

v34h 走的命令:
```bash
cmd.exe /c "call C:\Xilinx\Vivado\2024.2\settings64.bat && cd /d D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq && C:\Xilinx\Vivado\2024.2\bin\vivado.bat -mode batch -source D:\claude_workspace\pov3d\zynq_pov\tools\build_v34h.tcl -log build_v34h.log -journal build_v34h.jou"
```

## 下次开机继续步骤

1. JTAG 接上 + 板子上电
2. cd /mnt/d/claude_workspace/pov3d/zynq_pov
3. dl_halt_green_test.tcl 或 anime_load_v34g_wordloop.tcl 看现 bit 状态
4. 如果是新 build 完的 bit: 跑 `_8color_cycle.tcl` idx 3 (W) 看是否出真白
5. 如果出白: XDC 改有效, 推 anime
6. 如果还橙: 加 verilog byte-slice 改 + rebuild 再测

## 已知 IP/SW 问题: W (R+G+B 全亮) 显示橙色 (B 整体掉)

- BRAM-fill 0x3F3F3F (或 0xFFFFFF) → panel 显示 R+G = 橙色, B 整体不出
- BRAM-fill 0x3F0000 (B 单) → 整屏蓝 OK
- BRAM-fill 0x3F003F (R+B = M) → 显示红, 无 B
- BCM=1 单 plane 也复现, 非 plane count 问题
- 怀疑 Vivado synth 在 `pattern_24[plane_ext + 5'd16]` 多通道路径上的 bug
- 试过改成 byte slice + 3-bit plane indexing 重 build, **Vivado 报 "Spawn failed: No error" 一直挂**, 没成功 rebuild
- 后续: 修复 Vivado 后重 build verify

**Why:** 影响纯白/带高 R 的混色显示. 红+绿一起 OK, 蓝单独 OK, 但 R+G+B 三通道时 B 永远不出.

**How to apply:** anime 显示如果包含大量"白"或"R+B"区域会色偏, 需要修 IP 后再用. 当前 chess 渐变没有纯白色, 不受影响.

## 文件位置

- IP: `02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v` (module `hub75e_panel_seq_v4`)
- BRAM 基址 (v34g):
  - FB_TOP1 = 0x40028000 (panel 1 row 0..31)
  - FB_BOT1 = 0x4002C000 (panel 1 row 32..63)
  - FB_TOP2 = 0x40038000 (panel 2 row 0..31)
  - FB_BOT2 = 0x4003C000 (panel 2 row 32..63)
- TCL: `tools/anime_load_v34g_wordloop.tcl` (改了 TUNIT=0x608, CTRL=0x521 use_fb 不 overlap)
- 8 色循环测: `tools/_8color_cycle.tcl <idx>` (idx 0..6 = R/G/B/W/Y/M/C)
- 棋盘生成: `tools/make_chess_8x8.py` → 4 bin
- driver 抽象: `tools/display_128x128.py`
- camera snap (Insta360 idx=1 MSMF): `tools/_snap_check.py`
