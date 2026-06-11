# SWAP TEST: panel 1 BRAM 喂 panel 2 数据, panel 2 BRAM 喂 panel 1 数据
# 如果"3 个缺陷"跟着数据走到右边 panel 1 → IP/SW bug
# 如果"3 个缺陷"留在左边 panel 2 → panel 2 硬件
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
set FB_TOP1 [expr {$BASE + 0x8000}]   ; # panel 1 top
set FB_BOT1 [expr {$BASE + 0xC000}]   ; # panel 1 bot
set FB_TOP2 [expr {$BASE + 0x18000}]  ; # panel 2 top
set FB_BOT2 [expr {$BASE + 0x1C000}]  ; # panel 2 bot

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

# SWAPPED: panel 1 BRAM 装 panel 2 数据, panel 2 BRAM 装 panel 1 数据
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_top2.bin" $FB_TOP1 "TOP1<-TOP2"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_bot2.bin" $FB_BOT1 "BOT1<-BOT2"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_top1.bin" $FB_TOP2 "TOP2<-TOP1"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_bot1.bin" $FB_BOT2 "BOT2<-BOT1"

mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x8}]  127
mwr -force $BASE 0x521
after 200
puts "CTRL=[mrd -force $BASE 1]"
exit 0
