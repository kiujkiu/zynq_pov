# Probe PL AXI read after fpga -file
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"

connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
after 200
# release FCLK resets (SLCR 0xF8000240, write 0 to release all 4)
mwr 0xF8000240 0
after 100
configparams force-mem-access 1
puts "--- try mrd 0x40020000 ---"
catch { mrd -force 0x40020000 } r1
puts "result: $r1"
puts "--- try mrd 0x40020008 ---"
catch { mrd -force 0x40020008 } r2
puts "result: $r2"
exit 0
