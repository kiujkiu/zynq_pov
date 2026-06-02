# Load anime fb (downsampled to 128×64) into HUB75E BRAM + enable
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# clean disable first
mwr 0x40020000 0
after 200
# top half (panel rows 0..31) → write to bot bank 0x4002C000 (panel 物理拼接反)
puts "loading fb_anime_top.bin → 0x4002C000..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_top.bin" -size w 0x4002C000 4096
# bot half → top bank 0x40028000
puts "loading fb_anime_bot.bin → 0x40028000..."
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_bot.bin" -size w 0x40028000 4096
# TUNIT=8 sweet spot, overlap mode
mwr 0x40020014 8
mwr 0x40020000 0x561
after 300
puts "CTRL=[mrd 0x40020000] STATUS=[mrd 0x4002000C]"
exit 0
