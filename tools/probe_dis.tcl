connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "PC=[rrd pc]"
puts ""
puts "Mem 0xFFFFFF20 (32 bytes):"
puts [mrd 0xFFFFFF20 8]
puts ""
puts "Mem 0xFFFFFF00 (256 bytes around hang point):"
puts [mrd 0xFFFFFF00 64]
exit
