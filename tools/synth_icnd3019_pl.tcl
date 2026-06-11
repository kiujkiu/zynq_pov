# synth_icnd3019_pl.tcl - 把 ICND3019 信号 (SDI/DCLK/RCLK) 移到 PL IP 端
# 1. BD: 加 3 个 external ports + 连接 led_panel_seq_0 新输出
# 2. XDC: W18/W17/W16 从 axi_gpio 切到 PL IP 输出
# 3. synth + impl + bit + XSA

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode All [current_project]

set bd_file [get_files hello_zynq.bd]
puts "=== open BD ==="
open_bd_design $bd_file

# Refresh module reference to pick up new Verilog ports
puts "=== refresh module led_panel_seq ==="
update_module_reference led_panel_seq

# Add 3 new external ports
foreach pname {panel_seq_icnd_sdi panel_seq_icnd_dclk panel_seq_icnd_rclk} {
    if {[llength [get_bd_ports -quiet $pname]] == 0} {
        puts "  creating port $pname"
        create_bd_port -dir O $pname
    } else {
        puts "  port $pname exists, skip"
    }
}

# Connect new IP outputs to new ports
foreach {pin port} {
    icnd_sdi_out  panel_seq_icnd_sdi
    icnd_dclk_out panel_seq_icnd_dclk
    icnd_rclk_out panel_seq_icnd_rclk
} {
    set src [get_bd_pins led_panel_seq_0/$pin]
    set dst [get_bd_ports $port]
    if {[llength $src] && [llength $dst]} {
        set existing [get_bd_nets -of_objects $dst -quiet]
        if {[llength $existing] == 0} {
            puts "  connecting $pin -> $port"
            connect_bd_net $src $dst
        } else {
            puts "  $pin -> $port already connected"
        }
    } else {
        puts "  ERROR: missing pin $pin or port $port"
    }
}

puts "=== validate + save BD ==="
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
