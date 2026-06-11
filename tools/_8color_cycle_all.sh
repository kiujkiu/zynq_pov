#!/bin/bash
cd /mnt/d/claude_workspace/pov3d/zynq_pov
NAMES=(R G B W Y M C)
for i in 0 1 2 3 4 5 6; do
    NAME=${NAMES[$i]}
    echo "=== $i $NAME ==="
    cmd.exe /c "D:\\Vitis\\2024.2\\bin\\xsdb.bat tools\\_8color_cycle.tcl $i" 2>&1 | tail -2
    sleep 2
    cmd.exe /c "python.exe tools\\_snap_check.py" 2>&1 | tail -2
    cp tools/panel_low_exp.jpg /tmp/8c_${NAME}.jpg
done
echo done
