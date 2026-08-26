---
name: WSL2 写不了 U 盘/SD 卡 — 走 9p, sudo 也没用; 改做镜像给 Etcher 烧
description: 四种写法全 Permission denied 且与卡无关; ext4 更需要块设备而 9p 不提供; 出路是 loop 设备做镜像
type: feedback
---
2026-08-26 装第二台 FS03 时踩的。想直接往 SD 卡写系统, **四种方式全部失败**:

```
WSL  cp (drvfs)                → Permission denied
WSL  sudo cp                   → Permission denied
WSL  重挂 -o umask=000,uid=...  → Permission denied
Windows PowerShell (从 WSL 调)  → UnauthorizedAccessException
```

🔴 **与卡和读卡器无关** —— 换了两张完全不同的卡、两套访问路径, 表现一模一样。

根因: WSL2 访问 Windows 盘走 **9p 协议**(`mount` 里显示 `type 9p`),
对可移动介质的写入受宿主侧限制。**Linux 的 root 管不到 Windows 的文件系统驱动**,
所以 `sudo` 在这一层没有任何意义。

而且就算能写也只解决一半: **ext4 需要块设备级访问, 9p 根本不提供**。
`lsblk` 在 WSL 里也看不到 U 盘(只有 WSL 自己的虚拟盘)。唯一的块设备路径是
`wsl --mount \\.\PHYSICALDRIVE<N> --bare`, 而它**需要管理员权限**。

## 出路: 在 loop 设备上做完整镜像, 再让人用 Etcher 烧

```
truncate 2600M → parted 分区 → losetup -fP → mkfs.vfat/mkfs.ext4
→ 挂载灌内容 → 解 rootfs → e2fsck → gzip -1
```
**全程在 WSL 内部, 不碰宿主磁盘, 普通权限就够。** 人只需要点三下 Etcher
(它认 .gz 不用解压, 自动隐藏系统盘, 写完自动校验)。实测 26.8 MB/s。

脚本: `mlkpai_fs03/stream/boot/make_card_image.sh`

⚠ 比 `dd` 稳: `dd` 打错一个字母就把系统盘写了; Etcher 有防呆。

**Why**: 这条边界不是权限配置问题, 是 WSL2 的架构 —— 试再多遍、加再多 sudo
也不会通。认清之后 5 分钟就能绕过去。

**How to apply**: WSL 里凡是要**写块设备**(烧卡/改分区/格式化非 Windows 文件系统),
第一反应就该是"做镜像给宿主工具烧", 而不是想办法直接写。
相关: [[feedback_touch_success_is_not_writable]]
