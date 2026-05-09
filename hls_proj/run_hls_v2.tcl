# run_hls_v2.tcl - Phase 9.5 task H: 综合 pov_project_batch_v2 (II→1 优化版)
#
# 用法 (Windows / WSL):
#   cmd.exe /c "D:\Vitis\2024.2\bin\vitis-run.bat --mode hls --tcl run_hls_v2.tcl --work_dir ."
#   或:
#   D:\Vitis\2024.2\bin\vitis_hls.bat -f run_hls_v2.tcl
#
# 产物:
#   proj_pov_v2/solution1/syn/report/pov_project_batch_v2_csynth.rpt
#   proj_pov_v2/solution1/impl/ip/pov_project_v2_ip.zip

open_project proj_pov_v2 -reset
set_top pov_project_batch_v2
add_files pov_project.cpp   -cflags "-std=c++11"
add_files pov_project.h     -cflags "-std=c++11"
add_files cos_sin_lut.h     -cflags "-std=c++11"

open_solution "solution1" -flow_target vivado
set_part {xc7z020clg484-2}
create_clock -period 6.67 -name default

puts "== SYNTHESIS pov_project_batch_v2 =="
csynth_design

puts "== EXPORT RTL AS IP =="
export_design -format ip_catalog -output pov_project_v2_ip.zip \
              -description "POV 3D projection engine v2 (II=1 dual-HP)" \
              -vendor povlab -library user -version 2.0 \
              -display_name "POV Project Engine v2"

puts "DONE. See proj_pov_v2/solution1/impl/ for IP package."
exit 0
