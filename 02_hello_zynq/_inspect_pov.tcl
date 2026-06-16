# 只读勘察 pov 域接线 (旧 IP + 专用 smc/reset), 为干净替换
open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
puts "===== pov_project_batch_0 接口 ====="
foreach pin [get_bd_intf_pins -quiet /pov_project_batch_0/*] { puts "  intf: $pin -> net [get_bd_intf_nets -quiet -of_objects $pin]" }
foreach pin [get_bd_pins -quiet /pov_project_batch_0/*] { puts "  pin: $pin  net=[get_bd_nets -quiet -of_objects $pin]" }
puts "===== axi_smc_pov_hp (SI/MI 连接) ====="
foreach pin [get_bd_intf_pins -quiet /axi_smc_pov_hp/*] { puts "  $pin -> [get_bd_intf_nets -quiet -of_objects $pin]" }
puts "===== sc_pov_axilite (SI/MI) ====="
foreach pin [get_bd_intf_pins -quiet /sc_pov_axilite/*] { puts "  $pin -> [get_bd_intf_nets -quiet -of_objects $pin]" }
puts "===== proc_sys_reset_pov ====="
foreach pin [get_bd_pins -quiet /proc_sys_reset_pov/*] { puts "  $pin  net=[get_bd_nets -quiet -of_objects $pin]" }
puts "===== HP1 接谁 ====="
foreach pin [get_bd_intf_pins -quiet /processing_system7_0/S_AXI_HP1] { puts "  $pin -> [get_bd_intf_nets -quiet -of_objects $pin]" }
puts "===== pov_project_batch_0 地址 ====="
catch { foreach a [get_bd_addr_segs -of_objects [get_bd_cells /pov_project_batch_0]] { puts "  $a = [get_property -quiet OFFSET $a] sz [get_property -quiet RANGE $a]" } }
catch { puts "  control seg offset: [get_property OFFSET [get_bd_addr_segs /processing_system7_0/Data/SEG_pov_project_batch_0_Reg]]" }
puts "===== GP0 AXI-Lite smc (axi_smc) MI 数 ====="
puts "  axi_smc NUM_MI=[get_property CONFIG.NUM_MI [get_bd_cells /axi_smc]]"
puts "===== DONE ====="
close_project
exit 0
