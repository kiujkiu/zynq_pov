connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
# 切到 use_fb=1, mode 0 SOLID (mode 不重要, use_fb 接管 pattern source)
# CTRL = enable | mode<<1 | use_fb<<5 | scan<<8
# = 1 | 0 | 0x20 | 0x500 = 0x521
mwr 0x40020000 0x00000521
after 200
puts "CTRL=[format 0x%08x [mrd -value 0x40020000]]  STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
