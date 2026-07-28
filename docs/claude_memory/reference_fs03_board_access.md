---
name: FS03 板子远程操作方式 (WiFi/SSH, 2026-07-27)
description: 板子走 WiFi @ 10.10.21.3, uisrc/root; WSL 无 sshpass → 用 PuTTY plink/pscp; WiFi 会掉且不自愈
type: reference
---
FS03 跑 Linux（`buster-armhf`, 内核 `6.6.0-xilinx-g343f487d6341`），日常靠 **WiFi + SSH** 操作，串口可以不接。

## 连接

- IP **10.10.21.3**（DHCP，会变；旧记录 10.10.20.234 已失效）。找不到就扫 ARP 找 `90-de-80` 前缀
  （MT7921U dongle），`stream/boot/_scan.ps1` 是现成的扫描脚本
- 账号 **uisrc / root**（sudo 密码同）
- ⚠ **WSL 没装 sshpass，`ssh` 无 TTY 会失败**。用 PuTTY：
  `/mnt/c/Program Files/PuTTY/plink.exe -ssh -batch -hostkey <SHA256:...> -pw root uisrc@10.10.21.3`
  - 首次要先跑一次拿 host key 指纹，再用 `-hostkey` 钉住（`-batch` 下不钉住会直接放弃）
  - **多条命令别直接跟在命令行后**（会被当成一个命令名），写成脚本文件用 `-m <winpath>` 传
  - 传文件用 `pscp.exe`，约 4 MB/s
- `devmem` 不是独立命令，要走 **`busybox devmem`**
- 后台任务**别挂在 SSH 会话上**（WiFi 一抖就被杀）。用 `systemd-run --unit=X --collect ...`
  或写 `/etc/systemd/system/*.service`

## SD 卡与启动镜像

FAT 分区是 `/dev/mmcblk0p1`，**默认不挂载**：`mount /dev/mmcblk0p1 /mnt/sdboot`。
启动镜像文件名是 **`BOOT.bin`**（小写 bin）。板上时钟是 **UTC**，比 CST 早 8 小时。
换 bit 只需替换 `BOOT.bin` 后 `sync` + 重启，不用拔卡。SD 上留了多版备份可随时切。

## 🔴 WiFi 会掉，且不自愈

`mt7921u` dongle 不稳，2026-07-27 一天掉了两次。掉了之后 `wpa_supplicant` **不会自己重连**，
只能断电重启。开机脚本 `pov_boot.sh` 里那段 USB PHY 复位脉冲就是为它写的。

⚠ **屏还亮着 ≠ Linux 还活着** —— PL 引擎从 fb 自走扫描，不依赖 CPU。掉线时画面会**定格**在最后一帧，
很容易误判成「显示卡死」。判断板子死活要看 ping / uptime。

怀疑与 5V 轨余量不足有关（TPS54560 总闸 5A，双屏 + FS03 本就紧，dongle 发射峰值一叠加就塌）。
用户也观察到**热插拔屏会导致板子重启**，同一根因。**插拔屏一律断电做**。

待办：加个 systemd timer 看门狗（查 `wl*` 有没有 IP，没有就重跑 wpa_supplicant+dhclient，
必要时 rebind USB PHY）。
