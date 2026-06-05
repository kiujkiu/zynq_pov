###############################################################################
# v34 Phase 2 BD recreate: hub75e_panel_seq_v2 → v3 + 加 hub75e_rgb_out2 output
# - 删旧 IP cache (xci + gen)
# - 删 BD cell, recreate with module_ref v3
# - 重连 AXI + clk + rst + 所有现有 output (rgb, dclk, lat, oe, addr)
# - 加新 external port hub75e_rgb2[5:0] + connect rgb_out2
# - 走 memory feedback_vivado_bd_addr_width_cache.md "唯一可靠 fix" 路径
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]

# Ensure verilog + xdc in fileset
set src_hub75e "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v"
set xdc_hub75e "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc"
if {[lsearch -exact [get_files -quiet] $src_hub75e] < 0} { add_files -norecurse $src_hub75e; puts "\[INFO\] added hub75e_panel_seq.v" }
if {[lsearch -exact [get_files -quiet] $xdc_hub75e] < 0} { add_files -fileset constrs_1 -norecurse $xdc_hub75e; puts "\[INFO\] added hub75e_pins.xdc" }
update_compile_order -fileset sources_1

# Open BD
open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

# 1. 捕获现有 cell 的所有连接 (备份重连用)
set old_cell [get_bd_cells hub75e_panel_seq_0]
puts "\[INFO\] old cell: $old_cell"

# Helper: 找出 net 的另一端 source pin (不是 cell pin 本身)
proc other_endpoint {net mycell_pin_name} {
    set pins [get_bd_pins -quiet -of_objects $net]
    set intf [get_bd_intf_pins -quiet -of_objects $net]
    foreach p $pins {
        if {[string match "*${mycell_pin_name}" $p]} { continue }
        return $p
    }
    return ""
}

set old_aclk_net  [get_bd_nets -quiet -of_objects [get_bd_pins ${old_cell}/s_axi_aclk]]
set old_arstn_net [get_bd_nets -quiet -of_objects [get_bd_pins ${old_cell}/s_axi_aresetn]]
# AXI interface — query 任意 case (cell intf_pin 可能 S_AXI 大写或 s_axi 小写)
set old_axi_intf_pin [lindex [get_bd_intf_pins -of_objects $old_cell -filter {VLNV =~ "*aximm*" && MODE == Slave}] 0]
set old_axi_intf  [get_bd_intf_nets -quiet -of_objects $old_axi_intf_pin]

set aclk_src  [other_endpoint $old_aclk_net  s_axi_aclk]
set arstn_src [other_endpoint $old_arstn_net s_axi_aresetn]
set axi_intf_pins [get_bd_intf_pins -of_objects $old_axi_intf]
set axi_src ""
foreach ip $axi_intf_pins {
    if {[string match "*/hub75e_panel_seq_0/*" $ip]} { continue }
    set axi_src $ip
}

# Output nets → external ports
set old_rgb_port  [get_bd_ports -quiet -of_objects [get_bd_nets -of_objects [get_bd_pins ${old_cell}/hub75e_rgb_out]]]
set old_dclk_port [get_bd_ports -quiet -of_objects [get_bd_nets -of_objects [get_bd_pins ${old_cell}/hub75e_dclk_out]]]
set old_lat_port  [get_bd_ports -quiet -of_objects [get_bd_nets -of_objects [get_bd_pins ${old_cell}/hub75e_lat_out]]]
set old_oe_port   [get_bd_ports -quiet -of_objects [get_bd_nets -of_objects [get_bd_pins ${old_cell}/hub75e_oe_out]]]
set old_addr_port [get_bd_ports -quiet -of_objects [get_bd_nets -of_objects [get_bd_pins ${old_cell}/hub75e_addr_out]]]

puts "\[INFO\] captured connections:"
puts "  aclk_src: $aclk_src"
puts "  arstn_src: $arstn_src"
puts "  axi_src: $axi_src"
puts "  rgb_port: $old_rgb_port"
puts "  dclk_port: $old_dclk_port"
puts "  lat_port: $old_lat_port"
puts "  oe_port: $old_oe_port"
puts "  addr_port: $old_addr_port"

# Capture address segment info before delete
set seg [get_bd_addr_segs -quiet -of_objects $old_cell]
puts "\[INFO\] addr segment: $seg"

# 2. 删 old cell
delete_bd_objs $old_cell
puts "\[INFO\] old cell deleted"

# 3. 删 IP cache 目录 (强制 Vivado regen)
set xci_dir "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/sources_1/bd/hello_zynq/ip/hello_zynq_hub75e_panel_seq_0_3"
set gen_dir "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.gen/sources_1/bd/hello_zynq/ip/hello_zynq_hub75e_panel_seq_0_3"
foreach d [list $xci_dir $gen_dir] {
    if {[file exists $d]} {
        file delete -force $d
        puts "\[INFO\] deleted $d"
    }
}

# 4. 创建新 cell with renamed module v3
create_bd_cell -type module -reference hub75e_panel_seq_v3 hub75e_panel_seq_0
puts "\[INFO\] created new cell hub75e_panel_seq_0 (ref v3)"

# 5. 重连
connect_bd_net $aclk_src  [get_bd_pins hub75e_panel_seq_0/s_axi_aclk]
connect_bd_net $arstn_src [get_bd_pins hub75e_panel_seq_0/s_axi_aresetn]
# New cell AXI intf pin (Vivado infer "s_axi" 小写 from verilog port prefix)
set new_axi_pin [lindex [get_bd_intf_pins -of_objects [get_bd_cells hub75e_panel_seq_0] -filter {VLNV =~ "*aximm*" && MODE == Slave}] 0]
puts "\[INFO\] new AXI pin: $new_axi_pin, source: $axi_src"
connect_bd_intf_net $axi_src $new_axi_pin
connect_bd_net [get_bd_pins hub75e_panel_seq_0/hub75e_rgb_out]  $old_rgb_port
connect_bd_net [get_bd_pins hub75e_panel_seq_0/hub75e_dclk_out] $old_dclk_port
connect_bd_net [get_bd_pins hub75e_panel_seq_0/hub75e_lat_out]  $old_lat_port
connect_bd_net [get_bd_pins hub75e_panel_seq_0/hub75e_oe_out]   $old_oe_port
connect_bd_net [get_bd_pins hub75e_panel_seq_0/hub75e_addr_out] $old_addr_port
puts "\[INFO\] reconnected all original nets"

# 6. 新建 external port hub75e_rgb2[5:0] + connect rgb_out2
create_bd_port -dir O -from 5 -to 0 -type data hub75e_rgb2
connect_bd_net [get_bd_pins hub75e_panel_seq_0/hub75e_rgb_out2] [get_bd_ports hub75e_rgb2]
puts "\[INFO\] created hub75e_rgb2 port + connected rgb_out2"

# 7. Re-assign AXI address (BD 删 cell 同时丢 address segment)
# Address segment: 新 cell intf 名小写, 用 wildcard 匹配
set new_seg [get_bd_addr_segs -quiet hub75e_panel_seq_0/*/reg0]
puts "\[INFO\] new addr seg: $new_seg"
assign_bd_address -target_address_space /processing_system7_0/Data $new_seg -force
puts "\[INFO\] reassigned AXI address"

validate_bd_design
save_bd_design

# 8. 重 wrap top
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1

# 9. Build
reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"

if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
