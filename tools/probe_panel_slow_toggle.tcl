# probe_panel_slow_toggle.tcl — 通过 xsdb 直接写 axi_gpio_panel
#   让 18 个 panel 信号以 ~1 Hz 频率全亮/全灭切换,
#   user 用万用表/LED 探针测 panel J1 各 pin 看信号是否到达
#
# 注意: 跑这个会跟 ARM scan loop 抢 GPIO, ARM hot loop 会立刻覆盖.
#       先 stop ARM, 跑这个, 看完再 con ARM.
#
# 跑法: xsdb.bat probe_panel_slow_toggle.tcl

connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}

puts "stopping ARM..."
stop

set base 0x40000000
set all_high 0x0003ffff
set all_low  0x00010000  ;# SPI_CS=1 (idle), 其余 0
set count 20

puts "=== 全 18 pin 慢速 toggle ($count 次, 每次 500ms) ==="
puts "万用表测 panel J1 的 DCLK/R1/G1/B1/.../AIN/BIN/CIN 应该跟着 0V <-> 3.3V 切"
puts "如果某根 pin 始终 0V, FPC 或 PL pin 路径有问题"
puts ""
for {set i 0} {$i < $count} {incr i} {
    mwr $base $all_high
    puts -nonewline "HIGH "; flush stdout
    after 500
    mwr $base $all_low
    puts "LOW"
    after 500
}

puts ""
puts "=== 只 R1 翻 (J1.24 → GPIO1.8 → AA22 → bit 3) ==="
puts "单 R1 toggle 5 次, 测 J1.24 应该跟着切, 其他 pin 保持低"
for {set i 0} {$i < 5} {incr i} {
    mwr $base 0x00010008
    puts -nonewline "R1=1 "; flush stdout
    after 800
    mwr $base 0x00010000
    puts "R1=0"
    after 800
}

puts ""
puts "=== 恢复并继续 ARM ==="
mwr $base 0x00010000
con
puts "done. ARM 又在跑 scan loop."
exit 0
