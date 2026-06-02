# Test mode isolation: serial vs overlap, use_fb=0 vs 1
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# Set known COLOR
mwr 0x40020014 32
mwr 0x40020004 0xFF8080   ; # pink-ish color (R+G半+B半)
mwr 0x40020010 0xFF8080

# 1) Serial mode 0 SOLID, use_fb=0
mwr 0x40020000 0x501
after 800
puts "1) SERIAL  mode0 use_fb=0 CTRL=0x501 STATUS=[mrd 0x4002000C]"
after 4000

# 2) Overlap mode 0 SOLID, use_fb=0
mwr 0x40020000 0x541
after 800
puts "2) OVERLAP mode0 use_fb=0 CTRL=0x541 STATUS=[mrd 0x4002000C]"
after 4000

# 3) Reload fb (in case earlier load broken)
puts "Reloading fb..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_top.bin" -size w 0x4002C000 4096
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_bot.bin" -size w 0x40028000 4096

# 4) Serial use_fb=1 → should show grid
mwr 0x40020000 0x521
after 800
puts "3) SERIAL  mode0 use_fb=1 CTRL=0x521 STATUS=[mrd 0x4002000C]"
after 4000

# 5) Overlap use_fb=1 → should show same grid if BCM preserved
mwr 0x40020000 0x561
after 800
puts "4) OVERLAP mode0 use_fb=1 CTRL=0x561 STATUS=[mrd 0x4002000C]"

exit 0
