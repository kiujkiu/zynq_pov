connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "=== SLCR SD0 select regs ==="
# 鹿小班 LXB-ZYNQ7000 UG585 chapter SLCR
puts "SLCR.SD0_WP_CD_SEL  (0xF8000130): [mrd -value 0xF8000130]"
puts "PRES (0xE0100024): [mrd -value 0xE0100024]"
puts "HC1  (0xE0100028 byte): [mrd -value 0xE0100028]"
con
exit
