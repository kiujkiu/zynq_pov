###############################################################################
# B: BRAM framebuffer build
#   - PL IP s_axi addr 5-bit → 16-bit, 加 framebuffer (64 KB region)
#   - BD assign address 4 KB → 64 KB
###############################################################################
open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"

open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

# 0a. 把 PL IP 文件移出后再加回, 强制 Vivado 重 parse module port
remove_files [get_files hub75e_panel_seq.v]
add_files -norecurse 02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v
update_compile_order -fileset sources_1

# 0. 删旧 hub75e cell + 5 个外部 port, 重新 create_bd_cell 拿新 PL IP port width
#    (Vivado update_module_reference 不稳, 用 delete+recreate)
delete_bd_objs [get_bd_cells hub75e_panel_seq_0]
foreach p {hub75e_rgb hub75e_dclk hub75e_lat hub75e_oe hub75e_addr} {
    catch {delete_bd_objs [get_bd_ports $p]}
}
puts "\[INFO\] removed old hub75e cell + ports"

# 1. 重新 create cell, reference 新 module name hub75e_panel_seq_v2
#    (rename module 让 Vivado 看作新 module, 强制 fresh elaborate, 旧 xci cache 失效)
create_bd_cell -type module -reference hub75e_panel_seq_v2 hub75e_panel_seq_0
puts "\[INFO\] created hub75e_panel_seq_0 cell (ref v2)"

# 2. 连 AXI-Lite 到 axi_smc 现有 M06_AXI (之前 hub75e 用的 master port 还在)
connect_bd_intf_net [get_bd_intf_pins axi_smc/M06_AXI] [get_bd_intf_pins hub75e_panel_seq_0/s_axi]
# 连 clock + reset (FCLK_CLK1 + proc_sys_reset_0)
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1] [get_bd_pins hub75e_panel_seq_0/s_axi_aclk]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins hub75e_panel_seq_0/s_axi_aresetn]

# 3. 暴露 5 个外部 panel port
foreach {pin port_name port_width} {
    hub75e_rgb_out  hub75e_rgb   6
    hub75e_dclk_out hub75e_dclk  1
    hub75e_lat_out  hub75e_lat   1
    hub75e_oe_out   hub75e_oe    1
    hub75e_addr_out hub75e_addr  5
} {
    if {$port_width == 1} {
        create_bd_port -dir O $port_name
    } else {
        create_bd_port -dir O -from [expr $port_width - 1] -to 0 $port_name
    }
    connect_bd_net [get_bd_pins hub75e_panel_seq_0/$pin] [get_bd_ports $port_name]
}
puts "\[INFO\] external ports re-created"

# 4. 分配 64 KB 地址
assign_bd_address -target_address_space /processing_system7_0/Data \
                  [get_bd_addr_segs hub75e_panel_seq_0/s_axi/reg0] \
                  -offset 0x40020000 -range 64K -force
puts "\[INFO\] hub75e address range = 64K"

# 2. validate + save
validate_bd_design
save_bd_design

# 3. wrapper 重生成 (端口宽度改了)
make_wrapper -files [get_files hello_zynq.bd] -top -force
update_compile_order -fileset sources_1

# 4. 删旧 wrapper imports 拷贝 (跟上次一样, 避免 stale)
set old_w [get_files -quiet -of_objects [get_filesets sources_1] "*imports/hdl/hello_zynq_wrapper.v"]
foreach w $old_w {
    remove_files -fileset sources_1 $w
    puts "\[INFO\] removed stale wrapper: $w"
}

# 5. relaunch
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
