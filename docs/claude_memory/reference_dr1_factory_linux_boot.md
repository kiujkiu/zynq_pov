---
name: DR1 出厂 Linux 启动方式 (TF 卡 / boot mode / initrd 不持久化)
description: 出厂系统从 TF 卡启动, rootfs 是 initrd 跑在 RAM 里 ⇒ 重启即丢; 板子标配带卡和读卡器
type: reference
---

2026-08-05 从资料包 `01_user_start/02_linux_start/` 逐份核出来的（板子到货但还没通电）。
上位: [[reference_anlogic_dr1_fs03_eval]] / [[reference_anlogic_td_toolchain_setup]]。

## 要不要 Linux / 要不要 TF 卡

**都要，但 TF 卡不用自己买** —— 装箱清单里 **TF 卡 = 标配**（还有第二张选配），
**读卡器也是标配**，另配电源 / Type-C 线 / 以太网线。出厂 Linux 就烧在这张卡里。

只有卡坏了或要重做时才用 `03_restore_factory/boot.zip`：
**把 TF 卡格式化成 FAT32，把 5 个文件全拷进根目录**（不是 dd 镜像）:
`BOOT.bin` / `boot.scr` / `system.dtb` / `uImage.lz4` / `uInitrd.lz4`（共 14.6 MB）。

## boot mode 拨码 (PIN1-PIN2, 0=ON 1=OFF)

| 拨法 | 模式 |
|---|---|
| ON-ON (00) | JTAG |
| ON-OFF (01) | QSPI |
| **OFF-OFF (11)** | **SD/TF** ← 出厂系统用这个 |

⚠ 与 Zynq 那块 FS03 不同，别把 [[feedback_lxb_boot_mode_sw3]] 的 SW3 经验套过来。

## 🔴 rootfs 是 initrd, 跑在 RAM 里 —— 重启即丢

`boot.scr` 解出来（跳过 64B u-boot 头）:
```
load ... 0x10000000 uImage.lz4
load ... 0x19000000 uInitrd.lz4
load ... 0x18000000 system.dtb
setenv bootargs console=ttyS0,115200n8 earlycon=uart,mmio32,0xf8401000 loglevel=8 \
       mtdparts=alspinor:1M(boot),-(data)
bootm 0x10000000 0x19000000 0x18000000
```
**bootargs 里没有 `root=`，是 `bootm` 带 uInitrd** ⇒ 整个文件系统是 ramdisk。后果:
- **拷上去的东西重启全没**（benchmark 二进制、帧数据、脚本每次都要重传）。
  连 `mount -t configfs` 和 `/tmp` 里的 dtbo 也一起没，PL 加载会以 `rc=1` 静默失败。
  🔴 **判断板子有没有重启要看 `uptime` / dmesg 时间戳，不能看"某个文件还在不在"** ——
  我踩过: 拿刚**重传过**的 `/lib/firmware/pl.bin` 的 MD5 对上了就断言"没重启"，
  于是绕着 configfs 白查了两轮。自己刚写进去的东西不能当证据。
  要持久化: 放 TF 卡的 FAT 分区，或自己加一个 ext4 rootfs 分区改 bootargs。
- rootfs 很小（uInitrd.lz4 仅 5.4 MB 压缩），别指望上面有 gcc/python。
  ⇒ 所有板端程序必须**交叉编译 + 静态链接**（见 [[reference_bench_codec_kit]]）。

## 串口 / 登录 / 网络

- 串口 **ttyS0, 115200 8N1**（Type-C 插上后在设备管理器看 COM 号，PuTTY 连）
- 登录 **root / root**（密码盲打，串口不回显）
- `ifconfig` 里 **eth0 = PS 端千兆网口**（YT8531 + stmmac）。
  官方教程用直连 PC 的做法: 板子 `ifconfig eth0 192.168.137.100`，PC 设同网段。
  ⇒ 传文件走网口最省事，不必碰 WiFi（出厂内核**没有无线栈**，见评估文档）。
- QSPI NOR 分区: `alspinor: 1M(boot), -(data)`

## WiFi 要什么 (2026-08-06 实测, mt76 dongle 路线)

出厂内核**无线栈为零**: `cfg80211`/`ieee80211` 符号数都是 **0**, `/sys/class/ieee80211` 不存在,
`/lib/firmware` 空, `iw`/`iwconfig`/`wpa_supplicant` 全无。插 dongle 也不会枚举成网卡。
(那 24 个看着像无线的 kallsyms 命中是 **Realtek 以太网 PHY** `rtl8201/8211b/c/8366rb`, 假阳性。)

🎯 **但内核支持加载模块 ⇒ 不必替换内核镜像**:
```
/proc/modules 存在(空)   CONFIG_MODULES=y
/sbin/{insmod,modprobe,rmmod,lsmod} 齐全   /proc/sys/kernel/modprobe = /sbin/modprobe
内核 6.1.111-rt42  #1 PREEMPT Mon Nov 18 22:27:54 PST 2024
编译器 riscv64-unknown-linux-gnu-gcc (g05ff855b4) 10.2.0  (Nuclei), ld 2.36.1
```
⇒ 只需编出 vermagic 匹配的 `cfg80211.ko` / `mac80211.ko` / `mt76*.ko` + 固件, `insmod` 即可。
工作量从"重编内核 + 重做 TF 卡"降到"编几个模块传上去"。

🔴 **前置条件(还没有)**: 米联客 Linux SDK 包 —— 内核源码 + **那份 `.config`** + Nuclei gcc 10.2.0。
`/proc/config.gz` 没开, 所以 `.config` 只能从源码包拿; 缺它则结构体布局对不上, 模块必崩。
🎯 **包的公开下载地址已找到**(在**公司官网** <https://www.milianke.com/p-downloads.html>，
**不用登录**；uisrc.com 那个论坛下载区才要登录，别去那边)：

| 包 | 百度网盘 | 提取码 |
|---|---|---|
| **`uisrc-lab-anlogicV-V4.0.1` (RISC-V)** ← **要这个** | `https://pan.baidu.com/s/1QAxazhi0fVoh-VgDzuL01Q?pwd=1111` | 1111 |
| `anlogic-linuxsdk` | `https://pan.baidu.com/s/1mJFREo7b_6gNlmIh-9jx_w?pwd=1111` | 1111 |
| `uisrc-ubuntu18x64` 虚拟机 | `https://pan.baidu.com/s/1euIyM1cHH3TLsHjc8rKnTA?pwd=1111` | 1111 |

🔴 **认准 `anlogicV`** —— `anlogicM` 是 ARM 版(DR1M90)，我们的 DR1V90 是 RISC-V。
⚠ 百度网盘要客户端登录，**我下不了**，只能用户下。
⚠ `04_secondary_development/demo.zip` 里**只有设备树和 SDK, 没有 Buildroot/内核源码**, 别白找。

**为什么 WiFi 最终必须解决**: 屏是转起来的, **转子上拉不了网线** —— 这是整套系统用 WiFi 的根本原因。
有线只能用于台架验证(而且台架阶段有线更好: 把链路波动这个变量摘掉,
见 [[feedback_wifi_throughput_bottleneck_isolated]] 的教训)。

## 板载 LED 是**低电平点亮**

vendor demo `01_run_led/uisrc/01_rtl/run_led.v` 的初值是 `7'b0111_1111` —— **那个 0 才是亮的**。
引脚 L21/L22/M21/M22/N22/P20/P22/P21，时钟 L18(25MHz)、复位 L19。
我第一版心跳写成 `1<<n`(高有效)，上板表现为"一灭七亮"，用户一眼看出极性反了。
(顺带: vendor 那行有位宽 bug，`7'b` 赋给 8 位寄存器会零扩展成 `8'b0011_1111`，实际亮两颗。)

## 🔴 迭代闭环已验证可用 (改 RTL → 综合 → 加载, 分钟级)

`td_gen.py` 生成工程 → syn/phy → `albg1.exe -process_bitstream bin` → 串口传 → overlay 加载。
**判据: 比对 `.bin` 的 MD5** —— 改完 RTL 若 MD5 没变, 说明改动根本没进去。
我踩过一次: 替换脚本**无条件打印"已改"却没做校验**, 静默失败, 白烧一轮
(现象: 重新综合、重新 bootgen, 但 bin 的 MD5 与上一版**逐字节相同**)。
⇒ 任何"改文件"的脚本都要**回读校验**, 并且改完先看 MD5 变没变再上板。

## 🔴 重打 rootfs 的两个致命细节 (2026-08-07)

### ① lz4 帧格式: kernel 用 modern, rootfs 用 **legacy**

```
kernel.bin  : lz4 -f -9   → modern frame 魔数 0x184D2204
rootfs.bin  : lz4 -l -9   → **LEGACY frame** 魔数 0x184C2102
```
🔴 **`mkimage -l` 分辨不出来** —— 两者都显示 "lz4 compressed"。只能 hexdump 偏移 0x40
(64 字节 uImage 头之后的第一个字)。用错帧格式板子起不来, 而起不来只能拔卡恢复。
`dr1v90/tools/mkrootfs.sh` 里对这 4 字节做了硬断言。

### ② 基底必须是**卡上正在跑的那份**, 三个候选互不相同

| 文件 | md5 | 大小 |
|---|---|---|
| **卡上 `rootfs.bin`(实际在跑)** | `0e68555093ef01f86c24505f1491b547` | 4,984,832 |
| `dr1v90/tfboot/uInitrd.lz4` (来自 03_restore_factory/boot.zip) | `ca0b0467f997eb81462d91cde05b7404` | 5,422,770 |
| SDK `boards/DR1V/buildroot/output/uInitrd.lz4` | `157931dc73f25f2c861e134556705ce0` | 4,984,795 |

**卡上跑的是第三个版本**, 两份"官方"资料都不是它。用错基底 = 把 userland 悄悄换成另一个
厂商版本(busybox 构建不同、strace 有无不同、shadow salt 不同)，可能几天后才以怪现象暴露。
⇒ **重打 rootfs 前必须先 `md5sum` 卡上那份并与基底对齐**。
从板上取文件用 `dr1v90/host/serial_recv.ps1`(板子有 wget 能拉, 但没有任何上传工具)。

⚠ 顺带: 卡上这套的文件名是 `kernel.bin`/`rootfs.bin`/`dtb.bin`, 资料包那套是
`uImage.lz4`/`uInitrd.lz4`/`system.dtb` —— **命名不同说明是不同的出厂发布**, 别混用。
