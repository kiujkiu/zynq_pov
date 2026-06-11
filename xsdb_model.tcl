connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
# model_n is at address - need symbol. Use nm equivalent.
# Just check MODEL_ADDR (model array) first 32 bytes
puts "=== MODEL_ADDR (0x11000000) first 32 bytes ==="
puts [mrd 0x11000000 8]
# Check BATCH IP registers (POV IP base)
# Find POV_BASE
puts "=== Check pov_render output: ring slot 18 (angle 90°) ==="
puts [mrd 0x120a7b20 16]
puts "=== Check pov_render output: ring slot 36 (angle 180°) ==="
puts [mrd 0x1214f640 16]
exit 0
