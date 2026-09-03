# build_eta.tcl -- DDR read-efficiency (eta) test bitstream for the LXB (luxiaoban) XC7Z020 board.
#
#   BD "eta":  PS7 (LXB DDR config copied from 02_hello_zynq) + 2x pov_eta_<v> HLS gauge IPs on
#              separate HP ports + eta_mon.v (start fan-out + cycle counters) + axi_gpio (ctrl/readout)
#              GP0 AXI-Lite: ip0 0x43C0_0000  ip1 0x43C1_0000  gpio 0x4120_0000
#              HP: ip0 vox->HP0, ip1 vox->HP2 (HP0/1 and HP2/3 share one DDRC port each, UG585 ch.10,
#                  so the two READ streams land on different DDRC ports); wr variant: out->HP1 / HP3
#              No PL pins at all (only PS DDR/FIXED_IO) -> no XDC needed.
#
# Run (WSL):
#   cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\eta_test && call C:\Xilinx\Vivado\2024.2\settings64.bat && vivado -mode batch -source tools\build_eta.tcl -tclargs rd" 2>&1 | tee build_eta_rd.log
#
# -tclargs <variant> [keywords]      variant = rd (read-only gauge, primary) | wr (as-is IP, read+write)
#   bdonly     stop after BD validate + generate_target (fast check of IP/BD wiring, ~3 min)
#   synthonly  stop after synth_design (resource/timing sanity, ~6 min)
#   f100       FCLK0 = 100 MHz instead of 150 (fallback if 150 does not close timing)
# NOTE: cmd.exe treats '=' and spaces as -tclargs delimiters -> keywords only, no key=value.
# NOTE: ASCII only in this file (Vivado on Windows reads .tcl as GBK).
#
# Prerequisite: hls/run_eta_hls.tcl has produced hls/proj_eta_<v>/sol/impl/ip (ETA_HLS_OK line).
#
# Products in build_eta_<v>/ :
#   eta_<v>.bit                       bitstream (load with xsdb 'fpga -file', NOT via JTAG program_hw_devices)
#   ps7_init.tcl                      PS init for xsdb (DDR!) -- self-checked against the golden hello_zynq one
#   eta_regs.tcl                      addresses + register offsets + FCLK Hz, parsed from the HLS driver header
#   eta_<v>.{timing,util,drc}.rpt
# How you know it worked: last line "=== BUILD_ETA_OK ..." AND "DDR_INIT_MATCH" printed earlier.
# The script exits non-zero (with a "BUILD_ETA_FAIL" line) on any self-check failure.

set variant "rd"
set BDONLY 0 ; set SYNTHONLY 0 ; set FCLK_MHZ 150
if {[llength $argv] > 0} { set variant [lindex $argv 0] }
foreach kw $argv {
    switch -- $kw {
        bdonly    { set BDONLY 1 }
        synthonly { set SYNTHONLY 1 }
        f100      { set FCLK_MHZ 100 }
    }
}
if {$variant ne "rd" && $variant ne "wr"} { puts "BUILD_ETA_FAIL: variant must be rd or wr, got '$variant'"; exit 1 }

set root   [file normalize [file dirname [info script]]/..]        ;# .../zynq_pov/eta_test
set zynq   [file normalize $root/..]                                ;# .../zynq_pov
set build  $root/build_eta_$variant
set iprepo $root/hls/proj_eta_$variant/sol/impl/ip
set golden $zynq/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl
set top    "pov_eta_$variant"
set PART   xc7z020clg484-2      ;# same as 02_hello_zynq.xpr (LXB core board is -2, memory project_luxiaoban_zynq_ddr_config)

proc fail {msg} { puts "BUILD_ETA_FAIL: $msg" ; exit 1 }

puts "=== build_eta: variant=$variant FCLK=${FCLK_MHZ}MHz part=$PART ==="
if {![file exists $iprepo/component.xml]} {
    fail "IP repo missing ($iprepo/component.xml). Run hls/run_eta_hls.tcl with ETA_VARIANT=$variant first."
}
if {![file exists $root/rtl/eta_mon.v]} { fail "rtl/eta_mon.v missing" }
file mkdir $build
cd $build

# --------------------------------------------------------------------------------------------
# Project + IP catalog
# --------------------------------------------------------------------------------------------
create_project -force eta_$variant $build/proj -part $PART
set_property target_language Verilog [current_project]
set_property ip_repo_paths [list $iprepo] [current_project]
update_ip_catalog -rebuild
set defs [get_ipdefs -quiet -filter "NAME == $top"]
if {[llength $defs] == 0} { fail "IP $top not found in catalog after update_ip_catalog (repo=$iprepo)" }
set VLNV [get_property VLNV [lindex $defs 0]]
puts "=== IP in catalog: $VLNV ==="
add_files -norecurse $root/rtl/eta_mon.v
update_compile_order -fileset sources_1

# --------------------------------------------------------------------------------------------
# Block design
# --------------------------------------------------------------------------------------------
create_bd_design eta

# ---- PS7: DDR/clock config copied from 02_hello_zynq (hello_zynq.bd, proven on LXB) ----
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "0" Master "Disable" Slave "Disable"} $ps
set_property -dict [list \
    CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V} \
    CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 3.3V} \
    CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ {33.333333} \
    CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {666.666666} \
    CONFIG.PCW_UIPARAM_DDR_ENABLE {1} \
    CONFIG.PCW_UIPARAM_DDR_MEMORY_TYPE {DDR 3} \
    CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41J256M16 RE-125} \
    CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {16 Bit} \
    CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ {533.333333} \
    CONFIG.PCW_UIPARAM_DDR_ECC {Disabled} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1} \
    CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF {0} \
    CONFIG.PCW_UIPARAM_DDR_ADV_ENABLE {0} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_M_AXI_GP1 {0} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP1 {1} \
    CONFIG.PCW_USE_S_AXI_HP2 {1} \
    CONFIG.PCW_USE_S_AXI_HP3 {1} \
    CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
    CONFIG.PCW_S_AXI_HP1_DATA_WIDTH {64} \
    CONFIG.PCW_S_AXI_HP2_DATA_WIDTH {64} \
    CONFIG.PCW_S_AXI_HP3_DATA_WIDTH {64} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_EN_CLK1_PORT {0} \
    CONFIG.PCW_EN_CLK2_PORT {0} \
    CONFIG.PCW_EN_CLK3_PORT {0} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $FCLK_MHZ \
    CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_UART0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_USB0_PERIPHERAL_ENABLE {0} \
] $ps
# read back what matters (a rejected/ignored property would otherwise fail silently on the board)
set FCLK_HZ_WANT [expr {$FCLK_MHZ * 1000000}]
foreach {k want} [list \
    PCW_UIPARAM_DDR_BUS_WIDTH   {16 Bit} \
    PCW_UIPARAM_DDR_PARTNO      {MT41J256M16 RE-125} \
    PCW_UIPARAM_DDR_MEMORY_TYPE {DDR 3} \
    PCW_UIPARAM_DDR_FREQ_MHZ    {533.333333} \
    PCW_USE_S_AXI_HP0 1  PCW_USE_S_AXI_HP1 1  PCW_USE_S_AXI_HP2 1  PCW_USE_S_AXI_HP3 1 \
    PCW_USE_M_AXI_GP0 1 \
    PCW_CLK0_FREQ $FCLK_HZ_WANT \
] {
    set got [get_property CONFIG.$k $ps]
    puts [format "   PS7 %-32s = %s" $k $got]
    if {$got ne $want} { fail "PS7 CONFIG.$k readback '$got' != wanted '$want'" }
}
set FCLK_HZ [get_property CONFIG.PCW_CLK0_FREQ $ps]
puts "   PS7 PCW_UIPARAM_ACT_DDR_FREQ_MHZ = [get_property CONFIG.PCW_UIPARAM_ACT_DDR_FREQ_MHZ $ps]"

# ---- infrastructure ----
set rst  [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst]
set scgp [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_gp0]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {3}] $scgp
set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gpio]
set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_GPIO_WIDTH {32} \
                         CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO2_WIDTH {32} CONFIG.C_DOUT_DEFAULT {0x00000000}] $gpio
set mon  [create_bd_cell -type module -reference eta_mon mon]

# ---- the two gauge IPs, each on its own HP port(s) ----
set clk_pins [list $ps/M_AXI_GP0_ACLK $ps/S_AXI_HP0_ACLK $ps/S_AXI_HP1_ACLK $ps/S_AXI_HP2_ACLK $ps/S_AXI_HP3_ACLK \
                   rst/slowest_sync_clk sc_gp0/aclk gpio/s_axi_aclk mon/clk]
set rst_pins [list sc_gp0/aresetn gpio/s_axi_aresetn mon/rstn]
set hp_rd  {0 2}
set hp_wr  {1 3}
foreach i {0 1} {
    set ip [create_bd_cell -type ip -vlnv $VLNV ip$i]
    puts "=== ip$i interfaces: [get_bd_intf_pins -quiet ip$i/*] ==="
    puts "=== ip$i ap pins   : [get_bd_pins -quiet ip$i/ap_*] ==="
    foreach p {ap_start ap_done ap_idle ap_ready ap_clk ap_rst_n} {
        if {[llength [get_bd_pins -quiet ip$i/$p]] != 1} { fail "ip$i has no pin $p (return not ap_ctrl_hs?)" }
    }
    lappend clk_pins ip$i/ap_clk
    lappend rst_pins ip$i/ap_rst_n
    # read stream -> HP0 / HP2
    set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_rd$i]
    set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $sc
    set vox [get_bd_intf_pins -quiet ip$i/m_axi_vox]
    if {[llength $vox] != 1} { fail "ip$i/m_axi_vox interface not found" }
    connect_bd_intf_net $vox [get_bd_intf_pins sc_rd$i/S00_AXI]
    connect_bd_intf_net [get_bd_intf_pins sc_rd$i/M00_AXI] [get_bd_intf_pins $ps/S_AXI_HP[lindex $hp_rd $i]]
    lappend clk_pins sc_rd$i/aclk ; lappend rst_pins sc_rd$i/aresetn
    if {$variant eq "wr"} {
        set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_wr$i]
        set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $sc
        set outp [get_bd_intf_pins -quiet ip$i/m_axi_out_r]
        if {[llength $outp] != 1} { fail "ip$i/m_axi_out_r interface not found" }
        connect_bd_intf_net $outp [get_bd_intf_pins sc_wr$i/S00_AXI]
        connect_bd_intf_net [get_bd_intf_pins sc_wr$i/M00_AXI] [get_bd_intf_pins $ps/S_AXI_HP[lindex $hp_wr $i]]
        lappend clk_pins sc_wr$i/aclk ; lappend rst_pins sc_wr$i/aresetn
    }
    # control
    connect_bd_intf_net [get_bd_intf_pins sc_gp0/M0${i}_AXI] [get_bd_intf_pins ip$i/s_axi_control]
    # monitor / start
    connect_bd_net [get_bd_pins ip$i/ap_done]  [get_bd_pins mon/done$i]
    connect_bd_net [get_bd_pins ip$i/ap_idle]  [get_bd_pins mon/idle$i]
    connect_bd_net [get_bd_pins ip$i/ap_ready] [get_bd_pins mon/ready$i]
    connect_bd_net [get_bd_pins mon/start$i]   [get_bd_pins ip$i/ap_start]
}
connect_bd_intf_net [get_bd_intf_pins $ps/M_AXI_GP0]   [get_bd_intf_pins sc_gp0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins sc_gp0/M02_AXI]  [get_bd_intf_pins gpio/S_AXI]
connect_bd_net [get_bd_pins gpio/gpio_io_o]  [get_bd_pins mon/ctrl]
connect_bd_net [get_bd_pins mon/dout]        [get_bd_pins gpio/gpio2_io_i]

# ---- clocks / resets: everything on FCLK_CLK0 ----
foreach p $clk_pins { connect_bd_net [get_bd_pins $ps/FCLK_CLK0] [get_bd_pins $p] }
connect_bd_net [get_bd_pins $ps/FCLK_RESET0_N] [get_bd_pins rst/ext_reset_in]
foreach p $rst_pins { connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_pins $p] }

# ---- addresses ----
set IP0_BASE 0x43C00000 ; set IP1_BASE 0x43C10000 ; set GPIO_BASE 0x41200000
assign_bd_address -offset $IP0_BASE  -range 64K -target_address_space [get_bd_addr_spaces $ps/Data] [get_bd_addr_segs ip0/s_axi_control/Reg]
assign_bd_address -offset $IP1_BASE  -range 64K -target_address_space [get_bd_addr_spaces $ps/Data] [get_bd_addr_segs ip1/s_axi_control/Reg]
assign_bd_address -offset $GPIO_BASE -range 64K -target_address_space [get_bd_addr_spaces $ps/Data] [get_bd_addr_segs gpio/S_AXI/Reg]
foreach i {0 1} {
    set sp [get_bd_addr_spaces -quiet ip$i/Data_m_axi_vox]
    if {[llength $sp] != 1} { fail "address space ip$i/Data_m_axi_vox not found: [get_bd_addr_spaces ip$i/*]" }
    assign_bd_address -offset 0x00000000 -range 512M -target_address_space $sp \
        [get_bd_addr_segs $ps/S_AXI_HP[lindex $hp_rd $i]/HP[lindex $hp_rd $i]_DDR_LOWOCM]
    if {$variant eq "wr"} {
        set sp [get_bd_addr_spaces -quiet ip$i/Data_m_axi_out_r]
        if {[llength $sp] != 1} { fail "address space ip$i/Data_m_axi_out_r not found" }
        assign_bd_address -offset 0x00000000 -range 512M -target_address_space $sp \
            [get_bd_addr_segs $ps/S_AXI_HP[lindex $hp_wr $i]/HP[lindex $hp_wr $i]_DDR_LOWOCM]
    }
}
puts "=== address map ==="
foreach s [get_bd_addr_segs -excluded -quiet] { puts "   EXCLUDED $s" }
foreach s [get_bd_addr_segs] { puts [format "   %-45s off=%-12s range=%s" $s [get_property OFFSET $s] [get_property RANGE $s]] }
foreach {n want} [list SEG_ip0_Reg $IP0_BASE SEG_ip1_Reg $IP1_BASE SEG_gpio_Reg $GPIO_BASE] {
    set seg [get_bd_addr_segs -quiet $ps/Data/$n]
    if {[llength $seg] != 1} { fail "segment $ps/Data/$n missing" }
    set off [get_property OFFSET $seg]
    if {[expr {$off}] != [expr {$want}]} { fail "segment $n offset $off != $want" }
}

validate_bd_design
save_bd_design
set_property synth_checkpoint_mode None [get_files eta.bd]     ;# global synthesis: lets in-process synth_design see IP RTL
generate_target all [get_files eta.bd]

# ---- ps7_init.tcl: copy + compare DDR block with the golden LXB one ----
set psinit [glob -nocomplain $build/proj/eta_${variant}.gen/sources_1/bd/eta/ip/eta_ps7_0/ps7_init.tcl]
if {[llength $psinit] != 1} { set psinit [glob -nocomplain $build/proj/*/sources_1/bd/eta/ip/*ps7*/ps7_init.tcl] }
if {[llength $psinit] != 1} { fail "ps7_init.tcl not generated (looked under $build/proj/*/sources_1/bd/eta/ip/*ps7*/)" }
set psinit [lindex $psinit 0]
file copy -force $psinit $build/ps7_init.tcl
proc block_lines {file procname} {
    set fh [open $file r] ; set lines [split [read $fh] \n] ; close $fh
    set out {} ; set in 0
    foreach l $lines {
        if {[regexp "^proc $procname " $l]} { set in 1 ; continue }
        if {$in && [regexp {^\}} $l]} { break }
        if {$in} { lappend out [string trim $l] }
    }
    return $out
}
proc compare_block {tag mine gold} {
    set a [block_lines $mine $tag] ; set b [block_lines $gold $tag]
    if {[llength $a] == 0} { puts "   $tag: NOT FOUND in new ps7_init"; return 0 }
    if {[llength $b] == 0} { puts "   $tag: golden file has no such block, skipping"; return 1 }
    set same 1
    if {[llength $a] != [llength $b]} { set same 0 }
    for {set i 0} {$i < [llength $a] && $i < [llength $b]} {incr i} {
        if {[lindex $a $i] ne [lindex $b $i]} { set same 0 ; puts "   $tag diff line $i:\n      new : [lindex $a $i]\n      gold: [lindex $b $i]" }
    }
    puts "   $tag: [expr {$same ? {MATCH} : {DIFFERENT}}] ([llength $a] vs [llength $b] lines)"
    return $same
}
set ddr_ok 1
if {[file exists $golden]} {
    puts "=== ps7_init self-check vs golden $golden ==="
    foreach blk {ps7_ddr_init_data_3_0 ps7_ddr_init_data_2_0 ps7_ddr_init_data_1_0} {
        if {![compare_block $blk $psinit $golden]} { set ddr_ok 0 }
    }
    # DDRIOB (0xF8000B40..B70) lives in the mio block; only those lines are DDR-relevant
    set mA [lsearch -all -inline -regexp [block_lines $psinit ps7_mio_init_data_3_0] {0XF8000B[4-7]}]
    set mB [lsearch -all -inline -regexp [block_lines $golden ps7_mio_init_data_3_0] {0XF8000B[4-7]}]
    puts "   DDRIOB lines: [expr {$mA eq $mB ? {MATCH} : {DIFFERENT}}] ([llength $mA] vs [llength $mB])"
    if {$mA ne $mB} { set ddr_ok 0 ; foreach l $mA { puts "      new : $l" } ; foreach l $mB { puts "      gold: $l" } }
    compare_block ps7_pll_init_data_3_0 $psinit $golden      ;# informational: IO PLL differs when FCLK set differs
    puts [expr {$ddr_ok ? "DDR_INIT_MATCH" : "DDR_INIT_MISMATCH (do not trust DDR on the board until understood)"}]
} else {
    puts "=== golden ps7_init not found at $golden -- DDR block NOT verified ==="
    set ddr_ok 0
}

# ---- eta_regs.tcl: everything run_eta.tcl needs, parsed rather than hand-copied ----
set hw [glob -nocomplain $iprepo/drivers/*/src/x${top}_hw.h]
if {[llength $hw] != 1} { fail "driver header x${top}_hw.h not found under $iprepo/drivers" }
set fh [open [lindex $hw 0] r] ; set hwtxt [read $fh] ; close $fh
set rf [open $build/eta_regs.tcl w]
puts $rf "# generated by build_eta.tcl -- do not edit"
puts $rf "set ETA(variant) $variant"
puts $rf "set ETA(bit)     [file normalize $build/eta_$variant.bit]"
puts $rf "set ETA(psinit)  [file normalize $build/ps7_init.tcl]"
puts $rf "set ETA(fclk_hz) $FCLK_HZ"
puts $rf "set ETA(ip0)     $IP0_BASE"
puts $rf "set ETA(ip1)     $IP1_BASE"
puts $rf "set ETA(gpio)    $GPIO_BASE"
puts $rf "set ETA(ddr_init_match) $ddr_ok"
set nreg 0
foreach {line name off} [regexp -all -inline -line {^#define X\w+_CONTROL_ADDR_(\w+)_DATA\s+(0x[0-9A-Fa-f]+)\s*$} $hwtxt] {
    puts $rf "set REG($name) $off" ; incr nreg
}
close $rf
puts "=== eta_regs.tcl: $nreg registers ==="
puts [exec cmd /c type [file nativename $build/eta_regs.tcl]]
foreach need {VOXEL PHASE N_SLOTS} { if {![regexp "REG\\($need\\)" [exec cmd /c type [file nativename $build/eta_regs.tcl]]]} { fail "register $need missing from hw header" } }

if {$BDONLY} { puts "=== BUILD_ETA_OK (bdonly): BD validated, ps7_init + eta_regs written to $build ===" ; exit 0 }

# --------------------------------------------------------------------------------------------
# Synthesis / implementation, in-process (launch_runs cannot spawn in batch mode here, memory feedback_hls_resynth_full_flow)
# --------------------------------------------------------------------------------------------
set wrapper [make_wrapper -files [get_files eta.bd] -top -force]
add_files -norecurse $wrapper
set_property top eta_wrapper [current_fileset]
update_compile_order -fileset sources_1

synth_design -top eta_wrapper -part $PART
set name eta_$variant
report_utilization -file $build/$name.synth_util.rpt
if {$SYNTHONLY} { puts "=== BUILD_ETA_OK (synthonly) -> $build/$name.synth_util.rpt ===" ; exit 0 }

opt_design
place_design
route_design
report_utilization    -file $build/$name.util.rpt
report_timing_summary -file $build/$name.timing.rpt
report_drc            -file $build/$name.drc.rpt
write_bitstream -force $build/$name.bit

set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "=== BUILD_ETA_OK variant=$variant FCLK=${FCLK_HZ}Hz WNS=$wns WHS=$whs ddr_init_match=$ddr_ok -> $build/$name.bit ==="
if {$wns < 0 || $whs < 0} { puts "=== TIMING FAIL: do not use this bit (try -tclargs $variant f100) ===" ; exit 1 }
exit 0
