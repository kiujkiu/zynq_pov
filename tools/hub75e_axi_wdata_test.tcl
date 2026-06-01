connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
puts ""
puts "=== AXI wdata 路径测试: 写 reg_color (0x40020004) ==="
mwr 0x40020004 0xCAFEBA
after 50
set v [mrd -value 0x40020004]
puts "  写 0x00CAFEBA, mrd 0x40020004 = [format 0x%08x $v]"

mwr 0x40020004 0xDEADBE
after 50
set v [mrd -value 0x40020004]
puts "  写 0x00DEADBE, mrd 0x40020004 = [format 0x%08x $v]"

mwr 0x40020004 0xFFFFFFFF
after 50
set v [mrd -value 0x40020004]
puts "  写 0xFFFFFFFF, mrd 0x40020004 = [format 0x%08x $v]"

mwr 0x40020004 0x00000001
after 50
set v [mrd -value 0x40020004]
puts "  写 0x00000001, mrd 0x40020004 = [format 0x%08x $v]"

puts ""
puts "=== fb write 单像素诊断: 写 fb[0]=0xCAFEBA, last_fb_wdata 应 = 0xBA ==="
mwr 0x40028000 0xCAFEBA
after 200
set st [mrd -value 0x4002000C]
puts "  STATUS = [format 0x%08x $st]"
puts "  last_fb_wdata[7:0] (STATUS[31:24]) = [format 0x%02x [expr {($st >> 24) & 0xFF}]]"
puts "  fb_we_count[7:0]   (STATUS[23:16]) = [format 0x%02x [expr {($st >> 16) & 0xFF}]]"
disconnect
exit 0
