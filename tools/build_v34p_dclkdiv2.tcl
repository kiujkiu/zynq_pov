# v34p build: DCLK_DIV 3→2 (75MHz/3 = 37.5MHz DCLK (user 要求提速, 接受超 spec))
# 目的: 验 panel 2 暗 14% 是否因 DCLK 超频(37.5M) + panel2 DCLK2 走普通 IO(Y14) 边沿差
# 改动: 仅 BD cell hub75e_panel_seq_0 的 CONFIG.DCLK_DIV = 3, 其余不动

open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]
update_compile_order -fileset sources_1

open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]
report_ip_status

# --- 核心改动: DCLK_DIV 2 → 3 ---
set old [get_property CONFIG.DCLK_DIV [get_bd_cells hub75e_panel_seq_0]]
puts "\[INFO\] DCLK_DIV 当前 = $old, 改为 2"
set_property CONFIG.DCLK_DIV {2} [get_bd_cells hub75e_panel_seq_0]
set new [get_property CONFIG.DCLK_DIV [get_bd_cells hub75e_panel_seq_0]]
puts "\[INFO\] DCLK_DIV 实际 = $new"

catch { upgrade_bd_cells [get_bd_cells] }

# v34i fix: 重 build 后 panel_seq s_axi addr segment 会丢 → DAP-AHB hang, 必须显式 assign
catch {
    assign_bd_address -target_address_space /processing_system7_0/Data \
        [get_bd_addr_segs hub75e_panel_seq_0/s_axi/reg0] \
        -range 128K -offset 0x40020000
    puts "\[INFO\] assigned panel_seq 0x40020000 128K"
}

validate_bd_design -force
save_bd_design
generate_target all [get_files hello_zynq.bd]

catch { make_wrapper -files [get_files hello_zynq.bd] -top -force }
catch { add_files -norecurse [glob -nocomplain [file normalize [get_property directory [current_project]]]/02_hello_zynq.gen/sources_1/bd/hello_zynq/hdl/hello_zynq_wrapper.v] }
update_compile_order -fileset sources_1

reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"
if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] v34p (DCLK_DIV=3) xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
