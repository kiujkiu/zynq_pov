# Poke register values over VIO and re-run the power-up sequence each time.
# reg_rom is RAM ($readmemh only gives the initial value); soft_rst does NOT
# clear it, so pokes accumulate until the device is re-programmed.
# ASCII-only on purpose (Vivado on Windows reads .tcl as GBK).
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg_div48"
open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROBES.FILE      "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE "$B/$NAME.ltx" $dev
refresh_hw_device $dev
set v ""
for {set t 0} {$t < 5} {incr t} {
    set vs [get_hw_vios]
    if {[llength $vs] > 0} { set v [lindex $vs 0] ; break }
    after 1000 ; refresh_hw_device $dev
}
if {$v eq ""} { puts "=== ABORT: no VIO ===" ; exit 1 }

proc PX {v want} {
    set best ""
    foreach p [get_hw_probes -of_objects $v] {
        set n [get_property NAME $p]
        if {$n eq $want} { return $p }
        if {[string match "*/$want" $n] || [string match "*.$want" $n]} { set best $p }
    }
    return $best }
proc setp {v n val} { set p [PX $v $n] ; set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 120  }
proc IV {v n} { return [expr 0x[get_property INPUT_VALUE [PX $v $n]]] }
set WE 0
proc poke {v addr data} {
    global WE
    setp $v dbg_reg_addr $addr
    setp $v dbg_reg_data $data
    set WE [expr {1-$WE}] ; setp $v g_dbg.o_we_tog $WE
    puts "===   poke reg\[0x$addr\] = 0x$data"
}
proc cycle {v tag} {
    setp $v g_dbg.o_soft_rst 1 ; after 2000
    setp $v g_dbg.o_soft_rst 0 ; after 2000
    refresh_hw_vio $v
    set c0 [IV $v frame_cnt] ; set e0 [IV $v ack_err_cnt] ; set a0 [IV $v ack_frame_cnt]
    after 6000
    refresh_hw_vio $v
    puts [format "===  %-34s frames/6s=%-7d ack_cnt+%-4d err+%-6d sticky=%d  status=0x%s" \
        $tag [expr [IV $v frame_cnt]-$c0] [expr [IV $v ack_frame_cnt]-$a0] \
        [expr [IV $v ack_err_cnt]-$e0] [expr ([IV $v g_dbg.status]>>10)&1] \
        [get_property INPUT_VALUE [PX $v g_dbg.status]]]
}

puts "=== WATCH THE PANEL. 5 steps, 6s each, changes accumulate. ==="
cycle $v "1) baseline (no poke)"
poke  $v 15 0007
cycle $v "2) 0x15\[5\]=0  (no short-detect-enh)"
poke  $v 00 0F3C
cycle $v "3) + 0x00 refresh groups 74->16"
poke  $v 03 0042
cycle $v "4) + 0x03 Line_len 52->66"
poke  $v 01 0010
cycle $v "5) + 0x01 refresh mult 32->16"
puts "=== done. re-program the device to restore the original table. ==="
close_hw_target
exit 0
