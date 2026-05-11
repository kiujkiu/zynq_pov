# Full re-synth from current BD (which has the strict reconnect applied)
open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }

# Force IP1-3 ap_clk / ap_rst_n connection (Vivado net auto-merge)
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file
foreach idx {1 2 3} {
    set clk_pin [get_bd_pins pov_project_batch_$idx/ap_clk]
    set net [get_bd_nets -quiet -of $clk_pin]
    if {$net eq ""} {
        puts "  fix IP$idx ap_clk"
        connect_bd_net [get_bd_pins pov_project_batch_0/ap_clk] $clk_pin
    }
    set rst_pin [get_bd_pins pov_project_batch_$idx/ap_rst_n]
    set net [get_bd_nets -quiet -of $rst_pin]
    if {$net eq ""} {
        puts "  fix IP$idx ap_rst_n"
        connect_bd_net [get_bd_pins pov_project_batch_0/ap_rst_n] $rst_pin
    }
}
validate_bd_design
save_bd_design
generate_target all $bd_file

# Force full re-synth
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
set is [get_property STATUS [get_runs impl_1]]
puts "impl_1: $is"
if {$is eq "write_bitstream Complete!"} {
    open_run impl_1
    write_hw_platform -fixed -include_bit -force \
        D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa
    puts "XSA done"
} else {
    puts "FAIL: $is"
}
close_project
exit 0
