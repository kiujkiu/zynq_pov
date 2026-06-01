open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
current_bd_design [get_bd_designs hello_zynq]
puts ""
puts "=== hub75e_panel_seq_0 AXI 端口属性 ==="
foreach p [get_bd_intf_pins hub75e_panel_seq_0/*] {
    puts "  intf: $p  vlnv=[get_property VLNV $p]"
}
foreach k {CONFIG.PROTOCOL CONFIG.ADDR_WIDTH CONFIG.DATA_WIDTH} {
    set v [get_property $k [get_bd_intf_pins hub75e_panel_seq_0/s_axi]]
    puts "  s_axi $k = $v"
}
puts ""
puts "=== address mapping (hub75e) ==="
foreach a [get_bd_addr_segs] {
    set name [get_property NAME $a]
    if {[string match "*hub75e*" $name] || [string match "*panel*" $name]} {
        puts "  $a  offset=[get_property OFFSET $a]  range=[get_property RANGE $a]"
    }
}
exit 0
