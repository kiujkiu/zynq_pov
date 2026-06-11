connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }

# Make sure CTRL is in SOLID mode (top half COLOR, bot half COLOR_BOT)
mwr -force 0x40020000 0x501

# COLOR reg layout: R[7:0] G[15:8] B[23:16]  (8-bit per channel)
set colors {
    0x000000
    0x0000FF
    0x00FF00
    0x00FFFF
    0xFF0000
    0xFF00FF
    0xFFFF00
    0xFFFFFF
}
set names {BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE}

set reps 5
set ms_each 600

puts "Cycling 8 colors x $reps reps, ${ms_each}ms each."

for {set rep 0} {$rep < $reps} {incr rep} {
    for {set i 0} {$i < 8} {incr i} {
        set c [lindex $colors $i]
        set n [lindex $names $i]
        mwr -force 0x40020004 $c
        mwr -force 0x40020010 $c
        puts "rep $rep  ${n}\t($c)"
        after $ms_each
    }
}

# End on a safe color (off) so panels do not stay locked at white
mwr -force 0x40020004 0
mwr -force 0x40020010 0
puts "Done. Ended on BLACK."
exit 0
