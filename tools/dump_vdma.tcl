# 读 VDMA MM2S Start Address regs (0x5C-0x98) 看 VDMA 实际取的是什么地址
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
after 200
set base 0x43c10000  ;# VDMA base
puts "=== VDMA MM2S regs ==="
puts "DMACR     [mrd [expr $base + 0x00] 1]"
puts "DMASR     [mrd [expr $base + 0x04] 1]"
puts "PARK_PTR  [mrd [expr $base + 0x28] 1]"
puts "REG_INDEX [mrd [expr $base + 0x14] 1]"
puts "VSIZE     [mrd [expr $base + 0x50] 1]"
puts "HSIZE     [mrd [expr $base + 0x54] 1]"
puts "FRMDLY_STRIDE [mrd [expr $base + 0x58] 1]"
puts "MM2S_START_ADDR1 (fstore0) [mrd [expr $base + 0x5C] 1]"
puts "MM2S_START_ADDR2 (fstore1) [mrd [expr $base + 0x60] 1]"
puts "MM2S_START_ADDR3 (fstore2) [mrd [expr $base + 0x64] 1]"
puts "=== Read at advertised fstore addrs (first 8 words each) ==="
catch {mrd [mrd [expr $base + 0x5C]] 8} d0; puts "fstore0 data: $d0"
catch {mrd [mrd [expr $base + 0x60]] 8} d1; puts "fstore1 data: $d1"
con
exit 0
