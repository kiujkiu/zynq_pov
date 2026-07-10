---
name: mlkpai-fs03-zynq-usb-wifi-board
description: "新入手米联客 MLKPAI-FS03-ZYNQ (XC7Z020) 板, 有真 USB2.0 HOST (USB0 MIO28-39 ULPI/USB3320), 可上 USB WiFi 取代鹿小班; AX900 别买买 MT7921AU"
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-23 18:00 CST
  updated_at: 2026-06-23 18:00 CST
  originSessionId: bffb6076-88a7-4b0b-a34c-5ef231a896fa
---

2026-06-23 入手, 为 USB WiFi 路线换板 (鹿小班无 USB host, 见 [[reference_lxb_no_usb_host]]).

## 📍 RESUME 点 (更新 2026-06-29): ✅✅ USB-WiFi 端到端打通!
**项目目标达成**: 换板MLKPAI → 自编6.6内核+mt7921u → 离线装wifi工具 → 连AP `undef`(5GHz/5805) → DHCP拿IP **10.168.168.189**(网关10.168.168.1) → **ping 8.8.8.8 0%丢包171ms = 真上网**. WPA2法在WPA3混合网上连通(`wpa_passphrase undef undefoffice1010`). ⚠ ping要sudo(raw socket); DNS通(huaweicloud不回ICMP而已).
- ⚠ **供电 marginal(非硬墙)**: 板靠PC USB Type-C供电, 前2次连WiFi掉电brownout(COM13消失), **第3次扛住了全程**. 即供电卡在边缘, 偶发brownout. **要稳定/跑iperf满速(POV数据流~100Mbps持续负载)建议加供电**(带供电USB Hub / 单独5V), 否则高负载可能掉电.
- **测速 (2026-06-29)**: 板上无iperf, 有wget/curl. curl下huaweicloud ls-lR.gz = **~15 Mbps (1.86MB/s, 16MB/8.7s, 没掉电)** — 但卡互联网/镜像出口非WiFi. **iw link: signal -48dBm(极好)/tx bitrate 172Mbps/5GHz** → WiFi链路能力~150-200Mbps, 15M是internet限速. 对POV ~100Mbps点云流 WiFi链路够用. (rx bitrate瞬时6M是抓到低速帧不代表持续). 
- **LAN吞吐实测 (2026-06-29)**: PC `python -m http.server` 发50MB(⚠端口8000被系统PID4占, 用8123), 板 `wget` 拉 = **9.43 MB/s ≈ 75 Mbps, 50MB完整下完没brownout**. 这是真WiFi吞吐(比15M互联网下载高5×). 注: PC+板都在WiFi上=两跳共享AP≈单跳一半 → 板单跳WiFi能力 ≈150Mbps(合172 PHY). **POV ~100Mbps点云流够用**(PC接网线单跳更稳). 测完清理(killed server, rm wifitest).
- 下一步: 想测真WiFi LAN吞吐装iperf板↔PC(brownout风险) / POV数据通路(WiFi收点云→喂PL显示, 以mlkpai_fs03 XSA为底加panel IP).
**(以下为历史 dongle 验证细节)**
dongle验证 100% 通过:
- ✅ MT7921AU 插上: `lsusb` 出 `0e8d:7961 MediaTek` / mt7921u 驱动绑定 / **固件WM Firmware加载成功** / wlan接口 `wlx90de80351c47` 创建 (wlan0重命名).
- ✅ wifi 用户态工具装好 (离线.deb, 见下). WiFi: SSID **`undef`** 密码 **`undefoffice1010`** WPA3(混WPA2) (同 [[feedback_office_ap_blocks_esp32c5_tcp]]).
- 🔴🔴 **供电brownout是硬墙**: 板子靠 PC USB口 Type-C 供电(供电+串口共用), **WiFi一活动(scan/wpa_supplicant握手)板子+dongle总功耗超过PC USB口能给的5V → 板子掉电重启, CH342串口(COM13/15)整个消失**. 反复复现(连启动期dongle枚举都扛不住). 
  - **必须解供电才能连WiFi**: ① 带供电的USB Hub (PC→有源hub→板, hub供电够dongle, 串口透传) ② 板单独5V供电+Type-C只做串口 ③ 换高功率USB口. 
  - 现状=连WiFi这步停在这, 等用户搞定供电. 软件侧不用再动, 供电好了直接 wpa_supplicant 连(配置写法见 Phase1).
- 串口=CH342 **COM13**(@115200, 靠Type-C供电, brownout时消失). PowerShell SerialPort 读写见 [[reference_wsl_burn_linux_sd]].

## 📍 (旧)RESUME 点 (截至 2026-06-24): 基础全打通, 等 dongle
**已完成且上板验证**: 出厂Debian+USB host / 自编6.6内核+mt7921u无线栈load / Vivado PS7基础工程+XSA+DDR上板读写(详见下各节).
**下一步 (三条, 按是否需 dongle 分)**:
- 🔴 **必须等 MT7921AU(在路上)**: 插上→wlan0→wpa_supplicant连AP→iperf测速.
- ⏳ **可先 prep (不需dongle)**: 板上装 wifi 用户态 `wpasupplicant`/`iw`/dhcp客户端. ⚠ 前提板先联网走eth0 apt, 但**板上连dhcp客户端都没装** → eth0拿IP要先手配静态IP(`ip addr add`+`ip route`+`/etc/resolv.conf`)或查出厂有没有NetworkManager/systemd-networkd. 我串口(COM13 uisrc/root)进去配.
- ⏳ **独立线 (不需dongle)**: POV PL 移植 — 以 mlkpai_fs03.xsa 为底, 加 panel驱动IP/HLS render 到 MLKPAI PL (同XC7Z020, 逻辑能搬鹿小班的). 更大的活.


## 板子身份
- **米联客 MLKPAI-FS03-ZYNQ**, 芯片 XC7Z020 CLG484
- 资料: `D:\BaiduNetdiskDownload\MLKPAI-AMD\03_MLKPAI-FS03_7020\FS03-ZYNQ\`
  - 原理图: `02_hardware\MLKPAI-FS03-ZYNQ-hardware-20240909\02_原理图\MLKPAI_FS03_ZYNQ_240909.pdf` (17 页, USB 在 P3=PS / P10=PHY)
  - 自带完整 Linux BSP: `01_userstart\02_start_linux` + `04_linux_demo` (Ubuntu 二次开发 + 驱动开发课程, PetaLinux 友好)
- ETH = YT8531 千兆 PHY; QSPI = W25Q128

## 有真 USB2.0 HOST (鹿小班最大缺口在这补上)
- U14 = **USB3320** ULPI PHY (QFN32), U16 = CH217K 供电限流开关 (400mA-2.7A, host 给设备供电), J6 = USB-A 母座 (USB-226-BRY), U15 = TPD2EUSB30 ESD, X1 = 24MHz
- **走 Zynq USB0**, 12 根 ULPI MIO 全齐:
  | MIO | BGA | ULPI | MIO | BGA | ULPI |
  |-----|-----|------|-----|-----|------|
  | 28 | A12 | DATA4 | 34 | B12 | DATA2 |
  | 29 | E8 | DIR | 35 | F14 | DATA3 |
  | 30 | A11 | STP | 36 | A9 | CLK |
  | 31 | F9 | NXT | 37 | B14 | DATA5 |
  | 32 | C7 | DATA0 | 38 | F13 | DATA6 |
  | 33 | G13 | DATA1 | 39 | C13 | DATA7 |
- MIO40-45 = 板载 microSD (PS_SD_*), 跟 USB **不冲突**
- PHY reset = PS_USB_RESETB (出厂 dts 有, 照抄)

## 配置要点
- Vivado PS7: MIO Config → USB 0 勾上, 自动占 MIO28-39 ULPI
- device tree: `&usb0 { dr_mode = "host"; }`, 从米联客出厂 dts 抄, 别从零配 (出厂 Linux USB host 已通)

## ✅ Phase 0 完成 (2026-06-23): 出厂 Linux 跑通 + USB host 确认
SD 卡(B方案 loop镜像+Rufus DD烧, 见 [[project_pov3d_lxb_standalone_autoboot]] 同类) → 插板 SD启动(模式开关 OFF-OFF) → 串口 **CH342 COM13 @115200** (COM15 是另一通道空). 登录 **uisrc/root**. 实况:
- 系统 = **Debian GNU/Linux 10 (buster) armhf**, 内核 **4.19.0-xilinx armv7l** (vendor build 2024-11). 不是 Ubuntu(文档误导).
- **USB host ✅**: `lsusb` 出 `1d6b:0002 2.0 root hub` (USB3320 生效). eth0 存在(DOWN无网线).

## 🔴🔴 出厂内核无无线栈 — USB WiFi 必须重编内核 (2026-06-23 实测)
出厂 4.19 内核**没编 cfg80211/mac80211/任何无线驱动**, 也**没 /lib/modules/.../build 头文件**(没法现场编模块). 实测全空: `net/wireless`,`drivers/wireless`,`cfg80211.ko`,`mac80211.ko`,`ath9k_htc/mt7921u/r8188eu` 模块, `wpa_supplicant/iw/dhclient` 工具 — 一个都没有.
→ **任何 USB WiFi 都得先重编内核(开 cfg80211+mac80211+驱动)**, 这就是原 PetaLinux 计划的内核定制活. 有 Vivado/Vitis 2024.2 + 米联客 BSP/驱动课程(04_linux_demo).
→ **内核版本卡 dongle**: AR9271(ath9k_htc 老内核就有)→重编 4.19 即可; **MT7921AU(mt7921u 需 5.15+)→ 4.19 跑不了, 要跳新内核(大改+可能改DT)**. 两路待用户定 A(4.19+AR9271省力~50-95M) / B(5.15+MT7921AU带宽足但费力).

## ✅ Vivado PS7 基础工程 (2026-06-23, 新仓 `D:\claude_workspace\pov3d\mlkpai_fs03\`)
独立 git 仓(master). 复刻出厂板子 Zynq PS 配置出 XSA, 给 PetaLinux/内核DT/后续POV PL.
- `docs/board_config.md` 全参数 + `docs/factory.dts`(出厂dtb反编译, MIO真值) + `vivado/create_zynq_ps.tcl`(建PS7工程).
- **part `xc7z020clg484-1`**(-1工业); DDR3L 512MB(0x20000000)/16bit/1066 MT41K256M16兼容; **Bank0/1 电压都 1.8V**(QSPI/USB/ETH都1.8); PS_CLK 33.333M; UART1=console(MIO48/49)/GEM0 RGMII(MIO16-27,PHY@4,phy-mode rgmii-id)/USB0 host(MIO28-39)/SD0(40-47)/SD1(9-15)/QSPI(1-6) — 大多标准默认MIO.
- 跑 Tcl 踩坑(已修): ① M_AXI_GP0 默认开但无PL用→clock未接ERROR, 设 `PCW_USE_M_AXI_GP0 {0}` 关掉(后续加PL再开) ② RGMII 不支持3.3V→设 `PCW_PRESET_BANK0/1_VOLTAGE {LVCMOS 1.8V}`. **validate_bd_design 通过 + wrapper 生成 ✓**.
- **✅ XSA 已出** `mlkpai_fs03.xsa`(291K, 含 system.hwh + ps7_init.tcl/c/h = DDR/MIO/时钟初始化codified). 坑: write_hw_platform 前必须 `generate_target all [get_files system.bd]` 否则只出空1.6K XSA报"no IPI hardware handoff". commits: 1e5469c init / 34bb815 validate修 / 0fa05c8 出XSA.
- **✅ DDR 配置上板验证通过 (2026-06-23 下载测试)**: 板子切 JTAG boot mode(SW1两个ON, 控MIO4/5 strap)+冷循环 → xsct 跑我们 XSA 的 ps7_init → **DDR 读写横跨 512MB 全 OK** (0x100000/0x10000000/0x1FF00000 + 块测试). 即 **MT41K256M16/1066 通用配就对**, 不用对齐米联客 preset. 测试脚本 `test/test_ps_ddr.tcl`.
  - 🔴 **坑: `rst -processor` 在 MLKPAI 板载 JTAG(MiLianKe MLK.JTAG1U1) 上挂死**(150s超时). 去掉即可: JTAG boot mode 下 Cortex-A9 核本就 "Already stopped", 直接 stop+ps7_init 不用 rst. xsct puts 输出被缓冲, 用 `open file + flush` 写进度文件才看得到挂在哪步.
  - **MLKPAI 有板载 USB-JTAG** (MLK.JTAG1U1 SN 2515BCEF4DEA), 不用外接下载器. 串口=CH342 COM13.
- 后续 POV PL 以此 XSA 为底加 panel IP.

## Phase 1 计划 = B 路: 换 6.6 内核 (2026-06-23 用户定 B, MT7921AU 已买寄出)
用户选 B(带宽足) + **已买 MT7921AU, 在路上**. 思路: **保留现在能跑的 Debian Buster rootfs, 只换内核** (比全套 PetaLinux 轻, 也绕开 PetaLinux 没装的阻塞). 目标内核 = **Xilinx linux-xlnx 6.6** (配 Vivado 2024.2, mt7921u 成熟; 不用纠结5.15). 板是 **Zynq7020 armv7l 32-bit → ARCH=arm, zynq config**.
开 config: CFG80211 + MAC80211 + MT76_USB + MT7921U + MT7921_COMMON + USB host(EHCI, zynq默认有) + mt7921 firmware. 装: uImage+.dtb→SD boot分区; `make modules_install`→Debian rootfs; mt7921 firmware→/lib/firmware; rootfs 里 apt 装 wpa_supplicant+iw+dhcpcd(先用 eth0 有线上网装).

### ✅✅ 内核侧全部跑通 (2026-06-23, kernel-swap 成功)
**6.6 内核 + 全 WiFi 驱动栈在板上验证通过** (dongle 还没到, 但 modprobe mt7921u 整链加载无报错). 工件全在 `~/mlkpai-kernel/`:
- 源码: `linux-xlnx/` (clone `git clone --depth 1 -b xlnx_rebase_v6.6_2024.2 github Xilinx/linux-xlnx`, 6.6.0-xilinx)
- 配置: `make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- xilinx_zynq_defconfig` + `scripts/config --module CONFIG_{CFG80211,MAC80211,MT76_USB,MT76_CONNAC_LIB,MT792x_USB,MT7921_COMMON,MT7921U}` + olddefconfig
- 编译: `make -j20 uImage modules LOADADDR=0x8000` (~1分钟, 交叉链=apt gcc-arm-linux-gnueabihf 13.3). 产物 `arch/arm/boot/uImage` 4.8M.
- 模块: `make INSTALL_MOD_PATH=~/mlkpai-kernel/staging modules_install` → staging/lib/modules/6.6.0-xilinx-g343f487d6341/ (187模块5.2M, depmod已跑)
- 固件: sparse clone linux-firmware 只 mediatek/, mt7921u 要 `mediatek/WIFI_MT7961_patch_mcu_1_2_hdr.bin`+`WIFI_RAM_CODE_MT7961_1.bin` (新命名, 非旧 mt7961_wm.bin)
- **安装 = kernel-swap**(脚本 `install_kernel.sh /dev/sde`): **复用出厂 devicetree.dtb + Debian rootfs**(DT稳定+WiFi走USB不靠DT). uImage→SD boot分区(旧的备份成 uImage.factory419.bak 可回滚), modules→rootfs /lib/modules, mt7961固件→/lib/firmware/mediatek. SD换卡装(走usbipd, ~10MB小不怕usbip不稳).
- 验证(串口COM13登录): `uname -r`=6.6.0-xilinx-g343f487d6341 ✓; `echo root|sudo -S modprobe mt7921u` → 整链 cfg80211/mac80211/mt76*/mt7921u 全 load ✓ (`usbcore: registered new interface driver mt7921u`).
- **✅ wifi 用户态工具已装 (2026-06-29, 离线.deb)**: 没RJ45→离线装. 流程: 板上 `sudo apt-get install --print-uris -y wpasupplicant iw isc-dhcp-client` (board apt有包列表)算出缺的8个.deb → **华为云镜像URL失效(buster已归档404), 改 archive.debian.org 下** (wpasupplicant+iw+libnl3×3+crda+wireless-regdb+libpcsclite1; isc-dhcp-client已装没列) → 拷到 **SD BOOT分区(FAT, Windows直接写, cmd copy从\\wsl到E:)** → SD回板 → `sudo mount /dev/mmcblk0p1 /mnt; sudo dpkg -i /mnt/debs/*.deb` (man-db触发器在armv7l慢~80s别以为挂了). 装上 /sbin/wpa_supplicant + /usr/sbin/{iw,wpa_cli}.
- **连WiFi配置 (WPA3混合网)**: `wpa_passphrase undef undefoffice1010 | sudo tee /etc/wpa_supplicant/wpa.conf` (WPA2法, 混合网可能够); 若WPA3需 `key_mgmt=SAE WPA-PSK`+`psk="undefoffice1010"`(明文)+`ieee80211w=1`. 然后 `sudo wpa_supplicant -B -i wlx90de80351c47 -c .../wpa.conf` + `sudo dhclient wlx90de80351c47` + ping. sudo密码=root(`echo root|sudo -S true`先缓存).
- 🔴 **但供电brownout挡在这** (见 RESUME 点): 连WiFi一活动板子掉电, 必须先解供电.

### 🔴 摸底结果 (2026-06-23, 要现拉的东西)
- **米联客下载包没内核源码/DT源/XSA/Vivado工程** (maxdepth4 搜 .xsa/.dts/linux-xlnx/.xpr/system.bit 全空; 04_linux_demo 俩zip 没匹配内核源). → **内核源要自己拉 github Xilinx/linux-xlnx (branch xlnx_rebase_v6.6 或 2024.2 tag)**.
- **设备树**: 没DTS源 → 用板上**出厂 devicetree.dtb 反编译**(dtc -I dtb -O dts)当基础改, 或从米联客Vivado工程生成(工程也没在包里).
- **交叉链**: WSL 无 arm-linux-gnueabihf-gcc → `apt install gcc-arm-linux-gnueabihf`. Vitis2024.2 自带的是 **`nt`(Windows .exe)版** (`/mnt/c/Xilinx/Vitis/2024.2/gnu/aarch32/nt/...`) WSL 用不了, 要 Linux 版或 apt 的.
- 下一步(dongle到之前先做): 拉 linux-xlnx 6.6 + 装交叉链 + 反编译出厂dtb + 配 wireless/mt7921u + 交叉编译 uImage/dtb/modules.

## WiFi dongle 选型 (关键坑)
- ❌ **绿联 AX900 = 型号 CM762**, 芯片 RTL8851BU 或 AICSemi AIC8800D80, **不在 mainline kernel**, 要 out-of-tree dkms 自编, ARM PetaLinux 交叉编译大坑 (同 [[reference_lxb_no_usb_host]] 避坑名单)
- ✅ 买 **MT7921AU** 芯片 (WiFi6 USB), `mt7921u` mainline kernel 5.15+ 自带, 实测 ~100-200Mbps, 够 128³ 点云 ([[project_pov3d_linux_wifi_anim_feasibility]] 需 ~100Mbps). 认准芯片名不看 AX900/AX1800 带宽命名
- 备选: AR9271 (WiFi4, ath9k_htc, ~50-95Mbps 偏紧, 认准 TL-WN722N v1)

## 取代关系
- 取代 ESP32-C5 SDIO 桥 (100KB/s) + 鹿小班 RTL8822CS SDIO 飞线方案 ([[project_lxb_sdio_wifi_plan]]); USB host 比 SDIO 飞线省事, 走标准 Linux 网络栈
