connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
puts "BEFORE: CTRL=[mrd -force 0x43C00000 1]"
puts "        ACTIVE=[mrd -force 0x43C00060 1]  HSYNC=[mrd -force 0x43C00070 1]"
puts "        VBLANK=[mrd -force 0x43C00074 1]  VSYNC=[mrd -force 0x43C00078 1]"
puts "        FRAME=[mrd -force 0x43C00084 1]"

# Disable generator first
mwr -force 0x43C00000 0
after 50

# Write 720p60 generator timing
# 0x060 GEN_ACTIVE_SIZE: V_active[28:16]=720 H_active[12:0]=1280 → 0x02D00500
mwr -force 0x43C00060 0x02D00500
# 0x06C GEN_POLARITY: bits[0]=ActiveChromaPol bits[1]=ActiveVideoPol bits[2]=FieldId bits[3]=Vblank bits[4]=Vsync bits[5]=Hblank bits[6]=Hsync
# 720p: Hsync=1 Vsync=1 ActiveVideo=1 → 0x56 ? Actually let's be safe: all 1
mwr -force 0x43C0006C 0x0000003F
# 0x070 GEN_HSYNC: hsync_end[28:16]=1430 hsync_start[12:0]=1390
mwr -force 0x43C00070 0x0596056E
# 0x074 GEN_VBLANK_HORI_F0: keep same start/end (no special vblank-h offset)
mwr -force 0x43C00074 0x05000500
# 0x078 GEN_VSYNC_F0: vsync_end[28:16]=730 vsync_start[12:0]=725
mwr -force 0x43C00078 0x02DA02D5
# 0x080 GEN_VSYNC_F1: same
mwr -force 0x43C00080 0x02DA02D5
# 0x07C GEN_VBLANK_HORI_F1: same
mwr -force 0x43C0007C 0x05000500
# 0x084 GEN_FRAME_SIZE: V_total[28:16]=750 H_total[12:0]=1650
mwr -force 0x43C00084 0x02EE0672

# Enable generator + REG_UPDATE
mwr -force 0x43C00000 0x06
after 100

puts "AFTER:  CTRL=[mrd -force 0x43C00000 1]"
puts "        ACTIVE=[mrd -force 0x43C00060 1]  HSYNC=[mrd -force 0x43C00070 1]"
puts "        VBLANK=[mrd -force 0x43C00074 1]  VSYNC=[mrd -force 0x43C00078 1]"
puts "        FRAME=[mrd -force 0x43C00084 1]"
puts "        ERROR=[mrd -force 0x43C00010 1]"
exit 0
