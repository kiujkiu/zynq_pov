open_checkpoint D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper_routed.dcp

puts ""
puts "=== rgb_out2_reg.D pin drivers ==="
foreach b {0 1 2 3 4 5} {
    set reg [get_cells "hello_zynq_i/hub75e_panel_seq_0/inst/hub75e_rgb_out2_reg\[$b\]"]
    set dpin [get_pins -of $reg -filter {REF_PIN_NAME==D}]
    set dnet [get_nets -of $dpin]
    set drv_pin [get_pins -leaf -of $dnet -filter {DIRECTION==OUT}]
    set drv_cell [get_cells -of $drv_pin]
    set drv_ref [get_property REF_NAME $drv_cell]
    set init "N/A"
    catch { set init [get_property INIT $drv_cell] }
    puts "  out2 bit $b D <- $drv_ref ($drv_cell) INIT=$init"
    set lut_ipins [get_pins -of $drv_cell -filter {DIRECTION==IN}]
    set lut_inets [get_nets -of $lut_ipins]
    puts "    LUT inputs: $lut_inets"
}

puts ""
puts "=== rgb_out_reg.D drivers (for comparison) ==="
foreach b {0 1 2 3 4 5} {
    set reg [get_cells "hello_zynq_i/hub75e_panel_seq_0/inst/hub75e_rgb_out_reg\[$b\]"]
    set dpin [get_pins -of $reg -filter {REF_PIN_NAME==D}]
    set dnet [get_nets -of $dpin]
    set drv_pin [get_pins -leaf -of $dnet -filter {DIRECTION==OUT}]
    set drv_cell [get_cells -of $drv_pin]
    set drv_ref [get_property REF_NAME $drv_cell]
    set init "N/A"
    catch { set init [get_property INIT $drv_cell] }
    puts "  out  bit $b D <- $drv_ref ($drv_cell) INIT=$init"
    set lut_ipins [get_pins -of $drv_cell -filter {DIRECTION==IN}]
    set lut_inets [get_nets -of $lut_ipins]
    puts "    LUT inputs: $lut_inets"
}

close_design
