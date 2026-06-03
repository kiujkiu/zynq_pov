connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "watching VDMA park_ptr 8 samples..."
for {set i 0} {$i < 8} {incr i} {
    after 100
    set p [mrd -force 0x43C10028 1]
    set s [mrd -force 0x43C10004 1]
    puts "  t=$i park=$p  SR=$s"
}
# Also fill fb_b white center
puts "filling fb_b (0x14000000) center 400x200 with white..."
for {set y 260} {$y < 460} {incr y} {
    set row_base [expr {0x14000000 + $y * 3840}]
    for {set x 440} {$x < 840} {incr x 4} {
        mwr -force [expr {$row_base + $x * 3}] 0xFFFFFFFF
    }
}
puts "done."
exit 0
