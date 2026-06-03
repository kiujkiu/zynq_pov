---
name: POV3D LED panel 首次点亮 (2026-05-27)
description: ICND1069+ICND3019 panel 终于点亮关键 fix 总结 — 双 chip PL IP + cascade=4 + pin 映射修正
type: project
originSessionId: 42b483be-17d4-4bd8-9194-41c6b8158af7
---
经过近 2 周 bring-up, 板子终于亮起来 (2026-05-27). 把所有关键 fix 汇总, 避免下次跌坑.

**关键 fix（按必要顺序）**:

1. **PL IP free-running DCLK 12.5 MHz 50% 方波** (led_panel_seq.v V2)
   - 之前 DCLK 只在命令期间跑, 命令间隙静止 → ICND1069 PLL 失锁 / 时序错乱
   - 重构为分离 clock divider + event-driven sequencer
   - FCLK1 保 75 MHz (IO_PLL 1800/24 精确), DCLK_DIV=6 → DCLK = 精确 12.5 MHz 3H+3L = 50% 占空比
   - 改 FCLK1=100MHz 不可行 (Vivado PS7 IP 报 "100 out of range {-2,-1}")

2. **CHIPS_PER_CHAIN = 4** (官方 cascade, bin 反解)
   - 之前用 1 → 后 3 颗 chip 收不到 reg 配置
   - 反解证据: WR_CFG 之间 73 DCLK = 4×16 shift + 9 DCLK gap

3. **SDI 在 DCLK 下降沿 update** (chip 上升沿采样, 半 DCLK setup)
   - led_panel_seq FSM S_DCLK_HI div_tick: falling DCLK 同步写 SDI/LE next bit

4. **PL IP 1 槽 cmd queue** (eliminate WR_CFG 间 ARM polling gap)
   - AXI 写 cmd 条件改 `!cmd_pending` (不是 !busy)
   - status reg bit[1] = cmd_pending, ARM API: panel_seq_wait_can_accept

5. **每 LE 命令后插入 16 DCLK gap** (chip 内部 commit 时间, 官方实测 ~9 DCLK)
   - wr_cfg / le_marker 末尾加 `panel_seq_word(0, 0)`
   - LATCH 循环每个 LATCH 后也加

6. **ICND3019 移到 PL IP 直驱** (CRITICAL fix!)
   - ARM bit-bang BIN/AIN 时序太烂, chip 采不到, OUT 永远 HIGH
   - 加 PL 输出: icnd_sdi_out, icnd_dclk_out, icnd_rclk_out
   - 加 PL FSM: 严格保证 DCLK HIGH ≥500ns (我们用 850ns), setup/hold ≥20ns
   - AXI 0x08 写 ICND3019 cmd, status bit[2] = icnd_busy

7. **ICND3019 pin 映射 (踩坑！)**: 用户硬件标 AIN/BIN/CIN 跟实际信号不对应！
   - 真实物理连接: **W16 (标 CIN) = ICND3019 SDI/DIN** (不是 AIN!)
   - W18 (标 AIN) = ICND3019 DCLK
   - W17 (标 BIN) = ICND3019 RCLK
   - 老 ARM bit-bang 代码用 AIN 当 SDI / BIN 当 DCLK 完全错了, chip 收到错乱时序
   - 教训: **panel 上标的 pin 名 ≠ 实际信号**, 必须看官方波形反推

8. **5 个官方 WR_CFG init 序列** (LE=5 each, cascade=4 = 64 DCLK shift):
   ```
   #1 addr=0x00 val=0xAA (PASSWORD_A 开锁)
   #2 addr=0x01 val=0xAA (PASSWORD_B)
   #3 addr=0x20 val=0x09 (未文档化 magic, 关键)
   #4 addr=0x00 val=0x55 (PASSWORD_A 关锁)
   #5 addr=0x01 val=0x55 (PASSWORD_B)
   ```

**关键文件**:
- `02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/led_panel_seq.v` — PL IP V2
- `02_hello_zynq/vitis_ws/hello_world/src/panel_seq.h` — C API (含 ICND3019)
- `02_hello_zynq/vitis_ws/hello_world/src/led_panel.c` — mode_a_minimal
- `02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/led_pins.xdc` — pin 映射

**当前状态 (2026-05-27 21:40)**: panel 完全不亮, 排线/电源问题, 等用户硬件检查.
**之前进度**: 见前面 "8 个关键 fix", 包括 cascade=12, init once + EN_OP 首帧后, 160 行 × 6 LATCH 等.

**重大确认 (2026-05-27)**: pin 映射完全对
- 看 panel 原理图: J1.14 = GCLKIN' (schematic 标签) = ICND1069 ROW 引脚 (chip 真名) → AA19
- J1.26 = CIN = ICND3019 SDI/DIN → W16
- J1.27 = BIN = ICND3019 RCLK → W17
- J1.28 = AIN = ICND3019 DCLK → W18
- panel 是 180×160 (W×H), ICND1069 cascade = 12 (15 IO × 12 = 180 col), ICND3019 = 24 chip (6 组 × 4 cascade, 每组 4 chip)

**尝试过失败的配置**:
- SCAN=19 + GAIN=0xFF 写 reg → 之后 panel 卡死全黑, 软件 reset 救不回, power cycle 也救不回
- 各种 row count (20/54/160) + LATCH per row (1/6/19/50) 组合都只能看到 6-10 矩形, 无法全 panel 亮
- 30+ 次 build+DL 后 panel 状态变, 不复现

**下次要 power-cycle panel 重测**, 软件已回 v10 已知能亮的 baseline (20 行 × 16 LATCH + SDI=1 全部行 + EN_OP 首帧后).

**🎨 R/G/B 全色验证通过 (2026-05-28 10:25)**: panel 整片红色干净覆盖 (commit d30ce12).
- PL IP V3 加 AXI 0x0C = sdi_mask (9-bit per-chain enable)
- C API: `panel_seq_set_sdi_mask(0x049/0x092/0x124/0x1FF)` R/G/B/白
- 实测 R/G/B 三色都干净覆盖整片 panel, cam_mean=120-148 循环

**🎉 BREAKTHROUGH (2026-05-27 22:35)**: panel 整片亮! 单一绿白色全覆盖, mean=122.6.

**关键发现**: ICND1069 chip RAM **跨上电不复位**, 之前 SCAN=19 / GAIN=0xFF 错值
留在 chip 里阻断后续操作. 解法 = **显式写所有寄存器回 datasheet 默认值**:

```c
wr_cfg(0x02, 19);    // SCAN 1/20
wr_cfg(0x03, 0x00);  // GROUPS 1 sub-frame
wr_cfg(0x04, 0x02);  // PLL_PRE_DIV
wr_cfg(0x05, 0x04);  // PLL_LOOP_DIV
wr_cfg(0x06, 0x01);  // PLL_POST_DIV
wr_cfg(0x07, 0x20);  // GCLK/row
wr_cfg(0x0D, 0x02);  // 消隐
wr_cfg(0x0E, 0x06);  // 第一行暗补偿
wr_cfg(0x1C, 0xC0);  // GAIN (不是 0xFF!)
wr_cfg(0x1D, 0xA6);  // 慢速开启
wr_cfg(0x20, 0x09);  // magic
wr_cfg(0x26, 0xAA);  // password
```

完整 commit: 9ded6c3 (branch panel-1655-redfull).

**最终状态 (2026-05-27 22:00 旧)**: panel 完全不亮无法恢复, 5 分钟断电后仍黑.
- 硬件检查: 电源 LED 亮 ✓, 排线插紧 ✓, VCC 3.8V 正常 ✓
- 软件: 已回最早能亮的 v10 baseline
- 推测: 多次 SCAN/GAIN reg 写 + 反复 DL 让 chip RAM 卡进异常 mode, 单纯 panel power cycle 救不回
- 下次方向: (1) 等更久断电 (1h+) 或 (2) 示波器测 SDI/DCLK/LE/ROW 信号到 chip pin 实际状态 (3) 试别的 panel 排除硬件确认问题在 chip RAM

**关键教训**:
- ICND1069 reg 写要慎重, SCAN/GAIN 错值可能让 chip 进 calibration mode 软件救不回
- 0x20=0x09 magic reg 必写, 其他 reg 用 chip default (没把握不要瞎写)
- 反复 DL 测试有累积 chip state 风险, 应该每次大改前先 panel power cycle

**下一步**:
- 调试: 黑条具体位置 (cam vs 物理) → 推断硬件 vs 软件
- 实现真扫描 (行 0 inject 1, 行 1-N inject 0)
- 写真实 framebuffer 数据 (不再 0xFFFF 全开)
- 颜色 / 灰度 / 1/20 scan / 帧率

---

**🗺 Chain → 区域映射 (2026-05-28 13:00)**: tools/c_*.jpg snap 序列证实
chain 索引对应水平 1/3 panel 宽度区域, 不是行组. (V2 build, 还没刷 V3.)

snap 循环 9 个 single-chain mask (60 帧切一次):
- c_1 (R1=0x001): 红色竖条在 RIGHT 1/3
- c_2 (G1=0x002): 紫蓝色竖条在 RIGHT 1/3
- c_3 (B1=0x004): 绿色竖条在 MIDDLE 1/3
- c_7 (R2 or 类似): 红色竖条在 MIDDLE 1/3
- c_9 (G2 or 类似): 绿色竖条在 LEFT 1/3

⚠ 注: snap 时刻和 mask 相位不严格对应 (snap 间隔 3s × 10 帧 = 30s, mask 切换 240ms),
所以具体 chain index → 区域映射要再做单帧确认. 但 *chain → 1/3 宽区域* 结构确定.

**✅ ICND3019 chain 没问题 (2026-05-28 14:30, commit 4b49a8a)**: 4-phase probe
验证, panel 可全均匀点亮. 之前以为的"6-8 条横带"是相机 rolling shutter + LED
PWM 摩尔条纹假象.

Probe phase 循环 (mask=0x1FF 全色, 30 帧/phase):
- phase 0: SDI=1@row0 only (chain walk)
- phase 1: SDI=1 always → 全 chain pos 高 → 全 row enable → probe_12 panel
  完全均匀全白 mean=174 ✓
- phase 2: SDI=0 always → 全 chain pos 低 → 全 row disable → panel 全黑 mean=2.9 ✓
- phase 3: SDI=1 前 8 row → 8 chain pos 高 → 8 条真亮带 mean=108 ✓

→ ICND3019 chain advance + 1069 SCAN 多路复用都 OK. 384 advance OK (chain 自然
shift out 不出错).

**🚧 PL IP V3 per-chain SDI 还没刷板** (commit 2b08f71): 代码就绪但需要 synth+download 才能验
per-chain mode 2'b11. 当前板上跑的是 V2 (broadcast + sdi_mask).

**📷 摄像头抓图 (2026-05-28 更新)**:
- icspring camera = **MSMF idx1** (推荐) 或 DSHOW idx1
- ffmpeg dshow 重复打开会 lock device (假"in use"错), 用 cv2 替代
- DSHOW idx0=C1-1 HDMI capture (常 mean=0 黑屏), idx2=OBS Virtual Camera (假帧)
- DSHOW idx1 会被 dl_helloworld 之后锁住, **改用 MSMF idx1** (cv2.VideoCapture(1, cv2.CAP_MSMF))
- helper: tools/cap_cv.py (12 帧 0.4s 间隔)

---

**🔬 Sub-module 标定 + per-pixel 架构 (2026-05-28 19:00, commit fa5896f)**:

用户澄清: panel block = 1 ICND1069 × 15 col + 4 ICND3019 × ~53 row.
panel = 36 blocks (12 col block × 3 row band).
9 chain × 12 chip = 108 = 36 × 3 colors ✓

但 calibrate 显示 per-LED 控制不完整:
- 1 chip × 1 bit (全 row_iter) = ONE 横条 across panel
- 窄 row_iter range = 几个分散小点 (1069 SCAN 1/20 sub-row 选)
- 真单像素 = chip + bit + 单 row_iter, 但 duty 1/384 不可见

实际可控粒度: **1728 个 "bar 位置"** (9 chain × 12 chip × 16 bit). 每 bar
= 1 row × 多 col. 不是单 LED 控制, 但够画图 (oval/字/动画).

要解锁真单 LED 需 PWM BCM + sub-row 时序同步, 大工程.

**🎬 LED 屏幕显示动画达成 (2026-05-28 17:00, commit a073c03)**:

V4 PL IP race-free + mode_mosaic 4-frame 动画, panel 显示真"anime-style"
彩色马赛克动画.

栈架构:
- PL IP V4 (commit 9668e0e): mode 2'b11 per-chain + pending_chain_data
  snapshot at queue time, ARM 无需 wait_can_accept
- LED 显示分辨率: 3 col region × 8 visible chip row = 24 cell
- 每 cell 8 色 (3-bit RGB, 通过选 R/G/B chain on/off)
- 4 frame palette cycle, 30 帧切, 1Hz 循环
- 物理 panel cascade 可见 chip ~8 个 (cascade 12 但 chip 8-11 不亮)

发现的限制:
- 1 bit ≠ 1 像素: 1 bit on 点 ~600 LED 矩形 (~45 col × 14 row), 不是单 LED
- per-bit col 控制理论可行 (3 region × 16 bit = 48 col), 但 bit↔col 顺序
  未 reverse map, smiley bitmap 显出形状 ≠ 期望笑脸
- chip↔row 物理顺序未确定 (color_grid 试 chip 0..3 R + 4..7 G + 8..11 B
  显示 top 红 + bot 绿, BLUE 不可见, 说明 chip cascade 顺序不简单)

下一步升级:
- HDMI FB sample → cell 色实时数据
- per-bit 反向映射 → 48×8 真分辨率
- chip↔row 反向映射 → 平滑 row 位置控制

**🎨 V3 per-chain SDI 验证通过 (2026-05-28 14:45, commit da04670)**:
PL IP V3 mode 2'b11 + chain_data buffer 全 OK. 3 段竖条 R/G/B 实拍干净.

**chain → region 完整映射** (snap 直接证):
- chain **0,1,2** = R/G/B for **右 1/3** (region 1)
- chain **3,4,5** = R/G/B for **中 1/3** (region 2)
- chain **6,7,8** = R/G/B for **左 1/3** (region 3)

mode_perchain_bars 实现: chain_data set once, 12 LATCH × panel_seq_word_perchain
(CHIPS_PER_CHAIN=12 cascade), 最后 LATCH le_count=1. 每 row 12 LATCH 全填 chain.
