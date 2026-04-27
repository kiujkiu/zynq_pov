# run_voxel_slice_synth.tcl — 综合 pov_voxel_slice_batch IP (#29).
# 用法: D:\Vitis\2024.2\bin\vitis-run.bat --mode hls --tcl run_voxel_slice_synth.tcl --work_dir .
# 产物: proj_voxel_slice/solution1/impl/ip/*.zip → 拿去 Vivado IP Repo

open_project proj_voxel_slice
set_top pov_voxel_slice_batch
add_files pov_project.cpp   -cflags "-std=c++11"
add_files pov_project.h     -cflags "-std=c++11"
add_files cos_sin_lut.h     -cflags "-std=c++11"
add_files -tb testbench.cpp -cflags "-std=c++11"

open_solution "solution1" -flow_target vivado
set_part {xc7z020clg484-2}
create_clock -period 6.67 -name default

puts "== C SIMULATION =="
csim_design

puts "== SYNTHESIS =="
csynth_design

puts "== EXPORT IP =="
export_design -format ip_catalog -output pov_voxel_slice_ip.zip \
              -description "POV voxel slice batch (4-IP parallel ready)" \
              -vendor povlab -library user -version 1.0 \
              -display_name "POV Voxel Slice Batch"

puts "DONE."
exit 0
