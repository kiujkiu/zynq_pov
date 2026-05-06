---
name: 鹿小班官方参考工程与芯片手册位置
description: 鹿小班 ZYNQ7020 核心板随附的 Vivado 参考工程、例程代码、芯片手册、视频教程所在目录
type: reference
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
鹿小班 LXB-ZYNQ7000 全部官方资料根目录：
```
/mnt/e/工程软件/ZYNQ7020-484核心板/LXB-ZYNQ7000/
```

子目录用途：
- `01_硬件资料/` — 原理图 PDF：`SCH_Schematic1_2024-10-07.pdf`（8 页）
- `02_芯片手册/` — Zynq/DDR/PHY 芯片 datasheet
- `04_apply-code/HelloZynqPS_Linux_ETH/` — **官方 Vivado 参考工程**（`.xpr` + 已导出的 `design_1_wrapper.xsa`），PS/DDR 配置金标准
- `04_apply-code/HelloZynq_Linux/` — Linux 版 Hello Zynq
- `05_文档教程/` — PDF 教程
- `06_视频教程/` — 视频
- `08_Vivado/2024.1/` — Vivado 2024.1 安装器（用户实际装了 2024.2）
- `09_Ubuntu_image/` — Ubuntu rootfs
- `10_PetaLinux/` — PetaLinux 资料
- `12_出厂测试固件/` — 整机自检固件

**用法：** 遇到 Vivado 配置疑问（特别是 PS/DDR 参数、MIO 分配、时钟）先去 `04_apply-code/HelloZynqPS_Linux_ETH/` 抄；可以用 Python 解压 `.xsa`（它就是 zip）提取 `ps7_init.c/.html` 读参数：
```python
import zipfile; zipfile.ZipFile('<path>/design_1_wrapper.xsa').extractall('/tmp/xsa')
```
