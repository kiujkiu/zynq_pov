connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# First, halt ARM so it doesn't keep overwriting fb_a with ring buffer scale-blit
targets -set -nocase -filter {name =~ "ARM*#0"}
catch {stop}
targets -set -nocase -filter {name =~ "APU*"}
puts "loading red/blue test pattern to fb_a (0x10000000)"
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_red.bin" -size b 0x10000000 2764800
puts "fb0=[format 0x%08x [mrd -value 0x10000000]]"
puts "fbm=[format 0x%08x [mrd -value 0x10153000]]"
exit 0
