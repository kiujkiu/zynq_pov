# 预配置工程并保存, 让 GUI 直接 Generate Bitstream (批处理切不动 synth_1 的 OOC 链接)
set WT "D:/claude_workspace/pov3d/zynq_pov_icnd2047"
open_project $WT/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]

# IP
set icnd_src "$WT/02_hello_zynq/02_hello_zynq.srcs/sources_1/imports/hdl/icnd2047_panel_seq.v"
if {[lsearch -exact [get_files] $icnd_src] < 0} { add_files -norecurse $icnd_src }
update_compile_order -fileset sources_1

# XDC
foreach x {hub75e_pins.xdc led_pins.xdc} { set f [get_files -quiet $x]; if {$f ne ""} { set_property is_enabled false $f } }
set p3xdc "$WT/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/icnd2047_p3.xdc"
if {[lsearch -exact [get_files] $p3xdc] < 0} { add_files -fileset constrs_1 -norecurse $p3xdc }
set_property is_enabled true [get_files icnd2047_p3.xdc]

# BD None → Singular (OOC), 重生成 + 创建 OOC run
set_property synth_checkpoint_mode Singular [get_files hello_zynq.bd]
reset_target -quiet all [get_files hello_zynq.bd]
catch { generate_target all [get_files hello_zynq.bd] }
catch { create_ip_run [get_files hello_zynq.bd] }
update_compile_order -fileset sources_1

puts "##### 工程已预配置: Singular + P3 XDC + OOC run. 关工程保存中... #####"
close_project
puts "##### 保存完成. GUI 打开工程后直接 Generate Bitstream #####"
exit 0
