---
name: project_pov3d_dr1v90_board_inventory
description: 板子台账 — 2 块 DR1V90 + 2026-09-17 到货 3 块 DR1M90(第一块 DR1M90_01); DR1V90-1 = 现在接 COM5 串口的那块 = 记忆里一直叫 "dr1a" 的那块(BOARD_ID pov-5d23750da9c1d32a), 它就是 JTAG 台架板; 两块同镜像 hostname 都是 dr1a, 只能按 BOARD_ID/MAC/SD CID 区分
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

## 🔴 09-16 22:1x 用户: "DR1V90-2 在测 WiFi, 不要搞错"
- DR1V90-2 正由 WiFi 会话使用 (COM18/COM12, 网络 10.10.21.13x, povsh 昵称 `dr1v90-2`) ⇒ **JTAG 相关工作 (jtag_load / 集成流程 / 上板代理) 一律只动 DR1V90-1, 永远不开 COM12/COM18, 不走 povsh/网络**。
- 主机侧 PnP 实例: DR1V90-1 = `USB\VID_1A86&PID_55D2&MI_00\7&2D66278&0&0000` (COM5), DR1V90-2 = `...\6&88CF9E7&0&0000` (COM18)。COM 号会随 USB 重插变 ⇒ 开口前先核 PnP 实例。
- 连上后第一条命令 `cat /mnt/mmcblk0p1/pov/BOARD_ID`: DR1V90-1 必须是 `pov-5d23750da9c1d32a` (DR1V90-2 是 `pov-31ee35b3807cf452`), 不对立即停手; 换 PL / 推包 / 重启前再核一次。

## DR1M90_01 — 2026-09-17 到货 (共 3 块, 用户定名 DR1M90_01/_02/_03)
| 项 | 值 | 怎么读出来的 |
|---|---|---|
| 型号 | **MLKPAI-FS03-DR1M90GEG** (与 DR1V90 **同一块 FS03 底板**, 只换核心模块) | 网盘目录名 / 共用 PINLIST |
| 串口 | 🔴 **还没插到电脑上** —— 09-17 14:3x PC 上只有两颗 CH342, 都是 DR1V90 的 | `Get-PnpDevice -Class Ports` |
| 架构 | **aarch64** (Cortex-A35 双核) | 出厂 `uImage.lz4` 头 = `Linux/ARM 64-bit` |
| 随板 TF 卡 | 29.15 GB, 单 FAT32 主分区, **无盘符**(出厂就不带), 卷 GUID `64657d69-a224-11f1-a7df-d494a9c8aabf` | Windows 磁盘管理 / `Get-Volume` |
| 出厂五件套 | 2024-11-19。`BOOT.bin` **4db94197**(4,007,680) / `boot.scr` **a999fce4**(466) / `system.dtb` **7d3b52e3**(18,681) / `uImage.lz4` **1415289f**(8,131,936) / `uInitrd.lz4` **204a09b0**(36,206,438) | 卡上读回 `Get-FileHash` |
| 备份 | `dr1v90/boot/factory_card_dr1m90/` | |
| pov/ 载荷 | ✅ 09-17 已加(不重烧, 只加目录): ksink/iperf3/pov_rxd(aarch64 静态) + ksinkbw.sh + wifibw.sh + helix.lz4hc; **双向 md5 校验过**, 厂商五件套逐字节未动 | `tools/add_pov_to_card.ps1` |
| 上电/启动 | 模式开关 **PIN1/PIN2 = OFF-OFF**(SD); psuart 的 Type-C 5V; 串口 115200 8N1; **root/root 密码盲打** | 厂商 `03-1_…Linux恢复出厂设置.pdf` |
| BOARD_ID | **还没有** —— 出厂系统里没有 `pov/BOARD_ID`(那是我们 povshd 生成的) | |

🔴 **DR1M90 与 DR1V90 最省事的区分判据是 `uname -m`**: `aarch64` vs `riscv64`。
BOARD_ID 在 DR1M90 上还不存在; eth0 MAC 更不能用(MAC 写死在 BOOT.bin 里, 米联派板全一样)。
⇒ 上板第一条命令: `uname -m; cat /mnt/mmcblk0p1/pov/BOARD_ID 2>/dev/null`。

## ✅ 09-17 14:3x COM18/COM12 归属已定 (此前"存疑"作废)
- **COM18/COM12 = DR1V90-2**, 就是 09-16 22:1x 用户说"在测 WiFi"的那块。
- WiFi 会话 09-17 12:09 记的"COM18 疑似 DR1M90_01 控制台, 被别的程序占着"**是错判**:
  `SerialPort.Open()` 报"访问被拒绝"正是因为**另一个会话正常占着它**。🔴 **不要去腾 COM18**, 那会打断别人的测试。
- 判据: 09-17 14:3x 枚举 PC 上**仍然只有两颗 CH342**(`7&2D66278`=COM4/5, `6&88CF9E7`=COM12/18), **没有第三块**
  ⇒ DR1M90_01 的 USB 串口还没插。插上之后会**多出一颗新的 CH342**, 那才是它。

## 🔴 09-17 12:2x COM18/COM12 归属存疑 (↑ 已由上一节解决, 保留原始记录)
- 用户 09-16 22:1x 说 DR1V90-2 在测 WiFi, 当时 COM18/COM12 = PnP 实例 `6&88CF9E7`; WiFi 会话 09-17 12:09 在 [[project_dr1m90_wifi_retest]] 里记 "COM18 疑似 dr1m90_1 控制台, 被别的程序占着"。09-17 12:21 只读枚举: PC 上仍只有两颗 CH342 (`7&2D66278` = COM4/5, `6&88CF9E7` = COM12/18), 没有第三块。
- 🔴 **PnP 实例 ID 跟 USB 口走、不跟板子走**: 同一个口换插另一块板, 实例 ID 不变 ⇒ PnP 实例只能排除"插错口", **认板只认 BOARD_ID (+ DR1M90 加 uname -m)**。
- 规则不变: JTAG 线只开 COM5 且 BOARD_ID 必须是 pov-5d23750da9c1d32a; COM12/COM18 不论接的是 DR1V90-2 还是 dr1m90_1 都不开。

## 怎么区分两块 (🔴 hostname 分不出)
hostname 不可靠(DR1V90-1 是 `dr1a`, DR1V90-2 卡上配 `dr1v90-2` 但没开 AUTOBOOT 时显示 `anlogic`)。有效指纹:
1. `cat /mnt/mmcblk0p1/pov/BOARD_ID` — povsh 的 `--whoami` 用的就是它(`host/povsh_lib.sh` 会拿它和 `POVSH_ID` 比, 不等就拒绝跑命令);
2. `cat /sys/block/mmcblk0/device/cid` — 认的是**卡**不是板, 换卡就变;
3. 主机侧: 串口 COM 号(CH342 的 USB 实例路径不同)。
🔴 **~~eth0 MAC~~ 作废 (09-16 实测)**: 两块板 eth0 都是 `e0:78:a3:00:00:08` —— **MAC 写死在 BOOT.bin 里**
(`tfboot/BOOT.bin` 偏移 3735196、出厂卡 BOOT.bin 偏移 3735140 都搜到这 6 个字节, dtb/kernel 里没有) ⇒
**所有用这份 BOOT.bin 的米联派板 MAC 都一样**; ⚠ 两块板同时插网线进同一个局域网会 MAC 冲突, 要用得先在板上 `ip link set eth0 address …` 改。

**Why:** 09-15 整整一段返工来自"板子身份没核对"; 现在两块同时在场, 不按指纹认板必然再错一次。
**How to apply:** 动任何一块板之前先跑一条 `uname -m; cat /mnt/mmcblk0p1/pov/BOARD_ID; cat /sys/block/mmcblk0/device/cid`, 对上台账再干活; 写记忆/文档时用 **DR1V90-1 / DR1V90-2 / DR1M90_01**(用户定名, DR1M90 用下划线+两位), 别再写 "dr1a" 或 "dr1m90_1"。
