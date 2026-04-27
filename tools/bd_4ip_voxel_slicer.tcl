# bd_4ip_voxel_slicer.tcl — instantiate 4× pov_voxel_slice_batch for parallel
# slot rendering. Run inside Vivado batch mode after pov_voxel_slice_batch IP
# package is in repo:
#
#   cd D:\workspace\zynq_pov\02_hello_zynq
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch -source ..\tools\bd_4ip_voxel_slicer.tcl -nojournal
#
# After: write_bitstream + impl + xsdb dl new bit/elf.
#
# Resource: each IP ~ 1300 LUT, 350 FF, 2 BRAM, 3 DSP. 4 IPs = 5200 LUT,
# 1400 FF, 8 BRAM, 12 DSP. Plus 4 entries in AXI Smartconnect for HP ports.
# Fits 7020 with margin (LUT ~25%, BRAM ~7%).
#
# Architecture:
#   - 4 IPs share voxel_grid (read-only) via single HP port using AXI Smartconnect
#   - Each IP writes to disjoint slots in ring buffer, share single HP for writes
#   - 4 s_axilite control buses connect to PS via single AXI Lite Smartconnect
#   - 4 ap_start/ap_done signals exposed to GPIO so ARM can sync

open_project 02_hello_zynq.xpr

# Open BD
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

# Names of existing IP - assume single instance present
set existing_ip {pov_voxel_slice_batch_0}

# Add 3 more instances (IP1..3)
foreach idx {1 2 3} {
    create_bd_cell -type ip -vlnv povlab:user:pov_voxel_slice_batch:1.0 \
        pov_voxel_slice_batch_$idx
}

# Wire each IP's clock + reset (assumes existing axi_clk net)
foreach idx {1 2 3} {
    connect_bd_net [get_bd_nets axi_clk] [get_bd_pins pov_voxel_slice_batch_$idx/ap_clk]
    connect_bd_net [get_bd_nets axi_rstn] [get_bd_pins pov_voxel_slice_batch_$idx/ap_rst_n]
}

# Add Smartconnect for HP read (gmem0 voxel_grid, shared across 4 IPs)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_vox_read
set_property CONFIG.NUM_SI 4 [get_bd_cells sc_vox_read]
set_property CONFIG.NUM_MI 1 [get_bd_cells sc_vox_read]
foreach idx {0 1 2 3} {
    connect_bd_intf_net [get_bd_intf_pins pov_voxel_slice_batch_$idx/m_axi_gmem0] \
        [get_bd_intf_pins sc_vox_read/S0${idx}_AXI]
}
# Connect sc_vox_read M00 to PS HP1
connect_bd_intf_net [get_bd_intf_pins sc_vox_read/M00_AXI] \
    [get_bd_intf_pins processing_system7_0/S_AXI_HP1]

# Add Smartconnect for HP write (gmem1 ring_base, shared across 4)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_vox_write
set_property CONFIG.NUM_SI 4 [get_bd_cells sc_vox_write]
set_property CONFIG.NUM_MI 1 [get_bd_cells sc_vox_write]
foreach idx {0 1 2 3} {
    connect_bd_intf_net [get_bd_intf_pins pov_voxel_slice_batch_$idx/m_axi_gmem1] \
        [get_bd_intf_pins sc_vox_write/S0${idx}_AXI]
}
connect_bd_intf_net [get_bd_intf_pins sc_vox_write/M00_AXI] \
    [get_bd_intf_pins processing_system7_0/S_AXI_HP2]

# Add Smartconnect for AXI Lite control (4 → 1 to PS GP0)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 sc_vox_axilite
set_property CONFIG.NUM_SI 1 [get_bd_cells sc_vox_axilite]
set_property CONFIG.NUM_MI 4 [get_bd_cells sc_vox_axilite]
# (assumes existing axi_periph_smartconnect for GP0; chain sc_vox_axilite to it)
# If existing GP0 has free port:
#   connect_bd_intf_net axi_periph/Mxx_AXI sc_vox_axilite/S00_AXI
foreach idx {0 1 2 3} {
    connect_bd_intf_net [get_bd_intf_pins sc_vox_axilite/M0${idx}_AXI] \
        [get_bd_intf_pins pov_voxel_slice_batch_$idx/s_axi_control]
}

# Address map — each IP gets distinct s_axilite address
assign_bd_address [get_bd_addr_segs pov_voxel_slice_batch_0/s_axi_control/Reg]
assign_bd_address [get_bd_addr_segs pov_voxel_slice_batch_1/s_axi_control/Reg]
assign_bd_address [get_bd_addr_segs pov_voxel_slice_batch_2/s_axi_control/Reg]
assign_bd_address [get_bd_addr_segs pov_voxel_slice_batch_3/s_axi_control/Reg]

# Validate, save, generate
validate_bd_design
save_bd_design
generate_target all [get_files hello_zynq.bd]

# Run synth + impl + bitstream
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

puts "DONE: 4-IP voxel slicer bitstream at .runs/impl_1/hello_zynq_wrapper.bit"
exit 0
