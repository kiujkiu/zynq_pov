# Args: ctrl_value  ; sets clean disable + grid fb + new CTRL
if {$argc < 1} { puts "usage: clean_grid.tcl <ctrl>"; exit 1 }
set ctrl [lindex $argv 0]
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# clean disable
mwr 0x40020000 0
after 300
# ensure fb is loaded
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_top.bin" -size w 0x4002C000 4096
mwr -bin -file "D:/claude_workspace/pov3d/zynq_pov/tools/fb_bot.bin" -size w 0x40028000 4096
mwr 0x40020014 32
after 200
# enable target mode
mwr 0x40020000 $ctrl
after 500
puts "CTRL=[mrd 0x40020000] STATUS=[mrd 0x4002000C]"
exit 0
