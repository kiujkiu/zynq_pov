---
name: project-dr1m90-02-remote-ops
description: DR1M90-02 无串口远程运维: 供电独立于串口; rootfs 是 initrd (RAM); 开机自连 WiFi + netguard; 10-13 起按名字 dr1m90-02.local 找板
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
- 10-13: 串口 = Windows **COM28 (CH342-A)**, `powershell.exe -NoProfile -ExecutionPolicy Bypass -File host/serial_run.ps1 -Port COM28 -Cmd "..."` (WSL 里无 ttyUSB)。10-13 "扫不到板子"其实 WiFi 开机 9 s 就连上了 (10.10.20.102); 原因是板子 WiFi 省电 (power_save on) 首包 ~0.4 s, dr1ssh 扫描探 22 口超时只有 0.4 s ⇒ 整段漏扫; 已改 1.5 s×2 (48c28bd)。netguard 日志零星 "link-down 1" 只是单次 ping 网关失败, 不是断线。板上没有 pgrep。全网段 root/root 扫描会被自动模式拦 (凭据试探), 别用, 改用串口。
- 办公网 DNS 不登记 DHCP 主机名; Windows WLAN 10.10.20.125 与板同 /23, WSL 在 NAT 192.168.0.0/20。用户提"按设备名找": 建议 = 主机名设 dr1m90-02 + 板上 mDNS 应答 (Windows 解析 dr1m90-02.local) + 板子主动广播报到兜底 (并入 PSTS 9510); 待上板 agent 做完后做。
- ✅ **10-13 按名字找板闭环** (b0f6b5d, feature/lvds-b2b, 已推 origin+yjhh): 板上 povmdns 应答 `dr1m90-02.local` (名字来自卡上 pov/boardname, autorun 拉起, netguard 掉了重拉, wlan0 关省电); PC 侧 host/mdns_query.ps1 在 Windows 发查询 (WSL NAT 收不到组播); dr1ssh.sh 顺序 缓存IP→mDNS→扫网段, 都核 MAC。实测无串口自重启: 下线 4 s, **34 s 按名找到并 ssh 上**, IP 变了照样找。坑: 旧版脚本取回包末 4 字节, 网段别的设备回同 ID 包时误报过 10.10.20.193, 已改严格解析。卡上 autorun/netguard 有 .bak-mdns 备份。
