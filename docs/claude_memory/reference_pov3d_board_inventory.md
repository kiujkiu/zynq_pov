---
name: 三台板子的身份识别与禁区
description: pov/pov2/安路 DR1 的 IP-MAC-特征对照; 🔴 第一台 pov 别人在用, 不要碰
type: reference
---
2026-08-27 全网段扫描 (`10.10.20.0/23`, 508 个地址) 逐台认定。DHCP 会变 IP，
**认 MAC 和特征，别认 IP**。

| 设备 | IP (2026-08-27) | MAC | 硬特征 |
|---|---|---|---|
| **pov** 第一台 Zynq | `10.10.20.239` | — | mDNS `pov.local`；9500 端口开 |
| **pov2** 第二台 Zynq | `10.10.21.226` | WiFi `90:de:80:47:f0:ff` / eth0 `00:0a:35:00:01:22` | hostname `pov2`；mDNS `pov2.local`；`SSH-2.0-OpenSSH_7.9p1 Debian-10`；9500 端口开 |
| **安路 DR1**（疑似） | `10.10.21.86` | `fc:a0:5a:1b:d7:e4` | SSH 是 **dropbear**（Buildroot 特征）；`root/root` **被拒**，密码未知 |

- `00:0a:35` 是 **Xilinx OUI** —— 认 Zynq 板最硬的一条。
- `90:de:80` 是 mt7921u USB WiFi 网卡。
- 两台 Zynq 的 rootfs 同源（pov2 的卡从 pov 克隆），所以 **SSH banner 完全一样，靠它分不开两台**；
  要分必须看 hostname 或 MAC。
- 判定"某台是不是刚被你重启"最硬的办法：`uptime` 读到 `up 0 min`。2026-08-27 就是靠这条
  确认了"物理板子 = SSH 目标"，排掉了"操作错设备"这个假设。

## 🔴 禁区

**第一台 `pov` 别人在用，不要碰**（2026-08-27 用户明确交代）。
只能 ping / 读 banner 做存活判定，**不要 SSH 登录、不要改配置、不要动它的屏**。
`tools/board_ssh.sh` 默认解析 `pov.local` 会指向第一台 —— 操作 pov2 **必须显式带
`BOARD_IP=10.10.21.226`**，否则会误连第一台。

## ⚠ board_ssh.sh 里的注释是错的

`tools/board_ssh.sh:22` 写 "pov2 … ICND2049 单面"，**不对**：pov2 挂的是
**ICND2047 偏心双屏**（2026-08-26 当场更正过，但注释没跟着改）。
见 [[project_pov3d_offset_axis_geometry]]。
