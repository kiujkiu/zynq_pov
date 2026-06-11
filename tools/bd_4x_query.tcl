# Query BD - what's actually connected on IP1/2/3
open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

puts "=== IP detailed state ==="
foreach idx {0 1 2 3} {
    puts ""
    puts "pov_project_batch_$idx:"
    foreach pin {ap_clk ap_rst_n} {
        set p [get_bd_pins pov_project_batch_$idx/$pin]
        set net [get_bd_nets -quiet -of $p]
        set src "?"
        if {$net ne ""} {
            set src_pins [get_bd_pins -quiet -of $net -filter {DIR == O}]
            foreach sp $src_pins {
                if {$sp ne $p} { set src $sp }
            }
        }
        puts "  $pin  net=[expr {$net eq "" ? "(none)" : $net}]  src=$src"
    }
    foreach intf {s_axi_control m_axi_gmem0 m_axi_gmem1} {
        set p [get_bd_intf_pins pov_project_batch_$idx/$intf]
        set net [get_bd_intf_nets -quiet -of $p]
        puts "  $intf  net=[expr {$net eq "" ? "(none)" : $net}]"
    }
}

puts ""
puts "=== axi_smc_pov_hp ==="
puts "  NUM_SI = [get_property CONFIG.NUM_SI [get_bd_cells axi_smc_pov_hp]]"
foreach idx {0 1 2 3 4 5 6 7} {
    set p [get_bd_intf_pins -quiet axi_smc_pov_hp/[format "S%02d_AXI" $idx]]
    if {$p eq ""} {
        puts "  S[format %02d $idx]_AXI: (not present)"
    } else {
        set net [get_bd_intf_nets -quiet -of $p]
        puts "  S[format %02d $idx]_AXI: net=[expr {$net eq "" ? "(disconnected)" : $net}]"
    }
}

puts ""
puts "=== proc_sys_reset_pov peripheral_aresetn destinations ==="
set p [get_bd_pins proc_sys_reset_pov/peripheral_aresetn]
set net [get_bd_nets -quiet -of $p]
puts "  net=$net"
if {$net ne ""} {
    set sinks [get_bd_pins -of $net]
    foreach s $sinks {
        puts "    sink: $s"
    }
}

close_bd_design $bd_file
close_project
exit 0
