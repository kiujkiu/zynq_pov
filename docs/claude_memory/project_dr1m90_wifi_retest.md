---
name: project_dr1m90_wifi_retest
description: 🎯 DR1M90_01 bring-up 完成并测出 WiFi 能力: TCP 接收**实测 159(台架顶, 板子 CPU 还余 22-33%)**, CPU 外推 **~210**; 同板 eth0 **941 线速** ⇒ SoC 不是墙; WiFi 比有线贵 **6.7× CPU**(stock mt76 不做 GRO); **USB2 硬墙 ~300**, 350/400 不可能; 三杠杆实测: GRO −8.4% CPU / 驱动 rx_agg 零收益(芯片默认一URB一帧) / MTU2304 本台架不可用; 🔴 供电问题**换 PC 另一个 USB 口就解决**; 🔴 收口: 链路已比下游 PL 入口(110)快 1.4-1.9× ⇒ 追 300 前先回答"300 服务什么内容"
metadata:
  type: project
---

# 状态速览 (2026-09-18 收工时, 新窗口从这里接手)

**板子**: DR1M90_01(米联客 MLKPAI-FS03-DR1M90GEG), 2× Cortex-A35, 6.1.111-rt42 aarch64, 487 MB。
串口 **COM24**(CH342-A), PC USB 口 **busid 7-2**(换到这个口才稳), 卡自动挂 `/mnt/mmcblk0p1` rw。

**一条命令恢复**(initrd 每次重启清空 /lib /usr /tmp):
```
sh /mnt/mmcblk0p1/pov/wifi_up.sh          # 原版驱动
sh /mnt/mmcblk0p1/pov/wifi_up_patched.sh  # 补丁驱动(GRO)
sh /mnt/mmcblk0p1/pov/wifi_join.sh        # 关联(hex PSK, 扫 5220+5240)
```
台架 AP: WSL 侧 hostapd, SSID `pov3d-p2p`, 192.168.77.1, 板子 192.168.77.2。
起 AP: `bash <rig>/wsl_ap_up.sh <rig>/hostapd_ch44.conf`(rig = `measure/03_wifibw/results/2026-09-15/tput_ab/rig`)。

**测出来的数**: 见本文 "2026-09-18 三个杠杆逐个实测" 和 "摸到台架尽头" 两节。一句话:
**实测 159(台架限) / 估计 ~210(板子 CPU 限) / 硬墙 300(USB2) / SoC 无关(有线 941)**。

**三个待办(按价值)**:
1. 需求问题: **"300 服务什么内容"** —— 未答。链路已比下游 PL 入口(110 Mbit/s)快 1.4-1.9×。
2. [[project_rotor_spinning_wifi_throughput_gap]] **转子旋转下的吞吐** —— 全项目唯一零数据的一跳, 现在供电好使是最好时机。
3. 若要 300: **重建 `aggctl.sh`**(拿芯片聚合 +48%, 唯一不依赖新硬件的杠杆) + AP 到货后有线发送端 + MTU 2304。

---

**2026-09-16 用户定: "wifi 速度问题我们先等一等, 换 DR1M90 来测"。板子是米联客 DR1M90GEG484, 还在买, 约 2 天到。**
⇒ 推翻 09-15 那条"保持 DR1V90 + 压数据量"的方向(见 [[project_wifi_300m_target]]), 也把 08-06 因价格否掉 DR1M90 的 ADR
([[project_dr1_sku_decision]])在**技术轴上**重新打开 —— 采购轴的"贵"用户显然已自己权衡过, 不要再重提。

## 预期: 推算 160-210 Mbit/s, 不是量级变化
三点拟合 `T = u/k + p`(u≈60 µs/URB, p≈72.5 µs/包, DR1V90 实测, 第三点预测 85.3 实测 85.2)。
换 CPU 只动 **p**(mac80211+TCP+拷贝); u 在 k≈5 时只剩 12.7 µs。A35 ~1.78 DMIPS/MHz **比 A9 的 2.5 还低**,
只比 DR1V90 的 RISC-V 核强一档 ⇒ p 估 40-48 µs ⇒ **160-210**: 刚够摸到 200 保底, **250/300 仍不成立**。
🔴 旧估算"DR1M90 约 85-125"**作废**: 那是从**没打补丁**的 Zynq(双 A9 同款网卡 110-125, CPU 还空一半)推的,
与打了 v3p1+聚合的 136 不是同一基准。
第二个核的价值是把 pov_rxd 整个挪出收包核, **不是加速收包本身**(双核并行只值 1.06×, [[feedback_lz4_onboard_reality_check]])。

## 已备好 (全文 `dr1v90/docs/DR1M90_RETEST_PREP.md`)
- `~/toolchains/aarch64-linux-musl-cross/`; `bench/deps/aarch64musl/` (zlib+lz4)。
- `measure/03_wifibw/out/iperf3_aarch64`; `build_iperf3.sh` 加了 `ARCH=`。
  ✅ riscv64 产物重编 **md5 与 8 月那份逐字节相同** ⇒ 91.7/136 的可比性没被破坏。
- 🎯 **`dr1v90/board/ksink/`(新)**: 带真实接收负载的吞吐探针, riscv64/aarch64/x86 三份。
  **它是这次准备的核心** —— DR1M90 到手时 povmem/bitstream/CMA 一个都没有, pov_rxd 跑不起来,
  而"能不能过 200"是要不要继续走这块板的前提, 必须第一天知道。
- `measure/03_wifibw/board/ksinkbw.sh`(新, 纯 ASCII): check/raw/base/dec 四档, 沿用 wifibw.sh 的三条预检。
  **`base`(不带 --sample)才是对标 PL 模式的数**(PL 模式 lz4 不在 CPU 上); `raw` 与 iperf3 交叉验证, 对不上先修台架再往下走。
- `pov_rxd` 加 `make aarch64` + `wmb_frame()` 的 `__aarch64__` 分支; sim 回归 PASS。
- ✅ **mt76 三个补丁只碰 `mt76/usb.c` + `mt76/mt7921/usb.c`, 零架构相关代码,
  对厂商 SDK 6.1.111 树内 mt76 `patch --dry-run` 全部干净套上** ⇒ 只要米联客 DR1M90 也是 6.1.x 树内 mt76, 原样可用。

## 🔴 仍然挡路: 台架发送端封顶 145 Mbit/s
USB/IP(每 802.11 帧一个 URB 经 Hyper-V vEthernet 往返) ⇒ ~12.2k pps ≈ 145, WSL CPU 并不忙([[reference_wsl_p2p_wifi_rig]])。
**换主控解决不了这条**; DR1M90 真到 180 也只会读到 145。两条路: A 原生 Linux 插网卡跑 hostapd; **B 专用 WiFi 6 AP + 发送端走有线**
(发送端不能是 WSL2, NAT 会把巨帧切回 1500)。✅ **09-16 用户定: 走 B, 要"好一点的、可以有线 mesh 的"。选型 = GL.iNet Flint 2 (GL-MT6000) × 2, 有线回程 mesh。**
🎯 **明确不选更贵的 Flint 3 (GL-BE9300, WiFi 7)**: Flint 3 是**高通闭源驱动**, Flint 2 是 **MT7986+MT7976 = mt76, 与板上 MT7921AU 同驱动家族**
⇒ 同计数口径、同聚合/MTU 旋钮; 🔴 **MTU 2304 那根杠杆要 AP 侧也能设, 高通闭源上很可能没这个旋钮 ⇒ 买 Flint 3 有把这条线索永久测不了的风险**。
且"余量"Flint 3 买不到: 客户端是 2×2 HE80 的 MT7921AU(PHY 顶 1200), Flint 2 的 4×4 AX6000 对 200-300 已有 3-5× 余量, WiFi 7 对 WiFi 6 客户端无收益
(转子侧换 WiFi 7 网卡不在桌面上 —— 四个 484 候选都没 PCIe)。**AP 是测量工具, 选型第一判据是"能不能看清能不能调", 不是空口速率。**
验收判据(先证 AP 不是瓶颈, 再测板子): 有线打有线 ≥900; 固定**非 DFS** 信道(149-165 或 36-48, 80 MHz —— 🔴 DFS 雷达检测会中途踢下线, 那种数据全废);
关掉 band steering/智能连接/airtime fairness/第二台 mesh 节点; 有线→普通 WiFi6 笔记本 TCP ≥400。
🔴 **仍未定: 发送端那台机器的操作系统。** ksink/iperf3 的发送端必须原生; 若 PC 只有 Windows, 要么用 Windows 原生 iperf3, 要么把 ksink 的发送端移到 winsock(约 30 行), 要么找台原生 Linux。

## 边界: 这次准备**没有**碰的
PL/RTL 没向 DR1M90 移植(第一天只能测 WiFi 接收, 测不了端到端); 米联客 SDK/内核/dtb 还没拿到;
🔴 **DR1M90 的 USB 主机是不是同款 dwc2+USB3320 ULPI 没查** —— 若不是, u≈60 µs/URB 的假设要重算, 160-210 这个区间会变,
**到手当天最先看这个**; 也**没有在 DR1V90 上用新 ksink 重跑基线**(建议到货前补上, 否则 DR1M90 的 ksink 数没有同工具对照)。

**Why:** 用户的方向决定; 而板子到手前的两天是消移植风险的窗口, 不是等待期。
**How to apply:** 板子到手先按 PREP 文档 §2 的五步顺序跑(原版基线 → 补丁), 别跳。谈 DR1M90 能到多少时用 160-210, 别用旧的 85-125。
相关: [[project_wifi_300m_target]] [[reference_dr1_wifi_ceiling_unestablished]] [[reference_main_soc_candidates_484]] [[feedback_dr1_wifi_dongle_brownout_reboot_loop]]

## 🔴 2026-09-17 板子到货(3 块, 第一块命名 DR1M90_01) — 卡卡在厂商镜像上
**我们手里没有任何能启动 DR1M90 的东西, 这是实测不是推断:**
- `boot/factory_card_dr1v90_2/kernel.bin` → `u-boot legacy uImage, Linux, **Linux/RISC-V**, OS Kernel Image`
- `boot/rootfs_wifi.bin` 里的 `bin/busybox` → `UCB RISC-V`
- `BOOT.bin`(3.7 MB) = 厂商 SPL+u-boot, **与芯片绑定**
- 全盘 `find -iname "*dr1m*"` → **0 命中**; 厂商 SDK `~/dr1sdk/uisrc-lab-anlogic/boards/` 只有 **DR1V**
⇒ 启动链三件(BOOT.bin / kernel / dtb)全是 DR1V90 的 RISC-V 版, **一个字节都不能用在 Cortex-A35 上**
⇒ **第一张 DR1M90 卡必须以米联客出厂镜像为底**, 我们只往 FAT 分区加 `pov/` 载荷。**待用户拿到米联客 DR1M90 资料包(网盘)。**

✅ 已备好 `tools/make_dr1m90_test_card.sh`: 厂商镜像一到, 一条命令注入 aarch64 载荷 + MANIFEST + 复验 + 打包成可烧的 .img.gz。
🎯 脚本里最重要的是**底座核对**: 若镜像里的内核是 RISC-V 就**拒绝注入**(反之认不出架构要 FORCE=1)。
  理由: 架构放错的症状是"上板才 cannot execute binary file", 那时候卡已经烧完、板已经插好、串口已经开好 —— 判据必须前移到做卡这一步。
🔴 **不要"先烧厂商镜像再往卡里拷文件"**: WSL 写 SD 卡实测四种方式全部 Permission denied(drvfs 9p 对可移动介质, Linux 的 root 管不到 Windows 文件系统驱动, sudo 无意义), 见 `boot/MAKE_CARD_DR1.md` §1 ⇒ 只能在 loop 设备上改镜像再 Etcher 烧一次。
🔴 **09-17 那条"COM18 疑似 DR1M90_01 控制台"是错的, 已由 [[project_pov3d_dr1v90_board_inventory]] 推翻**:
**COM18/COM12 = DR1V90-2**(PnP 实例 `6&88CF9E7`), 09-16 22:1x 起正由另一个 WiFi 会话使用 —— "访问被拒绝"正是因为**它被那个会话正常占着**。
⇒ **不要去腾 COM18**, 那会打断别人的测试。规则照旧: COM12/COM18 一律不开。
⇒ 而且 PC 上**只有两颗 CH342**(`7&2D66278`=COM4/5=DR1V90-1, `6&88CF9E7`=COM12/18=DR1V90-2), **没有第三块**
  ⇒ **DR1M90_01 的 USB 串口根本还没插到电脑上**。接串口前先插线, 插上后会多出一颗新的 CH342。

## ✅ 2026-09-17 厂商做卡方式已查清 (看的是已下完的 DR1V90 同款包)
米联客**不发整卡 .img**, 发的是 `01_user_start/02_linux_start/03_restore_factory/boot.zip`(**约 10 MB**) + 一份 PDF。
zip 里就 5 个文件: `BOOT.bin`(3.74M, SPL+u-boot) `boot.scr`(466B) `system.dtb`(17.6K) `uImage.lz4`(5.39M) `uInitrd.lz4`(5.42M)。
官方步骤(`03-1_…Linux恢复出厂设置.pdf` §四): **"格式化 SD 卡为 FAT32, 将 boot 文件夹内文件全部拷贝到 SD 卡中"**。
🔴 **模式开关 PIN1/PIN2: ON-ON=JTAG(00), ON-OFF=QSPI(01), OFF-OFF=SD(11)** —— 要 SD 启动必须 OFF-OFF。
上电走 psuart 的 Type-C(5V); 串口 115200 8N1; 登录 **root/root(密码盲打)**。
🎯 **`uImage.lz4` 的 u-boot 头带 arch 字段**, `file` 直接报 `Linux/RISC-V` 或 `Linux/ARM64`
⇒ **架构可以从厂商内核里读出来, 不用猜、不用靠参数**。
`boot.scr` 正文: load uImage.lz4→0x10000000 / uInitrd.lz4→0x19000000 / system.dtb→0x18000000, bootm 三地址;
bootargs `console=ttyS0,115200n8 earlycon=uart,mmio32,0xf8401000`。

✅ **`tools/make_dr1_test_card.sh`(取代之前那个基于 .img 的版本, 前提本来就错)**: 吃厂商 boot.zip, 从 uImage 头判架构,
按架构挑 ksink/iperf3/pov_rxd, 核对"载荷架构 == 厂商内核架构"且必须静态链, 造 MBR+FAT32 镜像, 复验 md5, 打包 .img.gz。
**已用 DR1V90 的 boot.zip 端到端实跑验证通过**(产出 `dr1_test_card_riscv64.img.gz` 11.7 MB, 6 个载荷 md5 全对)
⇒ DR1M90 的 boot.zip 一到, 同一条命令直接出卡。
🔴 **关键路径只有那 10 MB 的 `03_restore_factory/`** —— 正在下的 630 MB `3_2_1_sdk_base.rar` 等**都不在关键路径上**。

## ✅ 2026-09-17 DR1M90_01 的卡已做好 —— 随板那张 TF 卡本身就是出厂卡
🔴 **我先判断"卡是空的"是错的**: 我看的是 `Get-Volume` 四舍五入到 0.1 GB 的剩余空间(29.1/29.1),
那个精度**根本分辨不出 29 GB 里的几百 MB**。按精确字节看是**已用 316,997,632 B ≈ 302 MB**。
⇒ **判"盘/卡是否为空"必须看精确字节或直接列文件, 不能看四舍五入的容量。**
卡上本来就有出厂五件套(2024-11-19): `BOOT.bin` 4,007,680 / `boot.scr` 466 / `system.dtb` 18,681 /
`uImage.lz4` 8,131,936 / `uInitrd.lz4` 36,206,438 —— 比 DR1V90 那份大不少(initrd 36M vs 5.4M)。
✅ **已备份到 `dr1v90/boot/factory_card_dr1m90/`**(md5: BOOT.bin 4db94197… uImage.lz4 1415289f… uInitrd.lz4 204a09b0…)。
⇒ 网盘 `03_restore_factory/` 不再是关键路径(下完也只是同样五个文件的副本, 留作后备)。
🎯 `file` 实测 **`Linux/ARM 64-bit`(中间有空格, 不是 "ARM64")** —— `make_dr1_test_card.sh` 的 case 分支已按实测修正, 只写 `*ARM64*` 会漏判。
DR1M90 `boot.scr`: uImage.lz4→**0x10000000**, uInitrd.lz4→**0x15000000**, system.dtb→**0x14000000**(与 DR1V90 的 0x19/0x18 不同), bootm 三地址;
bootargs `console=ttyS0,115200n8 earlycon=uart,mmio32,0xf8401000`。

🎯 **做法改为"不重烧, 直接往出厂卡加 pov/"**: 卡本来就能启动, 重烧没有收益只有风险。
✅ `tools/add_pov_to_card.ps1`(新, 带 BOM): 按 **`\\?\Volume{GUID}\` 卷路径**写卡。
🔴 **这推翻了 `boot/MAKE_CARD_DR1.md` §1 里"从 WSL 调 Windows PowerShell 也 Permission denied"那条**:
  实测 **PowerShell 按卷路径写可移动介质是成功的**。之前失败很可能是因为**卡没有盘符**(厂商卡出厂就不带盘符, 分配盘符要管理员)。
  ⇒ 以后要往卡上加文件, **先试卷路径**, 不必每次都走 "造 img + Etcher" 那一套。
🔴 `New-Item` 在 PowerShell 5.1 **没有 `-LiteralPath`**(只有 -Path/-Name), 用 `[System.IO.Directory]::CreateDirectory()` 代替。
✅ **卡已就绪并双向校验**: pov/ 六个文件从卡上读回算 md5 与 staging 的 MANIFEST **逐行一致**;
  厂商五个文件与备份**逐字节一致, 没被动过**。载荷: ksink/iperf3/pov_rxd(均 aarch64 静态实测过) + ksinkbw.sh + wifibw.sh + helix.lz4hc(真帧 HC12, 39.62×)。
**下一步(还没做)**: 模式开关 PIN1/PIN2=OFF-OFF, psuart Type-C 上电, 串口 115200 8N1, root/root 盲打;
🔴 上电前要腾出 **COM18**(被别的程序占着)。

## ✅ 2026-09-17 15:0x DR1M90_01 首次上电成功 —— 关键未知数全部消掉
串口 **COM24**(新 CH342 的 A 口, PnP `7&1409325E`; B 口 COM23 无输出)。开口瞬间收到 64 字节乱码(29/64 高位),
但 `rx_errors=0` 且之后安静 ⇒ 是 **DTR/RTS 拉起的线路瞬态**, 不是波特率不对。敲一个回车就出 `Welcome to Buildroot` / `buildroot login:`。
**root/root 盲打登录成功。**

| 项 | 实测 |
|---|---|
| uname | `Linux buildroot **6.1.111-rt42** #1 **SMP** PREEMPT Tue Nov 19 15:18:18 CST 2024 **aarch64**` |
| CPU | MIDR part **`0xd04` = Cortex-A35**, processor 0/1 = **双核**; 无 cpufreq 驱动 |
| 内存 | **487 MB** |
| USB 主机 | 🎯 **`dwc2 f8180000.usb` —— 与 DR1V90 同一个控制器、同一个地址** |
| 网口 | `dwc-eth-dwmac f8100000.ethernet0`, PHY **YT8531 千兆**, **RGMII** (与 DR1V90 同) |
| 卡 | 自动挂 **`/mnt/mmcblk0p1`**, **rw** ⇒ 板上可直接改卡, 不必拔卡 |

🎯🎯 **两条最重要的结论:**
1. **内核版本与 DR1V90 完全相同(6.1.111-rt42)** ⇒ 那三个 mt76 补丁(已验证对 6.1.111 树内 mt76 干净套上)**大概率原样可用**。
2. **USB 主机是同一个 dwc2、同一个地址 ⇒ 外设复合体没变, 变的只有 CPU** ⇒ `u≈60 µs/URB` 的假设成立,
   **PREP 文档里 160-210 Mbit/s 的推算区间不需要修正**。(这正是我在 PREP §4 列为"到手当天最先看"的那一条。)

✅ **载荷链路端到端验证**: 板上 `md5sum -c MANIFEST.md5` 六个文件全 OK(字节经 Windows→卡→板没坏);
`cp 到 /tmp && chmod +x && 运行` ⇒ **ksink 真的跑起来了**(打出 listening 然后阻塞等连接)。
⇒ aarch64 交叉工具链 + musl 静态 + 做卡 + 认架构 这一整条链子全部走通。

🔴 **教训: ksink 的运行时输出原来是中文, 串口把它吃掉了**(第一次跑打出 `ksink  0.0.0.0:5201`, 动词没了)。
仓库约定本来就写着 **ASCII ONLY**(`board/povboot.sh`、`measure/03_wifibw/board/wifibw.sh` 的头注释), 我没遵守。
已全部改成 ASCII 并在 `ksink.c` 里把这条规则写进注释。**源码注释可以是中文, 任何会打到板子 stdout 的字符串不行。**

## 🔴 2026-09-17 16:4x 插网卡 → 板子复位一次; 出厂内核**完全没有无线栈**
用户插上 MT7921AU 后板子复位。**只复位一次, 没进循环**(DR1V90 是 18 s 一轮), 之后 uptime 稳定增长、load 0。
⚠ 但**这不等于 DR1M90 没有供电问题**: DR1V90 的重启循环是**射频上电**(驱动下完固件后)触发的,
而这里驱动根本没加载 ⇒ 射频从没上电 ⇒ **供电风险还没测到**。要等有了带无线栈的内核才能验。

🔴 **串口会话的一个真实缺陷(踩到了)**: 板子复位 → CH342 跟着断电重新枚举 → 会话攥着的句柄失效,
但**读循环静悄悄地停了, 只在尝试写的时候才报 `PORT LOST`**。
表现是"两小时一个字节都没有 + `port_open=1`" —— **死句柄和安静的板子长得一模一样**。
⇒ 我据此下过"日志里没有重启痕迹 ⇒ 没重启过"的结论, **是错的**。
**判据教训: `port_open=1` + rx 不增长 ≠ 板子安静; 必须主动写一下(或看 uptime)才能区分。**

板上实测(登录后):
- `1-1` = **`0e8d:7961` "Wireless_Device"** ⇒ **网卡本身在 dwc2 上枚举正常**
- `/sys/module` 里 **cfg80211 / mac80211 / mt76 一个都没有**; `/lib/modules` **整个是空的**
- `/lib/firmware` **空**; `wpa_supplicant` / `iw` **都没有**; 无 `/proc/config.gz`
⇒ **出厂内核没有无线栈**, 与 DR1V90 出厂内核同样情况(当年也是自己编了一个带无线栈的 6.1.111-rt42)。

## ✅ 内核源码不用下那 6 GB 的 ARM SDK —— 手上这棵树就支持 DR1M90
`~/dr1sdk/uisrc-lab-anlogic/sources/linux`(名义上是 V 版/RISC-V 的 SDK)里**同时有 arm64 侧的安路支持**:
- `arch/arm64/boot/dts/anlogic/` 有 **`anlogic-dr1m90-ad101-v10.dts`** 等 15 个文件 + `anlogic-dr1m90.dtsi`
- `arch/arm64/configs/` 有 **`anlogic_dr1m90_defconfig`**(CONFIG_PREEMPT=y ← **板上跑的是这个**)、
  `anlogic_dr1m90_rt_defconfig`(PREEMPT_RT)、`anlogic_dr1m90_mini_defconfig`、`anlogic_dr1_kernel_defconfig`
- 无线栈源码齐全: `net/wireless`(67) `net/mac80211`(127) `drivers/net/wireless/mediatek/mt76`(89)
- 板上 dtb 的 model = **`Anlogic, DR1M90 FPSoc`**
🔴 两个 dr1m90 defconfig 里都是 **`# CONFIG_WIRELESS is not set` / `# CONFIG_WLAN is not set`** ⇒ 要自己加。
厂商构建环境(从驱动示例的 `.cmd`/Makefile 抠出): `KERNEL_DIR=/home/uisrc/uisrc-lab-anlogic/sources/linux`,
`ARCH=arm64`, `CROSS_COMPILE=gcc-linaro-7.5.0-2019.12 aarch64-linux-gnu-`。本机只有 **aarch64-linux-gnu-gcc 15.2.0**,
⚠ 用 gcc 15 编 6.1 内核可能要加 `-Wno-error=...`(WSL 那次编 6.6 就踩过一串, 见 [[reference_wsl_p2p_wifi_rig]])。

🔴 **不能在 `~/dr1sdk/.../sources/linux` 里编**: 那棵树**不干净**(残留 DR1V90 的 riscv 树内构建, `CONFIG_RISCV=y`),
`make O=` 会要求先 `mrproper`, 而**另一个会话正用这棵树做 DR1M90 的 JTAG 移植**([[project_dr1m90_jtag_port_checklist]])。
⇒ 已 `cp -a` 出一份私有副本 **`~/dr1m90_kernel`** 再 mrproper。

🎯 **DR1V90 留下的决定性经验, 省掉一条死路**(`dr1v90/wifi/BRINGUP.md`):
**"只编模块"走不通** —— `CRYPTO_ALGAPI=y` ⇒ `CRYPTO_MANAGER2` 恒 y ⇒ `aead.o` 必然内建,
而原厂内核里没有 ⇒ mac80211 永远缺符号。**内核与模块必须同一次构建。**
✅ 可直接复用的: **MT7961 固件 4 个 blob 是架构无关的**, 在 `dr1v90/wifi/firmware/mediatek/`。
⚠ DR1V90 当年还缺 `regulatory.db`(哪儿都没有), 没它国家码卡 00、5 GHz 起不来。
⚠ rootfs 是 **initrd(RAM)**, 重启清空 `/lib/modules` `/lib/firmware` `/usr/sbin`
⇒ DR1V90 的做法是卡上放 `wifi_payload.tar.gz` + `wifi_tools.tar.gz`, 开机解回去。DR1M90 要照做(内容换 aarch64)。

## ✅ 2026-09-17 17:0x 带无线栈的 DR1M90 内核已编出来
私有树 `~/dr1m90_kernel`(从 SDK 那棵 `cp -a` 再 mrproper, 1.5 G)。配置已存档 **`dr1v90/boot/dr1m90_wifi.config`**。
基线 `anlogic_dr1m90_defconfig`(= 板上跑的那个, CONFIG_PREEMPT) + `scripts/config`:
`-e MODVERSIONS -e WIRELESS -m CFG80211 -m MAC80211 -m RFKILL -e WLAN -e WLAN_VENDOR_MEDIATEK`
`-m MT76_CORE -m MT76_USB -m MT76_CONNAC_LIB -m MT7921_COMMON -m MT7921U -e MT76_LEDS`
(6.1 的符号里**没有 MT792x_LIB**, 那是 6.3+ 才有的, 别照抄新内核的名字。)
🎯 **gcc 15.2 编 6.1 arm64 一次过, 零错误、不需要任何 -Wno-error workaround**(厂商用的是 gcc-linaro 7.5.0)。
🔴 **不要建 `dtbs`**: `arch/arm64/boot/dts/anlogic/Makefile` 引用 `anlogic-dr1.dtb`, 而树里只有 `anlogic-dr1m90-*.dts`
 —— 那份 `anlogic-dr1.dts` 是米联客工程流程生成后拷进内核树的(`01_ex_linux_base` 包里有)。
 我们只换内核, 设备树用出厂 `system.dtb`(USB 网卡不涉及 DT) ⇒ `make Image modules` 即可。
🎯 **uImage 打包参数(从出厂 uImage 头读出, 必须照抄)**: `-A arm64 -O linux -T kernel -C lz4 -a 0x400000 -e 0x400000 -n Linux`;
 payload 是 **LZ4 帧格式**(magic `04 22 4d 18`, 标准 `lz4` CLI 输出)。自编头与出厂逐项一致(8,131,628 vs 8,131,872 B)。
 ⚠ `boot.scr` 把文件读到 **0x10000000**, bootm 再把内核搬到 **0x400000** —— 两个地址不是一回事, 别混。
版本串 `6.1.111-rt42` **与出厂完全相同** ⇒ `uname -r` 区分不了自编/原厂, 判据看 `/proc/version` 的构建者(同 DR1V90)。
模块 vermagic: `6.1.111-rt42 SMP preempt mod_unload modversions aarch64`。

**产物 `dr1v90/boot/dr1m90_wifi/`**: `uImage.lz4`(8.13 MB) + `wifi_payload_aarch64.tar.gz`(1.5 MB)。
payload 内含 8 个 .ko(cfg80211 mac80211 rfkill mt76 mt76-usb mt76-connac-lib mt7921-common mt7921u,
已 `--strip-debug`) + `lib/firmware/mediatek/` 4 个 MT7961 blob(架构无关, 复用 DR1V90 的)
+ **`regulatory.db` + `regulatory.db.p7s`**(本机 `/lib/firmware/` 就有, 签名正是内核 `net/wireless/certs/` 内置那把 key) + MANIFEST.md5。

✅ `tools/update_dr1m90_card.ps1`(新, 带 BOM): 换 uImage 用。**它比 add_pov_to_card.ps1 危险**(动的是启动文件), 所以:
 ① 先按 `BOOT.bin`/`boot.scr`/`system.dtb` 的 md5 核对"这真是 DR1M90 出厂卡", 不对就拒绝;
 ② 写之前把出厂内核在**卡上**留一份 `uImage.factory.lz4` ⇒ 不启动时恢复只是一次改名, 不用从 PC 重拷;
 ③ 写完读回算 md5 才算过。
🔴 **9.6 MB 不能走串口**(实测 156 KB 用了 2 分钟 ⇒ 9.6 MB 约 2 小时)。板上有 `wget`/`tftp`/`udhcpc`,
 但 PC 侧 WSL 是 NAT, 跨到局域网给板子取文件有已知的坑 ⇒ **这次拔卡走读卡器**; 以后只换 mt76 模块(约 300 KB)再用串口推。
⚠ DR1M90 的 eth0 MAC 是 **`e0:78:a3:01:02:03`**, 与两块 DR1V90 的 `e0:78:a3:00:00:08` **不同** ⇒ 不会撞 MAC。

## 🔴🔴 2026-09-17 17:3x 自编内核起来了, 但**射频上电照样整板复位** —— DR1M90 没躲过 DR1V90 那个毛病
✅ 自编内核启动成功, 判据是 `/proc/version` 的构建者: `wanqi@PC-W003SS3G0143 ... gcc 15.2.0 ... Thu Sep 17 16:58:32 CST 2026`
(不是出厂的 `uisrc@ubuntu / Nov 18 2024`)。`uname -r` 两边都是 `6.1.111-rt42`, **区分不了**。
✅ payload 解回 `/lib` 后 14 个文件 md5 全 OK。⚠ 我生成 MANIFEST 时用 `find . -type f` **把 MANIFEST 自己也算进去了** ⇒ 它自己永远 FAILED; `pov/` 那份用 `grep -v MANIFEST` 排除了, 是对的。以后统一排除。
🔴 **漏了一个模块: `libarc4.ko`** —— `mac80211` 报 `Unknown symbol arc4_setkey/arc4_crypt`。
🎯 **别再靠试错凑模块**: `make modules_install INSTALL_MOD_PATH=… INSTALL_MOD_STRIP=1` + 读 `modules.dep`, depmod 直接给出闭包。
**mt7921u 的完整闭包 = 9 个**: `rfkill cfg80211 libarc4 mac80211 mt76 mt76-usb mt76-connac-lib mt7921-common mt7921u`(按此顺序 insmod)。
✅ 前 8 个全部干净加载(lsmod 依赖计数正确)。

🔴 **`insmod mt7921u.ko` ⇒ 整板复位**(17:29:54 日志里出现全新启动: dhcpcd/ssh-keygen/`Welcome to Buildroot`)。
- **只复位一次, 没进循环**: rx_bytes 18 s 不涨, 之后 uptime 正常增长到 141 s, 网卡仍枚举为 7961。
- 🎯 **与 DR1V90 的差别只是表象**: DR1V90 那个"18 s 一轮"的循环是因为**驱动开机自动加载**(S95pov)⇒ 每次启动都重试;
  这里模块在 RAM 里、重启即失 ⇒ 不重试 ⇒ 看起来"只复位一次"。**底层故障是同一个: 射频上电那一刻掉电复位。**
- 板上读不到复位原因(dmesg 无 reset reason/POR/brownout 字样)。
⇒ **PREP 文档里"供电风险还没测到"这一条, 今天测到了, 结论是: 有。**
⇒ 下一步待用户确认: 当时用的是什么供电(电脑 USB-C 还是充电头)。DR1V90 上 **换充电头 A/B 已确认是供电**([[feedback_dr1_wifi_dongle_brownout_reboot_loop]]);
  若这次已经是充电头还照样复位, 就是更硬的问题。**另一条更彻底的路: 网卡插带电 USB hub**, 把射频电流尖峰整个挪出板子的电源轨。

## ✅✅ 2026-09-17 17:4x DR1M90_01 WiFi bring-up 走通 —— wlan0 起来且射频上电不再复位
🔴 **根因确认是供电**: 之前那次 `insmod mt7921u` 整板复位, 用户确认当时**只用电脑 USB-C 供电**;
换成一个独立的 USB 口(把 DR1V90 那边用的那个换过来)后, **同一条命令过了, 板子没复位**。
⇒ 与 DR1V90 的结论一致([[feedback_dr1_wifi_dongle_brownout_reboot_loop]] 的"换充电头 A/B 已确认是供电")。
🔴 **板子唯一供电入口就是 Type-C 的 VBUS**(原理图 `MLKPAI_FS03_DR1_241023.pdf` 里写着
`VBUS_5V→5V→0.95V_VCCINT→VCCAUX_1.8V→3.3V&1.8V&VCC_DDR_1.35V→DDR_VTT`)
⇒ **psuart 那个口供电和串口共用**, 插充电头就没串口 —— 用户指出的这个约束是真的。
⇒ 所以"换充电头"在 DR1M90 上**不是免费的**; 想同时要大电流和串口, 正解是
  **把网卡插带电 USB hub**(把射频电流尖峰整个挪出板子的 5V 轨), 而不是动板子的输入电源。
🔧 板上 USB 主机口经 **CH217 限流配电开关**, `Iset = 60K/Rset`, 可调 400 mA~2.7 A(手册在硬件包
`05_相关芯片手册/06_USB/CH217DS1.PDF`); 实际 Rset 值原理图是矢量图抠不出来
⇒ **主机口能给多少电流是板子设计时定死的, 与板子输入电源多强无关**, 这是"带电 hub"方案更可靠的硬理由。

**实测通过的链条**(全部一手):
1. 自编内核启动: `/proc/version` = `wanqi@PC-W003SS3G0143 ... Sep 17 16:58`(不是 `uisrc@ubuntu`)
2. `sh /mnt/mmcblk0p1/pov/wifi_up.sh` ⇒ 9 个模块全 OK, lsmod 依赖计数正确
3. **固件下载成功**: `mt7921u 1-1:1.0: HW/SW Version: 0x8a108a10` + `WM Firmware Version: ____010000, Build Time: 20260224110949`
4. **`wlan0` + `phy0` 注册成功**; ⚠ netdev 注册比固件打印晚几十秒, **我第一次查太早以为失败了** —— 查 wlan0 要留时间/重试
5. `ip link set wlan0 up` OK; **60 s 稳定性: uptime 140→200 s 无复位**
6. regdb 证书已加载: `cfg80211: Loaded X.509 cert 'sforshee'` / `'wens'`(regulatory.db 本身是首次用到时才加载)
🎯 **wlan0 MAC = `90:de:80:47:f0:fd` —— 与 DR1V90-2 上那块 dongle 同一个 MAC**
⇒ **是同一块物理 MT7921AU**, 所以两块板的吞吐数天然可比(同一个射频), 这对 A/B 是好事。

✅ 卡上已放 **`pov/wifi_up.sh`**(纯 ASCII): 解 payload + 按 depmod 闭包顺序 insmod 9 个模块 + 打印 lsmod/网卡/uptime。
 initrd 每次重启清空 `/lib`, 所以"加载驱动"永远是解包再 insmod ⇒ 重启后跑这一条就行。
 `pov/libarc4.ko` 也单独放在卡上(卡上那个 tarball 是漏了 libarc4 的旧版; PC 侧 `boot/dr1m90_wifi/wifi_payload_aarch64.tar.gz` 已修为 9 模块 + 带 wifi_up.sh + MANIFEST 不含自己)。

**下一步(还缺)**: 板上**没有 `iw` / `wpa_supplicant`** ⇒ 连不了 AP, 也读不到国家码(必须不是 `00`, 否则 5 GHz 起不来, 而要量的 HE80 全在 5 GHz)。
✅ DR1V90 当年的构建环境还在 **`~/wpabuild`**(`iw-5.19` / `libnl-3.7.0` / `wpa_supplicant-2.10` + `pkg` `sysroot`) ⇒ 改架构重编 aarch64 即可, 不用从零找。

## 🎯🎯 2026-09-17 18:1x 第一个真数: **DR1M90 原版驱动 TCP 接收 162 Mbit/s**
台架: 09-15 那套 WSL 点对点(PC 第二块 MT7921AU + usbipd + 自编无线栈 + hostapd), SSID `pov3d-p2p`,
信道 48 / 5240 MHz / 80 MHz, AP 192.168.77.1, 板 192.168.77.2, 信号 **-30 dBm**,
空口协商 **1200.9 Mbit/s 80MHz HE-MCS11 HE-NSS2** —— 与 DR1V90 当时**同一块 dongle、同一套台架、同一协商速率**, 对照条件干净。

| 配置 | TCP 接收 |
|---|---|
| DR1V90 原版驱动 | 91.7 |
| DR1V90 v3p1 补丁 + 芯片 USB RX 聚合 | 136 |
| 🎯 **DR1M90 原版驱动, MTU 1500, 零调优** | **162** |

⇒ **原版就超过 DR1V90 打满补丁的 136(+19%), 是 DR1V90 原版的 1.77 倍。**
⇒ 而且 **162 > 文档里"台架发送端封顶 145"** ⇒ 那个 145 不是硬限(当时的测法/配置所致), [[reference_wsl_p2p_wifi_rig]] 那条要改。
⇒ **PREP 文档 160-210 的推算区间, 下沿被实测证实**; 补丁和 MTU 2304 两个杠杆都还没上。

UDP 裸收阶梯(5 s/档, 全部无复位): 20M→20.0 / 50M→50.0 / 110M→110(0.4% 丢) / 140M→139(0.81%) / **请求 200M→实收 159(11% 丢)**
⇒ UDP 顶 ~159, 与 TCP 162 基本同一水平 ⇒ **此时瓶颈不在 TCP 协议栈**。DR1V90 的 UDP 裸收是 ~130@100% CPU。

## 🔴 但**持续负载会掉电复位** —— 这是现在的真瓶颈, 不是 CPU
- TCP **5 s @162 Mbit/s: 过**(uptime 继续涨)
- TCP **20 s: 复位**(18:03 那次和 18:11 这次都是); UDP 5 s 各档全过
⇒ **是"持续电流"而不是"瞬时尖峰"**: 秒级能扛, 十几秒扛不住。
⇒ 供电仍是 **电脑 USB-C**(板子唯一供电入口 = Type-C VBUS, 且与串口共用一个口)。
🔴 **所以 162 这个数是"5 秒内的数", 不是可持续吞吐。** 报这个数必须带上这句。
下一步验: ① 时长阶梯找断点 ② 降板子 TX 功率(`iw dev wlan0 set txpower fixed`)看能否延长 —— TCP 要发大量 ACK, 发射电流远高于接收, 这能分离"TX 电流"这个变量 ③ **带电 USB hub**(根治)。

✅ 卡上已放好, 重启后两条命令恢复(initrd 每次清空 /lib /usr /tmp):
`sh /mnt/mmcblk0p1/pov/wifi_up.sh`(解 payload+工具, 先 insmod **cmac/ccm** 再 9 个无线模块, 等 wlan0, `iw reg set CN`)
`sh /mnt/mmcblk0p1/pov/wifi_join.sh`(内联 hex PSK 的 wpa conf, 关联, 配 192.168.77.2)
🔴 **`ccm.ko`/`cmac.ko` 是 depmod 看不见的运行时依赖**: mac80211 装 CCMP 密钥时按算法名 `ccm(aes)` 请求模块(request_module),
不是符号引用 ⇒ **`modules.dep` 里没有**。缺了它 4 次握手死在 `Failed to set PTK to the driver`,
而 wpa_supplicant 会把它误报成 **"pre-shared key may be incorrect"** —— 我为此白查了一轮密码。
**AP 侧日志才是关键证据: hostapd 说 `EAPOL-4WAY-HS-COMPLETED` ⇒ 密码本来就是对的。**
教训: 四次握手失败时**先看 AP 侧日志**, 别信客户端那句"密码可能不对"。

## 🎯🎯🎯 2026-09-17 18:2x 摸到台架尽头: **DR1M90 ≥158 Mbit/s 持续, 且还剩 33% CPU**
🔴 **先纠正上一节的 162**: 那是**不限速 TCP** 的数, 5-8 s 就把板子搞复位, 是突发撑出来的虚高。
**给发送端限速(`iperf3 -b`)做整形后, 板子稳跑 30 s 不复位** ⇒ **掉电是突发电流, 不是平均功耗**。

限速 30 s 阶梯(每档都活): 60M→60.0 / 90M→90.0 / 110M→110 / 130M→130 / 155M→155 / **160M→158** / 165M→157(顶)
⇒ **可持续 TCP 接收 ≈ 158 Mbit/s**(原版 mt76 驱动, MTU 1500, 零调优)。

🎯 **158 是台架的极限, 不是板子的**, 两条独立证据:
1. **板子 CPU 在 158 时 idle 33%**(双核合计, 即只用掉 1.34 核)。`top`: 56% sys / 13% irq / 4% sirq,
   `mt76-usb-rx phy` 22%, iperf3 9%, load 2.06。**对比 DR1V90 在 136 时单核已 100% 打满。**
2. **发送端 UDP 请求 300M 只发出 158 Mbit/s, 而 WSL 侧 CPU 99.5% 空闲** ⇒ 发送端在自己不忙的情况下发不出更多,
   正是 USB/IP 经 Hyper-V vEthernet 的每帧开销([[reference_wsl_p2p_wifi_rig]] 记的 145, 今天实测 158)。

| | TCP 接收 | CPU |
|---|---|---|
| DR1V90 原版 | 91.7 | 单核 100% |
| DR1V90 v3p1+聚合 | 136 | 单核 100% |
| **DR1M90 原版, 零调优** | **≥158(台架顶)** | **双核只用 1.34, 余 33%** |

⇒ **DR1M90 原版就比 DR1V90 打满补丁快 16%+, 且还没到自己的墙。**
⇒ 三个杠杆一个都还没用: mt76 的 3 个补丁、芯片 USB RX 聚合、MTU 2304。
⇒ **200 Mbit/s 目标现在看是可达的**(线性外推 1.34 核→158 则 2 核→~236, 但 `mt76-usb-rx` 是单线程,
  不能线性外推到底, 所以这只是"看起来可达", 不是结论)。
🔴 **要测出真实上限, 必须换发送端** —— 这正是已定的 B 路线(专用 AP + 有线发送端)。台架这条路到此为止。

⚠ TX 功率这条杠杆**不存在**: 板子 `txpower` 本来就是 **3.00 dBm**(被 CN 国家码压在底), 没有下调空间。
⇒ 掉电不是"射频发射电流"单独造成, 是整板在高速率下的总功耗/突发电流超过电脑 USB-C 的供给。

## 🎯🎯🎯 2026-09-17 20:2x 有线对照实验 —— 定位瓶颈在 USB-WiFi 路径, 不在 SoC
台架: 一根网线**直连** PC 的空闲 Realtek 2.5GbE 口 ↔ 板子 eth0(RGMII/YT8531), 双方 1 Gbps 链路。
🎯 **不需要管理员权限也不用改 PC 网络设置**: PC 那个口已自动拿到 APIPA `169.254.140.60/16`,
只要把板子 eth0 设成同段(`169.254.140.61/16`)就通(ping 0% 丢, RTT 0.6-1.3 ms)。
⚠ 先把 wlan0 上的 169.254 地址删掉, 否则两个接口同段会打架。
✅ **WSL 能穿过 NAT 直接打到这个 link-local 地址**(实测 940 Mbps), 不必装 Windows 原生 iperf3。

**有线限速阶梯(20 s/档, 全部无复位)**: 200M→200 / 300M→300 / 400M→440 / 500M→550 / 600M→649 / 800M→835 / **940M→941(线速)**
⇒ **板子 TCP 接收在有线上能持续跑满千兆线速。协议栈/内存带宽/CPU 都不是 200 Mbit/s 的瓶颈。**

🎯🎯 **同速率 CPU 对照(158 Mbit/s, 这是最有说服力的一组)**:
| 158 Mbit/s 接收 | CPU idle(双核) | 折合核数 |
|---|---|---|
| **eth0 有线** | **90%** | **0.20 核** |
| **WiFi (mt7921u/USB)** | **33%** | **1.34 核** |
⇒ **同样的比特率, WiFi 路径比有线贵 6.7 倍 CPU。**
原因: eth0 走 stmmac, 有硬件校验和/TSO/GRO + DMA 直入内存, 一次中断覆盖多个包;
WiFi 走 USB: 每个 802.11 帧一个 dwc2 URB → mt76 解 RX 描述符 → mac80211 做 802.11→802.3 转换 → 逐包 netif_receive_skb。
⇒ **瓶颈是 USB-WiFi 的每包开销, 不是这颗 SoC。** 有效的杠杆只有降低"每包成本"那一类:
  芯片 USB RX 聚合、GRO、MTU 2304 —— 这正好对上 DR1V90 上拟合出的 `T = u/k + p`。

## 🔴 供电的真相(比前面几条都准): 是**突发**, 不是平均, 而且与数据路径无关
- WiFi **不限速** TCP(162): 5-8 s 复位 | WiFi **限速** 158: 30 s 无事
- 有线 **不限速**(940): 25 s 复位 | 有线 **限速 940M**: 20 s 无事(941 Mbps, 线速)
⇒ 🔴 **我中途说过"掉电是网卡射频电流造成的", 那是错的** —— 有线测试时网卡只是挂着不跑流量, 一样掉;
  而限速到同样甚至更高的平均速率反而不掉。
⇒ **结论: 是未整形流量的突发电流**(瞬时功耗尖峰), 电脑 USB-C 供不上。平均功耗本身是够的。
⇒ 实践上: **所有测试都用 `iperf3 -b` 限速**, 就能在现有供电下稳定测量, 不必等 hub。
⇒ 根治仍建议**带电 USB hub 接在 PC 与板子 Type-C 之间**(hub 供电、数据仍回 PC ⇒ **串口不丢**),
  这比"换充电头"好, 因为板子唯一供电口与串口共用。
今天板子复位十几次(日志里 21 条启动横幅, 含 CR 探测的重复打印), 每次都要跑 wifi_up.sh + wifi_join.sh 重来。

**How to apply(更新)**: 谈 DR1M90 能到多少时, 用 **≥158(台架顶, 板子还剩 33% CPU)**, 并说明
**有线能到 941 ⇒ 200 的目标不受 SoC 限制**; 要测出 WiFi 真实上限必须换发送端(专用 AP + 有线发送端)。

## 🎯 为什么 WiFi 路径比有线贵 6.7 倍 —— 理论与实测对齐(2026-09-17)
**框架: 代价按"包"算, 不按"字节"算。** 证据是 DR1V90 的拟合 `T = u/k + p`(u≈60 µs/URB, p≈72.5 µs/包):
**只改聚合系数 k、字节数不变**, 吞吐 87.3 → 136(+56%) ⇒ 成本确实挂在包数上。
WiFi 多付的几笔:
1. 🎯 **stock mt76-usb 根本不做 GRO** —— 从 `patches/gro.patch` 源码确认(不是推测): 该补丁要**自造一个假 NAPI 上下文**当 GRO 聚合点,
   注释原文 "dev->napi[MT_RXQ_MAIN] is only used as a GRO context fed synchronously by the rx worker"。
   而板上 `eth0` 实测 `generic-receive-offload: on`。⇒ 有线上几十个 TCP 段进 IP/TCP 前已合成一个大 skb; WiFi 上**每帧单独走完整栈**。**这是最大一笔。**
2. `eth0` 还有 `rx-checksumming: on` / `tcp-segmentation-offload: on`; USB WiFi 无对应卸载。
3. **802.11→802.3 每帧转换**: 剥变长 802.11 头(QoS/HT/HE control 长度不同)、剥 CCMP 头 8 B + MIC、处理 LLC/SNAP、重写以太网头。有线帧进来就是栈要的格式。
4. **mac80211 逐帧记账**: BA 重排序缓冲(按 TID)、重复帧检测、CCMP PN 重放检查、速率统计。
5. **传输粒度**: 每帧一个 dwc2 URB + 软件处理完成事件 + 解 RX 描述符(`round_up(len,8)+4`); stmmac 是 DMA 环 + 硬件中断合并。
🎯 **实测把"按字节"这个解释排除了**: 同样 158 Mbit/s、同一 TCP 栈、同一次 recv() 拷贝、同样字节数 ⇒ 有线 0.20 核 vs WiFi 1.34 核。
若代价按字节算, 两者应接近。⇒ 6.7× 只能来自驱动+mac80211+未聚合的栈穿越。
⇒ **有效杠杆只有降低"每字节包数"那一类**: 芯片 USB RX 聚合(DR1V90 实测 +48%)、GRO 补丁、MTU 2304(包数 ÷1.55)。
   **单纯换更快 CPU 只压 p**, 而 SoC 不是墙已有硬证据(同板 eth0 跑满 941 Mbps 线速)。

## 关于"要不要也测 DR1V90"(2026-09-17 用户问)
**WiFi 不用**: 同一套台架、同一块 dongle 的数已有(原版 91.7 / 补丁 136, 09-15)。
**有线有一点价值但不建议现在做**: DR1V90 的 eth0 吞吐从没测过(09-15 实验被取消), 测了能得纯 CPU 对 CPU 对照;
但要挪线, 而 DR1V90-1 是 JTAG 台架板(台账规定不碰)、DR1V90-2 已拔 ⇒ 收益是"知道快多少", 而我们已知"够快", 不值得打乱 JTAG 那条线。

## 🔴 2026-09-17 20:4x 供电成为硬阻塞 —— 千兆 PHY 的电流就是压垮骆驼那根稻草
测完有线之后回去测 WiFi, **连续在 `wifi_up.sh`(射频上电) 和 `wifi_join.sh`(EAPOL 要发包) 处复位**,
而几小时前同样的命令是能过的。变量是: **eth0 现在插着网线、千兆链路 up**(YT8531 跑 1000BASE-T 要几百毫瓦)。
✅ **假设已验证**: `ip link set eth0 down` 之后 `wifi_up.sh` **一次就过, 不复位**。
🔴 但 **每次开机 eth0 会自动 link up**(`dwc-eth-dwmac ... Link is Up - 1Gbps/Full`), 软件 down 掉的设置重启即失
⇒ **要稳定省下这份电流必须物理拔掉网线。** 只留其中一条链路(WiFi 或有线), 不要两条同时在。

**今天到此为止能给出的 DR1M90 WiFi 结论:**
- **可持续 TCP 接收 ≥158 Mbit/s**(原版 mt76 驱动, MTU 1500, 零调优, 限速发送, 30 s 无复位)
- **158 是台架顶不是板子顶**: 板子此时 CPU 还剩 33%(只用 1.34/2 核); 发送端 UDP 请求 300M 只发出 158 而其 CPU 99.5% 空闲
- **上限尚未测到。** 三个杠杆(芯片 USB RX 聚合 / GRO 补丁 / MTU 2304)一个都没用上
- **SoC 不是墙**: 同一块板 eth0 持续跑满 **941 Mbit/s** 线速, 且同速率下 WiFi 比有线贵 **6.7 倍** CPU
⇒ 200 Mbit/s 目标**没有被 SoC 否掉**, 要测出真值需要: ① 供电 ② 更强的发送端。

**要继续测 WiFi 上限, 需要的两件事(按顺序):**
1. 🔴 **供电**: **带电 USB hub 接在 PC 与板子 Type-C 之间** —— hub 供电、数据仍回 PC ⇒ **串口不丢**。
   这比"换充电头"好, 因为板子唯一供电口(Type-C VBUS)与串口共用。同时**拔掉网线**。
2. **发送端**: 专用 AP + PC 的 2.5GbE 有线发送(B 路线)。🎯 **发送端那半今天已被独立验证**:
   PC 的 Realtek 2.5GbE 口 + WSL 打到板子 eth0 实测 **941 Mbit/s**, 所以 B 路线的瓶颈只剩 AP 本身。
   权宜之计 **MTU 2304** 能把台架顶从 158 抬到约 248(pps 不变、每包 ×1.57), 今天因为反复掉电没测成。

## ✅ 2026-09-17 20:5x 改用 SSH 控制, 弃用串口; 目标调整为 300 Mbit/s
🔄 **用户 2026-09-17 把目标从 200 调到 300 Mbit/s**, 并换 **5V/3A 充电头**供电(Type-C 供电口与串口共用 ⇒ 换充电头就没串口)。
⚠ 我已说明: **300 恰好落在 USB 2.0 的实机墙上**(需 39.9 MB/s USB 吞吐, 实机好主机 40-45 MB/s;
按实测封装 1448 B 段占 1540 B = ×1.064 折算) ⇒ **300 是天花板而非舒适目标**; **350/400 做不到**
(350 需 46.6 MB/s、400 需 53.2 MB/s ≈ 规范理论值), 且 dwc2 是软件调度主机, 只会更差。
要 350-400 必须换链路形态(USB3/PCIe), 而**四个 484 候选全无 PCIe**。

✅ **无串口控制通路已验证(在还有串口时先验的, 顺序很重要)**:
- 板上 `sshd` 出厂就跑(pid 217), `/etc/ssh/sshd_config` 有 **`PermitRootLogin yes`**, root 密码哈希在镜像 `/etc/shadow` 里(就是 `root`)
- 🔴 **必须用密码认证, 不能用密钥**: `/root` 在 initrd(RAM), 重启即失, 而没串口就没法再塞公钥进去。
  密码烧在镜像里 ⇒ 跨重启有效。主机密钥每次开机重新生成 ⇒ 需 `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null`
- 命令: `sshpass -p root ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@<板子IP>`(WSL 已装 sshpass)
- **eth0 地址由出厂 dhcpcd 自动配 APIPA `169.254.125.44/16`, 跨重启稳定**(不依赖我们放的任何东西)
- 🎯 **丢地址的退路: Windows ARP 表按 MAC 找** —— `Get-NetNeighbor | ? LinkLayerAddress -eq 'E0-78-A3-01-02-03'` → 169.254.125.44
⚠ 代价: 没串口 ⇒ 板子卡死或网络起不来时完全失明, 恢复只能靠人断电。

✅ **三个 mt76 补丁已套上 DR1M90 内核并编出 aarch64 模块**(`~/dr1m90_kernel`, 叠加顺序照 DR1V90):
`gro.patch` → `rxagg_v3_on_gro.patch` → `v3p1/rxagg_v3p1_on_v3.patch` → `mt7921u_disconnect.patch`, **四个全部干净套上(+558 行), 编译零错误零警告**。
🎯 **补丁生效的判据(modinfo -F parm, 必须出现这些)**: `disable_usb_gro`(GRO 补丁),
`rx_agg` / `rx_agg_buf_size` / `rx_agg_multi_en` / `rx_agg_align` / `rx_agg_trailer` / `rx_agg_urbs`(聚合 v3/v3p1)。
产物(strip 后): mt76.ko 113K / mt76-usb.ko 48K / mt76-connac-lib.ko 75K / mt7921-common.ko 121K / mt7921u.ko 22K。

## 🔴🔴 2026-09-17 21:0x 换 5V/3A 充电头后**更差了** —— 干净的 A/B 指向供电路径而非板子
| 供电 | eth0 状态 | 射频上电(mt7921u probe) | 关联(EAPOL TX) | 吞吐 |
|---|---|---|---|---|
| 电脑 USB-C | **物理拔掉网线** | ✅ 过 | ✅ 过 | ✅ **158 Mbit/s 持续 30 s** |
| 5V/3A 充电头 | 千兆 up | ❌ **确定性复位**(连试 2 次 uptime 都 77 s) | — | — |
| 5V/3A 充电头 | 强制 100 Mb/s | ✅ **过**(RESULT: WIFI UP, wlan0 2 s) | ❌ 复位 | — |
| 5V/3A 充电头 | `ip link set eth0 down` | ❌ 复位(脱离终端脚本跑的) | — | — |
⇒ 🔴 **最后一行是关键: eth0 完全关掉时, 充电头路径仍然失败, 而电脑 USB-C 路径当时是成功的**
⇒ **充电头这条路给的电流比电脑 USB-C 口还少。**
🎯 **最可能的原因: 线是 USB-A → Type-C, 或充电头本身是 A 口输出。**
Type-C 的取电许可靠 CC 引脚上的 Rp 电阻通告; A 口那头没有 CC ⇒ 板子只能按 **legacy 500 mA** 取电,
而电脑 USB-C 口通常给 900 mA~1.5 A。**充电头标 3A 不代表板子能吃到 3A。** 必须 **C-to-C 线 + Type-C 输出的充电头**。
🎯 **另一个已验证的省电手段(要留着用)**: **eth0 从 1000 降到 100 Mb/s**
(`ethtool -s eth0 speed 100 duplex full autoneg on`) 就足以让射频上电从"确定性复位"变成"通过"
—— 1000BASE-T 的 PHY 功耗远高于 100BASE-TX, 而 SSH 控制面用不到千兆。
🔴 **但每次重启 eth0 会自动回到 1000 Mb/s**(`ethtool -s` 不持久) ⇒ 每次启动后要重设。
🔴 **板子空载在充电头上是稳的**(uptime 35→61 s 正常增长) ⇒ 不是持续供电不足, 是**负载阶跃**时垮。
⇒ 与"有线 941 Mbit/s 不限速也会复位、限速到 941 反而不会"完全一致: **敏感的是快速负载阶跃, 不是平均功耗。**

**结论: 在供电路径修好之前, WiFi 上限测不下去。** 三个杠杆(补丁已编好待用 / 芯片聚合 / MTU 2304)全部卡在这。
恢复测量的两条路: ① 确认并换成 **C-to-C 线 + Type-C 输出充电头**; ② **带电 USB hub 给 dongle 供电**(根治, 且不占板子 5V 轨);
③ 退回**电脑 USB-C + 串口 + 拔网线**这个**已验证可用**的组合继续测(代价: 没有有线控制面, 回到串口)。

## 🔴 2026-09-17 21:1x 退回"电脑 USB-C + 串口 + 拔网线"后, 供电仍然是概率性失败
用户已换回该组合(网线 Disconnected、COM24 回来、板子在同一个 USB 口 **busid 1-12**, 与 17:37 成功那次**同口**)。
但现在: **`wifi_up.sh`(射频上电) 约 50% 成功; `wifi_join.sh`(EAPOL TX) 基本必复位。**
⇒ 同一配置在 17:37-18:11 那个窗口是稳定可用的(还跑出了 158 持续 30 s), 现在不行 ⇒ **有退化因素**,
最可能是**热**(板子+MT7921AU 连续跑了 4+ 小时, dongle 发热后电流上升)。口/线/供电路径都已排除(同 busid)。
⇒ **不要再靠重试硬碰**: 每次尝试约 2 分钟, 关联那步基本不过, 效率极低。

🎯 **必要的解除阻塞项: 带电(有源) USB hub 给 dongle 供电。**
理由(全部有今天的实测支撑):
- 板子唯一供电入口是 Type-C VBUS, 与串口共用 ⇒ 换充电头就没串口, 且**实测充电头路径给的电流还更少**(疑 A-to-C 线, 无 CC ⇒ 500 mA)
- 主机口经 CH217 限流, 门限由固定 Rset 定死 ⇒ **板子能给 dongle 多少电流与上游电源多强无关**
- 板子**空载稳定**、**限速流量稳定**、**负载阶跃/射频上电时垮** ⇒ 要拿掉的是 dongle 那份尖峰电流, 不是提高平均供电
⇒ hub 接在 dongle 与板子之间(hub 自带电源), 射频电流走 hub 的电源, 不经过板子 5V 轨。

**今天的最终成果(供电修好后可直接继续):**
- DR1M90 WiFi TCP 接收 **≥158 Mbit/s**(台架顶, 原版驱动零调优), 该点**板子 CPU 尚余 33%**
- **SoC 不是墙**: 同板 eth0 持续 941 Mbit/s 线速; 同速率 WiFi 比有线贵 **6.7×** CPU
- **三个杠杆已备好待用**: 四个 mt76 补丁已套进 DR1M90 内核并编出 aarch64 模块(参数判据已验)、芯片 USB RX 聚合、MTU 2304
- 🔴 补丁模块**还没送上卡**(打算走 scp 时有线已被拔掉) ⇒ 下次要么先 scp 再拔网线, 要么走串口推 ~379 KB(约 6 分钟)

## 🔴 2026-09-17 立项: 转子旋转下的吞吐测量 (全文 [[project_rotor_spinning_wifi_throughput_gap]])
用户问"普通家用 WiFi 能不能到这个速度"。答: **能, AP 不是瓶颈** —— 今天的证据是台架发送端顶 158 而其 CPU 99.5% 空闲,
空口协商 1200.9 Mbit/s(2×2 HE80 MCS11), 任何 WiFi 6 路由器给的都是同一条链路(MT7921AU 就是 2×2, AP 再强也喂不进更多);
连 WiFi 5(ac) 的 2×2 VHT80 MCS9 = 867 Mbit/s PHY 对 300 都富余。
**但四个条件缺一不可**: 5 GHz **80 MHz**(2.4G 不可能)、🔴 **独占空口**(我们的 158 是 -30 dBm/信道 48/零其他流量下测的;
家用环境被邻居挤到 40 甚至 20 MHz 就腰斩 —— 这才是买**专用 AP** 的真正理由, 不是 AP 性能)、有线上行千兆、距离近。
🔴 **而真正的空白是: 所有数都是静止测的, 转子旋转下从未测过。** 单独立了一条记忆, 见上面的链接。

## 🎯 2026-09-17 架构对比: Zynq vs DR1V90 vs DR1M90 的 WiFi 接收能力
| | Zynq-7020 | DR1V90 | DR1M90 |
|---|---|---|---|
| CPU | 2× Cortex-A9 | 1× RISC-V 800 MHz | 2× Cortex-A35 |
| USB 主机 | **ci_hdrc**(ChipIdea) | **dwc2** | **dwc2 @ f8180000**(今天实测, 与 DR1V90 同 IP 同地址) |
| USB3 / PCIe | 无 / 无 | 无 / 无 | 无 / 无 |
| 千兆网 | GEM | stmmac | dwc-eth-dwmac + YT8531 |
| WiFi TCP 上限 | **~125** | 91.7 原版 / 136 补丁 | **≥158** |
| 撞的是什么墙 | 🔴 **未归因** | **CPU 单核 100%** | **台架**(板子余 33% CPU) |

**结构性共同点**: ci_hdrc 和 dwc2 都是 USB 2.0 且都是"软件重"控制器 —— 没有 xHCI 那种**硬件环(TRB)调度**,
每个批量传输要软件调度进有限的 host channel 再逐个处理完成中断。这是两块板 USB 都费劲的根因。

**接收一帧的主机侧流程(stock 每一步都是「每帧一次」)**:
dwc2 URB 完成→中断→completion(u≈60 µs/URB) → mt76-usb 取帧(🔴 stock **只取 transfer 里第一帧**) →
解 RXD 描述符建 skb → mac80211(去重/CCMP PN 重放/BA 重排序/802.11→802.3 转换/剥 CCMP 头+MIC/LLC-SNAP) →
`netif_receive_skb`(🔴 stock **无 GRO**, 逐包进栈) → IP/TCP(软件校验和/拥塞控制/重排) → recv() 拷贝 (p≈72.5 µs/包)。
有线路径: stmmac 硬件校验和 + DMA 直写 ring → NAPI 批量 poll(硬件中断合并) → `napi_gro_receive` **GRO 合成大 skb** →
一个大 skb 只走一次 IP/TCP → recv()。
⇒ **有线把这些按"GRO 超级包"付一次(可含十几个线上包), WiFi 按"每个 802.11 帧"付一次** ⇒ 今天量到的 6.7×。

🔴🔴 **但 158 vs 125 是被污染的对比, 不能据此说"DR1M90 的 USB/驱动比 Zynq 好"**:
- DR1M90 的 158: **专用点对点 AP、-30 dBm、信道 48 零争用**
- Zynq 的 125: **办公 AP**(SSID `undef`), 且当时 PHY 协商 324-540 而 TCP 只 124 ⇒ **效率 25-28%**(正常 WiFi 50-65%),
  这个缺口记忆里列的两个嫌疑「mt76 的 USB 批量开销」和「**办公 AP 空口争用**」**至今都没排除**
⇒ 158 > 125 有可能**只是因为空口干净**。
⚠ 另外单核性能上 **A35(~1.78 DMIPS/MHz) 反而低于 A9(~2.5)** ⇒ DR1M90 的优势不在单核算力。
⚠ 也不是"双核比单核会分散": Zynq 在 125 时是**两核各 50% busy**(合计 1.0 核), 本来就分散了。

## 🎯 待做: 同口插 U 盘测裸吞吐 —— 从 8 月挂到现在, 且**当前阻塞对它无效**
[[reference_wireless_link_alternatives]] 早就把它标为 ⭐"决定性且几乎免费", 但 Zynq 和 DR1 都没做过。
(⚠ 记忆里"U 盘 480M"只是**枚举速度**, 不是实测吞吐, 别当结果用。)
判据: **U 盘 250+ Mbps ⇒ 是 mt76/驱动的锅, USB 主机还有空间; 也只有 ~125-160 ⇒ dwc2 主机到顶, 换什么 dongle 都没用。**
它直接把「USB 主机控制器」和「mt76+mac80211 每包开销」两个嫌疑分开 —— 正是"WiFi 解析能力差别"的核心。
🎯 **对 DR1M90 现在特别合适: 不需要射频上电 ⇒ 不会掉电复位**, 供电那个阻塞卡不住它。只要往板子 USB 口插一个 U 盘。

## ✅✅ 2026-09-18 换 PC 上另一个 USB 口, 掉电问题彻底解决
用户把板子 Type-C 换到 **PC 的另一个 USB 口(busid 7-2, 之前是 1-12)**, 其余不变(串口在, 网线未接)。
| 测试 | 结果 | 板子 |
|---|---|---|
| `wifi_up.sh` 射频上电 | ✅ 一次过 | 活 |
| `wifi_join.sh` 关联 | ✅ `wpa_state=COMPLETED after 1s` | 活 |
| 限速 160M / 30 s | **159 Mbit/s** | 活 |
| 🎯 **不限速 20 s**(9-17 时 5-8 s 必掉电) | **159 Mbit/s** | **活** |
⇒ 🎯 **同一块板、同一根线、同一个充电/供电类型, 只换 PC 上的 USB 口, 从"射频上电 50% 复位"变成"不限速满载也不复位"。**
**教训: 排查这类掉电时, "换 PC 上另一个 USB 口"要排在换充电头、换线、买 hub 之前 —— 它免费且这次就是它。**
(9-17 那晚的 5V/3A 充电头反而更差, 现在看大概率是那条 A-to-C 线只给 500 mA。)
台架顶仍是 **159**(与 9-17 的 158 一致, 可比)。

## 🔴 2026-09-18 MTU 2304 在这套台架上不可用 —— 抓到了直接证据
两端 `ip link set wlan0 mtu 2304` 都设上, **2276 B 的 DF ping 0% 丢包**(比 9-15 更进一步), 但 iperf3 一跑:
- 板子**没复位**(uptime 继续涨), **AP 也没崩**, 但**板子掉线**(`iw link` → Not connected)
- 🎯 AP 侧 dmesg 抓到根因: **`Workqueue: mt76 mt7921_mac_reset_work` + `mt76u_stop_tx` + `mt7921u_mac_reset`**
  ⇒ **MTU 2304 的流量把 AP 侧 mt7921 打进了 MAC 复位**
- 复位后 nl80211 残留注册 ⇒ hostapd 再也切不进 AP 模式: **`nl80211: Could not configure driver mode` / `kernel reports: Match already configured`**, `iw info` 显示 `type managed`
✅ **恢复办法(不用物理拔插, 9-15 记的"只能拔插网卡"可以更新)**: `usbipd detach --busid 3-4` → `attach --wsl`
⇒ 设备重新枚举成**新的 phy(phy1)**, 固件重下, 再 `iw reg set CN` + 重起 hostapd 即可。
🔴 **重起后 AP 可能落在不同信道**: `hostapd_ch44.conf` 配的是 44(5220), 但它**只要在 44 上看到别人的信标就会自己挪到 48(5240)**
("Switch own primary and secondary channel...")。9-17 在 48, 9-18 在 44。
⇒ 🔴 **板子端 `scan_freq`/`freq_list` 写死单一频点会让一个完全健康的 AP 看起来连不上** —— 我为此白查了一轮。
   **已把卡上 `wifi_join.sh` 改成 `scan_freq=5220 5240` / `freq_list=5220 5240`**, 代价只是多扫一个信道。
⇒ 结论: **MTU 2304 这条杠杆在本台架上验不了**(是 AP 侧 mt7921u 的 TX 路径扛不住, 不是板子的问题);
  换真 AP 之后值得重试, 因为它同时能抬高台架顶(pps 不变 ×1.57)。

## 2026-09-18 原版驱动的 CPU 基准(供补丁对比)
固定 **150 Mbit/s** 限速、信号 -42 dBm、5220 MHz、MTU 1500:
**CPU idle 22.6% ⇒ 用掉 1.55 核**; `mt76-usb-rx phy` 26%, iperf3 13%。
⚠ 与 9-17 在 158 时测的 1.34 核不完全可比(那次信号 -30 dBm) ⇒ **补丁对比必须在同一次会话、同一信号条件下做**, 这就是本次基准的用途。

## 🎯🎯 2026-09-18 三个杠杆逐个实测 (固定 150 Mbit/s, 同一会话, 信号 -42~-44 dBm, 5220 MHz, MTU 1500)
判据统一用"同吞吐下的 CPU 核数"(台架顶 159 卡不住这个对比)。补丁模块在线替换(先 rmmod 5 个 mt76 模块再 insmod 补丁版, **5 个全部干净卸载, 无 oops**)。
⚠ 在线替换后接口会被**重命名**(wlan0→wlan1→wlan2, 旧名字还被占着) ⇒ 脚本里写死 `wlan0` 会失效, 要用 `ls /sys/class/net | grep ^wlan` 取当前名。

| 配置 | CPU(双核) | 折合核数 | 相对原版 |
|---|---|---|---|
| **原版驱动** | idle 22.6% | **1.55 核** | 基准 |
| **补丁: GRO 生效, 聚合关**(`disable_usb_gro=N`, `rx_agg=N`) | idle 29.2% | **1.42 核** | 🎯 **−8.4% CPU** |
| **补丁: GRO + 驱动侧 `rx_agg=Y`**(已重新 probe) | idle 22.2% | **1.56 核** | **无收益, 反而略差** |

🎯🎯 **为什么 `rx_agg=Y` 没用 —— 计数器直接给出答案(这是个重要的负面结果)**:
```
rx_agg_urbs        = 262633
rx_agg_frames      = 262710        <- 与 urbs 基本相等
rx_agg_would_multi = 0             <- 芯片一个 URB 里只塞 1 帧, 完全没聚合
rx_agg_splits = 0, rx_agg_errors = 0   <- 干净, 不是出错导致的
rx_agg_frame0_fallback = 9         <- 已知的 ROM bootloader 阶段帧, 文档有记
```
⇒ **驱动侧 `rx_agg` 只是"能解析多帧 URB"的能力; 芯片默认不产生多帧 URB, 所以它单独开启等于白付解析开销。**
⇒ DR1V90 那 +48% 来自 **Step 7 写芯片寄存器**: `WLCFG_1 0x10040002` / `WLCFG_0 0x00f40202`(stock `0x10040000`/`0x00f40000`)。
🔴 **这一步现在做不了**: 它的工具 `aggctl.sh` 在仓库里**已不存在**(RUNBOOK 指向的 `mt76agg/deploy/` 那棵树没了),
而 RUNBOOK Step 7 列的前置条件(更新 aggctl.sh 的 tail/直方图/计数器清单、先用 `rx_agg_multi_en=0` 测帧间距、
`rx_agg_splits` 非零立即停、保持 `rx_agg_buf_size=8192` 因为 32768 要 128 个 order-3 页)**一条都没法满足**。
⚠ 且 RUNBOOK 明写: 写了芯片寄存器后**只能用 `aggctl.sh stock` 或重启还原, 绝不能用 rmmod**。
⇒ **要拿 +48% 必须先把 aggctl.sh 重建出来**, 这是一项独立工作, 不是一个旋钮。

## 2026-09-18 据实测外推: 靠 CPU 这条路到不了 300
按"同吞吐 CPU 线性外推到 2 核满载":
- 原版 1.55 核 @150 ⇒ 2 核 ≈ **194 Mbit/s**
- **GRO 生效 1.42 核 @150 ⇒ 2 核 ≈ 211 Mbit/s**
⇒ **目前能证明的 CPU 上限约 210**, 离 300 差 1.43×。
⇒ 差的那一截必须来自**降低每包成本**的杠杆, 而现在两个都拿不到:
  **芯片聚合**(要重建 aggctl.sh) 和 **MTU 2304**(本台架的 AP 侧 mt7921u 扛不住, 换真 AP 才能试)。
⚠ 线性外推偏乐观: `mt76-usb-rx` 是单线程, 不能无限摊到两核。

## 🎯🎯🎯 2026-09-18 收口: 链路已经领先下游 2-6 倍, 300 该不该追是个需求问题不是技术问题
把今天的链路数和**下游/需求**摆在一起(后两项来自 [[project_wifi_300m_target]], 都是既有实测):
| 环节 | 能力 | 来源 |
|---|---|---|
| WiFi 链路(实测) | **159**(台架顶) | 今天 |
| WiFi 链路(CPU 外推, GRO 生效) | **~210** | 今天, 1.42 核 @150 |
| 🔴 **PL 三引擎解码入口** | **~110 Mbit/s** | 147 MB/s 解压输出 ÷ cyl2 压缩比 10.8× |
| 现役最重内容 cyl2 @16 fps | ~94 Mbit/s | 既有实测 |
| 24 芯片屏(192×216) 载荷预算 | **32.5 Mbit/s**(最坏随机色 58.5 @15fps) | 09-15 载荷规划 |
⇒ 🔴 **链路(159~210)已经比它的消费者(PL 入口 110)快约 1.4~1.9 倍, 比规划载荷(32.5)快 5~6 倍。**
⇒ **把链路从 210 推到 300, 是给一个只吃得下 110 的下游加料。** 而且 PL 解码器目前**还是不可用状态**
  (09-15 连续推流 37 帧后引擎卡死; 09-17 才坐实根因是内核 `ccm_dcache_op` 开中断被软中断改 CSR, 另一会话在修)。
⇒ [[project_wifi_300m_target]] 里"**300 服务什么内容没确认**"这个问题**到今天仍然没有答案** ——
  300 大致对应"终极目标的实时切片"(266-837 Mbit/s), 那是另一个量级的项目, 不是现役内容的需求。

## 下一步建议 (2026-09-18, 按价值排)
1. 🎯 **先回答"300 服务什么内容"**(需求问题)。在它被回答之前, 继续追链路是给吃不下的下游加料。
   若答案是"现役+24 芯片屏", 则 **210 已有 3-6× 余量, 链路这条线可以收工**。
2. **无论 300 追不追都要做的**: [[project_rotor_spinning_wifi_throughput_gap]] —— **转子旋转下的吞吐**, 全项目唯一零数据的一跳。
   现在供电已修好(换 USB 口), 板子能稳定满载 ⇒ **这是做它的最好时机**。
3. 若确认要 300: (a) **重建 `aggctl.sh`** 拿芯片聚合的 +48%(唯一不依赖新硬件的杠杆);
   (b) AP 到货后用**有线发送端**打开台架顶 + 重试 **MTU 2304**。两者都拿到, 纸面 ~310, 但正好贴 USB 2.0 墙, 零余量。
4. 与链路并行、且可能比链路更值钱: **PL 解码入口只有 110** —— 若要 >110 的链路有意义, 得先重算引擎数/DDR 带宽。

## ✅ 2026-09-18 U 盘实验(快盘)结论回填: **USB 主机不是瓶颈**
TOSHIBA 盘在板上 `dd iflag=direct` 稳定 **32.7-33.0 MB/s = 264 Mbit/s**(bs 1M/2M/4M 与偏移均无关)。
⇒ **dwc2 能搬 264, 是 WiFi 实测 159 的 1.66 倍 ⇒ USB 主机不是 WiFi 卡住的原因**, 瓶颈是 mt76+mac80211 每包成本。
⇒ **264 > CPU 外推上限 ~210 ⇒ 当前先撞到的是 CPU 不是 USB** ⇒ 降低每包成本的杠杆(芯片聚合/GRO/MTU)方向正确。
⚠ 首次用的慢盘(`14cd:1212`)只有 19.5 MB/s=156, 与 WiFi 的 159 巧合吻合, **差点被读成"dwc2 到顶"**;
  是靠"同一器材在已知快主机上复测"的对照(PC 上只有 13 MB/s ⇒ 盘自己慢)才推翻。详见 [[reference_wireless_link_alternatives]]。
