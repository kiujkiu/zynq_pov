connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
after 200
puts "=== CPU0 state after stop ==="
puts "PC = [format 0x%08X [rrd pc]]"
catch { puts "LR = [format 0x%08X [rrd lr]]" }
catch { puts "SP = [format 0x%08X [rrd sp]]" }
catch { puts "CPSR = [format 0x%08X [rrd cpsr]]" }
puts ""
puts "=== Memory regions ==="
puts "0x00000000 (BootROM) first 16B:"
mrd 0x00000000 4
puts ""
puts "0x10000000 (DDR app load area) first 16B:"
mrd 0x10000000 4
puts ""
puts "0xE0000018 (UART0 BAUDGEN):"
mrd -value 0xE0000018
puts "0xE0000034 (UART0 BAUDDIV):"
mrd -value 0xE0000034
puts ""
puts "0xF8000A1C (BOOT_MODE):"
mrd -value 0xF8000A1C
exit
