# synth_impl_led_panel.tcl — 跑 synth+impl+bitstream+XSA 给 led panel BD 后的工程
#
# Prerequisites: bd_add_led_panel_drv.tcl 已成功跑过 (axi_gpio_panel 在 BD),
# led_pins.xdc 已写好 panel signal package_pin.
#
# 跑法 (Windows):
#   D:\Vivado\2024.2\bin\vivado.bat -mode batch \
#     -source D:\claude_workspace\pov3d\zynq_pov\tools\synth_impl_led_panel.tcl \
#     -nojournal -log D:\claude_workspace\pov3d\zynq_pov\synth_led_panel.log
#
# 约 20-25 min on 20-core CPU.

open_project D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.xpr

# 1) Reset old runs (确保 fresh)
catch { reset_run impl_1 }
catch { reset_run synth_1 }

# 2) Synth
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "synth_1 failed: PROGRESS [get_property PROGRESS [get_runs synth_1]] STATUS [get_property STATUS [get_runs synth_1]]"
}
puts "synth_1 done"

# 3) Impl + bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 failed: PROGRESS [get_property PROGRESS [get_runs impl_1]] STATUS [get_property STATUS [get_runs impl_1]]"
}
puts "impl_1 done"

# 4) Export XSA (fixed platform, include bitstream)
set xsa_path D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.xsa
write_hw_platform -fixed -include_bit -force -file $xsa_path
puts "XSA exported: $xsa_path"

# 5) Report
report_utilization -file D:/claude_workspace/pov3d/zynq_pov/util_led_panel.rpt
report_timing_summary -file D:/claude_workspace/pov3d/zynq_pov/timing_led_panel.rpt
puts "reports written"

puts "DONE synth+impl+bitstream+XSA. Next:"
puts "  1) cd vitis_ws && regen platform 或在 Vitis 里 Update Hardware Specification"
puts "  2) grep XPAR_AXI_GPIO_PANEL_*_BASEADDR in xparameters.h"
puts "  3) 改 led_panel.c LED_PANEL_GPIO_BASE 成那个值"
puts "  4) 设 ENABLE_LED_PANEL_TEST=1 in helloworld.c, rebuild + JTAG dl"
exit 0
