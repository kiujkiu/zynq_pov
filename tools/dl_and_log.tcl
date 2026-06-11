# dl_and_log.tcl — dl elf, immediately run, then capture UART via xsdb readback
# 用 xsdb readreg pc 看 ARM 是否在跑 + 是否 stuck

set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/02_hello_zynq.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/hello_world/build/hello_world.elf"

connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1000
fpga -file $bit
source $psinit
ps7_init
ps7_post_config
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05
targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
con
puts "running..."

# Sample PC 5 次, 看 ARM 是否在跑 (PC 在变 = OK, 不变 = 卡)
for {set i 0} {$i < 5} {incr i} {
    after 500
    stop
    set p [lindex [rrd pc] 1]
    con
    puts "sample $i pc = $p"
}
exit 0
