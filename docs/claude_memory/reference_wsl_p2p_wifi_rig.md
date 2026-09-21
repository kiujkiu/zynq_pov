---
name: reference_wsl_p2p_wifi_rig
description: 2026-09-15 搭成的 DR1 WiFi 点对点测试台架: PC 插第二块 MT7921AU → usbipd 进 WSL2 → 自编 6.6.87.2 无线栈 + hostapd 当 AP, 板子作 STA; 排除办公 AP/空口, PC 端发送封顶 ~145 Mbit/s; 重建步骤和坑
metadata:
  type: reference
---

# WSL 点对点 WiFi 台架 (2026-09-15)

用途: 测 DR1 板子 WiFi 接收的**真实 CPU 上限**, 不受办公室 AP/空口/PC 内置网卡那一跳影响。
脚本和重建笔记: `dr1v90/measure/03_wifibw/results/2026-09-15/tput_ab/rig/`（wsl_ap_up.sh, hostapd_ch44.conf, board_join_p2p.sh, board_wpa_p2p.conf, check_crc.py, wsl_kernel/NOTES.md + build_mt76.sh）。
数据: 同目录上级 `README.md`（原版 91.7 → v3p1+聚合5帧 136 Mbit/s）。

## 结构
- PC(Windows) 插 MT7921AU(0e8d:7961, Windows 无驱动, 错误码 28) → `usbipd bind --busid 3-4`(管理员, 一次) → `usbipd attach --wsl --busid 3-4`(USB 3.2 SuperSpeed)。
- WSL2 内核 6.6.87.2 自带 cfg80211/mac80211 模块但**无 mt76**; 源码 tag `linux-msft-wsl-6.6.87.2` 解压在 `~/wslkernel`, 只加 MT7921U 等 =m 编模块。
- hostapd 2.11(apt), 国家码 CN, 5 GHz 80 MHz HE WPA2; hostapd 因 44 信道有信标自动把主信道挪到 **48**; AP 地址 192.168.77.1, 板 192.168.77.2(freq_list 5240)。
- iperf3 客户端直接在 WSL 里跑(无 NAT, UDP 也通)。板上切网只动用户态(杀 wpa/udhcpc 起新 wpa), 回退 = 重启。

## 坑 (都已踩过)
- WSL 自带 **cfg80211 的 CRC 与同版本源码不一致(78 个)**, mac80211 也就不能用自带的 ⇒ 整套 cfg80211+mac80211+mt76 用自编的; vmlinux/usbcore/led-class/libarc4 CRC 全等可用自带。先 `check_crc.py` 核对再 insmod。
- 主机 gcc 15 编 6.6: libbpf `-Werror=discarded-qualifiers`(HOSTCFLAGS 加 -Wno-error=...)、realmode 缺 `-std=gnu11`(改私有副本 arch/x86/Makefile)、`vmlinux.symvers` 要拷成 `Module.symvers`、M= 构建前要 `modules_prepare`(缺 module.lds)。不能关 DEBUG_INFO_BTF(会改 struct module)。
- **WSL 内核直读固件走 VM 根目录, 看不到发行版 /lib/firmware** ⇒ 固件和 regulatory.db 放 `/mnt/wsl/fw` 并 `echo -n /mnt/wsl/fw > /sys/module/firmware_class/parameters/path`; 没 regdb 国家码卡 00, 5 GHz 起不了 AP。
- 第一次缺固件导致 mt7921 **补丁信号量卡死**, 驱动重试/重绑都清不掉 ⇒ **物理拔插网卡**才恢复。6.6 mt7921u 初始化失败后断开是安全的(mt76_unregister_device 有 REGISTERED 检查), 与板上 6.1 不同。
- **台架上限: PC 端发送 ~12.2k pps ≈ 145 Mbit/s**(USB/IP 每帧一个 URB 经 Hyper-V vEthernet 往返, WSL CPU 不忙) ⇒ 板子 >140 的能力测不出。
- 板上自带 iperf3 3.10.1 服务端的 UDP 字节统计是错的, 按数据报数算。
- 🔴 **台架热点端扛不住 MTU 2304 大流量**(09-15 22:01): 两端 MTU 2304 后 DF 2276 ping 能通, 但 iperf3 一跑 WSL 侧 mt7921u 报 `Message 00020003 timeout` +
  `timed out waiting for pending tx` + mt7921_mac_reset_work 里 WARN, 芯片复位后下行数据一直不通(板子 rx 6 Mbit、ping 全丢), 解绑重绑又卡"补丁信号量" ⇒ **只能拔插网卡**。
  板子侧 v3p1 计数全 0 错误 ⇒ 是台架问题, MTU 2304 对板子的收益没测出。要测得换定速率比 CPU/Mbit 的方法、查热点端大帧发送问题、或换原生 Linux 发送端。
- pov_rxd/iperf 之外用 `ping 192.168.77.2` 验链路时, 先确认 WSL 里 wlan0 还在: 热点网卡掉了以后同一个地址可能被别的网络上的设备应答, 会误以为通。

相关: [[reference_dr1_wifi_ceiling_unestablished]] [[feedback_dr1_experimental_module_hard_hang]] [[feedback_wsl_nat_is_not_the_lan]]
