# bd_fix_axi_to_fclk.tcl
# 诊断用：AXI 回到 FCLK_CLK0，只服务 axi_gpio（砍掉 v_tc/v_tpg 的 AXI 控制）
# 目的：验证 AXI + LED 能不能工作，排除 clk_wiz / clk_pixel 故障

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"

puts "=== Opening project ==="
open_project $proj_xpr
open_bd_design [get_files ${bd_name}.bd]

# -------- Step 1: 断开 SmartConnect 到 v_tc/v_tpg 的 AXI 接口 --------
puts "=== Step 1: Disconnect SmartConnect M01/M02 ==="
foreach intf {axi_smc/M01_AXI axi_smc/M02_AXI} {
    set ip [get_bd_intf_pins $intf]
    set nets [get_bd_intf_nets -of_objects $ip]
    foreach n $nets {
        puts "  delete $intf net [get_property NAME $n]"
        delete_bd_objs $n
    }
}

# 缩小 SmartConnect 到 1 个 MI (只留 M00 给 axi_gpio)
puts "=== Step 1b: Shrink SmartConnect NUM_MI=1 ==="
set_property CONFIG.NUM_MI {1} [get_bd_cells /axi_smc]

# -------- Step 2: AXI 时钟搬到 FCLK_CLK0 --------
set axi_pins {
    processing_system7_0/M_AXI_GP0_ACLK
    axi_smc/aclk
    axi_gpio_0/s_axi_aclk
    proc_sys_reset_0/slowest_sync_clk
}
puts "=== Step 2: AXI clocks -> FCLK_CLK0 ==="
foreach pin $axi_pins {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
}
set fclk [get_bd_pins processing_system7_0/FCLK_CLK0]
foreach pin $axi_pins {
    connect_bd_net $fclk [get_bd_pins $pin]
}

# 视频 IP 保留在 clk_pixel 域（即使 AXI 断了，reset 管脚还要保留原来的连接）
# proc_sys_reset_0 现在服务 FCLK 域，视频 IP 的 aresetn 之前连到 proc_sys_reset_0/peripheral_aresetn
# 视频现在跨时钟域 reset 用不上，但不影响 LED 实验

# -------- Step 3: validate & save --------
puts "=== Step 3: Validate & save ==="
catch {validate_bd_design} errmsg
puts "validate returned: $errmsg"
save_bd_design

puts "=== Regenerate outputs ==="
generate_target all [get_files ${bd_name}.bd] -force

puts "=== Synth + Impl + Bitstream ==="
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
puts "synth_1 status: [get_property STATUS [get_runs synth_1]]"
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
puts "impl_1 status: [get_property STATUS [get_runs impl_1]]"

puts "=== Export XSA ==="
open_run impl_1
write_hw_platform -fixed -include_bit -force "$proj_dir/hello_zynq_wrapper.xsa"
close_project
puts "=== DONE ==="
exit 0
