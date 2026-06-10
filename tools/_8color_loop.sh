#!/bin/bash
# Infinite 8-color cycle, 2s per color
trap "echo; echo stopped; exit 0" SIGINT SIGTERM
NAMES=(R G B W Y M C)
while true; do
  for i in 0 1 2 3 4 5 6; do
    echo "[$(date +%H:%M:%S)] idx=$i ${NAMES[$i]}"
    cmd.exe /c "C:\Xilinx\Vitis\2024.2\bin\xsdb.bat D:\claude_workspace\pov3d\zynq_pov\tools\_8color_cycle.tcl $i" 2>&1 | grep -E "set|fill" | tail -2
    sleep 2
  done
done
