# 单色定住: 参数 = BRAM word (R[7:0] G[15:8] B[23:16]). 保持 CTRL=0x561, 填 4 BRAM 后断开, panel 保持显示
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0xF8000180 0x00500500
mwr -force 0x40020014 0x00000608
mwr -force 0x40020008 127
mwr -force 0x40020000 0x561
after 100
set c [lindex $argv 0]
mwr -force 0x40028000 $c 4096
mwr -force 0x4002C000 $c 4096
mwr -force 0x40038000 $c 4096
mwr -force 0x4003C000 $c 4096
puts "SET word=$c held"
after 500
disconnect
