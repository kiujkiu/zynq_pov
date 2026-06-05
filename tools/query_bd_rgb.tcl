# Verify hub75e_rgb_out connections after BD recreate
open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
puts "===== hub75e_panel_seq_0 output pins ====="
foreach p [get_bd_pins -of_objects [get_bd_cells hub75e_panel_seq_0] -filter {DIR == O}] {
    set L [get_property LEFT $p]
    set R [get_property RIGHT $p]
    set net [get_bd_nets -quiet -of_objects $p]
    set ports [get_bd_ports -quiet -of_objects $net]
    puts "  $p L=$L R=$R net=$net port=$ports"
}
puts "===== hub75e_rgb external port ====="
foreach pt [get_bd_ports -quiet hub75e_rgb*] {
    puts "  $pt  left=[get_property LEFT $pt]  right=[get_property RIGHT $pt]"
}
exit 0
