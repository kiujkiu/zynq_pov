# 只读勘察 hello_zynq BD 结构, 不改动
open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
puts "===== CELLS ====="
foreach c [get_bd_cells] { puts "  $c  ([get_property VLNV $c])" }
puts "===== PS7 HP/ACP 口使能 ====="
set ps [get_bd_cells -filter {VLNV =~ *processing_system7*}]
foreach p {PCW_USE_S_AXI_HP0 PCW_USE_S_AXI_HP1 PCW_USE_S_AXI_HP2 PCW_USE_S_AXI_HP3 PCW_USE_S_AXI_ACP PCW_USE_M_AXI_GP0 PCW_USE_M_AXI_GP1} {
    catch { puts "  $p = [get_property CONFIG.$p $ps]" }
}
puts "===== FCLK ====="
foreach p {PCW_FPGA0_PERIPHERAL_FREQMHZ PCW_FPGA1_PERIPHERAL_FREQMHZ PCW_EN_CLK1_PORT} {
    catch { puts "  $p = [get_property CONFIG.$p $ps]" }
}
puts "===== 显示 IP (hub75e) 接口/时钟 ====="
set hub [get_bd_cells -quiet -filter {VLNV =~ *hub75e*}]
puts "  cell: $hub"
foreach pin [get_bd_intf_pins -quiet -of_objects $hub] { puts "    intf: $pin" }
foreach pin [get_bd_pins -quiet $hub/*clk* ] { puts "    clk pin: $pin  net=[get_bd_nets -quiet -of_objects $pin]" }
puts "===== SmartConnect/Interconnect ====="
foreach sc [get_bd_cells -quiet -filter {VLNV =~ *smartconnect* || VLNV =~ *axi_interconnect*}] {
    puts "  $sc  ([get_property VLNV $sc])  NUM_SI=[get_property -quiet CONFIG.NUM_SI $sc] NUM_MI=[get_property -quiet CONFIG.NUM_MI $sc]"
}
puts "===== 地址分配 ====="
catch { foreach a [get_bd_addr_segs] { puts "  $a" } }
puts "===== 空闲 clk 源 ====="
foreach n [get_bd_nets -quiet -filter {NAME =~ *FCLK* || NAME =~ *clk*}] { puts "  net: $n" }
puts "===== DONE INSPECT ====="
close_project
exit 0
