# 探测: AXI 到 PL 是否活着, hub75e 是否响应
set bit    "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/hello_zynq.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"

connect
after 1500
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1500
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
after 2000

# 不跑 ELF, 用 APU 直接探 AXI
configparams force-mem-access 1

puts ""
puts "=== AXI 各地址读测试 (slow path) ==="
# 各 PL IP base 地址
foreach {name addr} {
    "axi_gpio_panel_0x40000000" 0x40000000
    "hub75e_0x40020000"         0x40020000
    "axi_gpio_0_0x41200000"     0x41200000
    "v_tc_0x43C00000"           0x43C00000
    "vdma_0x43C10000"           0x43C10000
    "pov_proj_0x43C20000"       0x43C20000
} {
    set rc [catch {mrd $addr} res]
    if {$rc} {
        puts "$name → ERROR: $res"
    } else {
        puts "$name → $res"
    }
}

exit 0
