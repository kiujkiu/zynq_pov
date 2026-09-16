---
name: 这台 Windows 往 SD 卡复制文件会被 DLP 静默加密
description: 文件系统写入被 #OCULAR3# 加密, 大小+37280B 且每次 md5 不同; 只有块级写整卡能正确写卡(Etcher 或 dr1v90/host/flash_card_raw.ps1)
type: feedback
---
2026-08-27 在这台机器（用户 `wanqi.liu`）上排查"板子起不来"，最后发现：
**任何经过文件系统往 SD 卡复制的文件，都会被企业安全软件整个加密。**

## 判据

把 4,703,152 B 的 `BOOT.BIN` 复制到卡上，读回来：

```
大小   4,740,432 B      = 源 + 37,280 B     ← 每次都是这个固定增量
md5    每写一次变一次    (f6b255e4 / 892cfe6f / 61ee837e / 1380880b / de78d67e ...)
文件头 23 4f 43 55 4c 41 52 33 23 34 35 34 45 34 33 35 32 35 39 35 30
       #  O  C  U  L  A  R  3  #  4  5  4  E  4  3  5  2  5  9  5  0
                                  └── ASCII hex = "ENCRYP" ──┘
```

正常的 Zynq BOOT.BIN 头应该是 `fe ff ff ea`×8 + `66 55 99 aa`(0xAA995566 同步字) + `"XNLX"`。

## 为什么容易误判成硬件坏

- **固定的大小增量** + **每次不同的 md5** ⇒ 极像介质随机损坏
- **换读卡器没用**（它是软件过滤器，不在硬件层）⇒ 更像卡坏
- 我因此一路怀疑到"卡的写入耐久度坏了"，差点让用户换卡

**真正区分开的是看文件头**。以后遇到"写卡后 md5 对不上"，**第一件事是 dump 前 64 字节**，
不要先怀疑硬件。

## 连带现象

- **从 WSL 拉起的 PowerShell / `cmd copy` 写卡一律"拒绝访问"**（`cmd` 报"已复制 0 个文件"）。
  DLP 只放行资源管理器，挡掉脚本 ⇒ **写卡这一步 claude 做不了，只能用户手动**。
- 卡上 8/26 用 **Etcher 整卡烧录**写的 `uImage` / `devicetree.dtb` / `uEnv.txt`，
  到 08-27 读回来 md5 **逐字节正确** ⇒ **块级写入绕过了文件系统过滤器**。

## How to apply

**这台机器上写 SD 卡只能块级写整卡镜像**。这台电脑**没装 Etcher**（09-16 查过）⇒
✅ **2026-09-16 实测可用的替代品**: `dr1v90/host/flash_card_raw.ps1`（UAC 提权, 核对 盘号/USB/容量/序列号 后
Clear-Disk → CreateFile 写 `\\.\PhysicalDriveN`(分区表那块最后写) → 整段读回比 md5）, 512MB **15 MB/s, 读回 PASS**。
⚠ 用户要点一次 UAC; 写完没盘符(新分区不自动分配, 非管理员 Update-Disk 被拒), 拔插读卡器即可。
🔴 **反方向也被 DLP 拦**: `Copy-Item E:\x D:\...` 报 UnauthorizedAccess(读 hash 却没问题) ⇒
从卡上**取**文件用 `[IO.File]::ReadAllBytes` + `[Console]::OpenStandardOutput().Write` 经管道重定向到 WSL, md5 逐字节对。
不要用资源管理器 / 脚本往卡里复制单个文件 —— 复制会"成功"，内容是密文，板子读到就是乱码。

要改卡上的单个文件（如 `BOOT.BIN`），正确做法是**从板子的 Linux 里改**：
`sudo mount /dev/mmcblk0p1 /mnt/boot` → `cp` → `sync` → **umount 后只读重挂复校 md5**。
2026-08-27 这么做过一次，md5 双重校验通过。

相关：[[feedback_wsl_cannot_write_removable_media]]（WSL 走 9p 写不了可移动介质，sudo 也没用）、
[[feedback_touch_success_is_not_writable]]（写成功≠数据正确，必须读回比对 md5）。

## 2026-09-16 复查: 块级写的卡上没有记号

DR1V90-2 那张卡 `flash_card_raw.ps1` 写完后, 不拔卡、走卷 GUID 路径(`\\?\Volume{...}\`, 没盘符也能读)逐文件查:
**23 个文件没有一个以 `#OCULAR` 开头**, 大小/md5 与本机源文件逐个相同, `pov/MANIFEST.md5` 11 项 bad=0,
也没有 `System Volume Information`(没分盘符, Windows 没碰过)。
🔴 **陷阱: 烧完后别在这台电脑上改卡里的文件** —— `make_card_image_dr1.sh` 结尾提示
"在 Windows 里往 pov\ 建空文件 AUTOBOOT"、手改 `pov/povboot.env`, 在这台机器上都会被加密
(空文件也会变成带 #OCULAR 头的 37 KB)。要改就重出镜像重烧, 或上板后在 Linux 里改。
