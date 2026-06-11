# v34g anime load: read bin files in tcl, write word-by-word (verify mwr -bin issue)
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set BASE 0x40020000
set FB_TOP1 [expr {$BASE + 0x8000}]   ; # 0x40028000 = Verilog fb_top = panel rows 0..31
set FB_BOT1 [expr {$BASE + 0xC000}]   ; # 0x4002C000 = Verilog fb_bot = panel rows 32..63
set FB_TOP2 [expr {$BASE + 0x18000}]  ; # 0x40038000 = panel 2 fb_top
set FB_BOT2 [expr {$BASE + 0x1C000}]  ; # 0x4003C000 = panel 2 fb_bot

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

load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_top1.bin" $FB_TOP1 "TOP1"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_bot1.bin" $FB_BOT1 "BOT1"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_top2.bin" $FB_TOP2 "TOP2"
load_bin "D:/claude_workspace/pov3d/zynq_pov/tools/fb_anime_128_bot2.bin" $FB_BOT2 "BOT2"

mwr -force [expr {$BASE + 0x14}] 0x00000608
mwr -force [expr {$BASE + 0x8}]  127
mwr -force $BASE 0x521
after 200
puts "CTRL=[mrd -force $BASE 1]"
puts "STATUS=[mrd -force [expr {$BASE + 0xC}] 1]"
exit 0
