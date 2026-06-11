connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
puts "Halted ARM core 0. Pushing SOLID red to hub75e_panel_seq_0 (0x40020000)."

# CTRL=0 disable
mwr -force 0x40020000 0
# COLOR top half = pure red (R[7:0]=0xFF)
mwr -force 0x40020004 0x000000FF
# COLOR_BOT = pure red (so 1/32 scan bottom half also red)
mwr -force 0x40020010 0x000000FF
# PARAM default
mwr -force 0x40020008 0
# TUNIT default 96
mwr -force 0x40020014 96
# CTRL = enable | mode=SOLID(0) | use_fb=0 | abits=5 (1/32 scan)
#       bit0=1 | bits3:1=000 | bit5=0 | bits12:8=5(<<8=0x500)
mwr -force 0x40020000 0x501

after 50
puts "CTRL=[mrd -force 0x40020000 1]"
puts "STATUS=[mrd -force 0x4002000C 1]"
puts "Done. ARM stays HALTED so it cannot touch CTRL."
exit 0
