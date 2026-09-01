# A/B: flip the CHKSUM algorithm at runtime and see if ack_err follows.
# ASCII-only on purpose (Vivado on Windows reads .tcl as GBK).
# crc_mode[0] = refl : 1 = manual LFSR (0x8408 reflected)  0 = old CCITT-FALSE
# crc_mode[1] = lsb_tx
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
    foreach p [get_hw_probes -of_objects $v] {
        if {[get_property NAME $p] eq $want} { return $p } }
    return "" }
set p_fps  [PX $v "fps_latched"]
set p_fc   [PX $v "frame_cnt"]
set p_st   [PX $v "g_dbg.status"]
set p_cnt  [PX $v "ack_frame_cnt"]
set p_err  [PX $v "ack_err_cnt"]
set p_nb   [PX $v "ack_f_nbits"]
set p_mode [PX $v "g_dbg.o_crc_mode"]
set p_rst  [PX $v "g_dbg.o_soft_rst"]

proc setp {p val} { set_property OUTPUT_VALUE $val $p ; commit_hw_vio $p ; after 120  }
proc samp {v tag p_fps p_fc p_st p_cnt p_err p_nb} {
    set a [expr 0x[get_property INPUT_VALUE $p_err]]
    set c0 [expr 0x[get_property INPUT_VALUE $p_fc]]
    after 2000
    refresh_hw_vio $v
    set b [expr 0x[get_property INPUT_VALUE $p_err]]
    set c1 [expr 0x[get_property INPUT_VALUE $p_fc]]
    puts [format "===  %-22s fps=%-5d frames/2s=%-6d ack_err/2s=%-7d ack_cnt=%-5d nbits=%-4d status=0x%s" \
        $tag [expr 0x[get_property INPUT_VALUE $p_fps]] [expr $c1-$c0] [expr $b-$a] \
        [expr 0x[get_property INPUT_VALUE $p_cnt]] [expr 0x[get_property INPUT_VALUE $p_nb]] \
        [get_property INPUT_VALUE $p_st]]
}
proc cyc {v p_rst p_mode m} {
    setp $p_mode $m ; setp $p_rst 1 ; after 300 ; setp $p_rst 0 ; after 1500
    refresh_hw_vio $v }

puts "=== A/B: CHKSUM algorithm, single variable, everything else identical ==="
cyc $v $p_rst $p_mode 1 ; samp $v "refl=1 (manual LFSR)" $p_fps $p_fc $p_st $p_cnt $p_err $p_nb
cyc $v $p_rst $p_mode 0 ; samp $v "refl=0 (old CCITT)"   $p_fps $p_fc $p_st $p_cnt $p_err $p_nb
cyc $v $p_rst $p_mode 1 ; samp $v "refl=1 (back again)"  $p_fps $p_fc $p_st $p_cnt $p_err $p_nb
cyc $v $p_rst $p_mode 0 ; samp $v "refl=0 (back again)"  $p_fps $p_fc $p_st $p_cnt $p_err $p_nb
cyc $v $p_rst $p_mode 3 ; samp $v "refl=1 lsb_tx=1"      $p_fps $p_fc $p_st $p_cnt $p_err $p_nb
cyc $v $p_rst $p_mode 1 ; samp $v "refl=1 (left here)"   $p_fps $p_fc $p_st $p_cnt $p_err $p_nb
close_hw_target
exit 0
