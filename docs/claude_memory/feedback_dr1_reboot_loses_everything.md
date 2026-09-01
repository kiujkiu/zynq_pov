---
name: feedback_dr1_reboot_loses_everything
description: 🔴 DR1 一重启就回到零 — 板载流水灯灭 + 屏灭 + 网不通是**同一个原因**(initrd 跑 RAM 重启即丢 + AUTOBOOT 默认关), 不是三个故障; 别拿灯或屏当"板子活没活"的判据
metadata:
  type: feedback
---

# 板子一重启就回到零 (2026-08-31 用户连撞两次)

现象: "插了串口, 为什么流水灯不亮了" → "现在屏幕不亮了, 之前显示过数字棋盘格"。
三个现象(**板载流水灯灭 / 屏灭 / povsh 连不上**)看着像三个故障, 其实是**一次重启**。

## Why: 上一次的成果全在 RAM 里

| 丢的东西 | 为什么丢 |
|---|---|
| PL bitstream | DR1 的 PL **不在 BOOT.bin 阶段加载**, 是 Linux 起来后 `povboot.sh pl` 走 fpga_manager + configfs overlay 装的 |
| povmem / CMA 句柄 | `stage_povmem` 装的 ko, 重启没了 |
| 屏上的图 | framebuffer 在 DDR, `auto_en` 在 PL 寄存器里 —— PL 都没了 |
| povsh / WiFi | `stage_wifi` / `stage_povsh` 是 initrd 里跑的, rootfs **重启即丢** |

而 **开机默认不会自动跑 povboot**: `tools/make_card_image_dr1.sh:38` `AUTOBOOT="${AUTOBOOT:-0}"`
⇒ 卡上没放 `pov/AUTOBOOT` ⇒ `S95pov` 闸门不开(`tools/mkrootfs.sh:283,319`)。
⇒ **重启后板子只是个裸 Linux, 什么都没有, 这是设计使然不是故障。**

## 🔴 板载流水灯永远不该亮

板载 8 个 LED(`O_led[7:0]`, `docs/PANEL_BRINGUP_CHECKLIST.md:155`) 只有
`boot/run_led.bit`(08-06 的 Step1 探针)会点。**生产 bit `td_pov` 根本不驱动它们。**
⇒ 刷了生产卡之后流水灯**不亮才是对的**; 亮反而说明卡上 `pl.bin` 被
`cp run_led.bin pl.bin` 覆盖了(`board/cmds_plload.txt:3` 记着这坑白跑过一轮)。

## How to apply

1. **判"板子活没活"看串口是哪一级提示符**, 不看灯也不看屏
   (同 [[feedback_serial_probe_stops_uboot_autoboot]]):
   u-boot 提示符 = 活着只是被停住(敲 `boot`) / `login:` = Linux 起来了 / **完全无输出**才是真没起来。
   串口设备还在 = 板子有电(CH342 由板子供电, [[feedback_static_panel_test_overheats]])。
2. **恢复顺序(屏保持灭)**: `povboot.sh pl` + `povboot.sh sw` 装 PL 和 povmem 但**不碰
   `auto_en`**(RTL 复位为 0) ⇒ 先配好亮度再点。**别直接 `povboot.sh all`/`engine`** ——
   那会用生产亮度点屏, 静态无风冷会烤重启。静态一律 `oe=8`。
3. 阶段名(`board/povboot.sh:1125-1134`): `pl` / `sw` / `wifi` / `mode` /
   `engine`(= mode && engine, **会点屏**) / `all`。
4. 要省掉这套手工恢复就打开 `AUTOBOOT`(卡上 `pov/AUTOBOOT` 建个空文件,
   或 `tools/stage_to_card.sh --autoboot`)。⚠ **代价是开机直接点屏**, 失去"先配亮度再点"
   这一层保护 —— 转子不转的时候这是过热风险。

## ✅ 2026-08-31 走通的完整恢复配方 (从零到脱离串口, 约 15 分钟)

板子重启后**唯一**的入口是串口。全程可从 WSL 无头驱动 Windows 侧的 COM 口:

```bash
# 0. 板子挂在哪个口 (CH342 双通道; 两个口都在 = 板子有电)
powershell.exe -NoProfile -c "[System.IO.Ports.SerialPort]::getportnames()"
#    COM5 = USB-Enhanced-SERIAL-A = **控制台**;  COM4 = B 通道, 无数据
# 🔴 从 WSL 调 .ps1 必须加 -ExecutionPolicy Bypass (只作用于这一次, 不改系统设置)

# 1. 探一探停在哪一级 (只发回车不发 Ctrl-C, 不会打断 autoboot)
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File 'D:\claude_workspace\pov3d\dr1v90\host\serial_probe.ps1' COM5 6
#    "anlogic login:" = Linux 起来了但什么都没自启(正常); u-boot 提示符 = 敲 boot

# 2. 跑命令 (serial_run.ps1 自动送 root/root + 关回显 + 标记定界, 默认 COM5)
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File '...\host\serial_run.ps1' -Cmd "sh /mnt/mmcblk0p1/pov/povboot.sh wifi" -TimeoutSec 240
#    ⚠ `wifi` 阶段是 `stage_card && stage_wifi`, **不依赖 pl/sw** ⇒ 可以第一个跑

# 3. 串口推 povsh v2 上板 (43 KB, 10 秒)
powershell.exe ... -File '...\host\serial_send.ps1' \
  -LocalFile '...\board\povsh\povsh_riscv64' -RemotePath '/tmp/povsh'

# 4. 起 povsh (🔴 后台进程必须自己接走三个 fd, 否则串口会话被挂住)
... -Cmd "chmod +x /tmp/povsh; setsid /tmp/povsh -p 9600 -t poval01 </dev/null >/tmp/povsh.log 2>&1 &"

# 5. 脱离串口
POVSH_HOST=<板子IP> ./host/povsh_run.sh --ping
```

🔴 **卡上的 `povboot.sh` 可能没有 `povsh` 阶段**(那是 08-28 22:20 才加的, 而卡是 18:22 刷的)
⇒ `povboot.sh povsh` 会报 unknown stage, povsh 只能手动起。**先 `grep -o '^  [a-z]*)' povboot.sh` 看它有哪些阶段。**

## 🎯 通路速率实测 (2026-08-31, 决定了"该走哪条路")

| 路 | 速率 | 11.2 MB 要多久 |
|---|---|---|
| 串口 `serial_send.ps1` | **4,301 B/s** 实测 | **52-62 分钟**, 无续传, 历史上 3.23 MB 那次**在 88% 处死掉** |
| povsh 走 WiFi `povsh_send.sh` | **29,823-53,964 B/s** 实测 | **6m49s**, 一次成功 |

⇒ **串口只用来发命令和推那个 43 KB 的 povsh, 不用来传 rootfs/素材。**

相关: [[project_dr1_panel_first_light]] [[feedback_static_panel_test_overheats]]
[[feedback_serial_probe_stops_uboot_autoboot]] [[reference_dr1_factory_linux_boot]]
