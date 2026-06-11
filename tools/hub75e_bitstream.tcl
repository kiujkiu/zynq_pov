###############################################################################
# hub75e_bitstream.tcl - disable 旧 xdc + 重生成 wrapper + synth/impl/bitstream + xsa
###############################################################################

open_project 02_hello_zynq.xpr
puts "\[INFO\] project opened: [current_project]"

# 1. disable 旧 led_pins.xdc
set old_xdc [get_files -quiet led_pins.xdc]
if {[llength $old_xdc] > 0} {
    set_property IS_ENABLED 0 $old_xdc
    puts "\[INFO\] disabled old xdc: $old_xdc"
}
set new_xdc [get_files -quiet hub75e_pins.xdc]
if {[llength $new_xdc] > 0} {
    set_property IS_ENABLED 1 $new_xdc
    puts "\[INFO\] enabled new xdc: $new_xdc"
}

# 2. 删旧 wrapper (imports 路径里的过时拷贝), 让 make_wrapper 生成的新版本 (gen/) 被用
set old_wrappers [get_files -quiet -of_objects [get_filesets sources_1] "*imports/hdl/hello_zynq_wrapper.v"]
foreach w $old_wrappers {
    remove_files -fileset sources_1 $w
    puts "\[INFO\] removed stale wrapper: $w"
}
# 顺便删旧 led_panel_seq.v (废, 跟 hub75e_panel_seq.v 重复 module 不冲突但 noise)
set old_seq [get_files -quiet -of_objects [get_filesets sources_1] "*led_panel_seq.v"]
foreach s $old_seq {
    remove_files -fileset sources_1 $s
    puts "\[INFO\] removed old led_panel_seq: $s"
}

# 3. 用 BD 重生成 wrapper (会出到 gen/sources_1/bd/hello_zynq/hdl/)
set bd_file [get_files -quiet hello_zynq.bd]
set wrapper_path [make_wrapper -files $bd_file -top -force]
puts "\[INFO\] new wrapper: $wrapper_path"
add_files -norecurse $wrapper_path
update_compile_order -fileset sources_1
set_property top hello_zynq_wrapper [current_fileset]

# 4. reset run + relaunch
reset_run impl_1
reset_run synth_1
puts "\[INFO\] launching synth_1 → impl_1 → write_bitstream (8 jobs)"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1

set imp_status [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $imp_status"

if {[string match "*Complete*" $imp_status] || [string match "*write_bitstream Complete*" $imp_status]} {
    puts "\[INFO\] bitstream done. exporting hardware..."
    set xsa_path "../hello_plat/hw/hello_zynq.xsa"
    write_hw_platform -fixed -include_bit -force -file [file normalize $xsa_path]
    puts "\[INFO\] xsa exported: [file normalize $xsa_path]"
} else {
    puts "\[ERROR\] impl_1 未完成: $imp_status"
}

puts ""
puts "================================================================"
puts " bitstream + xsa done."
puts "================================================================"
