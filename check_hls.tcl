connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "POV_BASE 0x43C20000"
puts "POV_AP_CTRL (offset 0):"
puts [mrd -force 0x43C20000 1]
puts "BATCH_MODEL_LO 0x10:"
puts [mrd -force 0x43C20010 1]
puts "BATCH_NUM_POINTS 0x1c:"
puts [mrd -force 0x43C2001c 1]
puts "BATCH_RING_LO 0x24:"
puts [mrd -force 0x43C20024 1]
puts "BATCH_SLOT_BYTES 0x30:"
puts [mrd -force 0x43C20030 1]
puts "BATCH_SLOT_STRIDE 0x38:"
puts [mrd -force 0x43C20038 1]
exit 0
