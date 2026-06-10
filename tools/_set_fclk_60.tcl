# 强制 unlock SLCR + 写 FCLK1 60M + 读回
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1

# Unlock SLCR
mwr -force 0xF8000008 0x0000DF0D
after 50
puts "FCLK1 before:  [mrd -force 0xF8000180 1]"
mwr -force 0xF8000180 0x00500600
after 100
puts "FCLK1 after:   [mrd -force 0xF8000180 1]"
# Lock SLCR
# mwr -force 0xF8000004 0x0000767B
exit 0
