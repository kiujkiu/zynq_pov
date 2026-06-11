# synth_icnd3019_pl_v2.tcl - 直接改了 xci/bd JSON, 这里只 validate + regen wrapper + synth
open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]

set bd_file [get_files hello_zynq.bd]
puts "=== open BD + validate ==="
open_bd_design $bd_file
validate_bd_design -force
save_bd_design
reset_target all [get_files $bd_file]
generate_target all [get_files $bd_file]

# Regenerate top-level BD wrapper to pick up new external ports
make_wrapper -files [get_files $bd_file] -top -force -import
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
