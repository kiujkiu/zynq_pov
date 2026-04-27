connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "BEFORE: BAUDGEN = [mrd 0xE0000018]"
mwr 0xE0000018 31
puts "AFTER:  BAUDGEN = [mrd 0xE0000018]"
exit 0
