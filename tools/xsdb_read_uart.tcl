connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== UART0 ==="
puts "CR      = [mrd 0xE0000000]"
puts "BAUDGEN = [mrd 0xE0000018]"
puts "BAUDDIV = [mrd 0xE0000034]"
puts "=== UART1 ==="
puts "CR      = [mrd 0xE0001000]"
puts "BAUDGEN = [mrd 0xE0001018]"
puts "BAUDDIV = [mrd 0xE0001034]"
exit 0
