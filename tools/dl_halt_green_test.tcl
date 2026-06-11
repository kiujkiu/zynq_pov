# dl bit, immediately halt ARM, then write SOLID GREEN to panel 1 — all in one xsdb session
set bit    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"

connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
mwr 0xE0000018 0x12
mwr 0xE0000034 0x05

# Do NOT con() — ARM remains halted, bridge cannot run.
# Now write SOLID GREEN to panel 1 BRAM:
configparams force-mem-access 1
set BASE 0x40020000
set FB_TOP1 [expr {$BASE + 0x8000}]
set FB_BOT1 [expr {$BASE + 0xC000}]
mwr -force $BASE 0
after 100
mwr -force 0xF8000180 0x00500500
puts "filling panel 1 with GREEN..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP1 + $i*4}] 0x0000FF00
    mwr -force [expr {$FB_BOT1 + $i*4}] 0x0000FF00
}
mwr -force [expr {$BASE + 0x14}] 8
mwr -force $BASE 0x561
after 200
puts "CTRL=[mrd -force $BASE 1]"
puts "done — ARM halted, panel 1 BRAM = GREEN, panel 1 should be all green"
exit 0
