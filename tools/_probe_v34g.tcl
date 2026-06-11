connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "old base 0x40010000:"
catch { puts "  [mrd 0x40010000 1]" } err1
puts "  err: $err1"
puts "new base 0x40020000:"
catch { puts "  [mrd 0x40020000 1]" } err2
puts "  err: $err2"
exit 0
