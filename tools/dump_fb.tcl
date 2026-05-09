# 暂停 ARM, mrd FB_A & FB_B 头几个像素, 看是不是 frame 强相关的彩色, 还是 wireframe 残影
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
after 200
puts "=== FB_A @ 0x10000000 first 32 bytes ==="
puts [mrd 0x10000000 8]
puts "=== FB_B @ 0x14000000 first 32 bytes ==="
puts [mrd 0x14000000 8]
puts "=== FB_A center (offset 0x180000) 8 words ==="
puts [mrd [expr 0x10000000 + 0x180000] 8]
puts "=== FB_B center (offset 0x180000) 8 words ==="
puts [mrd [expr 0x14000000 + 0x180000] 8]
con
exit 0
