open_checkpoint D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper_routed.dcp

puts ""
puts "=== rgb_out vs rgb_out2 register existence ==="
foreach pattern {hub75e_rgb_out_reg hub75e_rgb_out2_reg} {
    set cells [get_cells -hierarchical -filter "NAME =~ *$pattern*"]
    puts "  $pattern: count=[llength $cells]"
    foreach c [lrange $cells 0 9] { puts "    $c" }
}

puts ""
puts "=== Net hub75e_rgb_out2\[N\] driver (the wire from reg to OBUF input) ==="
foreach b {0 1 2 3 4 5} {
    set net [get_nets "hello_zynq_i/hub75e_panel_seq_0/inst/hub75e_rgb_out2\[$b\]"]
    if {[llength $net] > 0} {
        set drv_pins [get_pins -leaf -of $net -filter {DIRECTION==OUT}]
        set drv_cells [get_cells -of $drv_pins]
        puts "  rgb_out2\[$b\] net driver: cell=$drv_cells pin=$drv_pins"
    } else {
        puts "  rgb_out2\[$b\] NET NOT FOUND"
    }
}

puts ""
puts "=== OBUF rgb_out2\[N\] input source ==="
foreach b {0 1 2 3 4 5} {
    set ob [get_cells -hierarchical -filter "NAME =~ *hub75e_rgb2_OBUF\\[$b\\]_inst*"]
    set ipin [get_pins -of $ob -filter {DIRECTION==IN && NAME =~ *I}]
    set inet [get_nets -of $ipin]
    set drv [get_cells -of [get_pins -leaf -of $inet -filter {DIRECTION==OUT}]]
    puts "  hub75e_rgb2\[$b\] OBUF I-net=$inet  driver_cell=$drv"
}

close_design
