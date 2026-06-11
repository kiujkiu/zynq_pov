# Clear all 4 BRAMs then load anime word-by-word
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
mwr -force $BASE 0
after 100
mwr -force 0xF8000180 0x00500500
after 50

set FB_TOP1 [expr {$BASE + 0xC000}]
set FB_BOT1 [expr {$BASE + 0x8000}]
set FB_TOP2 [expr {$BASE + 0x1C000}]
set FB_BOT2 [expr {$BASE + 0x18000}]

puts "clear all 4 BRAMs..."
foreach addr [list $FB_TOP1 $FB_BOT1 $FB_TOP2 $FB_BOT2] {
    for {set i 0} {$i < 4096} {incr i} {
        mwr -force [expr {$addr + $i*4}] 0
    }
}
puts "BRAMs cleared, loading anime..."

proc load_bin {file_path base_addr name} {
    set fd [open $file_path rb]
    fconfigure $fd -translation binary
    set data [read $fd]
    close $fd
    set nwords [expr {[string length $data] / 4}]
    puts "  $name: $nwords words to 0x[format %X $base_addr]"
    for {set i 0} {$i < $nwords} {incr i} {
        binary scan [string range $data [expr {$i*4}] [expr {$i*4+3}]] iu word
        mwr -force [expr {$base_addr + $i*4}] [format "0x%08X" $word]
    }
}

load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_top1.bin" $FB_TOP1 "TOP1"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_bot1.bin" $FB_BOT1 "BOT1"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_top2.bin" $FB_TOP2 "TOP2"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_bot2.bin" $FB_BOT2 "BOT2"

mwr -force [expr {$BASE + 0x14}] 8
mwr -force $BASE 0x561
after 200
puts "CTRL=[mrd -force $BASE 1]  STATUS=[mrd -force [expr {$BASE + 0xC}] 1]"
puts "done - check panel"
exit 0
