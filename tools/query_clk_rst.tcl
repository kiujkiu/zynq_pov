open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
foreach p [list s_axi_aclk s_axi_aresetn] {
    set pin [get_bd_pins -quiet hub75e_panel_seq_0/$p]
    set net [get_bd_nets -quiet -of_objects $pin]
    puts "$p: pin=$pin net=$net"
    foreach other [get_bd_pins -of_objects $net] {
        if {$other ne $pin} { puts "    connects to: $other" }
    }
}
exit 0
