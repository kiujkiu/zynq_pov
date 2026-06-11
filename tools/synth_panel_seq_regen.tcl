# synth_panel_seq_regen.tcl - 强制 regenerate BD/IP 后 synth + impl + bit + XSA
# 用于 BD 直接改 JSON 后, PS7 IP HDL 重生成 (ps7_init divisor 等)

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]

set bd_file [get_files hello_zynq.bd]
puts "=== regenerate BD: $bd_file ==="
open_bd_design $bd_file
validate_bd_design -force
save_bd_design
reset_target all [get_files $bd_file]
generate_target all [get_files $bd_file]
close_bd_design hello_zynq

# DRC severity override hook
set_property STEPS.WRITE_BITSTREAM.TCL.PRE \
    [pwd]/../bitgen_severity_override.tcl [get_runs impl_1]
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
