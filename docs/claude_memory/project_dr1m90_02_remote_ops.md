---
name: project-dr1m90-02-remote-ops
description: DR1M90-02 无串口远程运维: 供电独立于串口; rootfs 是 initrd (RAM), WiFi 开机不自连; netguard 守护; 开机自连 WiFi 方案
metadata:
  type: project
---

- **供电独立** (用户 10-12 更正): 拔串口不会断电。卡上 wifi_up.sh 注释里"唯一供电是 Type-C/与串口共用"已过时。
- 连板: `host/dr1ssh.sh dr1m90-02 '<命令>'` (按 wlan0 MAC 认板, root/root), 10-12 IP 10.10.20.104, 办公网 SSID undef。
- rootfs = initrd (RAM), /etc 改动重启即失; 开机脚本只跑 /etc/init.d/S??*, 不会去卡上执行东西; WiFi 靠卡上 pov/wifi_up.sh (解包模块+insmod) + 手动 wpa_supplicant -c /tmp/wpa_office.conf; dhcpcd manager 开机就在。
- 卡上已有 aarch64 povmem: pov/m90/povmem_dr1_a64.ko; pov/m90/up.sh = 加载显示位流 + insmod povmem + 屏保持黑。
- 板上跑 /tmp/netguard.sh (开机由 autorun 拉起): 每 10 s 查 wlan0+网关, 连续 6 次失败重拉 wpa_supplicant+dhcpcd; sshd/wpa/dhcpcd oom_score_adj=-1000。日志 /tmp/netguard.log。硬件看门狗故意不开 (重启=失联, 且曾疑似误复位)。
- ✅ **10-12 开机自连 WiFi 已做并重启实测通过** (uptime 8 s WiFi / 9 s IP / 21 s 显示位流加载、屏黑)。uInitrd 追加 S45povboot → 卡上 pov/autorun.sh → wifi_up + wpa(pov/wifi_office.conf) + netguard + m90/up.sh。卡上 pov/noauto 禁用、pov/nodisplay 跳过位流; 回退 = 卡上 uInitrd.lz4.bak-20261012 改回。脚本入库 dr1v90 task/m90-autoboot boot/m90_autoboot/。重启后 IP 会变 (10-12: .104→.102), 用 dr1ssh.sh 扫; 办公网偶发 "No route to host", 重试即可。串口可拔 (用户 10-12 拔)。

**How to apply:** 远程操作板子前先确认 netguard 在跑; 要重启板子前先确认自连 WiFi 已生效, 否则必须有串口或人在旁边拔卡。
