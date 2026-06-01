open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]

set ps7 [get_bd_cells processing_system7_0]
puts ""
puts "=== PS7 clock config ==="
foreach k {PCW_FPGA0_PERIPHERAL_FREQMHZ PCW_FPGA1_PERIPHERAL_FREQMHZ PCW_FPGA2_PERIPHERAL_FREQMHZ PCW_FPGA3_PERIPHERAL_FREQMHZ \
           PCW_FCLK0_PERIPHERAL_DIVISOR0 PCW_FCLK0_PERIPHERAL_DIVISOR1 \
           PCW_FCLK1_PERIPHERAL_DIVISOR0 PCW_FCLK1_PERIPHERAL_DIVISOR1 \
           PCW_IO_PLL_FREQMHZ PCW_ARM_PLL_FREQMHZ PCW_DDR_PLL_FREQMHZ \
           PCW_CLK0_FREQ PCW_CLK1_FREQ} {
    if {[catch {get_property CONFIG.$k $ps7} val]} continue
    puts "  $k = $val"
}
exit 0
