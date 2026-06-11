open_project 02_hello_zynq.xpr
puts ""
puts "=== ALL constraint files ==="
foreach f [get_files -of_objects [get_filesets constrs_1]] {
    set enabled [get_property IS_ENABLED $f]
    puts "  IS_ENABLED=$enabled  $f"
}
puts ""
puts "=== net ↔ PACKAGE_PIN (BANK 33 only, after impl) ==="
open_run impl_1 -name impl_1
foreach port [list hub75e_rgb hub75e_dclk hub75e_lat hub75e_oe hub75e_addr] {
    set p [get_ports -quiet "${port}*"]
    foreach pp $p {
        set loc [get_property PACKAGE_PIN $pp]
        puts "  $pp  →  $loc"
    }
}
exit 0
