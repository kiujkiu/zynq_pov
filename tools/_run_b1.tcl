# B1 板端测试: 点云直进FPGA, pov_render_full 清网格+散射+gather 一条龙. ARM 不碰渲染.
# 冷启动安全. B1 control @0x43C20000.
set bit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/02_hello_zynq.runs/impl_1/hello_zynq_wrapper.bit"
set psinit "D:/claude_workspace/pov3d/zynq_pov/02_hello_zynq/vitis_ws/hello_plat/hw/sdt/ps7_init.tcl"
set PTS "D:/claude_workspace/pov3d/zynq_pov/anime_points.bin"   ;# raw point_t, 无头
set LUT "D:/claude_workspace/pov3d/zynq_pov/tools/transform_lut.bin"
set NPTS 100000

# pov_render_full 寄存器 (base 0x43C20000)
set PB 0x43C20000
set AP      [expr {$PB+0x00}]
set R_PTS   [expr {$PB+0x10}]
set R_VOX   [expr {$PB+0x1C}]
set R_LUT   [expr {$PB+0x28}]
set R_SB    [expr {$PB+0x34}]
set R_NPT   [expr {$PB+0x40}]
set R_NT    [expr {$PB+0x48}]
set R_SS    [expr {$PB+0x50}]
set R_NS    [expr {$PB+0x58}]

connect
after 1000
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
targets -set -nocase -filter {name =~ "APU*"}
fpga -file $bit
after 500
source $psinit
ps7_init
ps7_post_config
configparams force-mem-access 1
puts "注入点云 (raw 100k, 1.6MB) @ 0x16000000 ..."
dow -data $PTS 0x16000000
puts "注入 LUT @ 0x1B000000 ..."
dow -data $LUT 0x1B000000

# B1 参数 (voxel_grid=0x1C000000 scratch, B1 自己清)
mwr -force $R_PTS 0x16000000
mwr -force $R_VOX 0x1C000000
mwr -force $R_LUT 0x1B000000
mwr -force $R_SB  0x18000000
mwr -force $R_NPT $NPTS
mwr -force $R_NT  720
mwr -force $R_SS  0
mwr -force $R_NS  720
puts "ap_start: B1 清网格+散射 100k 点+gather 720 片..."
mwr -force $AP 0x1
set done 0
for {set i 0} {$i < 400} {incr i} {
    after 50
    if {[mrd -force -value $AP] & 0x2} { set done 1; break }
}
puts "B1 AP_CTRL=[format 0x%X [mrd -force -value $AP]] done=$done (~[expr {$i*50}]ms)"

# 配显示
mwr -force 0xF8000180 0x00300700
mwr -force 0x40020014 0x1FF
mwr -force 0x40020008 127
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 14577
mwr -force 0x40020020 720
mwr -force 0x40020000 0xC5E1
after 500
puts "显示: CTRL=[format 0x%X [mrd -force -value 0x40020000]] DBG=[format 0x%08X [mrd -force -value 0x40020024]]"
# grid 互质抽样 (确认 FPGA 散射填了网格) + slice 非零
set gnz 0
for {set k 0} {$k < 4000} {incr k} { if {[mrd -force -value [expr {0x1C000000 + ($k*1009 % 2097152)*4}]] != 0} { incr gnz } }
puts "grid 抽样 4000 非零: $gnz (>0 = FPGA 散射成功)"
set nz 0
foreach line [mrd -force 0x18000000 2048] { foreach t $line { if {[string match "*:" $t]} continue; if {$t ne "" && $t ne "00000000"} { incr nz } } }
puts "slice0 非零 word: $nz / 2048"
exit 0
