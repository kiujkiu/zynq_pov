# bd_fix_hdmi_tmds.tcl — 只补 hdmi_tmds external interface + rebuild bit.
# 上一次 bd_use_batch_ip.tcl 跑 upgrade_ip rgb2dvi 时丢了顶层 hdmi_tmds external,
# 导致 led_pins.xdc 里 hdmi_tmds_* 全部 No ports matched, HDMI 黑屏.
#
# 用法:
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch -source bd_fix_hdmi_tmds.tcl -nojournal

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Open project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

puts "=== Ensure hdmi_tmds external interface ==="
set rgb_tmds [get_bd_intf_pins -quiet rgb2dvi_0/TMDS]
if {[llength $rgb_tmds] == 0} {
    puts "ERROR: rgb2dvi_0/TMDS not found in BD"
    exit 1
}
set tmds_nets [get_bd_intf_nets -quiet -of_objects $rgb_tmds]
if {[llength $tmds_nets] == 0} {
    puts "  rgb2dvi_0/TMDS 未连 — make external"
    make_bd_intf_pins_external $rgb_tmds
    set new_port [get_bd_intf_ports -quiet TMDS_0]
    if {[llength $new_port]} {
        set_property name hdmi_tmds $new_port
        puts "  renamed TMDS_0 -> hdmi_tmds"
    } else {
        puts "  WARN: 没找到 TMDS_0 port, 当前 ports:"
        foreach p [get_bd_intf_ports] { puts "    $p" }
    }
} else {
    puts "  rgb2dvi_0/TMDS 已连: $tmds_nets — 检查 external port 名"
    foreach n $tmds_nets {
        foreach pp [get_bd_intf_ports -quiet -of_objects $n] {
            puts "    external port: $pp"
        }
    }
}

puts "=== Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design

# regenerate target + wrapper (wrapper 端口要新增 hdmi_tmds_*)
generate_target all [get_files ${bd_name}.bd] -force
puts "=== Regenerate wrapper ==="
set wrapper [make_wrapper -files [get_files ${bd_name}.bd] -top -force]
add_files -norecurse -force $wrapper
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "=== Re-run synth + impl + bitstream ==="
reset_run synth_1
reset_run impl_1
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl: [get_property STATUS [get_runs impl_1]]"

puts "=== Export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
puts "=== DONE ==="
exit 0
