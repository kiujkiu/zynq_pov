# bd_force_rebuild_iprepo.tcl — diagnostic: force rebuild IP catalog + reload rgb2dvi from disk
# 应对 Vivado 2024.2 + Digilent vivado-library 的 generate_target 报 "Unsupported VHDL data type ''"
# 用法: D:\Vivado\2024.2\bin\vivado.bat -mode batch -source bd_force_rebuild_iprepo.tcl -nojournal

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set lib_repo "D:/workspace/zynq_pov/vivado-library"

puts "=== Open project ==="
open_project $proj_xpr

puts "=== Force rebuild IP catalog ==="
set_property ip_repo_paths $lib_repo [current_project]
update_ip_catalog -rebuild -repo_path $lib_repo

puts "=== Report IP status BEFORE upgrade ==="
report_ip_status -name ip_status_before

puts "=== Force upgrade rgb2dvi ==="
set rgb_ip [get_ips -quiet hello_zynq_rgb2dvi_0_0]
if {[llength $rgb_ip]} {
    upgrade_ip -force $rgb_ip
    puts "rgb2dvi IP-XACT model_param check:"
    report_property $rgb_ip MODELPARAM*
}

puts "=== Try generate_target ==="
open_bd_design [get_files hello_zynq.bd]
generate_target all [get_files hello_zynq.bd] -force

puts "=== DONE diagnostic ==="
