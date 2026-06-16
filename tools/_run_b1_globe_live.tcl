# B1 换地球仪点云 LIVE 重触发 (板已 live B1 bit, 不重烧). 停显示→灌点云→B1一条龙→重启显示.
set PB 0x43C20000
connect
after 500
targets -set -nocase -filter {name =~ "APU*"}
configparams force-mem-access 1
mwr -force 0x40020000 0x0          ; # 停显示 DMA (B1 要重写 ring)
after 200
puts "注入地球仪点云 (128944 pts, 2MB) @ 0x16000000 ..."
dow -data "D:/claude_workspace/pov3d/zynq_pov/globe_points.bin" 0x16000000
dow -data "D:/claude_workspace/pov3d/zynq_pov/tools/transform_lut.bin" 0x1B000000
mwr -force [expr {$PB+0x10}] 0x16000000  ; # POINTS
mwr -force [expr {$PB+0x1C}] 0x1C000000  ; # VOXEL_GRID scratch
mwr -force [expr {$PB+0x28}] 0x1B000000  ; # LUT
mwr -force [expr {$PB+0x34}] 0x18000000  ; # SLICE_BASE
mwr -force [expr {$PB+0x40}] 128944      ; # N_POINTS
mwr -force [expr {$PB+0x48}] 720         ; # N_TOTAL
mwr -force [expr {$PB+0x50}] 0           ; # SLOT_START
mwr -force [expr {$PB+0x58}] 720         ; # N_SLOTS
puts "ap_start: B1 清网格+散射地球仪+gather..."
mwr -force [expr {$PB+0x00}] 0x1
set done 0
for {set i 0} {$i < 400} {incr i} { after 50; if {[mrd -force -value [expr {$PB+0x00}]] & 0x2} { set done 1; break } }
puts "B1 AP_CTRL=[format 0x%X [mrd -force -value [expr {$PB+0x00}]]] done=$done (~[expr {$i*50}]ms)"
# 重启显示
mwr -force 0xF8000180 0x00300700
mwr -force 0x40020014 0x1FF
mwr -force 0x40020018 0x18000000
mwr -force 0x4002001C 14577
mwr -force 0x40020020 720
mwr -force 0x40020000 0xC5E1
after 300
set gnz 0
for {set k 0} {$k < 4000} {incr k} { if {[mrd -force -value [expr {0x1C000000 + ($k*1009 % 2097152)*4}]] != 0} { incr gnz } }
set nz 0
foreach line [mrd -force 0x18000000 2048] { foreach t $line { if {[string match "*:" $t]} continue; if {$t ne "" && $t ne "00000000"} { incr nz } } }
puts "显示 CTRL=[format 0x%X [mrd -force -value 0x40020000]]  grid非零=$gnz/4000  slice0非零=$nz/2048"
exit 0
