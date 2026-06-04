# Runtime 切 1-bit BCM (reg_tunit[11:8]=1), 保留 t_unit
connect
after 200
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
set cur [lindex [mrd -force -value 0x40020014 1] 0]
set t_unit_low [expr {$cur & 0xFF}]
set new [expr {($t_unit_low) | (1 << 8)}]
puts "TUNIT cur=0x[format %x $cur] new=0x[format %x $new] (planes_n=1, t_unit=$t_unit_low)"
mwr -force 0x40020014 $new
after 100
puts "TUNIT now [mrd -force 0x40020014 1]"
exit 0
