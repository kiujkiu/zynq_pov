connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "ring0=[format 0x%08x [mrd -value 0x12000000]]"
puts "ring1=[format 0x%08x [mrd -value 0x12010000]]"
puts "fb_b0=[format 0x%08x [mrd -value 0x14000000]]"
puts "fb_a0=[format 0x%08x [mrd -value 0x10000000]]"
exit 0
