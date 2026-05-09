# 暂停 ARM, 通过 DAP/AXI bridge 读 axi_gpio_0 data, 然后恢复
connect
after 500
targets -set -nocase -filter {name =~ "ARM*#0"}
stop
after 200
puts "=== snapshot 6 次, ARM halt → mrd → con → halt ==="
for {set i 0} {$i < 6} {incr i} {
    catch {mrd 0x41200000 1} out
    puts "i=$i: $out"
    con
    after 400
    stop
    after 100
}
con
exit 0
