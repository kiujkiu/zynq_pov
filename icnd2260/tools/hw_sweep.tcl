# Sweep CHKSUM variants (and optionally P/N polarity) and report with guards.
# ASCII-only on purpose (Vivado on Windows reads .tcl as GBK).
#
# Hardening learned the hard way on 2026-09-01:
#  * probe names are NOT uniform -> exact match first, then suffix
#  * read every counter TWICE and compare -> a torn JTAG capture will not repeat
#  * enforce the ceiling: replies/s can never exceed questions/s = fps/16
#  * print ABSOLUTE values, not just deltas
set B "D:/claude_workspace/pov3d/zynq_pov/icnd2260/build_dbg"
set NAME "icnd2260_lvds_dbg_div48"
set PNLIST 0
set MODELIST {1 0 3 2}
# args are comma-separated so cmd.exe quoting cannot mangle them:
#   -tclargs 1:5:9:D  0:1:2:3   (comma is an ARG SEPARATOR in cmd.exe -- do not use it)
if {[llength $argv] > 0} { set MODELIST [split [lindex $argv 0] ":"] }
if {[llength $argv] > 1} { set PNLIST   [split [lindex $argv 1] ":"] }

open_hw_manager
connect_hw_server -allow_non_jtag
current_hw_target [lindex [get_hw_targets */Digilent/*] 0]
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
set dev [current_hw_device]
set_property PROBES.FILE      "$B/$NAME.ltx" $dev
set_property FULL_PROBES.FILE "$B/$NAME.ltx" $dev
refresh_hw_device $dev
# chaining two vivado batch runs can race the previous hw_server shutdown ->
# get_hw_vios comes back empty and every PX returns "" ("Invalid option value ''").
set v ""
for {set try 0} {$try < 5} {incr try} {
    set vios [get_hw_vios]
    if {[llength $vios] > 0} { set v [lindex $vios 0] ; break }
    puts "=== no VIO yet, refreshing (try $try) ==="
    after 1000 ; refresh_hw_device $dev
}
if {$v eq ""} { puts "=== ABORT: no VIO core found -- is the right bit loaded? ===" ; exit 1 }

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
proc snap {v} {
    refresh_hw_vio $v
    set a [list [IV $v frame_cnt] [IV $v ack_frame_cnt] [IV $v ack_err_cnt] [IV $v ack_f_nbits] [IV $v ack_f_data0] [IV $v g_dbg.status]]
    after 250
    refresh_hw_vio $v
    set b [list [IV $v frame_cnt] [IV $v ack_frame_cnt] [IV $v ack_err_cnt] [IV $v ack_f_nbits] [IV $v ack_f_data0] [IV $v g_dbg.status]]
    set tear 0
    foreach i {1 2 3 4 5} { if {[lindex $a $i] != [lindex $b $i]} { set tear 1 } }
    return [list $b $tear]
}

puts "=== sweep: MODELIST={$MODELIST}  PNLIST={$PNLIST} ==="
puts "=== dwell 3s per point; questions = fps/16 = ~10/s => ceiling 30 replies per point ==="
puts "=== WATCH THE PANEL -- any light at all is the real criterion ==="
foreach pn $PNLIST {
  foreach m $MODELIST {
    # list entries are HEX digits ("D" etc) -> scan to int before any bit math,
    # and format back to hex for OUTPUT_VALUE. [format %X D] throws.
    set mv 0 ; scan $m  %x mv
    set pv 0 ; scan $pn %x pv
    setp $v dbg_pn_inv        [format %X $pv]
    setp $v g_dbg.o_crc_mode  [format %X $mv]
    setp $v g_dbg.o_soft_rst  1 ; after 300
    setp $v g_dbg.o_soft_rst  0 ; after 2000
    set s0 [snap $v] ; set a0 [lindex $s0 0]
    after 3000
    set s1 [snap $v] ; set a1 [lindex $s1 0] ; set tear [expr [lindex $s0 1] || [lindex $s1 1]]
    set dfr  [expr [lindex $a1 0]-[lindex $a0 0]]
    set dcnt [expr [lindex $a1 1]-[lindex $a0 1]]
    set derr [expr [lindex $a1 2]-[lindex $a0 2]]
    set sticky [expr ([lindex $a1 5] >> 10) & 1]
    set flag ""
    if {$tear}      { set flag "$flag TORN-READ" }
    if {$dcnt > 30} { set flag "$flag RATE-OVER-CEILING(bogus)" }
    if {$dcnt == $derr && $dcnt != 0} { set flag "$flag CNT-EQ-ERR(bogus)" }
    if {$dcnt < 0 || $derr < 0}       { set flag "$flag WRAP" }
    if {$flag eq "" && ($dcnt > 0 || $sticky)} { set flag " <<<< CANDIDATE" }
    puts [format "===  pn=%X crc=%X (refl=%d lsbtx=%d vhcopy=%d ckfree=%d) | frames+%-5d ack_cnt+%-4d err+%-6d nbits=%-4d data0=0x%04x sticky=%d%s" \
        $pv $mv [expr $mv & 1] [expr ($mv>>1)&1] [expr ($mv>>2)&1] [expr ($mv>>3)&1] $dfr $dcnt $derr [lindex $a1 3] [lindex $a1 4] $sticky $flag]
  }
}
setp $v g_dbg.o_crc_mode 0
setp $v dbg_pn_inv 0
setp $v g_dbg.o_soft_rst 1 ; after 2000
setp $v g_dbg.o_soft_rst 0
puts "=== restored crc_mode=0 (vendor-capture-confirmed) pn_inv=0 ==="
close_hw_target
exit 0
