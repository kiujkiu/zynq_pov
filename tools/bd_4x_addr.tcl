open_project D:/workspace/zynq_pov/02_hello_zynq/02_hello_zynq.xpr
set_property source_mgmt_mode None [current_project]
catch { update_compile_order -fileset sources_1 }
set bd_file [get_files hello_zynq.bd]
open_bd_design $bd_file

puts "=== Address segments for IP m_axi ==="
foreach idx {0 1 2 3} {
    foreach mem {gmem0 gmem1} {
        set as [get_bd_addr_spaces -quiet pov_project_batch_$idx/Data_m_axi_$mem]
        puts ""
        puts "IP$idx/Data_m_axi_$mem space=$as"
        if {$as ne ""} {
            set segs [get_bd_addr_segs -quiet -of $as]
            foreach seg $segs {
                set off [get_property OFFSET $seg]
                set rng [get_property RANGE $seg]
                puts "  seg=$seg  off=$off  rng=$rng"
            }
            if {[llength $segs] == 0} {
                puts "  (NO segments assigned)"
            }
        }
    }
}

close_bd_design $bd_file
close_project
exit 0
