---
name: feedback_wsl_nat_is_not_the_lan
description: 🔴 WSL2 是 NAT 模式, `ip addr` 看到的 192.168.x/20 是 WSL 自己的 NAT 网段不是局域网(局域网在 Windows 的 WLAN 上); 据此判"网段变了"错了两次, 判局域网拓扑必须问 Windows
metadata:
  type: feedback
---

# WSL 里看到的网段不是局域网 (2026-08-31 据此误判)

## 事情

板子连不上, 我在 WSL 里跑 `ip -4 addr` 看到 `eth0 = 192.168.2.204/20`、网关 `192.168.0.1`,
而板子上次的地址是 `10.10.20.239` ⇒ **判定"开发机网段换了, 板子连的旧 WiFi 用不了了"**,
并据此写了一整套串口迁移序列。**判错了。**

| 事实 | 证据(本机实跑) |
|---|---|
| WSL2 是 **NAT 模式** | `wslinfo --networking-mode` → `nat`; `lo` 上挂 `10.255.255.254/32`(NAT 的标志物) |
| `192.168.0.1/20` 是 **WSL 自己的 NAT 网段** | Windows `Get-NetIPAddress`: 属于 **`vEthernet (WSL (Hyper-V firewall))`** |
| **局域网是 `10.10.20.0/23`** | Windows **`WLAN` = `10.10.20.125/23`** |
| WSL 单播出站到局域网**正常** | `ping 10.10.21.241`(Zynq 板) → **0% 丢包**, 4-16 ms |

⇒ 板子那个网段**一直活着**; 连不上的真因是**它重启后 WiFi 没起来**
([[feedback_dr1_reboot_loses_everything]] + [[feedback_s95pov_never_shipped_in_any_rootfs]])。
⇒ `10.10.20.125:8099` 那五处硬编码**不是"旧网段"**, 那正是这台 PC 的 WLAN, **今天仍有效**。

## How to apply

1. 🔴 **判局域网拓扑一律问 Windows, 不要用 WSL 的 `ip addr`**:
   `powershell.exe -NoProfile -c "Get-NetIPAddress -AddressFamily IPv4"` ——
   找 `WLAN` / `以太网` 那一行, 别看 `vEthernet (WSL...)`。
2. **判"板子在不在网上"最快的一手判据是直接 ping 一个已知的局域网设备**
   (比如 Zynq 那块板), 通了就说明 WSL 出站没问题, 问题在板子那边。
3. ⚠ **NAT 模式下 WSL 收不到组播/广播**(实测: WSL 发 mDNS 查询 replies=0,
   同一时刻 Windows 发同一个包 replies=2; 65 秒广播监听收到 30 个包**全部**来自
   `192.168.0.1`, 来自 `10.10.x` 的 = 0)。
   ⇒ **mDNS / 广播信标这类方案在 WSL 侧必须借 Windows**:
   `cmd.exe /c "ping -4 -n 1 <name>"` 抠 IP, 实测 244-264 ms
   (配方出处 `mlkpai_fs03/tools/board_ip.sh:38-39`; 🔴 `-4` 不能省,
   不带会回 `fe80::` 而 WSL 用不了 —— `board_ssh.sh:40`)。
4. 🎯 **教训**: 这条和 [[mnt-d-drvfs-drop-kills-bash]] 同族 —— **WSL 是个中间层,
   它给你看的东西不一定是宿主机的东西**。涉及网络/文件系统/设备的判断, 先确认是在
   哪一层看到的。

相关: [[feedback_dr1_reboot_loses_everything]] [[reference_fs03_board_access]]
