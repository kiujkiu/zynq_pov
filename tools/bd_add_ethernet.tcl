# bd_add_ethernet.tcl
# 按照 鹿小班 HelloZynqPS_Linux_ETH 参考工程的拓扑加 GEM0 ETH + gmii_to_rgmii

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Opening project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# -------- Step 1: PS 启用 ETH0 on EMIO + MDIO on EMIO --------
puts "=== Step 1: PS config ETH0 EMIO ==="
set_property -dict [list \
    CONFIG.PCW_EN_ENET0 {1} \
    CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_ENET0_ENET0_IO {EMIO} \
    CONFIG.PCW_EN_EMIO_ENET0 {1} \
    CONFIG.PCW_ENET0_GRP_MDIO_ENABLE {1} \
    CONFIG.PCW_ENET0_GRP_MDIO_IO {EMIO} \
    CONFIG.PCW_ENET0_PERIPHERAL_FREQMHZ {1000 Mbps} \
] [get_bd_cells /processing_system7_0]

# -------- Step 2: 添加 gmii_to_rgmii IP --------
puts "=== Step 2: Add gmii_to_rgmii_0 ==="
if {[llength [get_bd_cells gmii_to_rgmii_0]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:gmii_to_rgmii:4.1 gmii_to_rgmii_0
    set_property CONFIG.SupportLevel {Include_Shared_Logic_in_Core} \
        [get_bd_cells gmii_to_rgmii_0]
}

# -------- Step 3: 添加反相器 (FCLK_RESET0_N 是低有效, gmii_to_rgmii 的 rst 是高有效) --------
puts "=== Step 3: Add util_vector_logic_eth (NOT gate) ==="
if {[llength [get_bd_cells util_vector_logic_eth]] == 0} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_eth
    set_property -dict [list \
        CONFIG.C_OPERATION {not} \
        CONFIG.C_SIZE {1} \
        CONFIG.LOGO_FILE {data/sym_notgate.png} \
    ] [get_bd_cells util_vector_logic_eth]
}

# -------- Step 4: 连线 --------
puts "=== Step 4: Wiring ==="
# FCLK_CLK0 -> gmii_to_rgmii.clkin (ref clock)
set fclk0 [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net $fclk0 [get_bd_pins gmii_to_rgmii_0/clkin]

# FCLK_RESET0_N -> util_vector_logic.Op1
set rstn [get_bd_pins processing_system7_0/FCLK_RESET0_N]
connect_bd_net $rstn [get_bd_pins util_vector_logic_eth/Op1]

# util_vector_logic.Res -> gmii_to_rgmii.rx_reset + tx_reset
set not_res [get_bd_pins util_vector_logic_eth/Res]
connect_bd_net $not_res [get_bd_pins gmii_to_rgmii_0/rx_reset]
connect_bd_net $not_res [get_bd_pins gmii_to_rgmii_0/tx_reset]

# 接口: PS GMII_ETHERNET_0 -> gmii_to_rgmii.GMII
puts "=== Step 4b: Interface nets ==="
if {[llength [get_bd_intf_nets -of_objects [get_bd_intf_pins processing_system7_0/GMII_ETHERNET_0]]] == 0} {
    connect_bd_intf_net [get_bd_intf_pins processing_system7_0/GMII_ETHERNET_0] \
        [get_bd_intf_pins gmii_to_rgmii_0/GMII]
}
if {[llength [get_bd_intf_nets -of_objects [get_bd_intf_pins processing_system7_0/MDIO_ETHERNET_0]]] == 0} {
    connect_bd_intf_net [get_bd_intf_pins processing_system7_0/MDIO_ETHERNET_0] \
        [get_bd_intf_pins gmii_to_rgmii_0/MDIO_GEM]
}

# -------- Step 5: Make external MDIO_PHY + RGMII --------
puts "=== Step 5: Make RGMII / MDIO external ==="
foreach intf {MDIO_PHY RGMII} {
    set pin [get_bd_intf_pins gmii_to_rgmii_0/$intf]
    set existing [get_bd_intf_nets -of_objects $pin]
    set has_external 0
    foreach n $existing {
        set ext [get_bd_intf_ports -of_objects $n]
        if {[llength $ext] > 0} { set has_external 1; break }
    }
    if {!$has_external} {
        puts "  make external: gmii_to_rgmii_0/$intf"
        make_bd_intf_pins_external $pin
    }
}

# -------- Step 6: validate & save --------
puts "=== Step 6: Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design

puts "=== Regenerate outputs ==="
generate_target all [get_files ${bd_name}.bd] -force

# -------- Step 7: 追加 ETH XDC 约束 --------
puts "=== Step 7: Ensure ETH XDC exists ==="
# 由于顶层端口名会是 MDIO_PHY_0_xxx 和 RGMII_0_xxx，对齐 vendor 约束
# 直接把 XDC 文件加进 constraints fileset (如果已有相同路径就跳过)
set xdc_path "$proj_dir/02_hello_zynq.srcs/constrs_1/new/eth_pins.xdc"
set existing_files [get_files -quiet $xdc_path]
if {[llength $existing_files] == 0} {
    add_files -fileset constrs_1 $xdc_path
}

puts "=== Synth + Impl + Bitstream ==="
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth_1 status: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl_1 status: [get_property STATUS [get_runs impl_1]]"

puts "=== Export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
puts "=== DONE ==="
exit 0
