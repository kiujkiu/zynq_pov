open_hw_manager
connect_hw_server -allow_non_jtag
foreach t [get_hw_targets] {
    puts "=== TARGET $t"
    current_hw_target $t
    if {[catch {open_hw_target} e]} { puts "===   打不开: $e"; continue }
    foreach d [get_hw_devices] {
        puts "===   设备 $d  part=[get_property PART $d]"
    }
    close_hw_target
}
puts "=== 枚举结束 ==="
