# Dump every ACK field repeatedly. ASCII-only (Vivado on Windows reads .tcl as GBK).
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
proc IV {v n} { return [expr 0x[get_property INPUT_VALUE [PX $v $n]]] }
puts "=== ACK detail. legal reply = 56 bits, ACK\[3:0\]=0b0010, reply rate ceiling = fps/16 = ~10/s ==="
for {set i 0} {$i < 12} {incr i} {
    refresh_hw_vio $v
    puts [format "===  t=%2d  nbits=%-4d ack=0x%X dev=0x%X off=0x%02X len=%-3d data0=0x%04X | cnt=%-5d err=%-6d sticky=%d" \
        $i [IV $v ack_f_nbits] [IV $v ack_f_ack] [IV $v ack_f_dev] [IV $v ack_f_off] \
        [IV $v ack_f_len] [IV $v ack_f_data0] [IV $v ack_frame_cnt] [IV $v ack_err_cnt] \
        [expr ([IV $v g_dbg.status]>>10)&1]]
    after 700
}
close_hw_target
exit 0
