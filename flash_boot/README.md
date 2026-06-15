# QSPI 自启动镜像 (POV 720片 anime, sensor 模式)

上电从 QSPI flash 自动跑 720 片 anime + 光电开关角度跟踪, 无需 JTAG。

## 重建 BOOT.bin
```sh
# 1. app (寄存器配置): vitis CLI 编 pov_boot.elf
cd ../02_hello_zynq/vitis_ws
vitis -s build_pov_boot.py        # -> pov_boot/build/pov_boot.elf

# 2. 收集文件到 flash_boot/
cp ../02_hello_zynq/vitis_ws/hello_plat/export/hello_plat/sw/boot/fsbl.elf  fsbl.elf
cp ../02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit         system.bit
cp ../02_hello_zynq/vitis_ws/pov_boot/build/pov_boot.elf                     pov_boot.elf
cp ../tools/anime_slices_720_compact.bin                                     anime.bin

# 3. bootgen -> BOOT.bin
bootgen -image boot.bif -arch zynq -o BOOT.bin -w on
```

## 烧 QSPI (W25Q256)
```sh
# hw_server 必须在跑; flash_type 是 qspi-x4-single (带横线!)
program_flash -f BOOT.bin -offset 0 -flash_type qspi-x4-single -fsbl fsbl.elf -verify -url tcp:localhost:3121
```
烧前若 DAP 锁死 (targets 空): 拔插 JTAG USB 或冷循环板子 (见 memory feedback_jtag_dl_reflash_loop_dead)。

## ⚠ 启动拨码
烧完必须把 **SW3** 切到 QSPI boot 模式才会从 flash 启动 (SW1/SW2 是 PL_KEY 无关)。

## BIF 分区
- `[bootloader] fsbl.elf` — PS/DDR/时钟初始化
- `system.bit` — PL 设计 (angle_tracker period-fix bit)
- `pov_boot.elf` — 配 FCLK1=85.7M + HUB75E 寄存器 -> CTRL=0xC5E1 (sensor 模式 720片)
- `[load=0x18000000] anime.bin` — FSBL 直接把 5.76MB 切片加载到 DDR
