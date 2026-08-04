---
name: FS03 板子远程操作方式 (WiFi/SSH, 2026-07-27)
description: 板子走 WiFi @ **静态 10.10.21.250** (2026-08-01 固定, 原 DHCP 会变); uisrc/root; PuTTY plink/pscp; WiFi 会掉且不自愈
type: reference
---
FS03 跑 Linux（`buster-armhf`, 内核 `6.6.0-xilinx-g343f487d6341`），日常靠 **WiFi + SSH** 操作，串口可以不接。

## 连接

- IP **10.10.21.250**（**静态**，2026-08-01 固定，见下方"IP 固定"节）
  - 历史: DHCP 时代地址会变 —— `10.10.20.234` → `10.10.21.3` → `10.10.20.239`，
    **每次变都伪装成"WiFi 掉线"**，这是最坑的一个失效模式（见下）
  - 万一还是找不到: 扫 ARP 找 `90-de-80` 前缀（MT7921U dongle），
    `stream/boot/_scan.ps1` 是现成的扫描脚本
- 账号 **uisrc / root**（sudo 密码同）
- ⚠ **WSL 没装 sshpass，`ssh` 无 TTY 会失败**。用 PuTTY：
  `/mnt/c/Program Files/PuTTY/plink.exe -ssh -batch -hostkey <SHA256:...> -pw root uisrc@10.10.21.250`
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

## 2026-07-31 网络位置: WSL **能**连到板子 (一条被我反复搞错的事)

| | 网段 | 到板子 |
|---|---|---|
| WSL | NAT 的 `192.168.2.204/20` | **TCP 通** (22/9500 实测); ICMP 偶尔不通 |
| Windows | `10.10.x` (办公网) | 通 |

🔴 **WSL2 走 NAT 出站, 目标可达; 但 ICMP 转发不可靠 —— `ping` 失败不代表连不上。**
判断板子死活**用 TCP 探测**, 别用 ping:
```bash
timeout 5 bash -c "exec 3<>/dev/tcp/10.10.21.250/9500" && echo 通
```
⇒ **推流/plink/pscp 从 WSL 或 Windows 发起都行**, 不存在"必须走 Windows"这回事。

⚠ 2026-07-31 我又踩了一次: 当时 WSL ping 不通 + Windows ping 通, 就断言"WSL 网络隔离,
推流必须走 Windows"。**实际是板子那一刻正在掉线**(几十秒后 Windows 也报目标不可达),
跟 WSL 无关。这与 [[reference_aibrain_app_project]] 里记的是同一个坑 ——
**拿中间层现象推断另一端状态前, 先确认自己站在哪个网络位置**, 且**先用 TCP 复核再下结论**。

### Windows 侧 Python 不在 PATH
当前 Windows 用户 `wanqi.liu` 的 PATH 里只有 Microsoft Store 的**占位 stub**(`WindowsApps\python.exe`),
真 Python 3.12 装在**另一个用户** `kiujkiu` 目录下:
`C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\python.exe`
⇒ 推流要用全路径, 或给当前用户装一份 (+ numpy/pillow/pygltflib/trimesh)。

### plink host key 指纹 (省得每次重捞)
```
SHA256:u14U8c0RuKnVinQuaGH5ey6OKScaPOlRF3vMNqSnEGI
```
用法 (多条命令必须写脚本文件用 `-m` 传, 且 .bat 包一层, 否则 bash→cmd 的引号会炸):
```bat
"C:\Program Files\PuTTY\plink.exe" -ssh -pw root -batch ^
  -hostkey SHA256:u14U8c0RuKnVinQuaGH5ey6OKScaPOlRF3vMNqSnEGI ^
  uisrc@10.10.21.250 -m C:\path\to\cmds.sh
```

### 掉线的样子 (2026-07-31 实拍一次全过程)
`ping 11ms` → plink 握手成功拿到 host key → **中途 `Software caused connection abort`** →
再试 `Connection timed out` → 最后网关回 **`无法访问目标主机`** = 彻底掉网。
全程约 2 分钟。**屏一直亮着不变** —— 就是 [[本文档]] 上面说的"定格最后一帧"。
⇒ 判断板子死活**用 TCP 探测**(见上节, 别用 ping —— WSL 侧 ICMP 不可靠), 更别看屏。
恢复只能**断电重启**(reboot 不重新枚举 dongle)。
⚠ 但 2026-08-01 发现: **这一整套现象也可能只是 DHCP 换了 IP**(见下节), 先查 ARP 再下结论。

## 🔴 IP 固定 (2026-08-01) —— 因为 DHCP 换址会伪装成"WiFi 掉线"

**这是本项目最浪费时间的一个失效模式, 务必记住现象。**

板子 MAC `90:de:80:35:19:41` 在一次重启后从 `10.10.21.3` 跳到 `10.10.20.239`
(这个 /23 网段 ARP 表里几百台设备, 地址复用频繁, 租约极易被顶掉)。后果:
网页端推送目标 / 远程探测脚本 / 看门狗的网关判定 **全部盯着旧 IP** ⇒ 全线失联,
**现象与真掉线完全相同**: ping 不通、ssh 超时、网关回"无法访问目标主机"。

⚠ 我据此推出过一套完全错误的理论("fps 从 11 单调掉到 4 = 渐进劣化 = 5V 供电不足"),
实际断流是 IP 变了, fps 下降是另一回事(`dec_avg=108ms` 本身就撑不住 26fps)。
**两个不相关现象被串成一条因果链** —— 排查时先排除 IP 变更再谈物理层。
自检: `cmd.exe /c "arp -a" | grep 90-de-80` 看 MAC 现在挂在哪个 IP。

### 配置方式
`pov_boot.sh` 里把 `dhclient $IF` 换成静态块 (原版备份 `pov_boot.sh.bak_dhcp`):
```sh
STATIC_IP=10.10.21.250; PFX=23; GWIP=10.10.20.1
ip addr flush dev $IF; ip addr add $STATIC_IP/$PFX dev $IF; ip link set $IF up
ip route replace 10.10.20.0/$PFX dev $IF src $STATIC_IP   # ⚠ 必须先有直连路由
ip route replace default via $GWIP dev $IF
NETOK=0; for t in $(seq 1 6); do ping -c1 -W2 -I $IF $GWIP >/dev/null 2>&1 && { NETOK=1; break; }; sleep 5; done
[ "$NETOK" = 1 ] || { ip addr flush dev $IF; dhclient $IF; }   # 兜底: 绝不能把自己关在门外
```
`.250` 选址依据: 实测空闲, 且 `10.10.21.24x-25x` 整段 ARP 无人使用(DHCP 池未覆盖)。

### 配的过程踩的两个坑 (都是自己制造的)
1. **`ip route replace default via GW` 报 `Nexthop has invalid gateway`** ——
   删掉旧地址时把共享的直连路由一起带走了, 没有直连路由就加不了默认路由。
   **必须先 `ip route replace 10.10.20.0/23 dev $IF src <静态IP>`**。
   当时板子一度完全没有默认路由: 同网段(Windows)还能连, **跨网段(WSL/容器)全断**。
2. **兜底判定太急** —— 配好静态立刻 ping 网关, 那一刻链路还没稳 → 误判失败 →
   跑 `dhclient` 把旧地址拉回来, 变成静态+DHCP 双地址并存。**必须重试**(现为 6 次/30s)。

### 配套改动
- 网页上位机 `aibrain-app` 的推送目标默认值改成 `10.10.21.250`
  (`app.py` 的 `id="pvs-host"`)。⚠ **源码是打进镜像的, 没有 volume 挂载** ——
  改仓库文件不会立刻生效; 要同时 `docker exec ... sed -i /app/app.py` 再 `docker restart`
  (可写层保留修改, 只有 `up --build` 重建才会丢)。
- 看门狗 `stream/board/povwifi_watchdog.sh` + `povwifi.timer` 已装(15s 一次)。
  ⚠ 它的网关判定同样受 IP 变更影响 —— 固定 IP 后才真正可信。
