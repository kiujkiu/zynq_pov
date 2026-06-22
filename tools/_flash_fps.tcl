# flash + ps7_init + 扫 (overlap, planes, T_UNIT) 测 fps. 一个连接全做完.
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
source $psinit
if {[catch {ps7_init} e]} { puts "ps7_init err: $e" }
catch { ps7_post_config }
configparams force-mem-access 1
mwr -force 0xF8000180 0x00600600
after 200
mwr -force 0x40020008 127
proc measfps {ov planes tunit} {
    set ctrl [expr {0x1 | (2<<1) | 0x500 | ($planes<<13) | ($ov<<6)}]
    mwr -force 0x40020000 0
    mwr -force 0x40020014 $tunit
    mwr -force 0x40020000 $ctrl
    after 400
    set t1 [expr {[mrd -force -value 0x4002000C] >> 16}]
    after 2000
    set t2 [expr {[mrd -force -value 0x4002000C] >> 16}]
    set d [expr {($t2-$t1) & 0xFFFF}]
    set tag [expr {$ov ? "OVERLAP" : "seq    "}]
    puts "  $tag planes=$planes T_UNIT=$tunit  =>  [expr {$d/2}] fps"
}
puts "=== ICND2047 1-bit: sequential vs OVERLAP (128col 32scan 50MHz) ==="
measfps 0 1 1
measfps 1 1 1
measfps 0 1 16
measfps 1 1 16
measfps 0 1 64
measfps 1 1 64
measfps 0 1 128
measfps 1 1 128
exit
