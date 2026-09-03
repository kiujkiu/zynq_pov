#!/usr/bin/env bash
# run_sim.sh -- 直供+乒乓链路自校验仿真 (iverilog, ~3 min)
#   ./ppbuf/tools/run_sim.sh      判据见 tb/ppbuf_tb.v 文件头 (A 正常 / B 拖慢填充器 / C 自愈 / D tick 短于帧 / E 自由跑量帧长)
set -euo pipefail
cd "$(dirname "$0")/../.."          # -> icnd2260/
ROOT=$PWD
BUILD=$ROOT/ppbuf/build_sim
mkdir -p "$BUILD"
cp rtl/*.mem "$BUILD/"
cd "$BUILD"
iverilog -g2012 -o ppbuf.vvp \
    "$ROOT/ppbuf/tb/ppbuf_tb.v" \
    "$ROOT/rtl/icnd2260_seq.v" "$ROOT/rtl/icnd2260_lvds_tx.v" \
    "$ROOT/ppbuf/rtl/slice_feed.v" "$ROOT/ppbuf/rtl/slice_ppbuf.v" \
    "$ROOT/ppbuf/rtl/pat_writer.v" "$ROOT/ppbuf/rtl/angle_tracker.v"
vvp ppbuf.vvp | tail -12
