###############################################################################
# hub75e_bd_integrate.tcl - 把 hub75e_panel_seq.v 集成进 hello_zynq BD
#
# 用法 (Vivado 2024.2 batch 或 GUI):
#   cd D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq
#   vivado -mode batch -source ../tools/hub75e_bd_integrate.tcl
# 或 GUI 里:
#   open_project 02_hello_zynq.xpr
#   source ../tools/hub75e_bd_integrate.tcl
#
# 做什么:
#   1. 删旧 led_panel_seq_0 cell + 5 个 panel_seq_* 外部 port
#   2. 加 hub75e_panel_seq module_ref cell
#   3. 暴露 5 个新外部 port: hub75e_rgb[5:0] / dclk / lat / oe / addr[4:0]
#   4. 连 AXI-Lite 到 ps7 M_AXI_GP0 (经现有 ps7_axi_periph + smartconnect)
#   5. 分配 base address 0x4002_0000
#   6. validate_bd + save_bd + make_wrapper
#   7. 加 hub75e_pins.xdc 到 constraints (如未加)
#
# 注意: FCLK1 = 120 MHz 这个改动用户需要手动在 PS7 IP customize 里改 (本脚本
#       会打印提醒, 不自动改 PS7 cfg 避免破坏其他 IP 时钟依赖).
###############################################################################

set bd_name "hello_zynq"
set ip_name "hub75e_panel_seq"
set ip_inst "hub75e_panel_seq_0"
set old_inst "led_panel_seq_0"

puts ""
puts "================================================================"
puts " HUB75E FM6124 panel BD integration"
puts "================================================================"

# 0. open project (batch 模式必需)
if {[catch {current_project} _proj] || $_proj eq ""} {
    open_project 02_hello_zynq.xpr
}
puts "\[INFO\] opened project: [current_project]"

# 1. open BD
if {[catch {current_bd_design} _bd] || $_bd eq ""} {
    open_bd_design [get_files ${bd_name}.bd]
}
current_bd_design [get_bd_designs $bd_name]
puts "\[INFO\] opened BD: $bd_name"

# 2. 添加 Verilog source (如未加)
set hdl_file "02_hello_zynq.srcs/sources_1/imports/hdl/hub75e_panel_seq.v"
if {![file exists $hdl_file]} {
    set hdl_file [file normalize "${hdl_file}"]
}
if {[llength [get_files -quiet hub75e_panel_seq.v]] == 0} {
    add_files -norecurse $hdl_file
    puts "\[INFO\] added source: $hdl_file"
} else {
    puts "\[INFO\] source already in project: hub75e_panel_seq.v"
}
update_compile_order -fileset sources_1

# 3. 删旧 led_panel_seq cell + 外部 port
if {[llength [get_bd_cells -quiet $old_inst]] > 0} {
    puts "\[INFO\] removing old cell: $old_inst"
    delete_bd_objs [get_bd_cells $old_inst]
}
foreach p {panel_seq_dclk panel_seq_le panel_seq_row panel_seq_sdi \
           panel_seq_icnd_dclk panel_seq_icnd_rclk panel_seq_icnd_sdi} {
    if {[llength [get_bd_ports -quiet $p]] > 0} {
        delete_bd_objs [get_bd_ports $p]
        puts "\[INFO\] deleted port: $p"
    }
}

# 4. 创建 hub75e_panel_seq cell (module_ref)
puts "\[INFO\] creating cell: $ip_inst (module_ref to hub75e_panel_seq)"
create_bd_cell -type module -reference $ip_name $ip_inst

# 5. AXI-Lite 连接到 ps7_axi_periph
# 找 axi interconnect (鹿小班标准 BD 用 ps7_axi_periph)
set axi_interconn [get_bd_cells -quiet "ps7_axi_periph"]
if {[llength $axi_interconn] == 0} {
    set axi_interconn [get_bd_cells -filter {VLNV =~ "*axi_interconnect*" || VLNV =~ "*smartconnect*"}]
    set axi_interconn [lindex $axi_interconn 0]
}
puts "\[INFO\] AXI interconnect: [get_property NAME $axi_interconn]"

# 给 interconnect 加一个 master port
# 先看现有 master count
set current_num_mi [get_property CONFIG.NUM_MI $axi_interconn]
puts "\[INFO\] current NUM_MI = $current_num_mi"
set new_mi_idx $current_num_mi
set_property CONFIG.NUM_MI [expr $current_num_mi + 1] $axi_interconn

# AXI clock / aresetn: 用 FCLK_CLK1 (沿用 75 MHz, 之前 led_panel_seq 设置)
# + proc_sys_reset_0 (跟 FCLK1 同步).
# DCLK = 75 / DCLK_DIV(4) = 18.75 MHz (Phase 1 看波形足够; 后续手动 GUI 调
# FCLK1 → 60/90/120 MHz 拿更高 DCLK).
set ps7_fclk1 [get_property CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ [get_bd_cells processing_system7_0]]
puts "\[INFO\] PS7 FCLK_CLK1 = $ps7_fclk1 MHz (DCLK 将 = $ps7_fclk1/4 MHz)"

set fclk_net [get_bd_nets -of_objects [get_bd_pins processing_system7_0/FCLK_CLK1]]
set rstn_net [get_bd_nets -of_objects [get_bd_pins proc_sys_reset_0/peripheral_aresetn]]
puts "\[INFO\] FCLK net = $fclk_net"
puts "\[INFO\] aresetn net = $rstn_net"

# 连 hub75e cell 的 AXI clk / rst
connect_bd_net -net $fclk_net [get_bd_pins $ip_inst/s_axi_aclk]
connect_bd_net -net $rstn_net [get_bd_pins $ip_inst/s_axi_aresetn]

# 连 AXI-Lite master 到 hub75e slave
set new_mi_name "M[format %02d $new_mi_idx]_AXI"
connect_bd_intf_net [get_bd_intf_pins $axi_interconn/$new_mi_name] \
                    [get_bd_intf_pins $ip_inst/S_AXI]
# axi_smc 是 smartconnect (非 axi_interconnect), 没有 per-master ACLK/ARESETN pin,
# 全局 aclk/aresetn 已经接好, 跳过这步.

# 6. 暴露外部 panel port
puts "\[INFO\] making external ports for panel signals"
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
    connect_bd_net [get_bd_pins $ip_inst/$pin] [get_bd_ports $port_name]
}

# 7. 分配 base address
assign_bd_address -target_address_space /processing_system7_0/Data \
                  [get_bd_addr_segs $ip_inst/S_AXI/reg0] \
                  -offset 0x40020000 -range 4K -force

# 8. validate + save
validate_bd_design
save_bd_design
puts "\[INFO\] BD saved."

# 9. xdc 文件加进 constraints
set xdc_file "02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc"
if {![file exists $xdc_file]} {
    set xdc_file [file normalize "${xdc_file}"]
}
if {[llength [get_files -quiet hub75e_pins.xdc]] == 0} {
    add_files -fileset constrs_1 -norecurse $xdc_file
    puts "\[INFO\] added constraint: hub75e_pins.xdc"
} else {
    puts "\[INFO\] xdc already in project"
}

# 10. 旧 led_pins.xdc 可能跟新 hub75e_pins.xdc 重复声明引脚 (AA22 等)
#     提醒用户手动处理 / disable
set old_xdc [get_files -quiet led_pins.xdc]
if {[llength $old_xdc] > 0} {
    puts ""
    puts "\[WARN\] !!! 旧 led_pins.xdc 还在 constraint set 里 !!!"
    puts "\[WARN\] 它会跟 hub75e_pins.xdc 抢同样的 PACKAGE_PIN, 引起冲突."
    puts "\[WARN\] 手动操作: 在 Sources panel 把 led_pins.xdc 右键 → Disable"
    puts "\[WARN\] 或运行: set_property IS_ENABLED 0 \[get_files led_pins.xdc\]"
}

# 11. wrapper 重新生成
puts "\[INFO\] regenerating wrapper..."
set wrapper_file [make_wrapper -files [get_files ${bd_name}.bd] -top -force]
add_files -norecurse $wrapper_file
update_compile_order -fileset sources_1

puts ""
puts "================================================================"
puts " HUB75E BD integration done"
puts "================================================================"
puts ""
puts " Next steps:"
puts "  1. 手动处理旧 led_pins.xdc (上面警告) — 推荐 disable"
puts "  2. PS7 IP customize → Clock Configuration → FCLK_CLK1 设 120 MHz"
puts "     (当前 FCLK_CLK1 是 75 MHz 给 led_panel_seq, 用户改后 BD 重 validate)"
puts "     ※ 用户也可暂时不改, 用 FCLK_CLK0 (100 MHz) → DCLK 25 MHz (FM6124 安全 spec)"
puts "  3. Generate Bitstream → 出 xsa"
puts "  4. Vitis 端 BSP regenerate + build hello_world"
puts "  5. boot 时:"
puts "       - 改 UserConfig.cmake \"ENABLE_HUB75E_TEST=1\""
puts "       - dl_helloworld.tcl → 板端跑循环 demo"
puts ""
