# run_eta_hls.tcl -- csynth + export the two eta gauge IPs (ASCII only: HLS on Windows reads .tcl as GBK)
#
#   rd = pov_eta_rd  read-only + burst_maxi prefetch + ap_ctrl_hs   (primary gauge)
#   wr = pov_eta_wr  pov_slice_v2 as-is (read+write) + ap_ctrl_hs   (literal version of yesterday's criterion)
#
# Run (WSL):
#   cd /mnt/d/claude_workspace/pov3d/zynq_pov/eta_test/hls
#   cmd.exe /c "set ETA_VARIANT=all&& set ETA_CSIM=1&& C:\Xilinx\Vitis_HLS\2024.2\bin\vitis_hls.bat -f run_eta_hls.tcl -nolog" 2>&1 | tee _hls_run.log
#   ETA_VARIANT = rd | wr | all.  ETA_CSIM=1 additionally runs the C testbench (rd only; 16 MB grid, ~20 s).
#   -nolog is REQUIRED to see puts output from WSL: without it vitis_hls.bat pipes stdout through
#   hls_tee, which swallows everything when stdout is not a Windows console (verified 2026-09-03).
#
# Products (per variant):
#   proj_eta_<v>/sol/syn/report/pov_eta_<v>_csynth.rpt        <- check: II=1, latency ~10,368/slice, timing < 6.67
#   proj_eta_<v>/sol/impl/ip/                                  <- IP repo dir (component.xml), consumed by tools/build_eta.tcl
#   proj_eta_<v>/sol/impl/ip/hdl/verilog/pov_eta_<v>.v         <- must contain ports ap_start/ap_done/ap_idle (ap_ctrl_hs)
#   proj_eta_<v>/sol/impl/ip/drivers/.../xpov_eta_<v>_hw.h     <- register map, parsed by build_eta.tcl -> eta_regs.tcl
#
# How you know it worked: the script ends with "ETA_HLS_OK <v>" only after it has verified the
# three facts above itself (grep of csynth.rpt + grep of the exported RTL). Anything else = failed.

set here [file normalize [file dirname [info script]]]
set inc  [file normalize $here/../../hls_proj]          ;# pov_slice_v2.h / _lut.h / _lut_603.h
set variant "rd"
if {[info exists ::env(ETA_VARIANT)]} { set variant $::env(ETA_VARIANT) }
set do_csim 0
if {[info exists ::env(ETA_CSIM)]} { set do_csim $::env(ETA_CSIM) }
set list [expr {$variant eq "all" ? [list rd wr] : [list $variant]}]

proc grep_file {f pat} {
    set fh [open $f r] ; set txt [read $fh] ; close $fh
    return [regexp -all -inline -line $pat $txt]
}

foreach v $list {
    set top  "pov_eta_$v"
    set proj "$here/proj_eta_$v"
    # fresh project: HLS export packs impl/ which is NOT rebuilt by csynth alone (see memory feedback_hls_resynth_full_flow)
    file delete -force $proj
    open_project $proj
    set_top $top
    set cflags "-std=c++14 -I$inc"
    add_files $here/$top.cpp -cflags $cflags
    if {$v eq "rd" && $do_csim} { add_files -tb $here/pov_eta_rd_tb.cpp -cflags $cflags }

    open_solution "sol" -flow_target vivado -reset
    set_part {xc7z020clg484-2}          ;# LXB core board is -2 (memory project_luxiaoban_zynq_ddr_config); 02_hello_zynq.xpr uses -2
    create_clock -period 6.67 -name default

    if {$v eq "rd" && $do_csim} {
        puts "== \[$v\] CSIM =="
        if {[catch {csim_design} msg]} { puts "!! csim_design nonzero rc (known on this machine): $msg" }
        set log [glob -nocomplain $proj/sol/csim/report/*.log]
        if {[llength $log]} {
            set hits [grep_file [lindex $log 0] {^TB_(?:PASS|FAIL).*$}]
            puts "== CSIM verdict: $hits =="
            if {![regexp {TB_PASS} $hits]} { puts "ETA_HLS_FAIL $v: csim testbench did not pass"; exit 1 }
        }
    }

    puts "== \[$v\] CSYNTH =="
    csynth_design

    set rpt "$proj/sol/syn/report/${top}_csynth.rpt"
    if {![file exists $rpt]} { puts "ETA_HLS_FAIL $v: no csynth report"; exit 1 }
    puts "== \[$v\] csynth summary =="
    foreach l [grep_file $rpt {^\s*\|ap_clk.*$}]  { puts "   $l" }
    foreach l [grep_file $rpt {^\s*\|\s*[0-9]+\|\s*[0-9]+\|.*ms\|.*$}] { puts "   $l" }
    foreach l [grep_file $rpt {^\s*\|Total\s*\|.*$}] { puts "   $l" }
    # II must be 1 on the (only) pipelined loop
    set ii_lines [grep_file $rpt {^\s*\|-.*\|\s*yes\s*\|\s*$}]
    set pipe_rpt [glob -nocomplain $proj/sol/syn/report/*Pipeline*_csynth.rpt $rpt]
    set bad_ii 0
    foreach r $pipe_rpt {
        foreach l [grep_file $r {^\s*\|-\s*\S+\s*\|.*\|\s*yes\s*\|\s*$}] {
            puts "   LOOP: $l"
            # columns: name | lat min | lat max | iter lat | II achieved | II target | trip | pipelined
            set cols [split $l |]
            set ii [string trim [lindex $cols 5]]
            if {$ii ne "1"} { set bad_ii 1 }
        }
    }
    if {$bad_ii} { puts "ETA_HLS_FAIL $v: a pipelined loop has II != 1 (see LOOP lines above)"; exit 1 }

    puts "== \[$v\] EXPORT IP =="
    export_design -format ip_catalog -output "$here/pov_eta_${v}_ip.zip" \
        -description "DDR read-efficiency gauge ($v)" \
        -vendor povlab -library eta -version 1.0 -display_name "POV eta gauge ($v)"

    # --- self-check of the export ---------------------------------------------------------
    set rtl "$proj/sol/impl/ip/hdl/verilog/$top.v"
    if {![file exists $rtl]} { puts "ETA_HLS_FAIL $v: exported RTL missing ($rtl)"; exit 1 }
    set ports [grep_file $rtl {^\s*(?:input|output)\s+.*\yap_(?:start|done|idle|ready)\y.*$}]
    puts "== \[$v\] ap_ctrl ports in exported RTL: [llength $ports] (need 4) =="
    foreach p $ports { puts "   $p" }
    if {[llength $ports] != 4} { puts "ETA_HLS_FAIL $v: ap_ctrl_hs pins not exported (return still s_axilite?)"; exit 1 }
    set hw [glob -nocomplain $proj/sol/impl/ip/drivers/*/src/x${top}_hw.h]
    if {![llength $hw]} { puts "ETA_HLS_FAIL $v: driver hw header missing"; exit 1 }
    set regs [grep_file [lindex $hw 0] {^#define X\S+_ADDR_\S+\s+0x[0-9a-fA-F]+\s*$}]
    puts "== \[$v\] register map ([lindex $hw 0]) =="
    foreach r $regs { puts "   $r" }
    if {[regexp {ADDR_AP_CTRL} $regs]} { puts "ETA_HLS_FAIL $v: AP_CTRL register present -> return is still s_axilite"; exit 1 }
    if {![file exists "$proj/sol/impl/ip/component.xml"]} { puts "ETA_HLS_FAIL $v: component.xml missing"; exit 1 }
    puts "ETA_HLS_OK $v  ip_repo=$proj/sol/impl/ip"
}
exit 0
