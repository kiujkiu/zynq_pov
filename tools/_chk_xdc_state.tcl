open_project 02_hello_zynq.xpr
foreach f [get_files -filter {FILE_TYPE == XDC}] {
    puts "[get_property is_enabled $f] : $f"
}
