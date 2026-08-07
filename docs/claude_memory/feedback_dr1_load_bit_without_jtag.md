---
name: 🎯 DR1 运行时加载 PL bitstream — 不用 JTAG 不用重启 (已跑通)
description: 关键是用 bootgen -arch dr1v90 -process_bitstream bin, 不是 TD 的 bit_to_bin; 附完整配方与三个坑
type: feedback
---

2026-08-06。**在 WinUSB 驱动那件事上卡了四轮之后找到的绕路，价值远大于把驱动装上。**

## 结论

DR1V90 出厂 Linux 里 **Linux FPGA Manager 框架 + 安路 PCAP 驱动 + configfs overlay 全都在**：
```
/sys/class/fpga_manager/fpga0/name   = "Anlogic dr1m90 FPGA Manager"
/sys/class/fpga_manager/fpga0/state  = operating
/sys/class/fpga_region/region0       存在 (dmesg: "of-fpga-region soc:base_fpga_region: FPGA Region probed")
mount -t configfs none /sys/kernel/config  → rc=0
/sys/kernel/config/device-tree/overlays/   存在(空) ⇒ CONFIG_OF_CONFIGFS 已开启
```
⇒ 机制上 **PL bitstream 可由 PS 经 PCAP 加载，全程不碰 JTAG**（与 Zynq 的 devcfg 同类）。
⚠ **但实测没走通到底**，见下面「实测状态」一节 —— 别照着结论就以为能用。

## 为什么这条路重要

安路 AL-Link FT 下载器(`VID_0403/PID_6042`, 序列号 AL9IKFER)必须把
`USB Serial Converter A` 的驱动从 `FTDIBUS` 换成 **WinUSB**（`hwserver.exe` 走 libusb，
libusb 在 Windows 上只能绑 WinUSB）。而这一步**我无法代劳**，三条路全堵:
- `pnputil`: TD 自带驱动只有 `VID_0547/1002` 和 `VID_336C/1001-1004`，**不含 6042**；
  libwdi 的 WinUSB 包是**模板且无 `.cat`**（未签名）
- 自己签名: 本机没有 `signtool`/`Inf2Cat`（要装几个 GB 的 Windows SDK）
- 鼠标自动化: 🔴 **UsbDriverTool 是提权进程，Windows UIPI 禁止非提权进程操作提权窗口** —
  `MoveWindow`/点击全部静默失败。这是安全设计，绕不过。

## ✅ 2026-08-06 已跑通 —— 完整配方

```
[82435.286404] dr1m90_fpga_manager f8801000.fpga-mgr: fpga prog successfully
STATE: operating    OVERLAY: applied    (零报错)
```

### 🔴 决定成败的一步: bin 必须用 **bootgen** 出, 不能用 TD 的 `bit_to_bin`

```bash
# ① .bit → PS 可加载的 .bin   (arch 是 dr1v90, 不是 dr1m90 —— 按芯片 V/M 变体选)
albg1.exe -arch dr1v90 -image pb.bif -process_bitstream bin -w
#   pb.bif 内容:  all: { run_led.bit }
#   工具在 C:\Anlogic\FD_2025.1	oolsootgenlbg1.exe (Xilinx bootgen 同构)
```
| 产出 | 大小 | 结果 |
|---|---|---|
| TD `bit_to_bin -bit x.bit -bin x.bin` | 2,778,190 B (mod4=2) | ❌ 补齐后仍 `prog done fail: -524308` |
| **bootgen `-process_bitstream bin`** | **2,878,528 B (天然对齐)** | ✅ **prog successfully** |

两者头部都是 `ffff ffff 2266 bbdd`(字节反转过的同步字), 但 bootgen 多出 ~10 万字节,
说明 PS 加载路径需要 `bit_to_bin` 不产生的额外内容。**别在 `bit_to_bin` 上浪费时间。**

### ② overlay (dtc 在开发机编, 板上没有 dtc)
```dts
/dts-v1/; /plugin/;
&{/soc/base_fpga_region} { firmware-name = "pl.bin"; };
```
🔴 **绝不能写 `#address-cells`/`#size-cells`** —— 目标节点已有, overlay 改它们会被拒:
`OF: overlay: ERROR: changing value of #address-cells is not allowed`。
⚠ 注意这个错**极具迷惑性**: 报错时 **FPGA 其实已经烧进去了**(编程发生在 overlay 的
pre-apply 通知里, 早于设备树合法性检查), 但 `create_overlay` 返回 -22 让人以为失败了。

### ③ 板上加载
```sh
mount -t configfs none /sys/kernel/config      # 出厂不自动挂
cp pl.bin /lib/firmware/                        # /lib/firmware 出厂为空
rmdir /sys/kernel/config/device-tree/overlays/pl 2>/dev/null   # 重载前必须先删旧的
mkdir -p /sys/kernel/config/device-tree/overlays/pl
cat pl_load.dtbo > /sys/kernel/config/device-tree/overlays/pl/dtbo
cat /sys/class/fpga_manager/fpga0/state         # 期望 operating
dmesg | tail                                     # 认准 "fpga prog successfully"
```
⇒ **改一次 RTL 就能秒级重配, 不用重启、不用拔卡、不用 JTAG。**
文件走串口 base64 传(`dr1v90/serial_send.ps1`), bitstream 压缩比 155× ⇒ 2.8MB 只要 ~6 秒。

## 排查过程留档 (曾以为失败)

```
configfs overlay → of-fpga-region → fpga_manager → PCAP 写入 2,778,192 B  ✅ 全部写完
                                                   最后的 DONE 检查        ❌
dr1m90_fpga_manager f8801000.fpga-mgr: fpga prog done fail: -524308
fpga_manager fpga0: Error after writing image data to FPGA
state: operating → "write complete error"
```

**已排除的四种可能**（都试过, 现象完全相同）:
1. 长度未对齐 —— 这个**是真问题且已解决**, 见下
2. 原始字节序 / 3. dword 逐字节反转 —— 两种都是同一个 `prog done fail`
4. 加载前 `echo 1 > plclk_reset` —— 无变化

器件不匹配也已排除: demo `01_run_led` 的 `.al` 是 `DR1V90GEG484` speed `-2`，与本板一致。

⇒ 剩余怀疑: **`bit_to_bin` 产出的可能不是"PS 可加载"变体**。还没试的:
`bitgen` 的选项（demo 目录里另有 `fpga_prj_compress.bit`）、`bit_convert` 命令。

## 🔴 已确认的格式要求: bin 长度必须 dword 对齐

`bit_to_bin -bit <in> -bin <out>` 产出 **2,778,190 B, 长度 ≡ 2 (mod 4)**，
驱动直接拒收: `bit data is not dword aligned: 2778190`。

修法: **头部补 2 个 `0xFF`**（不是补尾巴）。依据是按 dword 重划头部就一目了然:
```
[ff ff] DDBB6622 FFFFFF00 FFFFFFFF FFFFFFFF 000000AA 11220044 ... CC55AA33 80000000...
```
`DDBB6622` 是同步字，前面本该是完整的 `FFFFFFFF` 哑字，`bit_to_bin` 只留了 2 个 `FF`。
补头之后同步字正好落在 dword 边界；补尾巴则会让同步字永远错位。

## 加载步骤（板上）

```sh
mount -t configfs none /sys/kernel/config          # 出厂不自动挂
cp fpga.bin /lib/firmware/                          # /lib/firmware 出厂是空的
mkdir /sys/kernel/config/device-tree/overlays/pl
cat pl.dtbo > /sys/kernel/config/device-tree/overlays/pl/dtbo
cat /sys/class/fpga_manager/fpga0/state             # 期望 operating
```
- bit → bin 用 TD 的 **`bit_to_bin`** 命令（tcl 命令列表里还有 `bit_convert`/`bit_to_bas`/`bit_to_vec`）
- 板上**没有 dtc**，`.dtbo` 在开发机编好再传
- 传输走串口 base64（`dr1v90/serial_send.ps1`，见 [[reference_bench_codec_kit]] 同款做法）
  或网口；⚠ rootfs 是 initrd，**重启即丢**（[[reference_dr1_factory_linux_boot]]）

## ⚠ 上板前必须确认的安全项

`td_panel` 那个 `panel_core_synth_top` 是**综合表征顶层，输入全由 LFSR 驱动** ——
它会把真实屏引脚(`panel_dclk/lat/oe/sdi[8:0]`, 已按真实 LOCATION 分配)**驱成伪随机波形**。
**接着屏时绝不能加载它**（OE 随机 ⇒ 可能整屏导通；参见 5V 轨余量本来就紧）。
首次 PL 加载要么屏不接，要么换一个不驱动屏引脚的测试设计。

## 决定: 先走厂商文档化的 BOOT.bin 路径

米联客 Linux 课程 PDF 里**只有 FSBL 路径**: `soc_sdk/soc_fsbl/build/soc_fsbl.elf`
+ `soc_sdk/soc_base/platform/system.bit` 由 FD 的 bootgen 打包成 **BOOT.bin**,
开机时 FSBL 配 PL。没有任何运行时 fpga_manager 的说明。
⇒ 这是**板子出厂就在跑**的已知good路径。

利好: TF 卡的 FAT 分区**已挂在 `/mnt/mmcblk0p1` 且可写** ⇒ 可以从板上直接覆盖
BOOT.bin 再 reboot，**不用拔卡**（[[reference_dr1_factory_linux_boot]] 记过制卡方式）。
代价: 每换一个 bit 要重启 ~30 s。对"点屏 + 抓眼图"够用。

## 教训

**卡在一个外部依赖上超过两三轮，就该退一步问"这个依赖是不是必需的"。**
这次的正确问题不是"怎么装上 WinUSB"，而是"**除了 JTAG 还有没有别的路把 bit 送进 PL**"。
FPSoC 有 PS，PS 能配 PL —— 这个可能性在第一轮就该想到。
