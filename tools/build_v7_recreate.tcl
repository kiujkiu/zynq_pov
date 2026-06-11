###############################################################################
# build_v7_recreate.tcl  (DRAFT 2026-06-11, 人工 review 后再跑)
#
# v7 BD recreate: hub75e_panel_seq_v6 -> v7 (1-bit compact frame, DMA 8KB/slice)
#   - 前提: hub75e_panel_seq_v7.v 已在 imports/hdl/ (module hub75e_panel_seq_v7)
#   - 删旧 cell + IP cache (memory: feedback_vivado_bd_addr_width_cache.md,
#     module_ref 改动唯一可靠 fix = rename + 删 cache + recreate)
#   - recreate module_ref v7, 重连 s_axi 原路径 + 全部 hub75e_* 外部 port
#   - v7 差异 vs v6 脚本:
#       * HP2 不再强开 (v6 已开, 只 sanity check)
#       * axi_smc_hp2 已存在时跳过创建 (get_bd_cells -quiet 判断), 只重连 S00_AXI
#       * PCW_FPGA1_PERIPHERAL_FREQMHZ 只 puts 当前值不强改 (运行时 SLCR 提速)
#   - assign_bd_address: s_axi reg0 @ 0x40020000 range 128K;
#     m_axi 看到 HP2_DDR_LOWOCM 全段
#
# 跑法 (memory: vivado batch 必须先 settings64, 间歇性 Spawn failed, GUI 最稳):
#   GUI Tcl console:  cd D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq
#                     source ../tools/build_v7_recreate.tcl
###############################################################################

# 若在 GUI 已开 project, 注释掉这行
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]

#------------------------------------------------------------------------------
# 0. 确认 v7 源文件在 fileset 里
#------------------------------------------------------------------------------
set src_hub75e "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq_v7.v"
set xdc_hub75e "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc"
if {[lsearch -exact [get_files -quiet] $src_hub75e] < 0} { add_files -norecurse $src_hub75e; puts "\[INFO\] added hub75e_panel_seq_v7.v" }
if {[lsearch -exact [get_files -quiet] $xdc_hub75e] < 0} { add_files -fileset constrs_1 -norecurse $xdc_hub75e; puts "\[INFO\] added hub75e_pins.xdc" }
update_compile_order -fileset sources_1

# sanity: v7 module 必须可见
if {[llength [get_files -quiet -compile_order sources -used_in synthesis $src_hub75e]] == 0} {
    puts "\[WARN\] hub75e_panel_seq_v7.v not in compile order? 检查 module 名是否 hub75e_panel_seq_v7"
}

#------------------------------------------------------------------------------
# 1. open BD, 捕获旧 cell 所有连接
#------------------------------------------------------------------------------
open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

set old_cell [get_bd_cells hub75e_panel_seq_0]
if {$old_cell eq ""} { error "old cell hub75e_panel_seq_0 not found, 列出: [get_bd_cells]" }
puts "\[INFO\] old cell: $old_cell (ref [get_property CONFIG.REF_NAME -quiet $old_cell])"

# Helper: net 另一端 pin (排除自己 cell 的 pin)
proc other_endpoint {net mycell_pin_name} {
    set pins [get_bd_pins -quiet -of_objects $net]
    foreach p $pins {
        if {[string match "*${mycell_pin_name}" $p]} { continue }
        return $p
    }
    return ""
}

set old_aclk_net  [get_bd_nets -quiet -of_objects [get_bd_pins ${old_cell}/s_axi_aclk]]
set old_arstn_net [get_bd_nets -quiet -of_objects [get_bd_pins ${old_cell}/s_axi_aresetn]]
set old_axi_intf_pin [lindex [get_bd_intf_pins -of_objects $old_cell -filter {VLNV =~ "*aximm*" && MODE == Slave}] 0]
set old_axi_intf  [get_bd_intf_nets -quiet -of_objects $old_axi_intf_pin]

set aclk_src  [other_endpoint $old_aclk_net  s_axi_aclk]
set arstn_src [other_endpoint $old_arstn_net s_axi_aresetn]
set axi_src ""
foreach ip [get_bd_intf_pins -of_objects $old_axi_intf] {
    if {[string match "*/hub75e_panel_seq_0/*" $ip]} { continue }
    set axi_src $ip
}

# 全部输出 pin -> external port 映射 (v34L 10 个: panel 1 + panel 2 独立 8 pin)
set out_pins [list hub75e_rgb_out hub75e_rgb_out2 hub75e_dclk_out hub75e_lat_out \
                   hub75e_oe_out hub75e_addr_out hub75e_dclk_out2 hub75e_lat_out2 \
                   hub75e_oe_out2 hub75e_addr_out2]
array set out_port_map {}
foreach pn $out_pins {
    set net [get_bd_nets -quiet -of_objects [get_bd_pins -quiet ${old_cell}/${pn}]]
    if {$net eq ""} { puts "\[WARN\] pin $pn 没接 net, 跳过"; continue }
    set prt [get_bd_ports -quiet -of_objects $net]
    if {$prt eq ""} { puts "\[WARN\] pin $pn 的 net 不接 external port, 跳过"; continue }
    set out_port_map($pn) $prt
    puts "\[INFO\] $pn -> $prt"
}

puts "\[INFO\] captured: aclk_src=$aclk_src arstn_src=$arstn_src axi_src=$axi_src"

#------------------------------------------------------------------------------
# 2. 删旧 cell + IP cache 目录 (强制 regen, 防 stale module_ref elaboration)
#------------------------------------------------------------------------------
delete_bd_objs $old_cell
puts "\[INFO\] old cell deleted"

foreach d [concat \
        [glob -nocomplain "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/bd/hello_zynq/ip/hello_zynq_hub75e_panel_seq_0_*"] \
        [glob -nocomplain "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.gen/sources_1/bd/hello_zynq/ip/hello_zynq_hub75e_panel_seq_0_*"]] {
    file delete -force $d
    puts "\[INFO\] deleted ip cache: $d"
}

#------------------------------------------------------------------------------
# 3. PS7 检查 (v7: 不强改)
#    - HP2 v6 已开, 只 sanity check (异常时才补开)
#    - FCLK1 频率只 puts, 不改 — 运行时走 SLCR 提速
#------------------------------------------------------------------------------
set ps7 [get_bd_cells processing_system7_0]

set fclk1 [get_property CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ $ps7]
puts "\[INFO\] PCW_FPGA1_PERIPHERAL_FREQMHZ = $fclk1 MHz (不强改, 运行时 SLCR 提速)"

set hp2_en [get_property CONFIG.PCW_USE_S_AXI_HP2 $ps7]
if {$hp2_en ne "1"} {
    puts "\[WARN\] PCW_USE_S_AXI_HP2 = $hp2_en (预期 v6 已开=1), 现在补开"
    set_property -dict [list CONFIG.PCW_USE_S_AXI_HP2 {1}] $ps7
} else {
    puts "\[INFO\] PS7 S_AXI_HP2 already enabled (v6)"
}

#------------------------------------------------------------------------------
# 4. recreate cell (module_ref v7)
#------------------------------------------------------------------------------
create_bd_cell -type module -reference hub75e_panel_seq_v7 hub75e_panel_seq_0
set new_cell [get_bd_cells hub75e_panel_seq_0]
puts "\[INFO\] created new cell (ref hub75e_panel_seq_v7)"

#------------------------------------------------------------------------------
# 5. 重连: clk / rst / s_axi 原路径 / 全部输出 port
#------------------------------------------------------------------------------
connect_bd_net $aclk_src  [get_bd_pins hub75e_panel_seq_0/s_axi_aclk]
connect_bd_net $arstn_src [get_bd_pins hub75e_panel_seq_0/s_axi_aresetn]

set new_saxi_pin [lindex [get_bd_intf_pins -of_objects $new_cell -filter {VLNV =~ "*aximm*" && MODE == Slave}] 0]
puts "\[INFO\] new s_axi pin: $new_saxi_pin <- $axi_src"
connect_bd_intf_net $axi_src $new_saxi_pin

foreach pn [array names out_port_map] {
    connect_bd_net [get_bd_pins hub75e_panel_seq_0/${pn}] $out_port_map($pn)
    puts "\[INFO\] reconnected $pn -> $out_port_map($pn)"
}

#------------------------------------------------------------------------------
# 6. sensor_pulse 接常量 0 (预留 angle_tracker, 接入时删 xlconstant 换 tracker)
#------------------------------------------------------------------------------
if {[get_bd_cells -quiet xlconst_sensor0] eq ""} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconst_sensor0
    set_property -dict [list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {1}] [get_bd_cells xlconst_sensor0]
}
connect_bd_net [get_bd_pins xlconst_sensor0/dout] [get_bd_pins hub75e_panel_seq_0/sensor_pulse]
puts "\[INFO\] sensor_pulse tied 1'b0"

#------------------------------------------------------------------------------
# 7. m_axi -> axi_smc_hp2 -> PS7 S_AXI_HP2
#    v7: smc v6 已建, 存在则跳过创建/HP2 侧连线, 只补 S00_AXI (删旧 cell 时
#    m_axi <-> S00_AXI 的 intf net 已被一并删掉)
#------------------------------------------------------------------------------
if {[get_bd_cells -quiet axi_smc_hp2] eq ""} {
    puts "\[INFO\] axi_smc_hp2 不存在, 创建并接 HP2 (clk/rst 同 s_axi)"
    create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc_hp2
    set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc_hp2]
    connect_bd_intf_net [get_bd_intf_pins axi_smc_hp2/M00_AXI] [get_bd_intf_pins processing_system7_0/S_AXI_HP2]
    connect_bd_net $aclk_src  [get_bd_pins axi_smc_hp2/aclk]
    connect_bd_net $arstn_src [get_bd_pins axi_smc_hp2/aresetn]
    connect_bd_net $aclk_src  [get_bd_pins processing_system7_0/S_AXI_HP2_ACLK]
} else {
    puts "\[INFO\] axi_smc_hp2 already exists (v6), skip create, 只重连 S00_AXI"
}

set new_maxi_pin [lindex [get_bd_intf_pins -of_objects $new_cell -filter {VLNV =~ "*aximm*" && MODE == Master}] 0]
if {$new_maxi_pin eq ""} { error "m_axi master intf 没被 infer 出来, 检查 v7 端口命名 m_axi_*" }
puts "\[INFO\] new m_axi pin: $new_maxi_pin"

connect_bd_intf_net $new_maxi_pin [get_bd_intf_pins axi_smc_hp2/S00_AXI]
puts "\[INFO\] m_axi -> axi_smc_hp2/S00_AXI connected"

#------------------------------------------------------------------------------
# 8. 地址分配
#    s_axi: 0x40020000, 128K (17-bit addr: 寄存器 + 4 BRAM 区)
#    m_axi: DDR 全段 (HP2_DDR_LOWOCM)
#------------------------------------------------------------------------------
set saxi_seg [get_bd_addr_segs -quiet hub75e_panel_seq_0/s_axi/reg0]
if {$saxi_seg eq ""} { set saxi_seg [get_bd_addr_segs -quiet hub75e_panel_seq_0/*/reg0] }
assign_bd_address -target_address_space /processing_system7_0/Data \
    -offset 0x40020000 -range 0x20000 $saxi_seg -force
puts "\[INFO\] s_axi @ 0x40020000 range 128K"

set ddr_seg [get_bd_addr_segs -quiet processing_system7_0/S_AXI_HP2/HP2_DDR_LOWOCM]
set maxi_space [get_bd_addr_spaces -quiet hub75e_panel_seq_0/m_axi]
if {$ddr_seg ne "" && $maxi_space ne ""} {
    assign_bd_address -target_address_space $maxi_space $ddr_seg -force
    puts "\[INFO\] m_axi sees DDR seg: $ddr_seg"
} else {
    puts "\[WARN\] DDR seg/m_axi space 没找到 (ddr_seg=$ddr_seg space=$maxi_space), 用 assign_bd_address 自动补"
    assign_bd_address
}

#------------------------------------------------------------------------------
# 9. validate + save + wrapper
#------------------------------------------------------------------------------
validate_bd_design
save_bd_design
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1
puts "\[INFO\] BD recreate done. 检查上面 WARN 后再 build."

#------------------------------------------------------------------------------
# 10. build (memory: batch spawn 间歇性卡死, GUI build 最稳;
#     GUI 里 source 本脚本会直接往下跑 build — 不想 build 就在这里 Ctrl 停)
#------------------------------------------------------------------------------
reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"
if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] v7 xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
