---
name: pov2 装机出厂配置 (2026-08-27 固化)
description: 上电即 3-bit + lz4x3 + 光电传感器模式的完整配置与每一处备份; 附 --fake 装机陷阱
type: project
---
2026-08-27 为 pov2(第二台 Zynq, 见 [[reference_pov3d_board_inventory]])固化的装机配置。
目标: **上电即显示, 不依赖任何人工操作**。

## 配置清单

| 项 | 值 | 备份 |
|---|---|---|
| 卡上 `BOOT.BIN` | `BOOT.bin.lz4x3`, md5 **67894f9c7032f2b99c754e05e9ca4937**, 4,703,152 B | `/home/uisrc/BOOT.BIN.prelz4.bak` (md5 98faaaf9) |
| `pov_boot.sh` | `BPP3 = 1` ⇒ 3-bit / `oe_w 184 92 46` / `n_slices 142` / 装 `helix3b.bin` (10,469,376 B) | `/home/uisrc/pov_boot.sh.pre20260827.bak` |
| `povrxd` drop-in | 仓库 `stream/board/systemd/povrxd.service.d-idle-pl.conf` 原样 | `idle.conf.fake.bak` (带 --fake 的台面版) |
| 自启 | `pov` enabled / `povrxd` enabled / `povcolors` **disabled** | `povcolors.service.bak` |

```
ExecStart=/home/uisrc/pov_rxd --idle-anim /home/uisrc/helix3b.pvs --idle-fps 11 \
          --pl-lz4 --pl-engines 3 --no-pipeline
```

## 🔴 装机陷阱: `--fake` 必须去掉

台面调试时给 drop-in 加了 `--fake 12 --fake-slices 142`(软件伪造转速, 因为桌上没电机)。
**装到真机上必须去掉** —— 否则屏按假的 12 rev/s 刷, 与实际转速无关, 体显示全糊。
去掉后走 `angle_tracker` 的光电传感器。2026-08-27 用户当场发现, 差点就这么装了。

⚠ 配套的坑: **`pov_rxd` 不带 `--fake` 时根本不写 `0x10`**(`pov_rxd.c:3392-3394`),
所以改完 drop-in 重启服务, `fake_en` 仍是上一次的残留 —— 要靠 `pov_boot.sh` 开机
写 `(N_SLICES<<16)|0x5` 才清掉。手动改的话记得自己写一次。

⚠ **台面上(无电机)去掉 `--fake` 后屏会定格/变暗, 这是对的**, 不是故障。

## 验证判据

**必须冷启动**(断电再上电) —— 热重启不重载 PL, 验不了 BOOT.BIN。三条同时成立才算过:

1. `ls /sys/kernel/config/device-tree/overlays/` → **空**(没有运行时 overlay)
2. `grep PLDIAG /home/uisrc/pov_rxd.log` → **`eng=3/3`** —— overlay 为空而三引擎还活着
   ⇒ **lz4x3 只可能来自 BOOT.BIN**。这是判定 PL 版本最硬的只读特征
   (prelz4 里没有这三个引擎, 会打三条"判死")
3. `pov_boot.log` → `bpp_mode 1 oe_w 184 92 46 n_slices 142` + 进程无 `--fake`

## 回滚

```sh
sudo mount /dev/mmcblk0p1 /mnt/boot
sudo cp /home/uisrc/BOOT.BIN.prelz4.bak /mnt/boot/BOOT.BIN && sudo sync && sudo umount /mnt/boot
```
板子起不来 ⇒ 拔卡用 `fs03_card.img.gz` 重烧, **但那会丢掉本条记的所有板上改动**
(镜像是 08-26 做的), 重烧后要照本条重做一遍。

## 写启动分区的正确姿势

1. 先传到 **rootfs** 校验 md5, 通过了才碰 FAT —— 坏的传输绝不落到启动分区
2. 写完 `sync`, 再 **umount + 只读重挂** 复校一次 —— 绕开页缓存假阳性
   (同类教训见 [[feedback_touch_success_is_not_writable]])

---

## 2026-08-28 进度

**pov1 的配置已加载到 pov2**（用户要求"一模一样"）：`lz4x3` 用 `fpga_manager` + configfs
overlay 运行时灌入，实测 `PLDIAG eng=3/3 ok=1`；bitstream md5 `69fd7495` 与仓库
`stream/boot/plbin/pl_lz4x3.bit.bin` 逐字节一致（= pov1 跑的那一份）。

⚠ **overlay 不持久，断电即回退到卡上的 prelz4** —— pov1 也是这样。每次上电要重灌：

```sh
BOARD=pov2 tools/board_ssh.sh --put stream/boot/plbin/pl_lz4x3.dtbo /tmp/pl_lz4x3.dtbo
BOARD=pov2 tools/board_ssh.sh --sudo "echo root | sudo -S systemctl stop povrxd"
BOARD=pov2 tools/board_ssh.sh --sudo "echo root | sudo -S sh -c 'mkdir -p /sys/kernel/config/device-tree/overlays/pl && cat /tmp/pl_lz4x3.dtbo > /sys/kernel/config/device-tree/overlays/pl/dtbo'"
BOARD=pov2 tools/board_ssh.sh --sudo "echo root | sudo -S systemctl restart pov.service"   # PL 换了要重配面板
BOARD=pov2 tools/board_ssh.sh --sudo "echo root | sudo -S systemctl start povrxd"
BOARD=pov2 tools/board_ssh.sh --sudo "echo root | sudo -S tail -c 4000 /home/uisrc/pov_rxd.log | grep -a PLDIAG | tail -1"   # 期望 eng=3/3
```

**2026-08-28 收尾时状态**：dtbo 已写入、povrxd 已停、overlay 已灌(RC=0)；
后三步（重配面板 / 起 povrxd / 验 eng=3/3）**未完成** —— 用户关机了。下次开机重做整套。

🔴 **想做成上电自动**：加一个开机 systemd unit 灌 overlay，**不要改 `BOOT.BIN`**。
2026-08-27 把 `BOOT.bin.lz4x3` 写进卡的 FAT 之后板子起不来，只能拔卡救 ——
**启动分区是唯一一处改错了就够不到板子的地方**。overlay 灌失败最多是 PL 停在 prelz4，
板子照样起得来。

## FS03 板载 LED（2026-08-28 从原理图查实，尚未用上）

原理图 `D:\BaiduNetdiskDownload\MLKPAI-AMD\03_MLKPAI-FS03_7020\FS03-ZYNQ\02_hardware\
MLKPAI-FS03-ZYNQ-hardware-20240909\02_原理图\MLKPAI_FS03_ZYNQ_240909.pdf`

```
VCC_3V3 ──▶| LED(红) ──[2.2K]── FPGA 引脚      ⇒ **低电平点亮**
LED1 L21   LED2 L22   LED3 M21   LED4 M22
LED5 N22   LED6 P20   LED7 P22   LED8 P21      (另有 LED9)
```

⚠ **全在 PL 引脚上，不是 MIO ⇒ Linux 碰不到，必须改 bitstream。**
现成的跑马灯 RTL 在 `dr1v90/dclk_probe/rtl/dclk_probe_top.v`（5 行：计数器 +
`assign O_led = ~(8'b1 << cnt[26:24])`）。移植要动顶层 port + XDC + **BD 里引出 external**,
而改 module_ref 的 port 会踩 [[feedback_vivado_bd_addr_width_cache]]（要改模块名 +
删 ip cache + 重建 cell），然后跑一遍完整综合布线。用户 2026-08-28 决定先不做。

🔴 **别盲扫 MIO 找 LED**：我按 `board_config.md` 没列到就当 MIO 0/7/8/50/51 是空闲的，
扫了一遍 —— 原理图显示 **MIO51 接的是一个晶体管 Q2(RUM001L02T2CL)**、MIO50 接按键，
板子随后失联。**"外设驱动没声明" ≠ "物理上没接东西"，动 MIO 前必须查原理图。**
