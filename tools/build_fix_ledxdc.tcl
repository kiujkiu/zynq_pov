# 禁用 stale led_pins.xdc (跟 mtr 抢 19 脚, panel_spi_miso 抢 AB16 把 dclk2 踢飞), 重 build
open_project 02_hello_zynq.xpr
set led "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/led_pins.xdc"
set_property is_enabled false [get_files $led]
puts "\[INFO\] led_pins.xdc disabled"
# 确认 mtr on, 直连 off
set mtr "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins_mtr_v01.xdc"
set dir "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.srcs/constrs_1/new/hub75e_pins.xdc"
set_property is_enabled true  [get_files $mtr]
set_property is_enabled false [get_files $dir]
reset_run synth_1
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_runs impl_1
set st [get_property STATUS [get_runs impl_1]]
puts "\[INFO\] impl_1 STATUS = $st"
if {[string match "*write_bitstream Complete*" $st]} {
    write_hw_platform -fixed -include_bit -force -file [file normalize "../hello_plat/hw/hello_zynq.xsa"]
    puts "\[INFO\] fixed xsa exported"
}
