connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1
# 写 fb 顶半 全 G=0x80 (但 BRAM 数据低 24-bit = R[7:0] G[15:8] B[23:16])
# 24-bit 0x008000 → R=0x00, G=0x80, B=0x00
puts "writing 4096 pixels fb_top = 0x008000 (G=0x80)..."
for {set i 0} {$i < 4096} {incr i 16} {
    mwr [expr {0x40028000 + $i * 4}] 0x008000
}
# 切 use_fb=1
mwr 0x40020000 0x00000521
after 200
puts "CTRL=[format 0x%08x [mrd -value 0x40020000]] STATUS=[format 0x%08x [mrd -value 0x4002000C]]"
disconnect
exit 0
