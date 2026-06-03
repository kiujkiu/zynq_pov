connect
after 1500
puts "---targets---"
puts [targets]
puts "---jtag targets---"
catch { puts [jtag targets] }
exit 0
