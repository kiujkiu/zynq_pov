#!/bin/bash
trap "echo stopped; exit 0" SIGINT SIGTERM
NAMES=(R G B)
while true; do
  for i in 0 1 2; do
    echo "[$(date +%H:%M:%S)] ${NAMES[$i]}"
    cmd.exe /c "C:\Xilinx\Vitis\2024.2\bin\xsdb.bat D:\claude_workspace\pov3d\zynq_pov\tools\_8color_cycle.tcl $i" 2>&1 | grep -E "set" | tail -1
    sleep 2
  done
done
