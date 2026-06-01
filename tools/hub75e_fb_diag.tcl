# Write fb=0xFFFFFF, poll STATUS multiple times to see fb_top_dout[15:0] value
connect
after 1500
targets -set -nocase -filter {name =~ "ARM*#0"}
configparams force-mem-access 1

puts "writing 4096 pixels fb_top = 0xFFFFFF (xsdb mwr num-words mode)..."
mwr 0x40028000 0xFFFFFF 4096
puts "writing 4096 pixels fb_bot = 0xFFFFFF..."
mwr 0x4002C000 0xFFFFFF 4096

# 切 use_fb=1, mode 0
mwr 0x40020000 0x00000521

puts ""
puts "=== poll STATUS 10 次, 看 fb_top_dout[15:0] (STATUS[31:16]) ==="
for {set i 0} {$i < 10} {incr i} {
    set st [mrd -value 0x4002000C]
    set fb_gb [expr {($st >> 16) & 0xFFFF}]
    set plane [expr {($st >> 13) & 0x7}]
    set row [expr {($st >> 8) & 0x1F}]
    puts "  $i: STATUS=[format 0x%08x $st]  fb_dout[15:0]=[format 0x%04x $fb_gb]  plane=$plane row=$row"
    after 50
}

# 测试: 写 fb[0]=0xCAFEBA, 检查写后立刻能否 see G byte
puts ""
puts "=== write fb[0]=0xCAFEBA, read STATUS (when row=0 col=0 fb_dout 应该=0xCAFEBA) ==="
mwr 0x40028000 0xCAFEBA
after 200
for {set i 0} {$i < 5} {incr i} {
    set st [mrd -value 0x4002000C]
    set fb_gb [expr {($st >> 16) & 0xFFFF}]
    puts "  $i: STATUS=[format 0x%08x $st]  fb_dout[15:0]=[format 0x%04x $fb_gb]  (期望 0xCAFE 当 plane=0 row=0)"
    after 50
}
disconnect
exit 0
