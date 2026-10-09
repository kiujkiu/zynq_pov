---
name: project_gw5a_loop_sit_0923
description: 2026-09-23 gw5a_loop 上机(10-09 复查仍 PASS) — 4lane@400M PASS(K=1 A=000F E=0); 800M 帽子 lane 有眼、跨电源脚的杜邦线 lane2 没眼; 跳线帽横短 TX→RX 才对、竖短 P/N 会烧驱动; 重扫用 SRAM 重烧不要按 KEY0; IODELAY SDTAP 硅上生效
metadata:
  type: project
---

# gw5a_loop 4 lane 上机 (2026-09-23, ACG525-CORE-V2 丝印 25B + CB-V2)

工程 `dr1v90/gw5a_loop/`, bit 在 `GW5A/loop_bits/`。下载器 FT2CH `--cable-index 1 --location 44`,
COM22 115200 (J5 CH9102, DTR/RTS 关)。重扫 = SRAM 重烧, **不要让人按 KEY0**。

## ✅ 4 lane @ 400 Mbps PASS

`gw5a_loop_n4_l400_verA.fs` 烧到 25B (USERCODE `0x00005BB3`, STATUS `0x70026020`):

```
GW5A-LOOP N=04 L=0400 ST=04
D=86882084 I=0000 Z=0000
S K=1 A=000F T=0 R=0000 B=015FFEFE E=00000000 Y=00000000 Q=0000 F=01
```

B 每秒 +`0x017C81B5` ≈ 2.49×10⁷ beat, E/Y/R/Q 一直 0。日志
`GW5A/loop_bits/sit_n4_l400_verA_20260923.log`。

接线: lane 0/1/3 用**横向**跳线帽 (P6 `1→3/2→4`, `5→7/6→8`, `15→17/16→18`);
lane 2 跨 P6-11/12 电源脚, 帽子够不着, 两根杜邦线 `9→13` / `10→14`。

## 800 Mbps: 帽子 lane 有眼, 长线 lane 2 没眼

同板同线 `n4_l800_verB.fs` (USERCODE `0x00004454`):

```
T=00 ..X.     ← 整份扫眼 lane2 列全是 X, 0/1/3 是 '.'
D=62640062 I=0000 Z=0010
S K=0 A=000B T=1
```

Z 是每 lane 一位 (`0010` = lane2 dead), 不是 16-bit 掩码。A=`000B` = bit0/1/3。
800M 要过 lane2 必须换短等长绞线; 现接线 400M 成立、800M 不成立。

无环回线基线 (烧完未接): `Z=1111 K=0 A=0000` (与 09-16 空扫一致)。

## 跳线帽口径 (原 wiring 警告写偏了)

P6 双排: 上排奇数 1/3/5/…, 下排偶数 2/4/6/…。
- **横帽** (1-3 与 2-4): TX 対 → 相邻 RX 対, 就是 lane 0/1/3/4/5/7/8 的正确短接。本次 0/1/3 就这么接, 400M/800M 都有眼。
- **竖帽** (1-2 / 3-4): 同一対 P 与 N 短路, 烧 LVDS 驱动。`wiring.txt` 里"别用跳线帽"指的是这种。
- 跨电源缝的 lane (2: 9↔13; 6: 27↔31) 帽子够不着, 只能杜邦线。

## 硅上坐实 (原先 "未验")

- **IODELAY SDTAP 脉冲装载生效**: 400M `D=86882084`、800M `D=62640062`, 各 lane 中心不同, 不是停在上电默认档。
- **ACG525 LED 高有效**: 见 [[feedback_acg525_led_active_high]]; loop_top `led={err,link,scan_done,locked}` 没取反是对的。
- 25B 可烧 verA 的 400M bit (冒烟 verA 同样能跑)。

## 操作坑

- `programmer_cli --cable-index 0` = GWU2X, 这块线是 FT2CH → index 1 loc 44。
- KEY0=重扫但是物理键; 接线后重扫走 SRAM `--run 2`, 串口先开着才能抓横幅/`T=`/`Z=`。
- 扫眼在接线前跑完会留下死眼延时, 状态行冻住 (`B/E` 不动, `R` 爆) —— 看起来像"线没接", 其实是旧扫。

## 600 Mbps: 同 800M, lane 2 没眼

自出 `n4_l600_verB.fs` (WNS +7.143, USERCODE `0x0000905E`):

```
GW5A-LOOP N=04 L=0600 ST=04
T=00 ..X.
D=76760072 I=0000 Z=0010
S K=0 A=000B T=1
```

长线边界: **400M 过 / 600M 不过 / 800M 不过**。帽子 lane 三档都有眼。日志
`GW5A/loop_bits/sit_n4_l600_verB_20260923.log`。板子已烧回 400M 保持 PASS。

13 lane 要再加 P6/P11 帽子, 动线才做。800M 等 lane2 换短线。
相关: [[project_gw5a_bridge_verification]] [[project_gw5a_bridge_firmware]] [[feedback_acg525_led_active_high]]

## 2026-10-09 复查：板子重新接上，400M 仍 PASS

用户 10-09 晚「接了高云的 FPGA」。`programmer_cli` 必须在 `Programmer\bin` 目录下经 `cmd.exe` 跑，
否则报 `MAINCMD module not found`；扫到 FT2CH loc 44，IDCODE `0x0001281B`，Target `GW5A-25B`。

- **重烧前**板上已在跑旧环回 bit（上电从 Flash 起的，或一直没断电），计数器停在
  `R=77FD E=302051D9 Y=EDF26461`，K=1 A=000F ⇒ **长时间挂着期间积累过误码/重同步**，原因未查
  （可能插拔/碰线）。只当现象记下，不当结论。
- SRAM 重烧 `gw5a_loop_n4_l400_verA.fs`（USERCODE `0x00005BB3`, STATUS `0x70026020`）后：
  扫眼 `T=34~3C` 有 X 带、其余全 `.`，`D=84863684 Z=0000`，20 s 内 `K=1 A=000F R=0 E=0 Y=0`，
  B 每秒 +`0x017C825F`。日志 `GW5A/loop_bits/cap_com22_1009.log`。
- 跳线（lane 0/1/3 横帽 + lane 2 杜邦）仍在原位。

命令（WSL）：
```bash
cd /mnt/c/Gowin/Gowin_V1.9.12.03_x64/Programmer/bin && cmd.exe /c "programmer_cli.exe --device GW5A-25B --run 2 --fsFile D:\...\x.fs --cable-index 1 --location 44 --frequency 2.5MHz"
```
串口抓取：`powershell.exe -File GW5A\loop_bits\cap_com22.ps1 -Seconds N -Log ...`（先起抓取再烧）。
