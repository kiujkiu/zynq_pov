# 探测 panel AXI 实际地址 + 状态
connect
after 300
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
# 试几个可能的 base
foreach base {0x40020000 0x40010000 0x40000000 0x44000000 0x44020000 0x60000000} {
    set rv [catch {mrd -force $base 1} out]
    if {$rv == 0} { puts "$base OK: $out" } else { puts "$base FAIL" }
}
exit 0
