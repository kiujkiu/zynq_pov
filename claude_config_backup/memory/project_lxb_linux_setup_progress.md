---
name: 鹿小班 Linux 开发环境准备进度 (2026-06-04)
description: LXB Zynq 7020 + PetaLinux 2024.2 setup, 脚本目录 ~/lxb-linux-setup/, 6 步骤 task list, 当前卡在用户下载 installer
type: project
created_at: 2026-06-04
updated_at: 2026-06-04
originSessionId: 0be7a193-9bc9-4973-bf90-99272813831e
---
## 决策路径

**阶段 A 先做**: PetaLinux + GEM0 wired，验证 Linux 跑在鹿小班上
**阶段 B 后做**: 飞线 RTL8822CS + SDIO WiFi (硬件到位再开)

不一上来就软硬双线 debug。

## 环境锁定

- WSL Ubuntu 24.04 (Noble), 15GB RAM, 20 核, /  944GB free
- Vivado/Vitis **2024.2** in `C:\Xilinx\` (从 WSL 走 `/mnt/c/Xilinx/`)
- PetaLinux **必须 2024.2**, 跟 Vivado XSA schema 严格绑定
- Ubuntu 24.04 不在官方支持表 (官方 22.04), 但社区可跑, 需手动补 libtinfo5

## 文件铺设 (已完成)

`~/lxb-linux-setup/` 目录:
- `01_install_prereqs.sh` — apt 装 PetaLinux 依赖 + libtinfo5 jammy + locale + dash→bash + 建 `/tools/petalinux/2024.2` 用户可写
- `02_install_petalinux.sh` — 跑 AMD installer, 非交互 EULA
- `env.sh` — 每个新 shell `source ~/lxb-linux-setup/env.sh` 进 PetaLinux 环境
- `download_notes.md` — AMD SSO 下载步骤
- `README.md` — 总览

`~/dl/` — 放 installer
`~/projects/lxb-linux/` — 未来 PetaLinux 工程目录

## 6 步骤 task list (id 1-6, 已在 TaskCreate)

1. ✅ 脚本铺设完成, ⏳ 等用户 `sudo bash 01_install_prereqs.sh`
2. ⏳ 用户下载 installer (AMD SSO, ~10GB) → `~/dl/`
3. ⏳ `bash 02_install_petalinux.sh` (~20-30 min, ~80GB 占用)
4. ⏳ smoke test: `petalinux-create -t project --template zynq -n smoke`
5. ⏳ Vivado BD 加 SD1 EMIO + export XSA `lxb_linux.xsa`
6. ⏳ BSP build: GEM0 + serial console + SD boot, **不带 WiFi**

## 关键约束记录

- **sudo 需密码** (没 NOPASSWD)
- AMD installer 不能 wget 直链, 必须用户登录
- PetaLinux **不能 root 安装**, installer 自检会拒绝
- /tools 权限由 prereq 脚本提前设给 $SUDO_USER

## 下次接力入口

打开 `~/lxb-linux-setup/README.md` 看顺序; `TaskList` 看进度; 已铺设但未跑的脚本不需要重写。
