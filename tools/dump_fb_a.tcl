# Dump 1280×720×3 fb_a content from DDR
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "dumping fb_a (0x10000000, 2.76 MB) → fb_a.bin"
mrd -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_a.bin" 0x10000000 691200
puts "done"
exit 0
