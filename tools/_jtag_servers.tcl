connect
after 1500
puts "--- jtag servers ---"
catch { jtag servers } servers_out
puts $servers_out
puts "--- jtag targets ---"
catch { jtag targets } targets_out
puts $targets_out
puts "--- jtag frequency / scan ---"
catch { jtag scan } scan_out
puts $scan_out
exit 0
