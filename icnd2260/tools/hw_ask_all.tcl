# Ask every cascaded device for register 0x00, in both CHKSUM modes.
# Read command is inserted by the sequencer every READ_PROBE_FR=16 frames
# => ~10 questions/s at 160 fps. 2s dwell = ~20 questions per device.
# A reply can NEVER exceed the question rate -- if it does, the instrument lies.
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
set v [lindex [get_hw_vios] 0]
proc PX {v want} {
    set best ""
    foreach p [get_hw_probes -of_objects $v] {
        set n [get_property NAME $p]
        if {$n eq $want} { return $p }
        if {[string match "*/$want" $n] || [string match "*.$want" $n]} { set best $p }
    }
    return $best }
proc setp {p val} { set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p }
proc IV {v n} { return [expr 0x[get_property INPUT_VALUE [PX $v $n]]] }

setp [PX $v "g_dbg.o_probe_en"] 1
setp [PX $v "dbg_probe_off"]    00
puts "=== asking reg 0x00 of dev 0..8 ; expected reply data0 = 0x493c ==="
puts "=== upper bound on replies = fps/16 = ~10/s  (anything above = instrument fault) ==="
foreach mode {1 0} {
    setp [PX $v "g_dbg.o_crc_mode"] $mode
    setp [PX $v "g_dbg.o_soft_rst"] 1 ; after 300
    setp [PX $v "g_dbg.o_soft_rst"] 0 ; after 1500
    puts "=== ---- crc_mode=$mode ([expr {$mode==1 ? "manual LFSR 0x8408" : "old CCITT 0x1021"}]) ----"
    for {set d 0} {$d < 9} {incr d} {
        setp [PX $v "dbg_probe_dev"] [format %X $d]
        refresh_hw_vio $v
        set c0 [IV $v "ack_frame_cnt"] ; set e0 [IV $v "ack_err_cnt"]
        after 2000
        refresh_hw_vio $v
        puts [format "===   dev=%-2d  ack_cnt+%-4d err+%-5d nbits=%-4d data0=0x%04x sticky=%d" \
            $d [expr [IV $v "ack_frame_cnt"]-$c0] [expr [IV $v "ack_err_cnt"]-$e0] \
            [IV $v "ack_f_nbits"] [IV $v "ack_f_data0"] \
            [expr ([IV $v "g_dbg.status"] >> 10) & 1]]
    }
}
setp [PX $v "g_dbg.o_crc_mode"] 1
setp [PX $v "g_dbg.o_probe_en"] 0
setp [PX $v "g_dbg.o_soft_rst"] 1 ; after 300
setp [PX $v "g_dbg.o_soft_rst"] 0
puts "=== restored: crc_mode=1, probe_en=0, pn_inv untouched (0) ==="
close_hw_target
exit 0
