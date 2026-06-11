# probe_panel_gpio.tcl — 验 ARM 真在驱动 axi_gpio_panel
#
# axi_gpio reg map (Xilinx axi_gpio 2.0):
#   0x00 GPIO_DATA   (ch1 data, 32-bit)
#   0x04 GPIO_TRI    (ch1 direction, 0=output)
#   0x08 GPIO2_DATA  (ch2 data, 1-bit)
#   0x0C GPIO2_TRI   (ch2 direction)
# axi_gpio_panel BASEADDR = 0x40000000
#
# 跑法 (Windows): D:\Vitis\2024.2\bin\xsdb.bat tools\probe_panel_gpio.tcl

connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}

set base 0x40000000

puts "=== axi_gpio_panel @ $base initial state ==="
puts [format "GPIO_DATA   = 0x%08x" [mrd -force -value [expr $base + 0x00]]]
puts [format "GPIO_TRI    = 0x%08x  (0=output)" [mrd -force -value [expr $base + 0x04]]]
puts [format "GPIO2_DATA  = 0x%08x" [mrd -force -value [expr $base + 0x08]]]
puts [format "GPIO2_TRI   = 0x%08x  (1=input)" [mrd -force -value [expr $base + 0x0C]]]

puts ""
puts "=== Snapshot 16 samples (~50ms apart) to verify ARM scan loop writing ==="
for {set i 0} {$i < 16} {incr i} {
    set v [mrd -force -value [expr $base + 0x00]]
    puts [format "sample %02d DATA = 0x%08x" $i $v]
    after 50
}

puts ""
puts "=== try forcing TRI=0 to confirm output mode ==="
mwr [expr $base + 0x04] 0
after 10
puts [format "TRI after write 0 = 0x%08x  (if hardwire, will still be ffffffff but pin still output)" \
    [mrd -force -value [expr $base + 0x04]]]

puts ""
puts "=== 强制驱动 pattern: 全 1 → 全 0 切换, 万用表/示波器可看到 PL pin 在动 ==="
mwr [expr $base + 0x00] 0x0003ffff
after 100
puts [format "DATA after write 0x0003ffff = 0x%08x" [mrd -force -value [expr $base + 0x00]]]
after 200
mwr [expr $base + 0x00] 0x00010000
after 100
puts [format "DATA after write 0x00010000 (just SPI_CS) = 0x%08x" [mrd -force -value [expr $base + 0x00]]]
puts "(注意: ARM scan loop 在跑会立刻覆盖这些值, 看 8 个 sample 是否在变即可)"

puts ""
puts "=== Bit分配解释 (ch1 data) ==="
puts "  bit 0  DCLK"
puts "  bit 1  LAT"
puts "  bit 2  GCLK"
puts "  bit 3-5 R1/G1/B1"
puts "  bit 6-8 R2/G2/B2"
puts "  bit 9-11 R3/G3/B3"
puts "  bit 12-14 AIN/BIN/CIN"
puts "  bit 15-17 SPI_CLK/CS/MOSI"
puts ""
puts "期望: DATA 在 8 个采样里有变化 (DCLK 翻 + ABC 切 + 数据切),"
puts "      如果 8 次都同值 → ARM 没在跑 scan_frame, 看 UART 是否 pattern 切"

exit 0
