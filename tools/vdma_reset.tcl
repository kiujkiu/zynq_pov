connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "BEFORE: CR=[mrd -force 0x43C10000 1]  SR=[mrd -force 0x43C10004 1]"
# Stop VDMA
mwr -force 0x43C10000 0x00000000
after 100
# SW reset (bit 2)
mwr -force 0x43C10000 0x00000004
after 200
puts "RESET:  CR=[mrd -force 0x43C10000 1]  SR=[mrd -force 0x43C10004 1]"
# Re-init: circular mode, RS=1, frmcntirqen, gen_lock_src
# Set Vsize/Hsize/Stride/StartAddr first
mwr -force 0x43C10058 0x00000F00  ; # Stride
mwr -force 0x43C10054 0x00000F00  ; # Hsize
mwr -force 0x43C1005C 0x10000000  ; # StartAddr0
mwr -force 0x43C10060 0x14000000  ; # StartAddr1
# Park mode + Circular + RS
mwr -force 0x43C10000 0x00010003
after 50
# Last: Vsize starts transfer
mwr -force 0x43C10050 0x000002D0  ; # Vsize = 720 (this triggers start)
after 300
puts "AFTER:  CR=[mrd -force 0x43C10000 1]  SR=[mrd -force 0x43C10004 1]"
puts "        Park=[mrd -force 0x43C10028 1]"
exit 0
