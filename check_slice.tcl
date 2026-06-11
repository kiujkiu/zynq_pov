connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "BATCH_SLICE_MODE 0x50: [mrd -force 0x43C20050 1]"
puts "BATCH_SLICE_HALF_THICK 0x58: [mrd -force 0x43C20058 1]"
puts "BATCH_PHASE 0x40: [mrd -force 0x43C20040 1]"
puts "BATCH_N_SLOTS 0x48: [mrd -force 0x43C20048 1]"
exit 0
