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
