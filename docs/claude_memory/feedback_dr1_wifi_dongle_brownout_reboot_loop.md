---
name: feedback_dr1_wifi_dongle_brownout_reboot_loop
description: 🔴 DR1(FS03) 用电脑 USB-C 口供电时, MT7921AU 下完固件、射频一上电整板就复位 ⇒ 约 18 s 一轮的重启循环(90 s 抓到 5 轮, 时间戳偏差 ±70 ms); USB 口本身是好的(U 盘 480M 正常枚举), 网卡本身也是好的(插电脑 Code 28 = 仅缺驱动)
metadata:
  type: feedback
---

# WiFi 网卡把 DR1 拉进重启循环 (2026-09-14, 原本是去跑 03_wifibw 测速)

## 现象链 (每一步都有板上证据)

| 阶段 | 看到的 | 证据 |
|---|---|---|
| 1 | `povboot.sh wifi` 报 `wlan0 never appeared` | modprobe rc=0, 固件 md5 全对, vermagic 一致 |
| 2 | USB 总线上只有根集线器, **无 `0e8d:7961`** | HPRT0=`0x1000`(PrtPwr=1, ConnSts=0), dmesg 零枚举记录 |
| 3 | 网卡插电脑 | `USB\VID_0E8D&PID_7961`, `ConfigManagerErrorCode 28` ⇒ **网卡好** |
| 4 | U 盘插 DR1 | `14cd:1212 speed=480`, HPRT0=`0x1005` ⇒ **口和 5V 对小电流设备是好的** |
| 5 | 网卡插回 DR1, **只听不发**抓串口 90 s | 每轮: `2.75 s usb 1-1 new` → `9.4 s reset` → `9.8 s HW/SW Version` → `9.85 s WM Firmware Version` → **紧接 `In Stage 1`(FSBL)**, 中间无 panic/oops |

⇒ **固件下完、射频启动那一刻的电流阶跃让整板复位。** 限流开关跳闸只会让网卡自己掉电,
整板复位说明主轨 `VCC_5V0`(给所有 DC-DC 供电)塌了。与 [[feedback_dr1_panel_current_brownout]] 同一形状。
✅ **单变量 A/B 已做(同日)**: 只把电脑 USB-C 口换成充电头, 网卡/口/卡/内核全不动 ⇒
uptime 265 s 无复位, `7961` 480M 枚举, 固件 9.93 s 下完后板子活着, 自启把 `wlan0` 拉起(10.10.21.113/112)。
⇒ **根因 = 电源供不上射频上电的电流阶跃**。⚠ 具体塌在哪一级(Type-C 源 / D15 / AO3401)仍没用表量过。
⚠ 阶段 1-2(网卡"插着"却 11 分钟零枚举)**未解释**, 之后每次插都在 2.75 s 枚举 ⇒ 大概率当时没插到位。

## 供电路径 (原理图 `pcb/dr1v90_core_v1/03_参考设计_米联客FS03/MLKPAI_FS03_DR1_241023.pdf`, P08/P10, 已渲染成图核对)

```
Type-C VBUS_+5V ─D15 肖特基─┐
VIN_5V0 ────────D16 肖特基─┴─ V_5V ─Q6 AO3401─ VCC_5V0 ─U16 CH217K(ISET R85 56K)─ ULPI_VBUS ─L11─ J6 Type-A
                                                              └ FLAG → D7 红 LED(故障亮)
```
- CH217K 的 EN 由 R89 4.7K 定死、R84 NC; **USB3320 的 CPEN 悬空** ⇒ ULPI 里 DrvVbus=1 对实际供电**毫无作用**。
- 5V 灌入改法(L16-L19)改的是 `VCC_CEP`, **不在 USB 这条路上**。

## 🔴 两个会骗人的量具

1. **USB3320 的 VbusValid 位在这块板上没意义**: VBUS 检测脚串了 **R88 10K** 才到 `ULPI_VBUS`,
   与片内阻抗分压。**U 盘正常工作时照样读 `0x13 = 0x04`(SessValid=1, VbusValid=0)**。
   我据此一度断言"VBUS < 4.4 V", 已撤回。
2. **dwc2 的 debugfs `regdump` 在 host 模式下会读设备模式寄存器** ⇒ 刷几百条
   `Mode Mismatch Interrupt` + `ttyS0 input overrun`。只是日志风暴, 不改状态。
   要读寄存器用 `devmem` 只读全局/host 寄存器(0x000 GOTGCTL / 0x014 GINTSTS / 0x440 HPRT0)。

## 可复用的配方

- **读 ULPI PHY 寄存器**(GPVNDCTL 视口, 先读厂商 ID 自证量具, 应得 0x24/0x04):
  `devmem 0xF8180034 32 0x02<RR>0000; sleep 1; devmem 0xF8180034 32` → bit27=done, [7:0]=值
- 🎯 **09-16 DR1V90-2: 网卡插了但 USB 上什么都没有 = 线只通电不通数据** —— 三个读数一起出现就是这个特征:
  `HPRT0=0x00001000`(PrtPwr=1, **ConnSts=0**) + ULPI `0x13=0x04`(SessValid=1, 口上有电) + **`0x15=0x00`(LineState SE0, 没人拉 D+)**,
  dmesg 无任何 `usb 1-1` 行, 开机前就插着也一样。换一根 USB 线立刻 `0e8d:7961` high-speed 枚举。
  ⇒ 先换线/直插, 别先怀疑板子的 J6 或 USB3320; 反过来 SessValid=0 才指向 VBUS 那一路。
- 🔴 **只听不发的串口脚本也必须 `DtrEnable/RtsEnable=$true`**: 这颗 CH342 DTR/RTS 为低时一个字节都不回,
  09-16 我用没拉 DTR 的监听脚本听了 40 s 得到 0 字节, 差点当成"板子没输出"(其实早停在 login)。
- **判"用户说重新上电了"是否属实**: 比 `/proc/uptime` 与 dmesg 同一行的时间戳 —— 本次两次读
  `mt7921u registered` 都是 `22.703911`、uptime 连续 ⇒ 没重启。
- **怀疑重启循环时, 串口只听不发**(`serial_run` 在循环中只会回显命令、没有输出, 像"卡住")。
  脚本见会话 scratchpad 的 `serial_listen.ps1`: 只 Open + ReadExisting, 不写一个字节, 不会打断 autoboot。
- 板上有两个 CH342 口之外的串口(本机 COM20=CH340, COM21=FT232H), **别往不认识的口发命令**。

## How to apply

- DR1 的 WiFi 起不来时, **先问供电方式**, 再查驱动。电脑 USB-C 口不够网卡用。
- 反复掉电复位对 TF 卡(FAT 以 rw 挂载)有风险 ⇒ 发现循环**先拔网卡**止损。
- 测 [[project_dr1_measure_bench]] 的 `03_wifibw` 前, 必须先用足够强的 5V 电源, 否则连 wlan0 都拿不到。

相关: [[feedback_dr1_panel_current_brownout]] [[project_dr1_wifi_modules]] [[reference_fs03_board_access]]
[[feedback_dr1_reboot_loses_everything]] [[feedback_serial_probe_stops_uboot_autoboot]]
