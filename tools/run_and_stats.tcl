# Program board, let it run, generate ping traffic externally, then read stats

proc r {label off} {
    set addr [expr {0xE000B000 + $off}]
    if {[catch {mrd -value $addr} v]} {
        puts [format "%-15s 0x%08x = BLOCKED" $label $addr]
    } else {
        puts [format "%-15s 0x%08x = 0x%08x (%u)" $label $addr $v $v]
    }
}

set bit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/lwip_echo_server/_ide/bitstream/hello_zynq_wrapper.bit"
set psinit "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/lwip_echo_server/_ide/psinit/ps7_init.tcl"
set elf  "D:/workspace/zynq_pov/02_hello_zynq/vitis_ws/lwip_echo_server/build/lwip_echo_server.elf"

connect
after 2000
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1000
fpga -file $bit
source $psinit
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "ARM*#0"}
dow $elf
con
puts ">>> CPU started, waiting 15s for lwIP init + user ping..."
after 15000

puts "=== Reading MAC stats ==="
targets -set -nocase -filter {name =~ "APU*"}
r NWCTRL 0x000
r NWCFG  0x004
r NWSR   0x008
r DMACR  0x010
r TXSR   0x014
r RXSR   0x020
r ISR    0x024
puts "--- TX ---"
r FRAMES_TX    0x108
puts "--- RX ---"
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

exit 0
