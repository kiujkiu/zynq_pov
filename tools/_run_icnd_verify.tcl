# ICND2047 板2 静态验证: 烧 GUI-built bit + FCLK1 50M(DDR有效) + 测试图案
# 用法: xsct _run_icnd_verify.tcl [mode]   mode: 0=纯白 2=8色竖条 3=棋盘格(默认2)
# 板2 单板时 name-based 选靶即可. 不转, 静态看色序+几何.
set mode 2
if {$argc >= 1} { set mode [lindex $argv 0] }
# CTRL = en | (mode<<1) | addr_bits5(0x500)
set ctrl [expr {0x1 | ($mode << 1) | 0x500}]
set bit "D:/claude_workspace/pov3d/zynq_pov_icnd2047/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"

connect
after 800
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 200
targets -set -nocase -filter {name =~ "APU*"}
puts "烧 ICND2047 bit..."
fpga -file $bit
after 500
configparams force-mem-access 1
# FCLK1 = 50M (ICND2047 物理 25M, DDR 有效 50M; SLCR 0x00600600)
mwr -force 0xF8000180 0x00600600
after 200
# 参数: width-1=127(128列全宽), TUNIT=16(亮度, 静态看够亮)
mwr -force 0x40020000 0          ; # disable 先
after 100
mwr -force 0x40020008 127        ; # PARAM width-1 = 127 → 128 列
mwr -force 0x40020014 16         ; # TUNIT 亮度
mwr -force 0x40020004 0x003F3F3F ; # COLOR top (mode0 用)
mwr -force 0x40020010 0x003F3F3F ; # COLOR bot
mwr -force 0x40020000 $ctrl      ; # en + mode
after 500
puts "MODE=$mode CTRL=[format 0x%X [mrd -force -value 0x40020000]] PARAM=[mrd -force -value 0x40020008] STATUS=[format 0x%08X [mrd -force -value 0x4002000C]]"
puts "frame_count(STATUS[31:16])=[expr {[mrd -force -value 0x4002000C] >> 16}]"
exit 0
