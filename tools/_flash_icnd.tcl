# ICND2047 板2 flash: fpga + ps7_init(配FCLK/DDR/AXI GP) + 测试图案
# 用法: xsct _flash_icnd.tcl [mode]  mode: 0纯白 2八色 3棋盘格
set mode 2
if {$argc >= 1} { set mode [lindex $argv 0] }
set ctrl [expr {0x1 | ($mode << 1) | 0x500}]
set base "D:/claude_workspace/pov3d/zynq_pov_icnd2047/02_hello_zynq"
set bit "$base/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
set psinit "$base/02_hello_zynq.gen/sources_1/bd/hello_zynq/ip/hello_zynq_processing_system7_0_0/ps7_init.tcl"

connect
after 800
targets -set -nocase -filter {name =~ "*APU*"}
puts "loading fpga..."
fpga -file $bit
after 500
targets -set -nocase -filter {name =~ "*Cortex-A9*#0*" || name =~ "ARM*#0"}
catch { stop }
after 100
puts "ps7_init (配 PS clocks/AXI)..."
source $psinit
if {[catch {ps7_init} e]} { puts "ps7_init err: $e" }
catch { ps7_post_config }
puts "ps7_init done"
configparams force-mem-access 1
mwr -force 0xF8000180 0x00600600
after 200
if {[catch {mrd -force -value 0x40020000} pr]} { puts "PROBE-FAIL: $pr"; exit 1 } else { puts "PROBE-OK 0x40020000 = [format 0x%X $pr]" }
mwr -force 0x40020000 0
after 100
mwr -force 0x40020008 127
mwr -force 0x40020014 16
mwr -force 0x40020004 0x003F3F3F
mwr -force 0x40020010 0x003F3F3F
mwr -force 0x40020000 $ctrl
after 500
puts "MODE=$mode CTRL=[format 0x%X [mrd -force -value 0x40020000]] PARAM=[mrd -force -value 0x40020008] STATUS=[format 0x%08X [mrd -force -value 0x4002000C]]"
exit
