---
name: DR1 WiFi (mt7921u) — 编 riscv64 内核模块的完整配方
description: SDK 包/工具链/defconfig 全对上; 关键是不能启用 WIRELESS_EXT 和 DEV_COREDUMP; 固件从 Zynq 板抠
type: project
---

2026-08-06。原计划: 给 DR1V90 加 WiFi，**不替换内核镜像**，只编可加载模块。
🔴 **该计划已被证伪 —— 必须换内核镜像**，原因见「§ 为什么只编模块走不通」。
（下面的配置配方仍然有效，只是产物要连内核镜像一起换。）
背景与判据见 [[reference_dr1_factory_linux_boot]]。

## 硬件

用户插的 dongle 实测 **`0e8d:7961 Wireless_Device` = MediaTek MT7921AU**，
**与现役 Zynq 板上那颗是同一芯片** ⇒ 驱动线、固件全可照抄。

## 材料 (全部齐备)

**SDK**: `uisrc-lab-anlogicV-V4.0.1.tar.gz` (1.9 GB) —— 公开下载，见 [[reference_dr1_factory_linux_boot]] 的链接表。
🔴 **必须解到 WSL 原生文件系统**(本机 `~/dr1sdk/`)，内核源码里有大量只差大小写的文件名，
解到 `/mnt/d` 的 NTFS 会撞名(与 musl 工具链同一个坑)。

```
sources/linux/                              内核源码 6.1.111 + localversion-rt = "-rt42"
tools/riscv64-linux/bin/riscv64-unknown-linux-gnu-   gcc (g05ff855b4) 10.2.0
boards/DR1V/configs/defconfigs/anlogic_dr1_kernel_defconfig
scripts/{drcfg.sh, kernel/*.sh}             官方构建脚本(要先 source 板级 cfg)
sources/buildroot/                          可用来编 wpa_supplicant
```

**三项精确匹配已验证**(这是模块能 insmod 的前提):
```
make -s kernelrelease            → 6.1.111-rt42      == 板上 uname -r ✓
tools/riscv64-linux gcc 版本      → (g05ff855b4) 10.2.0 == 板上 /proc/version ✓
CONFIG_MODULES=y / MODVERSIONS=y / MODULE_SIG 未启用                    ✓
```

## 🔴 两个必须关掉的选项(否则 insmod 必失败)

**① `CONFIG_WIRELESS_EXT` —— 会改 `struct net_device` 布局**
```c
#ifdef CONFIG_WIRELESS_EXT
    const struct iw_handler_def *wireless_handlers;   /* ← 加了这个字段 */
#endif
```
布局一变，**所有网络相关导出符号的 CRC 全变**，MODVERSIONS 下模块全线拒载。
mt7921u 走 nl80211 不需要 wext ⇒ `--disable CFG80211_WEXT --disable WIRELESS_EXT`。

**② `CONFIG_DEV_COREDUMP` —— 板上内核根本没有这个符号**
启用 mt76 会自动 `select WANT_DEV_COREDUMP` ⇒ `DEV_COREDUMP=y` ⇒ mt76.ko 引用 `dev_coredumpv`。
**板上实测 `dev_coredumpv`/`dev_coredumpm` 都 MISSING** ⇒ 加载时 "Unknown symbol"。
`DEV_COREDUMP` 的依赖是 `ALLOW_DEV_COREDUMP` ⇒ `--disable ALLOW_DEV_COREDUMP` 强制关掉。

⇒ **方法论**: 上板前先拿模块的**未定义符号**去比对板上 `/proc/kallsyms`，
别等 insmod 报错才发现。(⚠ `__crc_*` 符号不进 kallsyms，数量为 0 不能证明 MODVERSIONS 关着。)

## 配置命令

```bash
cp boards/DR1V/configs/defconfigs/anlogic_dr1_kernel_defconfig sources/linux/arch/riscv/configs/
cd sources/linux
export CROSS=~/dr1sdk/uisrc-lab-anlogic/tools/riscv64-linux/bin/riscv64-unknown-linux-gnu-
make ARCH=riscv CROSS_COMPILE=$CROSS anlogic_dr1_kernel_defconfig
./scripts/config --enable WIRELESS --module CFG80211 --module MAC80211 \
    --disable CFG80211_WEXT --disable WIRELESS_EXT \
    --enable WLAN --enable WLAN_VENDOR_MEDIATEK \
    --module MT76_CORE --module MT76_USB --module MT76_CONNAC_LIB \
    --module MT7921_COMMON --module MT7921U \
    --disable ALLOW_DEV_COREDUMP \
    --disable CFG80211_REQUIRE_SIGNED_REGDB --disable CFG80211_USE_KERNEL_REGDB_KEYS
make ARCH=riscv CROSS_COMPILE=$CROSS olddefconfig
make ARCH=riscv CROSS_COMPILE=$CROSS -j$(nproc) modules
```
⚠ 6.1 的模块拆分与板上 6.6 不同: **没有 `mt792x_lib`/`mt792x_usb`**(那是 6.6 才拆出来的)，
6.1 是 `mt76` + `mt76-usb` + `mt76-connac-lib` + `mt7921-common` + `mt7921u`。

**构建主机依赖**: `libssl-dev libelf-dev bc flex bison`
(缺 openssl 头会在 `certs/extract-cert` 处 fatal error；本机 apt 索引过期需先 `apt-get update`)。

## 固件 (已备好)

从现役 Zynq 板 `/lib/firmware/mediatek/` 抠的，**固件是 WiFi 芯片自己的 MCU 代码，与主机架构无关**：
`dr1v90/wifi/firmware/mediatek/` 下 4 个文件
(`WIFI_RAM_CODE_MT7961_1{,a}.bin`, `WIFI_MT7961_patch_mcu_1{,a}_2_hdr.bin`)，MD5 已记在该目录。

Zynq 板上工作中的模块栈(6.6)供参考:
`mt7921u ← mt7921_common ← mt792x_lib ← mt76_connac_lib ← mt792x_usb ← mt76_usb ← mt76 ← mac80211 ← cfg80211` + `libarc4`

## 还没做

- 模块编完后逐个比对未定义符号 → 传上板 `insmod`
- `wpa_supplicant` (riscv64) —— 用 SDK 里的 buildroot 编
- 连 AP + 测吞吐；**注意别重蹈 [[feedback_wifi_throughput_bottleneck_isolated]]**
  (拿 ping 网关当判据 + 自己写的看门狗污染测量，烧过 6 小时)

## 🔴 为什么"只编模块"走不通 —— 必须换内核镜像

上板前的**符号比对**（`tools/check_undef_syms.sh` 的思路: 把模块的未定义符号列表
发到板上 `grep -vxF -f` 比对 `/proc/kallsyms`，比拉 537KB 的 kallsyms 回来快得多；
⚠ busybox **没有 `comm`**，要用 `grep -vxF -f`）查出 **13 个缺失符号**，追下来是**一个根因**:

```
CFG80211_REQUIRE_SIGNED_REGDB=y
  └→ SYSTEM_DATA_VERIFICATION → CRYPTO_RSA/KEYS      ← keys 组 4 个符号
mac80211 → CRYPTO_CCM/GCM/CTR/CMAC(=m) → CRYPTO_MANAGER=m
  └→ MANAGER2 = def_tristate CRYPTO_MANAGER || (CRYPTO_MANAGER!=n && CRYPTO_ALGAPI=y)
     基础配置里 **CRYPTO_ALGAPI=y**(zlib/lzo/crc32c 等内建用户带来) ⇒ **MANAGER2 恒为 y**
       └→ select CRYPTO_AEAD2=y / CRYPTO_SKCIPHER2=y
          而 `obj-$(CONFIG_CRYPTO_AEAD2) += aead.o` ⇒ **aead.o 必然内建进镜像**
          ⇒ crypto 组 9 个符号(crypto_alloc_aead 等)做不成模块              ← 死结
```
**只要基础配置里 `CRYPTO_ALGAPI=y`，mac80211 需要的 crypto 核心就一定是内建的**，
而板上那个内核没有无线、自然没编这部分 ⇒ 模块永远缺符号。绕不过。

### 附带学到的 Kconfig 陷阱

`CFG80211_REQUIRE_SIGNED_REGDB` 用 `scripts/config --disable` **关不掉**，
`olddefconfig` 每次都翻回 `=y`。原因:
```kconfig
config CFG80211_REQUIRE_SIGNED_REGDB
    bool "require regdb signature" if CFG80211_CERTIFICATION_ONUS   ← 提示符是**有条件的**
    default y
config CFG80211_CERTIFICATION_ONUS
    depends on EXPERT
```
**提示符不可见 ⇒ 符号不可由用户设置 ⇒ kconfig 强制用 default，忽略 `is not set`。**
要关它必须先 `--enable EXPERT --enable CFG80211_CERTIFICATION_ONUS`。
⇒ **`--disable` 之后必须回读 `.config` 确认**，别假定生效（我假定了两次，都被翻回）。

另: 无 selector 的**有提示符**残留值(`CRYPTO_RSA`/`KEYS`/`CRYPTO_MANAGER`)
`olddefconfig` 不会主动清，要显式 `--disable`。

## 新方案: 换内核镜像 (代价没想象中大)

- SDK 有官方 `scripts/kernel/make_kernel.sh`
- **TF 卡 FAT 分区已挂在板上 `/mnt/mmcblk0p1` 且可写** ⇒ 从板上直接覆盖 `kernel.bin` 再重启，
  **不用拔卡**（卡上文件名是 `kernel.bin`/`rootfs.bin`/`dtb.bin`，与资料包的
  `uImage.lz4`/`uInitrd.lz4`/`system.dtb` 命名不同，见 [[reference_dr1_factory_linux_boot]]）
- 好处: 内核与模块一起编，**ABI 匹配问题整个消失**，反而更简单

## ✅ 2026-08-07 跑通: 换内核 + 模块加载, wlan0 已就绪

```
Linux version 6.1.111-rt42 (wanqi@PC-W003SS3G0143) ... #1 PREEMPT Thu Aug  6 22:12:22 CST 2026
   ← 自编内核已生效 (原版是 uisrc@ubuntu / Nov 18 2024)
mt7921u 1-1:1.0: HW/SW Version: 0x8a108a10
mt7921u 1-1:1.0: WM Firmware Version: ____010000     ← 固件加载成功
wlan0  DOWN  90:de:80:47:f0:ff    /sys/class/ieee80211/phy0 存在
模块栈: mt7921u ← mt7921_common ← mt76_connac_lib ← mt76_usb ← mt76 ← mac80211 ← cfg80211 + libarc4
```

### 换内核的操作纪律 (值得照抄)

1. **先备份再覆盖**: `cp kernel.bin kernel.orig` —— 新内核起不来时可从 U-Boot 改载 `kernel.orig`
   (串口在 U-Boot 阶段就通, 同一个 ttyS0)。**换启动镜像前先留退路**。
2. 传输**先落地成 `kernel.new`、校验 MD5 后再改名**覆盖 —— 中途失败不会毁掉可启动的卡。
3. 覆盖后 `sync` + `umount` 再拔卡。
4. 打包: `Image → lz4 -f -9 → mkimage -A riscv -O linux -T kernel -C lz4 -a 0x00400000 -e 0x00400000`
   (照抄 SDK 的 `scripts/kernel/make_kernel.sh`)。产物大小应与原 `kernel.bin` 接近(5.4 MB)。
5. 模块用 `make modules_install INSTALL_MOD_PATH=... INSTALL_MOD_STRIP=1` 打包,
   **`modules.dep` 在主机端生成好带上去** —— 板上 busybox **没有 `depmod`**。
6. 模块+固件放 **TF 卡**(持久), 不要放 `/tmp`(initrd, 重启即丢)。

### 🔴 板端脚本的两个硬约束

- **命令文件必须纯 ASCII**: 串口控制台把 UTF-8 搞乱, 乱码字节落进引号内会让 shell
  卡在 `>` 续行提示符、后续命令全被吞。救援: `host/serial_break.ps1` 发 Ctrl-C。
- **busybox 缺很多工具**: 没有 `comm`(用 `grep -vxF -f`)、没有 `depmod`、
  `tar` **不支持 `-z`**(用 `gzip -dc ... | tar x`)。

### ✅ 全链路已通 (2026-08-07)

```
iw 5.19 / wpa_supplicant 2.10 / wpa_cli  交叉编译上板, 静态, soft-float ABI 实测能跑
wlan0: authenticated -> associated -> Connected to SSID "undef" @ 5745 MHz (ch149)
udhcpc: lease 10.10.21.53/23 from 10.10.20.1,  signal -51 dBm
tx bitrate 458.8 MBit/s 40MHz HE-MCS9 HE-NSS2   (WiFi 6)
```

**吞吐差分对照**(同一 HTTP 服务器 / 同一 AP / 同一 50MB 不可压缩文件):

| 板子 | 实测 |
|---|---|
| DR1V90 | 26.7 / 28.4 Mbps  (CPU 仅 40-47%, **未饱和**) |
| Zynq-7020 现役 | 18 / 47 Mbps |

⇒ **两块板同量级, DR1 无明显劣势**。一度以为 DR1 只有 20 Mbps 是问题(对比记忆里 Zynq 的
125 Mbps), 但那个 125 是 iperf 受控测的; 本次用 Windows 上的 Python `http.server`
(单线程无 sendfile) + **两端都在 WiFi 上共享空口**, 把两块板**同样**卡在 20-50 Mbps。
⇒ **瓶颈是测试装置, 不是板子。** (Zynq 自己 18 vs 47 的离散也印证空口波动之大。)
🔴 绝对吞吐数字仍未确立 —— 要可信的数必须用 iperf + 有线服务端 + 多次取分布。

### 交叉编译三件套的坑

- 手工编而不是跑 buildroot: buildroot 会重编整个工具链(1-2h), 为 3 个二进制不值当。
  `libnl-3.7.0` → `wpa_supplicant-2.10`(CONFIG_TLS=internal, 免 OpenSSL) → `iw-5.19`, 全静态。
- 🔴 **别在 make 命令行覆盖 `CFLAGS`** —— 会冲掉 wpa_supplicant 自带的 `-I../src`,
  报一堆 `includes.h: No such file`。要在 `.config` 里 `CFLAGS +=` **追加**。
- 🔴 **别顺手开 `CONFIG_SAE`(WPA3)** —— 内置 TLS 没有它要的大数运算,
  链接报 `undefined reference to crypto_bignum_to_bin`。目标 AP 是 WPA2-PSK, 用不上。
  **按实际需要开功能。**
- 工具链默认出 **soft-float ABI** 二进制, 板子是 lp64d 硬浮点 —— 这个方向安全
  (软浮点二进制在有 F/D 的硬件上照跑), 实测 `iw`/`wpa_supplicant` 均正常。

### 还差

- `wpa_supplicant` / `iw` 板上都没有, 需用 SDK 的 buildroot 交叉编译
- `regulatory.db` 缺失 (cfg80211 回落到内置 world regdomain, 信道受限), 可从 Zynq 板拷
- 办公 AP 凭据在 [[feedback_office_ap_blocks_esp32c5_tcp]]: 密码 `undefoffice1010`
- 模块目前解在 initrd 里, **重启即丢**; TF 卡上的 `wifi_payload.tar.gz` 还在, 重启后重解一次即可。
  长久做法是重做 `rootfs.bin` 让其持久化 (等 WiFi 全链路验完再做)
