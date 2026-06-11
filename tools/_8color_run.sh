#!/bin/bash
cd /mnt/d/claude_workspace/pov3d/zynq_pov
for i in 0 1 2 3 4 5 6; do
    NAMES=(R G B W Y M C)
    NAME=${NAMES[$i]}
    echo "=== color $i $NAME ==="
    cmd.exe /c "D:\\Vitis\\2024.2\\bin\\xsdb.bat tools\\_8color_cycle.tcl $i" 2>&1 | tail -2
    cp /mnt/d/claude_workspace/pov3d/zynq_pov/tools/panel_low_exp.jpg /tmp/before_snap_$NAME.jpg 2>/dev/null || true
    cmd.exe /c "python.exe tools\\_snap_check.py" 2>&1 | tail -2
    cp /mnt/d/claude_workspace/pov3d/zynq_pov/tools/panel_low_exp.jpg /tmp/cycle_$NAME.jpg
    echo "snap saved /tmp/cycle_$NAME.jpg"
done
echo "all 7 colors done"
