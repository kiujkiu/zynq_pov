# 加载 6-2 留下的 fb_anime_top/bot.bin (单 panel 128×64) 到 panel 1, panel 2 BRAM 清零
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
set FB_TOP1 [expr {$BASE + 0x8000}]
set FB_BOT1 [expr {$BASE + 0xC000}]
set FB_TOP2 [expr {$BASE + 0x18000}]
set FB_BOT2 [expr {$BASE + 0x1C000}]

mwr -force $BASE 0
after 50
mwr -force 0xF8000180 0x00500500
after 50

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

# 旧单 panel 物理拼接反: top → bot bank, bot → top bank
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_top.bin" $FB_BOT1 "TOP→BOT1"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_bot.bin" $FB_TOP1 "BOT→TOP1"

# panel 2 清零
puts "clear panel 2..."
for {set i 0} {$i < 4096} {incr i} {
    mwr -force [expr {$FB_TOP2 + $i*4}] 0
    mwr -force [expr {$FB_BOT2 + $i*4}] 0
}

mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x8}]  127
mwr -force $BASE 0x521
after 200
puts "CTRL=[mrd -force $BASE 1]"
puts "STATUS=[mrd -force [expr {$BASE + 0xC}] 1]"
exit 0
