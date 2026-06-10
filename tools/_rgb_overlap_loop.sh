#!/bin/bash
# 一直跑 R/G/B 循环, overlap mode 保持 (每次 fill 后立刻 set CTRL=0x561)
trap "echo stopped; exit 0" SIGINT SIGTERM
NAMES=(R G B)
while true; do
  for i in 0 1 2; do
    echo "[$(date +%H:%M:%S)] ${NAMES[$i]}"
    cmd.exe /c "C:\Xilinx\Vitis\2024.2\bin\xsdb.bat D:\claude_workspace\pov3d\zynq_pov\tools\_8color_cycle.tcl $i" 2>&1 | grep -E "set" | tail -1
    cmd.exe /c "C:\Xilinx\Vitis\2024.2\bin\xsdb.bat D:\claude_workspace\pov3d\zynq_pov\tools\_set_overlap.tcl" 2>&1 | grep -E "CTRL" | tail -1
    sleep 3
  done
done
