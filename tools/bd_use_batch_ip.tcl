# bd_use_batch_ip.tcl
# 替换 BD 里的 pov_project_0 为新的 pov_project_batch IP.
# 接口稍有不同 (没有 angle_idx/dst_x/dst_y, 加了 ring_base/slot_bytes/slot_stride/phase/n_slots)
# 但 m_axi 和 s_axi_control 结构一致, 所以能原地替换.

set proj_dir "D:/workspace/zynq_pov/02_hello_zynq"
set proj_xpr "$proj_dir/02_hello_zynq.xpr"
set bd_name  "hello_zynq"
set ip_repo  "D:/workspace/zynq_pov/hls_proj/proj_pov/solution1/impl/ip"

puts "=== Open project ==="
open_project $proj_xpr
set existing_repos [get_property ip_repo_paths [current_project]]
if {[lsearch -exact $existing_repos $ip_repo] < 0} {
    set_property ip_repo_paths [concat $existing_repos $ip_repo] [current_project]
}
update_ip_catalog
open_bd_design [get_files ${bd_name}.bd]

# --- 升级已被锁的 IP (HLS IP 重综合后) ---
set locked_ips [get_ips -filter "IS_LOCKED==1"]
if {[llength $locked_ips] > 0} {
    puts "=== Upgrading locked IPs: $locked_ips ==="
    upgrade_ip $locked_ips
    export_ip_user_files -of_objects $locked_ips -no_script -sync -force -quiet
}

# --- 删除老 pov_project_0 ---
puts "=== Delete old pov_project_0 ==="
foreach seg {/processing_system7_0/Data/SEG_pov_project_0_Reg} {
    set s [get_bd_addr_segs -quiet $seg]
    if {[llength $s]} { delete_bd_objs $s }
}
if {[llength [get_bd_cells -quiet pov_project_0]]} {
    delete_bd_objs [get_bd_cells pov_project_0]
}

# --- 实例化 pov_project_batch IP (如果不存在) ---
if {![llength [get_bd_cells -quiet pov_project_batch_0]]} {
    puts "=== Add pov_project_batch_0 ==="
    create_bd_cell -type ip -vlnv povlab:user:pov_project_batch:1.0 pov_project_batch_0
} else {
    puts "=== pov_project_batch_0 already exists, reusing ==="
}

# --- 接控制/数据 (跳过已连的) ---
proc safe_intf_connect {src dst} {
    if {![llength [get_bd_intf_nets -of_objects [get_bd_intf_pins $dst]]]} {
        connect_bd_intf_net [get_bd_intf_pins $src] [get_bd_intf_pins $dst]
    }
}
safe_intf_connect axi_smc/M03_AXI pov_project_batch_0/s_axi_control
safe_intf_connect pov_project_batch_0/m_axi_gmem0 axi_smc_pov_hp/S00_AXI
safe_intf_connect pov_project_batch_0/m_axi_gmem1 axi_smc_pov_hp/S01_AXI

# --- 时钟 FCLK_CLK3 (150 MHz) ---
set fclk3 [get_bd_pins processing_system7_0/FCLK_CLK3]
foreach pin {pov_project_batch_0/ap_clk} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $fclk3 $p
}

# --- 复位 ---
set rst_pov [get_bd_pins proc_sys_reset_pov/peripheral_aresetn]
foreach pin {pov_project_batch_0/ap_rst_n} {
    set p [get_bd_pins $pin]
    foreach n [get_bd_nets -of_objects $p] { disconnect_bd_net $n $p }
    connect_bd_net $rst_pov $p
}

# --- 地址 (保持 0x43C20000 以便 ARM 代码少改) ---
assign_bd_address -offset 0x43C20000 -range 64K \
    [get_bd_addr_segs {pov_project_batch_0/s_axi_control/Reg}] -force

puts "=== Validate & save ==="
catch {validate_bd_design} e
puts "validate: $e"
save_bd_design
generate_target all [get_files ${bd_name}.bd] -force

puts "=== Build bitstream ==="
reset_run synth_1
reset_run impl_1
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
