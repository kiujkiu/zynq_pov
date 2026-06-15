# 重启用 led_pins (HDMI 约束回来, 冲突行已注释) + mtr on/直连 off, 重 build
# 目标: sensor_pulse 落 V14, HDMI 回 L21, mtr 所有脚不被抢
open_project 02_hello_zynq.xpr
set led "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/led_pins.xdc"
set mtr "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins_mtr_v01.xdc"
set dir "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc"
set_property is_enabled true  [get_files $led]
set_property is_enabled true  [get_files $mtr]
set_property is_enabled false [get_files $dir]
puts "\[INFO\] led on (conflicts commented), mtr on, direct off"
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] sensor-fix xsa exported"
}
