connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "dumping fb_b (0x14000000)"
mrd -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_b.bin" 0x14000000 691200
puts "done"
exit 0
