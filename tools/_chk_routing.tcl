open_checkpoint D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper_routed.dcp

puts ""
puts "=== Pin → Net mapping ==="
foreach pin {AA19 AA13 Y13 AB15 AB14 Y16  AB22 AA22 AA21 Y20 AB21 Y21} {
    set p [get_package_pins $pin]
    set nets [get_nets -of [get_sites -of $p]]
    set ports [get_ports -of $p]
    puts "  $pin: port=$ports nets=$nets"
}

puts ""
puts "=== rgb_out2 register expansion ==="
foreach b {0 1 2 3 4 5} {
    set regs [get_cells -hierarchical -filter "NAME =~ *hub75e_rgb_out2_reg\\[$b\\]*"]
    puts "  rgb_out2\[$b\] reg cells: $regs"
}

puts ""
puts "=== Nets driving panel 2 OBUFs ==="
foreach port {hub75e_rgb2[0] hub75e_rgb2[1] hub75e_rgb2[2] hub75e_rgb2[3] hub75e_rgb2[4] hub75e_rgb2[5]} {
    set pp [get_ports $port]
    set net [get_nets -of $pp]
    set driver [get_cells -of [get_pins -leaf -of $net -filter {DIRECTION==OUT}]]
    puts "  $port → driver_cell: $driver"
}

close_design
