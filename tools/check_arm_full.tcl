connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
after 100
puts "PC = [rrd pc]"
puts "LR = [rrd lr]"
puts "SP = [rrd sp]"
puts "CPSR = [rrd cpsr]"
# Read DFAR (data fault addr) via CP15 c6 c0 0
puts "DFAR (CP15 c6,c0,0):"
catch {puts [rrd dfar]}
catch {puts [rrd r14_abt]}
# Read banked LR_abt directly
mrd 0xF8F00000 4
exit 0
