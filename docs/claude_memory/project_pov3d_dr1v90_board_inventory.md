---
name: project_pov3d_dr1v90_board_inventory
description: 2026-09-16 用户定名 — 手里 2 块米联派 DR1V90(MLKPAI-FS03); DR1V90-1 = 现在接 COM5 串口的那块 = 记忆里一直叫 "dr1a" 的那块(BOARD_ID pov-5d23750da9c1d32a), 它就是 JTAG 台架板; 两块同镜像 hostname 都是 dr1a, 只能按 BOARD_ID/MAC/SD CID 区分
metadata:
  type: project
---

# DR1V90 板子台账 (2026-09-16 用户定名)

用户 2026-09-16: **"我们手里有 2 块米联派的 DR1V90, 这个记录为 1"**(指当时接在串口上的那块)。

## DR1V90-1 — 当前 JTAG 台架板
| 项 | 值 | 怎么读出来的 |
|---|---|---|
| 串口 | **COM5**(CH342, COM4 是同一颗芯片的另一路) | `host/serial_run.ps1 -Port COM5` |
| BOARD_ID | **`pov-5d23750da9c1d32a`** | `cat /mnt/mmcblk0p1/pov/BOARD_ID` |
| hostname | `dr1a` | `hostname` |
| eth0 MAC | **`e0:78:a3:00:00:08`** | `ip link show eth0` |
| SD 卡 CID | **`ad4c534d5353443020000003a4018800`**(29.1 G) | `cat /sys/block/mmcblk0/device/cid` |
| 网口 | can0/can1/eth0/lo; 09-16 15:0x 时 eth0 **NO-CARRIER**, 无 wlan0(dongle 没插) | `ls /sys/class/net` |

🔴 **它就是记忆里反复出现的 "dr1a"(10.10.21.112/113, WiFi 测试板)。**
⇒ [[project_pov3d_jtag_load_bench]] 和 `jtag_load/HANDOFF.md` 里"**09-15 误把 jtag 包推到 dr1a, 台架板是另一块**"这个判断,
**2026-09-16 被用户定名推翻**: 用户就是拿这块做 JTAG 台架。那批文件推对了板, 只是版本旧(09-16 已更新为新版, md5 见 `jtag_load/sw/README.md`)。
⇒ `jtag_load/README.md` §S1 第 1 步"判据: ID **不是** `pov-5d23750da9c1d32a`"**作废**, 反过来: **ID 必须等于它**。

## DR1V90-2
| 项 | 值 | 怎么读出来的 |
|---|---|---|
| 串口 | **COM18**(CH342 A 路, 控制台; B 路 COM12) | 插上前后对比 `Win32_PnPEntity` 里的 `(COMn)` |
| BOARD_ID | **`pov-31ee35b3807cf452`**(09-16 16:5x `povshd.sh ensureid` 生成, src=urandom) | `cat /mnt/mmcblk0p1/pov/BOARD_ID` |
| hostname | `anlogic`(卡上 povboot.env 写的是 `dr1v90-2`, 但**没放 AUTOBOOT ⇒ S95pov 在闸门处就退出, 改名那步不跑**) | `hostname` |
| eth0 MAC | `e0:78:a3:00:00:08` —— 🔴 **与 DR1V90-1 相同, 不能认板**(见下) | `ip link show eth0` |
| SD 卡 CID | **`ad4c534d535344302000000339018800`**(29.1G, 61132800 扇区) | `cat /sys/block/mmcblk0/device/cid` |
| WiFi | ✅ 09-16 `povboot.sh wifi` 通过: dongle wlan0 MAC **`90:de:80:47:f0:fd`**, SSID undef 5745MHz, -42 dBm, rx 432/tx 344 Mbit/s(协商速率), DHCP **10.10.21.130**(会变), Windows ping 8/8; 射频开后 70 s+ 未重启 | `ip link show wlan0` |
| 自启 | ✅ 09-16 **卡上已放 `pov/AUTOBOOT`**(板上 Linux 里 touch, 不是 Windows 写的), 热重启后 S95pov `povsh sdoff pl sw wifi` **全 PASS**, hostname 变 `dr1v90-2`, PL 开机加载(不点屏) | `/var/log/povboot.log` |
| povsh | ✅ 走 WiFi 可控, 已登记 `~/.povsh/boards.tsv` 昵称 **`dr1v90-2`** ⇒ `POVSH_BOARD=dr1v90-2 ./host/povsh_run.sh --ping` | |
| ⚠ 双 IP | wlan0 同时有 **.130(udhcpc) 和 .132(dhcpcd)** —— 两个 DHCP 客户端都在管 wlan0, 暂无害, 未修 | `ps \| grep -E 'udhcpc\|dhcpcd'` |
| 首次上电 | 09-16 16:5x Linux 正常起到 login, MANIFEST 11/11 OK, 内存 468MB, 网口 can0/can1/eth0/lo(无 wlan0) | |

**09-16 16:45 卡已刷好**(用户定名镜像 "dr1v90_2"):
- 镜像 `pov3d/dr1v90_2_card.img.gz`(md5 `072f58a2edeb283b5dcda14488502e15`, 解压后 512MB `15df2f09…4a67`),
  `make_card_image_dr1.sh` 出的, **hostname = `dr1v90-2`**(主机名不能带下划线) ⇒ **和 DR1V90-1 的 `dr1a` 终于分得开了**;
  rootfs `rootfs_pov_20260831b.bin`, pl.bin = `known_good/pov_obs_20260828`, OE_W0=24, **没放 AUTOBOOT**。
- 烧写: 29.2G USB 读卡器(Windows 磁盘 1, 序列号 `121220160204`), `dr1v90/host/flash_card_raw.ps1` 块级写 + **整段读回 md5 一致 PASS**。
- 原来卡上是**没用过的出厂系统**(2024-11-19, 无 pov/), 与仓库里已有的出厂版**不同**: BOOT.bin `5e2074b5…`(3,739,968) / kernel.bin `1582f616…`(5,419,029) / boot.scr `2660fe65…`
  已备份到 `dr1v90/boot/factory_card_dr1v90_2/`; rootfs.bin = `boot/rootfs_card_orig.bin`、dtb.bin = `boot/dtb_card.bin`(md5 相同, 没重复存)。
- 🔴 两块同时插串口时 DR1V90-2 会是**另一个 COM 口**, `serial_*.ps1` 默认 COM5 = DR1V90-1, 必须显式 `-Port`。

## 怎么区分两块 (🔴 hostname 分不出)
hostname 不可靠(DR1V90-1 是 `dr1a`, DR1V90-2 卡上配 `dr1v90-2` 但没开 AUTOBOOT 时显示 `anlogic`)。有效指纹:
1. `cat /mnt/mmcblk0p1/pov/BOARD_ID` — povsh 的 `--whoami` 用的就是它(`host/povsh_lib.sh` 会拿它和 `POVSH_ID` 比, 不等就拒绝跑命令);
2. `cat /sys/block/mmcblk0/device/cid` — 认的是**卡**不是板, 换卡就变;
3. 主机侧: 串口 COM 号(CH342 的 USB 实例路径不同)。
🔴 **~~eth0 MAC~~ 作废 (09-16 实测)**: 两块板 eth0 都是 `e0:78:a3:00:00:08` —— **MAC 写死在 BOOT.bin 里**
(`tfboot/BOOT.bin` 偏移 3735196、出厂卡 BOOT.bin 偏移 3735140 都搜到这 6 个字节, dtb/kernel 里没有) ⇒
**所有用这份 BOOT.bin 的米联派板 MAC 都一样**; ⚠ 两块板同时插网线进同一个局域网会 MAC 冲突, 要用得先在板上 `ip link set eth0 address …` 改。

**Why:** 09-15 整整一段返工来自"板子身份没核对"; 现在两块同时在场, 不按指纹认板必然再错一次。
**How to apply:** 动任何一块板之前先跑一条 `cat /mnt/mmcblk0p1/pov/BOARD_ID; cat /sys/block/mmcblk0/device/cid`, 对上台账再干活; 写记忆/文档时用 **DR1V90-1 / DR1V90-2** 这个名字, 别再写 "dr1a"。
