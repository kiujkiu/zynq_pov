# Read a few words from fb BRAM to verify load worked
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# Reload fb first (in case grid_ab_v28.py inline xsdb failed)
puts "Loading fb_top.bin → 0x4002C000..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_top.bin" -size w 0x4002C000 4096
puts "Loading fb_bot.bin → 0x40028000..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_bot.bin" -size w 0x40028000 4096

after 200

# Spot-check fb: read pixel at row 0 col 0 (top half) and middle
puts "fb_top[0] (cell 0,0 corner)  = [mrd 0x4002C000]"
puts "fb_top[64] (mid row 0)       = [mrd 0x4002C100]"
puts "fb_bot[0] (cell 2,0 corner)  = [mrd 0x40028000]"
puts "fb_bot[64]                   = [mrd 0x40028100]"
puts "fb_bot[127] (cell 2,7 right) = [mrd 0x400281FC]"

# Set use_fb mode 0 + overlap_en=1, ensure TUNIT=32
mwr 0x40020014 32
mwr 0x40020000 0x561
after 300
puts "CTRL=[mrd 0x40020000] STATUS=[mrd 0x4002000C]"
exit 0
