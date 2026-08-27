---
name: pov2 台面全黑排查 — pov_boot.sh 取帧顺序 bug (2026-08-27, 待上板验证)
description: 台面无电机时 fb 只按 1-bit 布局被写过一次 ⇒ 56% 读地址恒 0 ⇒ 近乎全黑; 附一串被证伪的假设与量具边界
type: project
---
2026-08-27 在 pov2（第二台 Zynq，见 [[reference_pov3d_board_inventory]]）上排查"屏全黑"，
耗了大半天。**结论先行：屏和硬件链路是好的**（用户在转接板 J1 上量到 RGB 有波形、屏亮过）。

## 🔴 代码级根因（行号已核，**尚未上板验证**）

```
pov_boot.sh:123   pw(0x10, (142<<16)|0x5)      ← pov_en=1, 触发全机唯一一次取帧
pov_boot.sh:151   pw(0x0C, (1<<30)|…|(1<<16))  ← bpp_mode=1 到这里才打开, 晚了 28 行
```

- `pov_dual_top.v:387` —— **只有 `slice_idx` 变化才重新取帧**
- 无电机 + sensor 模式 ⇒ `angle_tracker.v:103` 的 `track_en = fake_en | (…)` = 0
  ⇒ `slice_idx` 定格 ⇒ **fb 一辈子只被写那一次**
- 那一次 `bpp3_r` 还是复位值 0，按 1-bit 取：`slice_off = idx*0x3000`，**只写 plane0**，
  fb 最大写地址 429；实际取到的是 **slice 25 的 plane0**，不是 slice 75
- 随后 `bpp_mode=1`，引擎按 3-bit 读 `pack_addr = row*18 + plane*6 + word`，范围 0..971
- ⇒ **972 个读地址里 542 个(56%)从没被写过 = 恒 0**，其余 430 个全部错位 ⇒ 近乎全黑

**为什么之前没暴露**：转起来时 `pov_rxd`/fake-spin 每片都在重取，bug 被完全掩盖。
`pov_rxd.c:3393` 除非带 `--fake` 否则从不碰 `POV_CTRL` ⇒ **永不自愈**。
它只在**台面 + sensor 模式 + 无电机**这个组合下致命。

**补丁**（已写进 `stream/board/pov_boot.sh`，未部署）：在 sub01 之后补一次 `pov_en` 0→1 脉冲，
`!pov_en` 会把 `df_last_slice` 复位成 `0xFFFF`（`pov_dual_top.v:417-421`）强制重取。

## 🔴 pov6_hold.py / pov6_fake.py 有真 bug

它们写 `0x10` 时带 `(360<<16)`，**每次都把 `n_slices` 从 142 砸成 360**。
`pov_dual_top.v:335-336`：`if (s_axi_wdata[31:16] != 16'd0) n_slices_r <= …`
—— **[31:16] 写 0 才是"不改 n_slices"**。用这两个脚本前要知道这一点。

## ⚠ 量具边界：oeprobe 测不到引脚

`icnd2047_panel_core.v:132` 原话「OE fabric 镜像（pad 是 ODDR，**不可回采**）」。
`oeprobe` 读的是 ODDR 的**输入端**触发器；DCLK/LE/SDI/行驱三线同样全经 ODDR，
**十二根线一根都不可回采**。所以 oeprobe 那组漂亮的占空比
（实测 0.247↔oe=48 / 0.550↔3-bit BCM / 0.570↔oe=111，全部分毫不差）
只证明**引擎 A 的状态机在按正确参数跑**，证明不了信号出了引脚。
真正跨过 ODDR 的只有示波器。⚠ 别再拿 oeprobe 的结果说"信号是好的"。

## 本轮被证伪的假设（别再查）

- **ICND2047 掉电要重配** ✗ —— 手册 P15 `REG1.R_IGAIN` 默认 `0xf` = 增益 100% 满电流，
  REG2 默认全 0 = 开路检测关闭；且现役 bitstream **根本没有写这两个寄存器的通路**
  （`panel_engine_2047.v:100-109` 把 `cmd_*` 全 tie 0）。原理上不可能解释"亮过之后再不亮"。
- **OE 极性反了** ✗ —— 手册 P12 / RTL `oe_r` 语义 / 亮度与 `oe_window` 单调正相关的历史实测 /
  屏原理图全链路无反相元件，四条独立证据。
- **FS03 跳帽 J1 (ADJ_BANK13) 掉了** ✗ —— DCLK 在 J1 上有波形，同 bank 的引脚是活的。
- **卡上 BOOT.bin 版本不对** ✗ —— 镜像逐字节确认是 prelz4；且 prelz4 与 lz4x3 的
  panel core 是同一套 RTL，点屏能力不变。
- **`frame_period=31590` 能证明引擎在扫** ✗ —— 它是帧末锁存的**残值**，引擎卡死也不归零
  （`icnd2047_panel_core.v:497-500`）。⚠ 但它**变化**时是有效的：1-bit/oe187 实测 14634，
  与理论值精确吻合，可用来确认配置真的生效了。

## 顺带确认

- pov2 的 PL 一直是卡上的 **prelz4**（三个 lz4 引擎自检全判死就是它的硬特征）；
  第一台 pov 跑的 `lz4x3` 是开机后用 `fpga_manager` + configfs overlay 从
  `/usr/lib/firmware/pl_lz4x3.bit.bin` **运行时**灌的，不在卡上。
  2026-08-27 在 pov2 上第一次灌上 lz4x3，`PLDIAG eng=3/3 ok=1` 确认生效。**断电即回退**。
- **列驱是恒流源**：点亮通道数不改变单颗 LED 亮度，只改总电流。
  **唯一的亮度旋钮是 OE 占空**，核内硬箝 `[2,187]`（`icnd2047_panel_core.v:158-159`）。
- `row_cfg (0x24)` 的 **bit19 是 SDI 反相** —— 置上会让 160 行几乎全导通，
  恒流下每颗暗 53 倍，"看起来和没亮一模一样"。排查时先 `pw(0x24, 0)`。
- 屏 J1 针位：DCLK=25 / LAT=26 / OE=27 / R1=32 G1=8 B1=31 / R2=9 G2=30 B2=10 /
  R3=29 G3=11 B3=28 / 行驱 A=34 B=7 C=33。⚠ 转接板 J1 是行序编号，屏 J1 是奇偶编号。

## 🔴 同一天挖到的第二个 bug: WiFi 等不到网卡就永久放弃

`pov_boot.sh` 的 WiFi 段有 30 秒轮询等 `^wl` 接口, 等不到就
`echo NO_WLAN_STATIC_ONLY; exit 0` —— **之后再也没有任何东西会把 WiFi 拉起来**。

实测 mt7921u 有过 **403 秒**才枚举出来的情况:

```
[  13.87] ci_hdrc.0: USB 2.0 started          <- 30 秒窗口 = uptime 14s ~ 44s
[ 403.68] usb 1-1: new high-speed USB device  <- 网卡到这时才枚举
[ 406.39] wlx90de8047f0ff: renamed from wlan0
```

网卡后来出现了、而且一直好好待着, 但没人管 ⇒ **板子永久失联, 只能插串口救**。
**这就是 [[reference_fs03_board_access]] 里那条「WiFi 会掉且不自愈」的真正机制,
不是射频问题, 也不是 AP 的问题。**

已修 (commit `7a8e478`, 已部署 pov2): 改成后台守候, 每 5s 查一次最多 20 分钟,
接口一出现就走同一套 wpa_supplicant + dhclient。⚠ 待下次开机验证。

手动救援 (串口里跑):
```sh
sudo pkill wpa_supplicant
sudo wpa_supplicant -B -i wlx90de8047f0ff -c /etc/wpa_supplicant/wpa.conf
sudo dhclient wlx90de8047f0ff
```

## 串口

- **pov2 = COM9** (CH342 双通道的 A 路; B 路 COM8 无输出)。115200 8N1, 登录 `uisrc`/`root`。
- **安路 DR1 = COM5** (另一颗 CH342 的 A 路), 登录提示符是 `anlogic login:` ⇒ 与
  网上那台 dropbear (`10.10.21.86`) 对得上。
- COM 口号会变, 别写死。列端口: `powershell.exe -NoProfile -Command "Get-CimInstance
  Win32_PnPEntity | Where-Object {$_.Name -like '*(COM*'} | Select-Object -ExpandProperty Name"`
  (`mode COMx` 的输出是 GBK, grep 会乱码)。

## 遗留

- **蓝色不亮**（2026-08-26 起）仍未定案 —— 全黑问题压过去了，还没回头查。
- 补丁未上板验证；验法：跑 `pov_boot.sh` 后不碰任何东西，看屏上有没有出现螺旋管截面。
