#!/usr/bin/env bash
# fix_xiltimer.sh — 修复 Vitis 2024.2 xiltimer.cmake 的 "Default;" bug
#
# 症状：FSBL build 失败，ld 报 "undefined reference to XTime_GetTime / XilSleepTimer_Init"
# 根因：xiltimer.cmake 的 XILTIMER_sleep_timer 默认值 "Default;"（尾随分号）
#       导致 STREQUAL "Default" 判断失败，任何 timer 后端都不编译进 libxiltimer.a
#
# 修复：把 bsp.yaml 里 XILTIMER_sleep_timer 值从 "Default;" 改成 "ps7_scutimer_0"，
#       并强制 rebuild libxiltimer.a + 覆盖到 lib/ 目录
#
# 用法:
#   bash fix_xiltimer.sh /mnt/d/workspace/zynq_pov/02_hello_zynq

set -euo pipefail

ROOT="${1:-}"
if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
    echo "用法: bash fix_xiltimer.sh <project_root>"
    exit 1
fi
VITIS_WS="$ROOT/vitis_ws"
[[ -d "$VITIS_WS" ]] || { echo "ERROR: $VITIS_WS 不存在"; exit 1; }

VITIS_BIN='D:\Vitis\2024.2\gnu\aarch32\nt\gcc-arm-none-eabi\bin'
CMAKE='D:\Vitis\2024.2\tps\win64\cmake-3.24.2\bin\cmake.exe'
NINJA='D:\Vitis\2024.2\tps\mingw\10.0.0\win64.o\nt\bin\ninja.exe'

# 找所有 bsp.yaml 并改写
for yaml in $(find "$VITIS_WS" -name "bsp.yaml" 2>/dev/null); do
    if grep -q 'XILTIMER_sleep_timer' "$yaml"; then
        python3 - "$yaml" <<'PY'
import sys, re
p = sys.argv[1]
with open(p) as f: src = f.read()
new = re.sub(
    r'(XILTIMER_sleep_timer:\s*\n(?:[^\n]*\n)*?\s*value:\s*)Default;',
    r'\1ps7_scutimer_0', src)
if new != src:
    with open(p,'w') as f: f.write(new)
    print(f'patched: {p}')
PY
    fi
done

# 对每个 BSP 的 gen_bsp 目录执行 cmake + 强制重建 libxiltimer.a
for gen_bsp in $(find "$VITIS_WS" -name "gen_bsp" -type d 2>/dev/null); do
    bsp_root=$(dirname $(dirname "$gen_bsp"))
    lib_dir="$bsp_root/lib"
    lib_a="$lib_dir/libxiltimer.a"
    built_a="$gen_bsp/libsrc/xiltimer/src/libxiltimer.a"

    echo "=== Processing: $bsp_root ==="
    rm -f "$lib_a" "$built_a"

    gen_bsp_win=$(echo "$gen_bsp" | sed 's|/mnt/\([a-z]\)/|\U\1:\\|;s|/|\\|g')
    cmd.exe /c "cd /d $gen_bsp_win && set PATH=$VITIS_BIN;%PATH% & $CMAKE . -DXILTIMER_sleep_timer=ps7_scutimer_0 > nul 2>&1 & $NINJA libsrc/xiltimer/src/libxiltimer.a > nul 2>&1" >/dev/null 2>&1

    if [[ -f "$built_a" ]]; then
        cp "$built_a" "$lib_a"
        echo "  rebuilt: $lib_a"
    else
        echo "  WARN: failed to rebuild $built_a"
    fi
done

echo "DONE"
