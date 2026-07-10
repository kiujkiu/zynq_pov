---
name: pov3d-lxb-standalone-autoboot
description: "鹿小班 POV 脱机自启动 (无JTAG): flash_boot 工具链 BOOT.bin (FSBL+bit+pov_boot.elf+data) + QSPI需JTAG boot mode / SD卡启动最省事 (FAT32+BOOT.bin根目录)"
metadata: 
  node_type: memory
  type: project
  created_at: 2026-06-23 CST
  updated_at: 2026-06-23 CST
  originSessionId: fe6cecaa-6915-4b7c-91e6-2e0b62bc1aaa
---

鹿小班 (FM6124 板, cable SN 210251A08870) 让 POV 上电自启动 anime/globe, 无需 JTAG/PC. 2026-06-23 实战.

## flash_boot 工具链 (commit fac19a9, `zynq_pov/flash_boot/`)
`boot.bif` 4 分区 → bootgen → BOOT.bin (~9.6M):
```
[bootloader] fsbl.elf            # PS/DDR/时钟 init
system.bit                       # PL 设计 (=当前 v8 panel IP bit)
pov_boot.elf                     # 配寄存器 (见下)
[load=0x18000000] anime.bin      # FSBL 把 5.76MB 切片直接载到 DDR
```
- `pov_boot_src/main.c` 寄存器序列 (内容无关, 等效 _run_720_sensor.tcl): FCLK1=0x00300700(85.7M) / TUNIT=0x1FF / **PARAM=127(W=128)** / SLICE_BASE=0x18000000 / ANGLE_PERIOD=14577(fallback) / N_SLICES=720 / **CTRL=0xC5E1**(sensor_en+compact+dma+overlap+use_fb+en).
- **换内容只换数据文件**: cp anime或globe `_slices_720_compact.bin` → flash_boot/anime.bin, 再 bootgen. pov_boot.elf 通用 (都 720 片).
- bootgen: `cmd.exe /c "cd /d D:\...\flash_boot && C:\Xilinx\Vitis\2024.2\bin\bootgen.bat -image boot.bif -arch zynq -o BOOT.bin -w on"`

## 🔴 prebuilt BOOT.bin 会过期 — 必须 md5 核对再重建
fac19a9 的 BOOT.bin 是 06-15 的 (旧 bit + 旧 anime), ≠ 部署验证过的 06-16 v8 bit. 烧前必 `md5sum flash_boot/system.bit impl_1/hello_zynq_wrapper.bit` + anime.bin vs 当前切片. 不一致就 cp 当前 bit/数据 + 重 bootgen.
⚠ **当前 flash_boot/anime.bin 装的是 GLOBE 数据** (2026-06-23 覆盖, 文件名仍 anime.bin).

## QSPI 烧录 (program_flash) — 🔴 需 JTAG boot mode
```
program_flash -f BOOT.bin -offset 0 -flash_type qspi-x4-single -fsbl fsbl.elf -url tcp:localhost:3121
```
- **必须先有 hw_server 在跑**: program_flash 不自启 hw_server (xsct 会). 独立后台起 hw_server, 别用 `start /b hw_server & program_flash` 组合 (吞输出+难管, 2026-06-23 踩).
- **🔴 板子必须 JTAG boot mode 才能写 QSPI**: 鹿小班当前 SD boot (BOOT_MODE 0xF8000A1C=0x5) → program_flash 报 `current boot mode is SD / Problem in running uboot / Flash Operation Failed`. 要切 JTAG(bm=0x0) 才行. 鹿小班 boot strap=SW3 但**组合不确定** (见 [[feedback_lxb_boot_mode_sw3]], JTAG=0x0/QSPI=0x1/SD=0x5, 边切边 mrd 0xF8000A1C 验). 这条很折腾.

## ✅ SD 卡启动 = 最省事 (推荐, 2026-06-23 走此路)
板子已 SD boot strap → **不碰拨码/JTAG/QSPI**:
1. SD 卡格 **FAT32** (exFAT/NTFS 不行, Zynq BootROM 只认 FAT16/32)
2. 把 BOOT.bin 拷到**根目录** (文件名必须 `BOOT.bin`, 就这一个文件)
3. 插卡上电 → BootROM 载 FSBL→bit→pov_boot→globe 自启动. 蓝 LED 亮=FPGA 载入成功.
- 同一个 BOOT.bin 两路通用 (QSPI/SD). 静止糊像正常, 转电机 + angle_tracker 锁上才稳.

关联 [[project_pov3d_lxb_pov_milestone]] [[feedback_lxb_boot_mode_sw3]] [[feedback_jtag_dl_reflash_loop_dead]] [[reference_luxiaoban_qspi_flash]].
