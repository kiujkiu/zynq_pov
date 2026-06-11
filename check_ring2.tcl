connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "POV_AP_CTRL: [mrd -force 0x43C20000 1]"
puts ""
# scan multiple slots looking for non-zero
puts "=== scan all 72 slots for nonzero ==="
set total_nz 0
for {set s 0} {$s < 72} {incr s} {
    set addr [expr {0x12000000 + $s * 38160}]
    # read first 16 bytes of each slot
    set v0 [mrd $addr 1]
    set v1 [mrd [expr {$addr + 8000}] 1]
    set v2 [mrd [expr {$addr + 19000}] 1]
    set v3 [mrd [expr {$addr + 30000}] 1]
    # check if any contain non-zero pattern
    foreach v "$v0 $v1 $v2 $v3" {
        if {[regexp {([0-9A-F]+):\s+([0-9A-F]+)} $v match addr val]} {
            if {$val ne "00000000"} {
                puts "slot $s nonzero at $match"
                incr total_nz
            }
        }
    }
}
puts "total nonzero samples: $total_nz / [expr {72 * 4}]"
exit 0
