---
name: reference-wsl-burn-linux-sd
description: "WSL 给 Zynq 板烧 Linux SD 卡 (FAT boot + ext4 rootfs) 全套踩坑: usbipd+usb-storage / parted缺装 / usbip大写不稳→loop镜像+Rufus DD"
metadata: 
  node_type: memory
  type: reference
  created_at: 2026-06-23 CST
  updated_at: 2026-06-23 CST
  originSessionId: fe6cecaa-6915-4b7c-91e6-2e0b62bc1aaa
---

2026-06-23 给米联客 MLKPAI-FS03 烧出厂 Debian SD 实战总结. WSL2 (Ubuntu 24.04) + Windows。

## 让 WSL 看到 SD 读卡器 (usbipd)
- WSL2 默认看不到 USB 读卡器. 用 **usbipd-win** (本机已装 `C:\Program Files\usbipd-win`):
  - 管理员 PowerShell: `usbipd list` → `usbipd bind --busid X-Y` (首次,需管理员) → `usbipd attach --wsl --busid X-Y`
  - **认对设备**: 读卡器 = `USB 大容量存储设备` (high-speed). 别选成 `布告栏设备`(USB Billboard)/`CH340 串口`/`DSL Instrument`(逻辑分析仪). 我一开始按模糊截图猜错 busid 卡了几轮 — `usbipd list` 我能直接 `cmd.exe /c "usbipd list"` 读(list 不需管理员, bind/attach 需要).
- **🔴 WSL2 内核默认没加载 usb-storage**: attach 后无 /dev/sd. 模块**存在但没load**: `sudo modprobe usb-storage uas` (uas 那条写法被当参数忽略无妨, usb-storage 够). 加载后真存储设备才枚举出 /dev/sdX (本次 = /dev/sde 29.2G).
- 认设备靠**容量+MODEL**: 虚拟盘是 "Virtual Disk", SD 是 "Storage Device"+真实容量. 给 sudo 烧命令前 Claude 按容量替用户确认设备名, 防格错盘.

## WSL Ubuntu 常缺工具
- **parted / dosfstools(mkfs.vfat) / partprobe 默认没装** (mkfs.ext4 有). `sudo apt-get install -y parted dosfstools`. WSL 联网 apt 正常.
- sudo secure_path 可能不含 /sbin → 脚本顶部 `export PATH=/usr/sbin:/sbin:$PATH` 保险.
- **sudo 要密码 Claude 跑不了** → 烧卡脚本写好让用户 `sudo bash <script>` 在 WSL 终端跑(密码留本地不进对话). 用户进 WSL: PowerShell 里敲 `wsl` 即可.

## 🔴 usbip 大文件写不稳 → B方案 (loop镜像 + Rufus DD)
- usbipd "mirrored 网络模式" 下 dmesg 狂刷 `WSL CheckConnection getaddrinfo failed`, **直接往 usbip 的 /dev/sde 写 2GB rootfs 中途 I/O 挂** (A方案 burn.sh 失败).
- **B方案(成功)**: 不碰 usbip 写. WSL 用 **loop 设备**本地造完整 .img (`losetup -P` 分区扫描 → parted 分区 → mkfs → 拷boot+解rootfs → losetup -d), 4GB稀疏镜像实占~1.2G. 脚本 `~/mlkpai-sd/make_img.sh`.
- 再 **Windows 侧烧** (绕开 usbip, 走原生USB): `usbipd detach` 把 SD 还 Windows → **Rufus**(单文件免安装, github pbatard/rufus, ~2M) 或 Etcher(只有安装版150M). Rufus: 设备选SD → SELECT 选 .img → **格式化选项变灰 = 已识别成磁盘镜像走 DD 裸写** → 开始. 镜像拷到 Downloads 让 Rufus 选本地最稳.
- ⚠ detach 后 Windows 弹"需要格式化此磁盘"(看不懂 ext4) → **点取消别格**.

## 串口 console (Claude 可直接读/操作)
- CH342 双串口: **COM13=PS console**(@115200), COM15 空. WSL2 不能直访 COM → 走 **PowerShell SerialPort** 从 Windows 侧读写: `powershell.exe -NoProfile -Command "..."` (内联, 不用 -ExecutionPolicy Bypass — 那个会被 auto classifier 拦; -File 跑 .ps1 受执行策略限). PS 里 `New-Object System.IO.Ports.SerialPort COM13,115200` + Open/Write([char]13)/ReadExisting/Close. bash 双引号内 \$ 转义, 字符串用 PS 单引号(避免跟 bash 双引号冲突), 行尾用 [char]13(避免 backtick 被 bash 当命令替换). 登录序列: 写 'uisrc'+CR → sleep → 'root'+CR → sleep → 命令.

关联 [[project_mlkpai_fs03_usb_wifi_board]] [[reference_git_push_via_cmd]].
