connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
puts "writing 4096 pixels fb_top = 0xFFFFFF..."
for {set i 0} {$i < 4096} {incr i 8} {
    mwr [expr {0x40028000 + $i * 4}] 0xFFFFFF
}
puts "writing 4096 pixels fb_bot = 0xFFFFFF..."
for {set i 0} {$i < 4096} {incr i 8} {
    mwr [expr {0x4002C000 + $i * 4}] 0xFFFFFF
}
mwr 0x40020000 0x00000521
after 200
puts "CTRL=[format 0x%08x [mrd -value 0x40020000]] STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
