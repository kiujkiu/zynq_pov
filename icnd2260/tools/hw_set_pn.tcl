# Report every VIO output, then force pn_inv back to 0 (original polarity).
# ASCII-only on purpose (Vivado on Windows reads .tcl as GBK).
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg_div48"
set PN 0
if {[llength $argv] > 0} { set PN [lindex $argv 0] }
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
# Probe naming is NOT uniform: some outputs keep the top-level net name
# (dbg_pn_inv), others carry the generate-block prefix (g_dbg.o_crc_mode).
# Match exact first, then any suffix -- same trick as hw_read_status.tcl.
proc PX {v want} {
    set best ""
    foreach p [get_hw_probes -of_objects $v] {
        set n [get_property NAME $p]
        if {$n eq $want} { return $p }
        if {[string match "*/$want" $n] || [string match "*.$want" $n]} { set best $p }
    }
    return $best }
refresh_hw_vio $v
puts "=== VIO outputs BEFORE ==="
foreach n {dbg_pn_inv g_dbg.o_crc_mode g_dbg.o_dclk_lvl g_dbg.o_minimal g_dbg.o_probe_en g_dbg.o_probe_dev g_dbg.o_soft_rst} {
    set p [PX $v $n]
    if {$p ne ""} { puts "===   $n = 0x[get_property OUTPUT_VALUE $p]" }
}
set p_pn [PX $v "dbg_pn_inv"]
set_property OUTPUT_VALUE [format %X $PN] $p_pn
commit_hw_vio $p_pn
# re-run the power-up sequence so the chips get the config at this polarity
set p_rst [PX $v "g_dbg.o_soft_rst"]
set_property OUTPUT_VALUE 1 $p_rst ; commit_hw_vio $p_rst
after 300
set_property OUTPUT_VALUE 0 $p_rst ; commit_hw_vio $p_rst
after 1500
refresh_hw_vio $v
puts "=== VIO outputs AFTER ==="
foreach n {dbg_pn_inv g_dbg.o_crc_mode g_dbg.o_dclk_lvl g_dbg.o_soft_rst} {
    set p [PX $v $n]
    if {$p ne ""} { puts "===   $n = 0x[get_property OUTPUT_VALUE $p]" }
}
set c0 [expr 0x[get_property INPUT_VALUE [PX $v "frame_cnt"]]]
set e0 [expr 0x[get_property INPUT_VALUE [PX $v "ack_err_cnt"]]]
after 2000
refresh_hw_vio $v
puts [format "===  fps=%d  frames/2s=%d  ack_err/2s=%d  ack_cnt=%d  status=0x%s" \
    [expr 0x[get_property INPUT_VALUE [PX $v "fps_latched"]]] \
    [expr [expr 0x[get_property INPUT_VALUE [PX $v "frame_cnt"]]] - $c0] \
    [expr [expr 0x[get_property INPUT_VALUE [PX $v "ack_err_cnt"]]] - $e0] \
    [expr 0x[get_property INPUT_VALUE [PX $v "ack_frame_cnt"]]] \
    [get_property INPUT_VALUE [PX $v "g_dbg.status"]]]
close_hw_target
exit 0
