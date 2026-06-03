---
name: 鹿小班 QSPI flash 容量 + Linux 预算 (W25Q256 默认 / W25Q512 升级路径)
description: 鹿小班板上 QSPI = W25Q256JVEIQ (32 MB) 默认; 可 drop-in 换 W25Q512 (64 MB) 但需 4-byte 地址改 FSBL/U-Boot/Linux
type: reference
originSessionId: b7a84340-ed43-45b4-b468-71142eb587e9
---
## 硬件事实
- 板上 QSPI flash 芯片 = **Winbond W25Q256JVEIQ**
- 容量 = **256 Mbit = 32 MB**
- 走 MIO1-6（见 reference_luxiaoban_mio_pinout）

## Zynq 7020 Linux flash 预算

**关键尺寸**
- BOOT.BIN（FSBL + 7020 full bitstream ~4 MB + U-Boot ~500 KB）≈ 5 MB
- uImage（PREEMPT_RT 也只 +1–2 MB）≈ 5–7 MB
- devicetree ≈ 30–64 KB
- initramfs busybox 静态 ≈ 4–8 MB
- Buildroot minimal rootfs ≈ 30–80 MB
- Yocto core-image-minimal ≈ 100–150 MB
- Debian armhf base ≈ 400 MB

**三档方案**
| 方案 | QSPI | SD | 说明 |
|---|---|---|---|
| A 极简纯 QSPI | 16 MB 紧/32 MB 舒 | — | kernel + initramfs 全压 QSPI |
| B QSPI boot + SD rootfs | 16 MB 够 | ≥ 2 GB | 鹿小班推荐, Python/Qt 友好 |
| C 全 SD boot | 无所谓 | ≥ 2 GB | QSPI 损坏时备用 |

**32 MB QSPI 推荐分区（纯 QSPI 方案）**
```
boot    0x000000  5 MB    BOOT.BIN
bootenv 0x500000  128 KB  U-Boot env
kernel  0x520000  6 MB    uImage (PREEMPT_RT)
dtb     0xB20000  64 KB   devicetree
rootfs  0xB30000  ~20 MB  squashfs / initramfs.cpio.gz
spare   末尾      ~1 MB   factory/MAC
```

**20 MB rootfs（squashfs 压缩后）能装**
- busybox 全套 + glibc/musl
- wpa_supplicant + iw + dhcpcd + dropbear
- ESP-Hosted daemon + 自己的 C 应用
- 剩 5–8 MB 余量

**装不下要走 SD/NFS**: Python3 / Qt / X11 / gcc

**省 QSPI 技巧**
- bitstream 改放 SD/FAT, U-Boot `fpga load`, BOOT.BIN 缩到 < 1 MB

## 何时用
- 评估"7020 上是否走 Linux"路径时引用
- 写 PetaLinux/Yocto BSP 分区表时直接套
- 跟 ESP32-C5 WiFi 桥切换到 Linux mac80211 标准 SDIO WiFi 模块的可行性讨论

## 升级路径：换 W25Q512JVEIQ (64 MB)

### 硬件
- **drop-in pin/封装/电压/协议全兼容** (SOIC-8/WSON-8, 3.3V, QSPI x4, Winbond 同系列指令集)
- 淘宝 ¥30-50, 热风一吹即可替换

### 软件 (关键改动: 4-byte 地址模式)
W25Q256 用 EAR 寄存器扩 24-bit → 32 MB, W25Q512 必须 **4-byte 地址 (32-bit 寻址)** 才能访问全部 64 MB。

**Zynq 7020 BootROM 限制**：只用 3-byte 地址，只能读 QSPI **前 16 MB**。所以：
- BOOT.BIN (FSBL + bitstream + U-Boot) **必须塞在前 16 MB**
- FSBL 加载后自己发 `0xB7` 切 4-byte mode
- U-Boot/kernel 才能访问 16-64 MB 区域

**改动清单**（参考 Xilinx XAPP1247）：
1. **FSBL**：`xqspips_g.c` 加 `XQspiPs_WriteEnable` + 发 `0xB7` (Enter 4-byte mode)
2. **U-Boot**：`CONFIG_SPI_FLASH_4BYTE_ADDR=y` (mainline 已支持 W25Q512)
3. **Linux MTD**：`drivers/mtd/spi-nor/winbond.c` mainline 已认 W25Q512JV, dtb compatible `"jedec,spi-nor"` 即可

### 64 MB 分区方案
```
0x0000_0000 - 0x0010_0000   (1 MB)    BOOT.BIN (FSBL+bitstream+U-Boot)
0x0010_0000 - 0x0050_0000   (4 MB)    bitstream 单独区 (PL 升级用)
0x0050_0000 - 0x0060_0000   (1 MB)    U-Boot
0x0060_0000 - 0x0062_0000   (128 KB)  U-Boot env
0x0062_0000 - 0x00A0_0000   (~4 MB)   kernel (Image)
0x00A0_0000 - 0x00A2_0000   (128 KB)  device tree
0x00A2_0000 - 0x00B0_0000   (~880 KB) WiFi firmware (rtw8822c_fw + NVRAM)
─────────── 以上必须在前 16 MB (BootROM 限制) ───────────
0x00B0_0000 - 0x0400_0000   (~53 MB)  rootfs (squashfs/jffs2)
```

### 53 MB rootfs (squashfs 压缩 ~2.5×) 容量
| 配置 | 压缩前 | 压缩后 | 53 MB 够吗 |
|------|-------|--------|-----------|
| busybox + WiFi 栈 + iperf | 20 MB | 8 MB | ✓ 余 45 MB |
| PetaLinux minimal + WiFi + 自定 daemon | 50 MB | 20 MB | ✓ 舒服 |
| + Python3 minimal | 120 MB | 50 MB | ⚠ 刚好 |
| + Debian base | 250 MB | 100 MB | ❌ |

### 何时换 W25Q512
**短期不换**：开发期烧 53 MB QSPI ~100s vs SD 卡秒级，迭代慢 50×；WiFi firmware 升级也得重烧。

**量产期换**：
- rootfs 固化, 摆脱 SD 卡 (POV 旋转结构装不下 SD 座)
- A/B 分区 fail-safe
- 抗插拔可靠性
