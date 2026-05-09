connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
puts "PC=[rrd pc] (CPU is halted, stuck here)"
puts ""
puts "Memory at 0xFFFFFF20..0xFFFFFF40:"
mrd 0xFFFFFF20 8
puts ""
puts "Disasm around 0xFFFFFF28 (8 instr ARM mode):"
catch { disassemble 0xFFFFFF20 8 } result
puts $result
exit
