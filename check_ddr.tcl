connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== MODEL_ADDR (0x1A000000) first 16 words ==="
puts [mrd 0x1A000000 16]
puts "=== model_n at 0x0011c25c ==="
puts [mrd 0x0011c25c 1]
puts "=== magic at 0x1F000000 ==="
puts [mrd 0x1F000000 2]
exit 0
