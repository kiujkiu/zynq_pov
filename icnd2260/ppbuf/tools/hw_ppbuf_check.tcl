# hw_ppbuf_check.tcl -- program the ppbuf bit and run the step-1 acceptance sequence over VIO.
#   1) baseline 10 s at 9,045 fps: expect fps=9045, under/over/drop/stale=0, mismatch=0, cmp growing
#   2) inject slow writer (wr_stall=40 -> fill ~151 us > 110.6 us slot): underrun MUST grow
#   3) restore: underrun stops growing (self-heal, no reset)
#   4) tick_period=12000 (< one frame 14,632): overrun/drop MUST grow
#   5) restore
# args: [build_dir] [name]      ASCII-only (Vivado on Windows reads .tcl as GBK).
set BD   "ppbuf/build_pp_div6"
set NAME "icnd2260_ppbuf_div6"
if {[llength $argv] > 0} { set BD   [lindex $argv 0] }
if {[llength $argv] > 1} { set NAME [lindex $argv 1] }
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
proc IV {v n} { return [expr 0x[get_property INPUT_VALUE [PX $v $n]]] }
set CLR 0
proc clr {v} { global CLR ; set CLR [expr {1-$CLR}] ; setp $v g_dbg.o_stats_clr $CLR }
proc snap {v tag secs} {
    after [expr {$secs*1000}]
    refresh_hw_vio $v
    set uo [IV $v cnt_under_over] ; set ds [IV $v cnt_drop_stale]
    puts [format "=== %-28s fps=%-6d under=%-5d over=%-5d drop=%-5d stale=%-5d fills=%-8d mismatch=%-8d cmp=%-10d status=0x%04X" \
        $tag [IV $v fps_latched] [expr {$uo>>16}] [expr {$uo&0xFFFF}] [expr {$ds>>16}] [expr {$ds&0xFFFF}] \
        [IV $v fill_cnt] [IV $v mismatch_cnt] [IV $v cmp_cnt] [IV $v g_dbg.status]]
}
puts "=== ppbuf step-1 acceptance on $NAME ==="
setp $v dbg_pat_mode 0 ; setp $v dbg_pat_lvl 0FFF ; setp $v dbg_wr_stall 0009
after 3000 ; clr $v
snap $v "1) baseline 9045fps"   10
setp $v dbg_wr_stall 0028
snap $v "2) slow writer (stall 40)" 5
setp $v dbg_wr_stall 0009
after 1000 ; clr $v
snap $v "3) restored"            5
setp $v dbg_tick_period 002EE0
snap $v "4) tick 12000 < frame"  5
setp $v dbg_tick_period 0047FA
after 1000 ; clr $v
snap $v "5) restored"            5
puts "=== PASS criteria: (1)(3)(5) all counters 0 and mismatch 0; (2) under>0; (4) over>0 ==="
