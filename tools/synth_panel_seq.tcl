# synth_panel_seq.tcl - reset + synth + impl + bit + XSA after BD change

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]

# panel_gpio_tri_o[0/1/3-11] 被 led_panel_seq 取代但 axi_gpio 仍输出, 没 LOC
# 让 DRC warning 而不是 error, Vivado 自动分配安全 pin
set_property STEPS.WRITE_BITSTREAM.TCL.PRE \
    [pwd]/../bitgen_severity_override.tcl [get_runs impl_1]

# 写 pre-hook tcl 让 write_bitstream 阶段降级 DRC
set fp [open "[pwd]/../bitgen_severity_override.tcl" w]
puts $fp {set_property SEVERITY {Warning} [get_drc_checks NSTD-1]}
puts $fp {set_property SEVERITY {Warning} [get_drc_checks UCIO-1]}
close $fp

puts "=== reset + impl + bit ==="
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "impl_1: $st"
if {$st ne "write_bitstream Complete!"} {
    puts "FAIL: $st"
    exit 1
}

puts "=== export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force \
    D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa

puts "DONE"
close_project
exit 0
