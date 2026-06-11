# spi_read_flash.tcl — 通过 axi_gpio_panel 软件 SPI master 读 panel 上 25VA16AT1G flash
# 用 xsdb 直接 GPIO bit-bang SPI: CLK=bit15 CS=bit16 MOSI=bit17 MISO=ch2 bit0
# 协议: SPI mode 0, MSB first, CS active low
# 命令: 0x9F (JEDEC ID, 3 bytes) - 验证 flash 真存在
#       0x03 + 24bit addr (READ) - 读 16 字节
#
# 注意: 这个 tcl 需要 ARM stopped (跑 ARM 同时 axi_gpio 会冲突)

connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
puts "ARM stopped, starting SPI bit-bang"

set base 0x40000000
set ch2  [expr $base + 0x08]   ;# GPIO2 data (input ch)
set CS_bit  16
set CLK_bit 15
set MOSI_bit 17

# 这是 PL 地址, xsdb 不能直接 mwr — 必须通过 ARM execute
# 用 ARM stub 函数实现 SPI: 但更简单, 让 ARM 跑专门的 SPI demo ELF
# 这里先 try mrd, see if reads succeed:
puts "GPIO_DATA = [format 0x%08x [mrd -force -value $base]]"
puts "GPIO2_DATA (MISO IN) = [format 0x%08x [mrd -force -value $ch2]]"

puts ""
puts "** xsdb 不能直接写 PL AXI slave **"
puts "** 需要 ARM-side SPI master 代码 — 改 led_panel.c 加 SPI flash 读 **"
exit 0
