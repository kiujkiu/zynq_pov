# icnd2260 — 鹿小班驱动 ICND2260 的首次点亮工程

纯 PL，不依赖 PS：板载 50 MHz 晶振起时钟，JTAG 下载 bit 就跑，不用 Vitis / ps7_init。

目标硬件：**鹿小班 XC7Z020-CLG484** + 转接板 `zynq-lxb_2260_V0.1` + 单颗 ICND2260（40×48）。

**两套 PHY，协议层与序列器共用**：

| | 顶层 | 约束 | 说明 |
|---|---|---|---|
| **mini-LVDS**（主线） | `icnd2260_lxb_lvds_top` | `xdc/lxb_icnd2260_lvds_pins.xdc` | 🔴 需先把 BANK 33 改 2.5V，见 [`docs/02_lvds_bringup.md`](docs/02_lvds_bringup.md) |
| TTL 3 通道（退路/调试） | `icnd2260_lxb_top` | `xdc/lxb_icnd2260_pins.xdc` | 3.3V 就能跑，25MHz 双沿 = 150 Mbps |

⚠ 两套的**帧格、时钟相位、第一通道、寄存器表全都不一样**，别混用。差异清单见
[`docs/02_lvds_bringup.md`](docs/02_lvds_bringup.md) §1。
转接板网表与协议要点在 [`docs/00_board_and_protocol.md`](docs/00_board_and_protocol.md)。

```
rtl/
  icnd2260_tx.v            TTL 协议层: I_SYNC 分隔的指令帧格 + 双沿位串行化
  icnd2260_lvds_tx.v       mini-LVDS 协议层: RSYNC/4倍过采样/CRC/I_SYNC 每帧一翻
  icnd2260_seq.v           上电流程 (编程指导 §12) + 帧循环 + 读探针 (两套共用)
  icnd2260_ack_rx.v        ACK 回传解调 (脉宽编码 -> 拆包 -> CRC 校验, 两套共用)
  icnd2260_lxb_top.v       TTL 顶层
  icnd2260_lxb_lvds_top.v  mini-LVDS 顶层 (90° 移相时钟 + OBUFDS)
  icnd2260_regs.mem        寄存器默认值 TTL 版      ← 生成物, 别手改
  icnd2260_regs_lvds.mem   寄存器默认值 LVDS 版 (0x06[9]=1, 0x1a[9]=1)
  icnd2260_fb.mem          帧缓存测试图 {B,G,R}     ← TTL 用
  icnd2260_fb_lvds.mem     帧缓存测试图 {R,G,B}     ← LVDS 用 (第一通道是 B!)
  icnd2260_regs_lvds1.mem  单通道寄存器表 (0xb4[5:4]=00) —— 数据通路未实现, 见 docs/03
tb/
  icnd2260_seq_tb.v        TTL  自校验测试台 (内含协议解码器, 逐字段对拍)
  icnd2260_lvds_tb.v       LVDS 自校验测试台 (含独立重算 CRC)
  icnd2260_ack_rx_tb.v     ACK 解调自校验测试台 (造波形 + 改坏 CRC + 毛刺)
xdc/lxb_icnd2260_pins.xdc, xdc/lxb_icnd2260_lvds_pins.xdc
tools/
  gen_reg_defaults.py    从手册 §11 表格生成 .mem + sw/icnd2260_regs.h (带自检)
  gen_test_pattern.py    生成帧缓存测试图
  schdoc_netlist.py      直接解 Altium .SchDoc 抽网表 (PDF 会是旧版, 别信)
  run_sim.sh             跑仿真 (TTL + LVDS 两套)
  synth_check.tcl        TTL  版综合+布局布线+时序+DRC 自检
  synth_check_lvds.tcl   LVDS 版同上
  build_bit.tcl          出 bitstream: -tclargs lvds | ttl
  build_bit_dbg.tcl      出带 VIO 调试核的 bit (+ .ltx), 见 docs/04_fps_sweep.md
sw/icnd2260_regs.h       PS 侧要用时的同一份寄存器表 ← 生成物
```

## 跑一遍

```bash
./tools/run_sim.sh            # TTL + LVDS 两套, 缩短版
./tools/run_sim.sh --full     # 两套全尺寸 (48 扫 / 64 空屏帧)
./tools/run_sim.sh --only lvds

# 综合到布线 + 时序 + DRC (Windows 侧 Vivado)
cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\icnd2260 && \
  call C:\Xilinx\Vivado\2024.2\settings64.bat && \
  vivado -mode batch -source tools\synth_check.tcl"
```

当前状态：**三套自校验仿真全过**（TTL / LVDS 全尺寸 + ACK 解调 4 个用例）；
布线都过 —— TTL WNS +0.411 / WHS +0.118，LVDS WNS +0.212 / WHS +0.037；
DRC 只剩纯 PL 设计固有的 `ZPS7-1`。**还没上过板。**

⚠ LVDS 的 WHS 余量小是因为约束用的是「数据沿卡在时钟沿 ±(1/4周期−1ns)」这个
**自定的**窗口（手册没给 TTL/LVDS 的板级 tSU/tHLD），不是真实器件余量。

## 上板前先做这几件事

**走 mini-LVDS（主线）**：整份清单见 [`docs/02_lvds_bringup.md`](docs/02_lvds_bringup.md)，
第一件是把鹿小班 BANK 33 改成 2.5V（换 U6 的 R13：33K → 22.6K），不改出不了 LVDS。

两条路都要做的：

1. **确认 LED 板上 `LVDS_EN` 的接法**：走 LVDS 要拉**高**，走 TTL 要拉**低** ——
   这根就是两种模式的物理开关，接反了数据全丢。LED 板图纸不在本工程里，得先看。
2. **测试图先用最小电流的**：默认 `gradient` 会把 1920 个像素全点亮（1/16 满量程）。
   首光建议先只点一个像素：
   ```bash
   python3 tools/gen_test_pattern.py --iface lvds --mode single   # LVDS 用
   python3 tools/gen_test_pattern.py --mode single                # TTL 用
   ```
   然后 `cross`（十字 + 边框，用来看方向和缺行）→ 最后 `gradient`。
3. **鹿小班的 boot mode 拨到 JTAG**（SW3，见记忆 `feedback_lxb_boot_mode_sw3`），
   否则 PL 可能起不来。

## 板载 LED 的含义

| LED | 含义 |
|---|---|
| LED1 (P20) | 常亮 = 卡在上电/配置阶段没进正常显示；闪 = 帧循环在跑 |
| LED2 (P21) | **亮 = 收到过一条 CRC 正确的 ACK 回包** |

LED2 比"屏亮不亮"硬得多：屏不亮还可能是电流、灰度、LED 板的事，而 LED2 亮说明
**链路通 + 芯片收到了指令 + CRC 那套推断是对的**三件事同时成立。
序列器每 `READ_PROBE_FR` 帧（默认 16）插一条读寄存器指令来产生这个回包。

## 分支

板子到了按 [`docs/03_branches.md`](docs/03_branches.md) 的分支矩阵二分：
主线 `feature/icnd2260-lvds`，另有 `-ttl`（不用改电阻就能先试）/ `-phase270`（相位）/
`-nocrc`（CRC 推断）/ `-slow`（速率）四个二分变体，
外加 **`-debug`（VIO 调试核）—— 作为验证平台真正要用的那个**。

## 作为 2260 验证平台

立项目的是实测这颗芯片的帧率上限（目标 ≥9,000 fps）。两件事要分清：
**链路可发帧率**由 `CLK_DIV` 定（只有 `CLK_DIV=6` 那一档能过 9,045），
**芯片显示帧率**由 2260 寄存器定（默认表只有 763 fps，必须改 `0x00`/`0x01`）。
算法、扫参数的步骤、以及高速档要同步放宽时序约束这件事，全在
[`docs/04_fps_sweep.md`](docs/04_fps_sweep.md)。

## 参数在哪调

| 想改什么 | 改哪 |
|---|---|
| DCLK 相位（首光打不出来时第一个要试的） | 顶层 `DCLK_INV` / `DCLK_Q90` |
| 级联颗数 / 扫描行数 | 顶层 `CASCADE` / `LINES`（VHEAD 会跟着变） |
| TTL 通道数 1/3/6 | `NLANE` + 寄存器 `0xb4[5:4]`（**两处都要改**） |
| 电源上电顺序 | `icnd2260_seq` 的 `POWER_2V8_FIRST` |
| 上电等待时间 | `RAIL_STAGGER` / `RAIL_SETTLE`（默认各 20 ms @25MHz） |

## 还没做

- **ACK 回读**（读寄存器指令 + 脉宽解调）—— 验证「芯片是否活着」最硬的判据，见 Q4
- PS 侧通路：现在帧缓存是 `$readmemh` 初始化的常量，还没有 AXI 写口
- 校正数据（CHEAD）通路：`icnd2260_tx` 里指令种类已经留好，序列器还没用
- 正式 POV 参数：默认寄存器表算出来只有 ~763 fps，见 Q3
