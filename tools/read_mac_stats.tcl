connect
targets -set -nocase -filter {name =~ "APU*"}

proc r {label off} {
    set addr [expr {0xE000B000 + $off}]
    if {[catch {mrd -value $addr} v]} {
        puts [format "%-15s 0x%08x = BLOCKED" $label $addr]
    } else {
        puts [format "%-15s 0x%08x = 0x%08x (%u)" $label $addr $v $v]
    }
}

puts "=== Status ==="
r NWCTRL   0x000
r NWCFG    0x004
r NWSR     0x008
r DMACR    0x010
r TXSR     0x014
r RXSR     0x020
r ISR      0x024

puts "=== TX frames ==="
r FRAMES_TX    0x108

puts "=== RX frames (key diagnostic) ==="
r FRAMES_RX    0x158
r BROADCAST_RX 0x15C
r UNDERSIZE_RX 0x18C
r OVERSIZE_RX  0x190
r JABBERS_RX   0x194
r FCS_ERR_RX   0x198
r LEN_ERR_RX   0x19C
r RX_SYMBOL    0x1A0
r RX_ALIGNMENT 0x1A4
r RX_RESOURCE  0x1A8
r RX_OVERRUN   0x1AC

disconnect
exit 0
