connect
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
puts "CTRL   (0x40020000) = [format 0x%08x [mrd -value 0x40020000]]"
puts "COLOR  (0x40020004) = [format 0x%08x [mrd -value 0x40020004]]"
puts "PARAM  (0x40020008) = [format 0x%08x [mrd -value 0x40020008]]"
puts "STATUS (0x4002000C) = [format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
