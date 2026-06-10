# v34i build: verilog byte-slice + plane[2:0] 直接索引
# 目的: 修 v34h 还残留的 R/G/B cross-channel mux 共用
# 改动: hub75e_panel_seq.v BCM slice 用 byte slice (8-to-1 mux 三组独立)
# XDC 不变 (保留 v34h 的 Y20↔AB21 swap + DRIVE 4 SLEW SLOW)

open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened"
set_property source_mgmt_mode All [current_project]

update_compile_order -fileset sources_1

puts "\[INFO\] BD validate + regen wrapper"
open_bd_design [get_files hello_zynq.bd]
report_ip_status
catch { upgrade_bd_cells [get_bd_cells] }

# v34i fix: 重 build 时 panel_seq s_axi 的 addr segment 丢了 → DAP-AHB hang
# 显式 assign 0x40020000, range 128K (v34g phase2 panel 2 BRAM 需要)
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

reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"
if {[string match "*write_bitstream Complete*" $imp_status]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] v34i xsa exported"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}
