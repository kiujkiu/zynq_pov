connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop

puts "=== Set ALL BATCH registers fresh ==="
mwr -force 0x43C20010 0x1A000000  ;# MODEL_LO
mwr -force 0x43C20014 0x00000000  ;# MODEL_HI
mwr -force 0x43C2001C 1000         ;# NUM_POINTS - try 1000
mwr -force 0x43C20024 0x12000000  ;# RING_LO
mwr -force 0x43C20028 0x00000000  ;# RING_HI
mwr -force 0x43C20030 38160        ;# SLOT_BYTES
mwr -force 0x43C20038 318          ;# SLOT_STRIDE = SLICE_W*3
mwr -force 0x43C20040 0            ;# PHASE
mwr -force 0x43C20048 72           ;# N_SLOTS
mwr -force 0x43C20050 0            ;# SLICE_MODE
mwr -force 0x43C20058 0            ;# SLICE_HALF_THICK

puts "Set: MODEL=0x1A000000 NUM=1000 RING=0x12000000 SLOTS=72"

puts ""
puts "Clear slot 0 to AA"
mwr 0x12000000 0xAAAAAAAA 9540
puts "Slot 0 head pre-fire: [mrd 0x12000000 4]"

puts ""
puts "Fire HLS"
mwr -force 0x43C20000 0x1
after 200
puts "AP_CTRL: [mrd -force 0x43C20000 1]"

puts ""
puts "Sample slot 0 multiple positions:"
for {set y 0} {$y < 120} {incr y 10} {
    set addr [expr {0x12000000 + $y * 318}]
    set v [mrd $addr 1]
    if {[regexp {([0-9A-F]+):\s+([0-9A-F]+)} $v match _ val]} {
        if {$val != "AAAAAAAA"} {
            puts [format "  row %d (0x%x): %s NONZERO!" $y $addr $val]
        }
    }
}
puts "(none above means slot 0 entirely AA)"

con
exit 0
