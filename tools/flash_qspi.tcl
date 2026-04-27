# flash_qspi.tcl — 把 BOOT.bin 烧到 QSPI Flash, 板子上电后从 QSPI 启动.
#
# 流程:
#   1) bootgen 生成 BOOT.bin (FSBL + bitstream + hello_world.elf)
#   2) xsdb program_flash 写 QSPI
#   3) 拔 USB → 改板子 BOOT MODE 跳线为 QSPI → 上电 → 自动启动
#
# 用法 (Vitis 命令行):
#   D:\Vitis\2024.2\bin\xsdb.bat flash_qspi.tcl
#
# 重要: BOOT MODE 跳线必须切回 QSPI 才会从 QSPI 启动.
#   LXB-ZYNQ7000 一般有 MIO[5:2] 配置跳线:
#     QSPI boot:  MIO5=0 MIO4=0 MIO3=0 MIO2=1
#     SD boot:    MIO5=1 MIO4=0 MIO3=1 MIO2=0
#     JTAG boot:  MIO5=0 MIO4=0 MIO3=0 MIO2=0  (默认调试)

puts "FLASH: starting"

set boot_bin "D:/workspace/zynq_pov/tools/BOOT.bin"

if {![file exists $boot_bin]} {
    puts "FLASH: $boot_bin 不存在, 先跑 bootgen 生成 BOOT.bin"
    puts "  cmd:  D:\\Vitis\\2024.2\\bin\\bootgen.bat -arch zynq \\"
    puts "        -image D:\\workspace\\zynq_pov\\tools\\bootgen.bif \\"
    puts "        -o $boot_bin -w on"
    exit 1
}

connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}

# QSPI flash 类型: 单芯片 4 线 mode (LXB-ZYNQ7000 标配 QSPI).
# 若板子用其他 type 改下面的 -flash_type:
#   qspi-x4-single, qspi-x8-single, qspi-x4-dual_parallel, etc.
puts "FLASH: program_flash QSPI..."
program_flash -f $boot_bin \
              -fsbl D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/export/hello_plat/sw/boot/fsbl.elf \
              -flash_type qspi-x4-single \
              -blank_check \
              -verify

puts "FLASH: done. 现在:"
puts "  1) 拔 USB / 断电"
puts "  2) 改 BOOT MODE 跳线 → QSPI"
puts "  3) 上电 → 板子从 QSPI 自动启动 hello_world"
exit 0
