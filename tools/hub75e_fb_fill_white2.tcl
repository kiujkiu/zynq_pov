connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
# xsdb mwr <addr> <value> <num-words> 写 N 个连续 word 同值
puts "writing 4096 pixels fb_top = 0xFFFFFF (all white)..."
mwr 0x40028000 0xFFFFFF 4096
puts "writing 4096 pixels fb_bot = 0xFFFFFF..."
mwr 0x4002C000 0xFFFFFF 4096
mwr 0x40020000 0x00000521
after 200
puts "CTRL=[format 0x%08x [mrd -value 0x40020000]] STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
