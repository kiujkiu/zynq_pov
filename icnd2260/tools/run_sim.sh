#!/usr/bin/env bash
# run_sim.sh -- 跑 icnd2260 自校验仿真
#
#   ./tools/run_sim.sh                 TTL + LVDS 两套, 缩短版 (4 扫 x 2 空屏帧)
#   ./tools/run_sim.sh --full          两套都跑全尺寸 (48 扫 x 64 空屏帧)
#   ./tools/run_sim.sh --only lvds     只跑 LVDS (或 --only ttl)
#
# 用 iverilog; 没有就退回 Vivado 的 xsim (Windows 侧)。
# .mem 要跟仿真工作目录同级, 所以先拷进 build/。
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
BUILD=$ROOT/build
mkdir -p "$BUILD"
cp rtl/*.mem "$BUILD/"

FULL=0
ONLY=both
while [ $# -gt 0 ]; do
    case "$1" in
        --full) FULL=1 ;;
        --only) shift; ONLY=$1 ;;
        *) echo "未知参数 $1"; exit 2 ;;
    esac
    shift
done

command -v iverilog >/dev/null 2>&1 || { echo "需要 iverilog"; exit 1; }
cd "$BUILD"

run_one() {   # $1 = ttl|lvds
    local name=$1 tb params=""
    if [ "$name" = ttl ]; then
        tb=icnd2260_seq_tb
        src="$ROOT/rtl/icnd2260_tx.v $ROOT/rtl/icnd2260_seq.v $ROOT/tb/icnd2260_seq_tb.v"
    else
        tb=icnd2260_lvds_tb
        src="$ROOT/rtl/icnd2260_lvds_tx.v $ROOT/rtl/icnd2260_seq.v $ROOT/tb/icnd2260_lvds_tb.v"
    fi
    [ $FULL = 1 ] && params="-P$tb.LINES=48 -P$tb.BLANK_FRAMES=64"
    echo "===== $name  ($([ $FULL = 1 ] && echo 全尺寸 || echo 缩短版)) ====="
    # shellcheck disable=SC2086
    iverilog -g2012 $params -o "$name.vvp" $src
    vvp "$name.vvp"
}

rc=0
[ "$ONLY" = both ] || [ "$ONLY" = ttl ]  && { run_one ttl  || rc=1; }
[ "$ONLY" = both ] || [ "$ONLY" = lvds ] && { run_one lvds || rc=1; }
exit $rc
