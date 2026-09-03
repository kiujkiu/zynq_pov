# Stochastic-failure measurement: repeat the power-up N times, same settings.
# The user counts how many of the N attempts bring up all 9 chips.
# ASCII-only (Vivado on Windows reads .tcl as GBK).
set NAME [lindex $argv 0]
set GAP  [lindex $argv 1]
set N    10
if {[llength $argv] > 2} { set N [lindex $argv 2] }
set BD "build_dbg"
if {[llength $argv] > 3} { set BD [lindex $argv 3] }
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/$BD"
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROGRAM.FILE     "$B/$NAME.bit" $dev
set_property PROBES.FILE      "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE "$B/$NAME.ltx" $dev
program_hw_devices $dev
refresh_hw_device $dev
after 2000
set v ""
for {set t 0} {$t < 5} {incr t} {
    set vs [get_hw_vios]
    if {[llength $vs] > 0} { set v [lindex $vs 0] ; break }
    after 1000 ; refresh_hw_device $dev }
if {$v eq ""} { puts "=== ABORT: no VIO ===" ; exit 1 }
proc PX {v want} {
    set best ""
    foreach p [get_hw_probes -of_objects $v] {
        set n [get_property NAME $p]
        if {$n eq $want} { return $p }
        if {[string match "*/$want" $n] || [string match "*.$want" $n]} { set best $p }
    }
    return $best }
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 150 }
setp $v dbg_frame_gap $GAP
# 可选: 第 5 个参数起是 "addr:data" 对, 每次上电前先 poke 进寄存器 RAM
set WE 0
set POKES [lrange $argv 4 end]
foreach pk $POKES {
    set a [lindex [split $pk ":"] 0] ; set d [lindex [split $pk ":"] 1]
    setp $v dbg_reg_addr $a ; setp $v dbg_reg_data $d
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
    puts "===   poke reg\[0x$a\] = 0x$d"
}
puts "=== RETRY STATS: $N power-up attempts, identical settings."
puts "=== Count how many attempts light ALL 9 tiles.  ~6 s per attempt."
for {set i 1} {$i <= $N} {incr i} {
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 5000
    refresh_hw_vio $v
    set st [expr 0x[get_property INPUT_VALUE [PX $v g_dbg.status]]]
    puts [format "=== %s  attempt %2d/%d   fps=%-4d ack_cnt=%-5d ack_err=%-6d nbits=%-4d data0=0x%04X  sticky=%d" \
        [clock format [clock seconds] -format %T] $i $N [expr 0x[get_property INPUT_VALUE [PX $v fps_latched]]] \
        [expr 0x[get_property INPUT_VALUE [PX $v ack_frame_cnt]]] \
        [expr 0x[get_property INPUT_VALUE [PX $v ack_err_cnt]]] \
        [expr 0x[get_property INPUT_VALUE [PX $v ack_f_nbits]]] \
        [expr 0x[get_property INPUT_VALUE [PX $v ack_f_data0]]] \
        [expr ($st >> 10) & 1]]
}
puts "=== done ==="
close_hw_target
exit 0
