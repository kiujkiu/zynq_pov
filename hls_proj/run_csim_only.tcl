# Quick csim-only run for verifying z-slice mode. Skip synth + export.
open_project proj_pov_csim
set_top pov_project_batch
add_files pov_project.cpp   -cflags "-std=c++11"
add_files pov_project.h     -cflags "-std=c++11"
add_files cos_sin_lut.h     -cflags "-std=c++11"
add_files -tb testbench.cpp -cflags "-std=c++11"

open_solution "solution1" -flow_target vivado
set_part {xc7z020clg484-2}
create_clock -period 6.67 -name default

puts "== C SIMULATION =="
csim_design

exit 0
