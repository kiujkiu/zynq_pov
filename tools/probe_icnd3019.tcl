# probe_icnd3019.tcl — sample axi_gpio_panel 读 ICND3019 控制信号
# AIN=bit12, BIN=bit13, CIN=bit14 (我假设映射 ICND3019 SDI/DCLK/RCLK)
#
# ARM 在跑 sanity 死循环, ICND3019 协议: AIN=1 + BIN 1 cycle (load row 0),
# 然后每 scan 后 AIN=0 + BIN 1 cycle (advance). 54 scan/frame.
#
# 期望波形:
#   AIN: 帧开始 1 个长脉冲高 (1 cycle), 其余时间低
#   BIN: 帧开始 1 个上升沿 + 每 scan 后 1 个上升沿 (54 sec total)
#   CIN: 始终 0 (没 init 寄存器)

connect
after 200
targets -set -nocase -filter {name =~ "ARM*#0"}

set base 0x40000000
puts "=== sampling axi_gpio_panel data 0x40000000 ==="
puts "bit12=AIN bit13=BIN bit14=CIN (ICND3019 SDI/DCLK/RCLK 假设)"
puts ""

# 100 个 sample, 间隔 50us. 应该能抓到 AIN/BIN 高低切换
for {set i 0} {$i < 100} {incr i} {
    set v [mrd -force -value [expr $base + 0x00]]
    set ain [expr ($v >> 12) & 1]
    set bin [expr ($v >> 13) & 1]
    set cin [expr ($v >> 14) & 1]
    set dclk [expr $v & 1]
    set le [expr ($v >> 1) & 1]
    set row [expr ($v >> 2) & 1]
    puts [format "s%03d DCLK=%d LE=%d ROW=%d  AIN=%d BIN=%d CIN=%d  raw=0x%05x" \
        $i $dclk $le $row $ain $bin $cin [expr $v & 0x7ffff]]
}

exit 0
