connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "BEFORE BAUDGEN: [mrd 0xE0000018]"
puts "BEFORE BAUDDIV: [mrd 0xE0000034]"
mwr 0xE0000018 27
mwr 0xE0000034 3
after 100
puts "AFTER BAUDGEN: [mrd 0xE0000018]"
puts "AFTER BAUDDIV: [mrd 0xE0000034]"
exit 0
