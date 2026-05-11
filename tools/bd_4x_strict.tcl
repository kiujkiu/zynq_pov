# bd_4x_strict.tcl — Verify and fix 4× pov_project_batch m_axi connections
#
# Earlier bd_4x_pov_project_batch.tcl used `catch {connect_bd_intf_net ...}`
# which silently swallowed errors when intf already connected or pin name
# wrong. This script:
#   1. Diagnoses current state (which IP m_axi pins are connected)
#   2. Disconnects any wrong connections
#   3. Re-connects all IP1/2/3 m_axi gmem0/1 to S02-S07 of axi_smc_pov_hp
#   4. Validate + save + synth + impl + write_bitstream + export XSA
#
# NO catch — let errors propagate so they're visible.

open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]
# update_compile_order has known "Spawn failed" bug under batch mode — skip
catch { update_compile_order -fileset sources_1 }
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

puts "=== Diagnose current BD state ==="

# Verify smartconnect NUM_SI
set num_si [get_property CONFIG.NUM_SI [get_bd_cells axi_smc_pov_hp]]
puts "axi_smc_pov_hp NUM_SI = $num_si  (expect 8)"
if {$num_si != 8} {
    set_property CONFIG.NUM_SI 8 [get_bd_cells axi_smc_pov_hp]
    puts "  → bumped to 8"
}

# Check each IP m_axi gmem0/1 connection
foreach ip {pov_project_batch_0 pov_project_batch_1 pov_project_batch_2 pov_project_batch_3} {
    foreach mem {gmem0 gmem1} {
        set pin [get_bd_intf_pins $ip/m_axi_$mem]
        set net [get_bd_intf_nets -quiet -of $pin]
        puts "  $ip/m_axi_$mem  -> net=[expr {$net eq "" ? "(disconnected)" : $net}]"
    }
}

puts ""
puts "=== Force-reconnect IP[1-3] m_axi → S02-S07 ==="
# Disconnect existing connections on IP1-3 m_axi (if any go to wrong target)
foreach idx {1 2 3} {
    foreach mem {gmem0 gmem1} {
        set pin [get_bd_intf_pins pov_project_batch_$idx/m_axi_$mem]
        set net [get_bd_intf_nets -quiet -of $pin]
        if {$net ne ""} {
            puts "  delete net for pov_project_batch_$idx/m_axi_$mem"
            delete_bd_objs $net
        }
    }
}

# Now connect (no catch — fail loud if pin/port name wrong)
foreach idx {1 2 3} {
    set s_gmem0 [format "S%02d_AXI" [expr {$idx * 2}]]
    set s_gmem1 [format "S%02d_AXI" [expr {$idx * 2 + 1}]]
    puts "  connect IP$idx/m_axi_gmem0 → axi_smc_pov_hp/$s_gmem0"
    connect_bd_intf_net [get_bd_intf_pins pov_project_batch_$idx/m_axi_gmem0] \
        [get_bd_intf_pins axi_smc_pov_hp/$s_gmem0]
    puts "  connect IP$idx/m_axi_gmem1 → axi_smc_pov_hp/$s_gmem1"
    connect_bd_intf_net [get_bd_intf_pins pov_project_batch_$idx/m_axi_gmem1] \
        [get_bd_intf_pins axi_smc_pov_hp/$s_gmem1]
}

# SmartConnect with NUM_CLKS=1 uses single aclk for all SI ports — no
# per-SI clock pin to wire. Skip clock/reset wiring (axi_smc_pov_hp.aclk
# already connected to FCLK / ap_clk via initial BD).
puts "  (SmartConnect NUM_CLKS=1 — no per-SI clock pin needed)"

# Address assignment — each IP m_axi gmem* needs HP1 DDR access mapping
puts ""
puts "=== Address assignments for IP[1-3] m_axi ==="
foreach idx {1 2 3} {
    foreach mem {gmem0 gmem1} {
        set as [get_bd_addr_spaces pov_project_batch_$idx/Data_m_axi_$mem]
        set seg [get_bd_addr_segs -of $as -quiet]
        if {$seg eq ""} {
            puts "  assign $as → HP1_DDR_LOWOCM"
            assign_bd_address -target_address_space $as \
                [get_bd_addr_segs processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM]
        } else {
            puts "  IP$idx/$mem already assigned: $seg"
        }
    }
}

validate_bd_design
save_bd_design
generate_target all $bd_file

puts ""
puts "=== Re-diagnose after fix ==="
foreach ip {pov_project_batch_0 pov_project_batch_1 pov_project_batch_2 pov_project_batch_3} {
    foreach mem {gmem0 gmem1} {
        set pin [get_bd_intf_pins $ip/m_axi_$mem]
        set net [get_bd_intf_nets -quiet -of $pin]
        puts "  $ip/m_axi_$mem  -> [expr {$net eq "" ? "(STILL DISCONNECTED)" : "OK"}]"
    }
}

# Synth + impl
puts ""
puts "=== Synth + Impl ==="
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] eq "write_bitstream Complete!"} {
    puts "=== Export XSA ==="
    open_run impl_1
    write_hw_platform -fixed -include_bit -force \
        D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xsa
    puts "XSA written"
} else {
    puts "ERROR: impl_1 failed: [get_property STATUS [get_runs impl_1]]"
    exit 1
}
close_project
puts "DONE"
exit 0
