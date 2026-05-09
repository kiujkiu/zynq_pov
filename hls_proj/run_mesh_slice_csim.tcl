# Quick csim-only run for mesh_slice_render. Skips synth + export.
# 用法: cd hls_proj && cmd.exe /c "D:\Vitis\2024.2\bin\vitis-run.bat \
#       --mode hls --tcl run_mesh_slice_csim.tcl --work_dir ."
open_project proj_mesh_slice_csim
set_top mesh_slice_render
add_files mesh_slice.cpp     -cflags "-std=c++11"
add_files mesh_slice.h       -cflags "-std=c++11"
add_files mesh_slice_lut.h   -cflags "-std=c++11"
add_files -tb mesh_slice_tb.cpp -cflags "-std=c++11"

open_solution "solution1" -flow_target vivado
set_part {xc7z020clg484-2}
create_clock -period 6.67 -name default

puts "== C SIMULATION =="
csim_design

exit 0
