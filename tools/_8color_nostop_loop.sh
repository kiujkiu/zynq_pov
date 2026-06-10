#!/bin/bash
trap "echo stopped; exit 0" SIGINT SIGTERM
# 先确保 OVERLAP mode 开
cmd.exe /c "C:\Xilinx\Vitis\2024.2\bin\xsdb.bat D:\claude_workspace\pov3d\zynq_pov\tools\_set_overlap.tcl" 2>&1 | grep -E "CTRL"
NAMES=(R G B W Y M C)
while true; do
  for i in 0 1 2 3 4 5 6; do
    echo "[$(date +%H:%M:%S)] ${NAMES[$i]}"
    cmd.exe /c "C:\Xilinx\Vitis\2024.2\bin\xsdb.bat D:\claude_workspace\pov3d\zynq_pov\tools\_8color_overlap_nostop.tcl $i" 2>&1 | grep -E "set" | tail -1
    sleep 2
  done
done
