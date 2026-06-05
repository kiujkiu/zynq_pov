# Query BD address assignments
open_project 02_hello_zynq.xpr
open_bd_design [get_files hello_zynq.bd]
puts "===== assigned bd_addr_segs ====="
foreach seg [get_bd_addr_segs] {
    puts "$seg"
    puts "  offset: [get_property OFFSET $seg]"
    puts "  range:  [get_property RANGE $seg]"
}
exit 0
