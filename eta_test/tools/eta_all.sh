#!/bin/bash
# eta_all.sh -- the whole chain from WSL, each stage gated on its own self-check line.
#   tools/eta_all.sh hls          Vitis HLS: csynth + export both gauge IPs        (~1.5 min)   gate: ETA_HLS_OK rd / wr
#   tools/eta_all.sh build [rd|wr] Vivado: BD -> bit                                (~4 min each) gate: BUILD_ETA_OK
#   tools/eta_all.sh voxel        python: random voxel grid + expectations          (~5 s)
#   tools/eta_all.sh dry [rd|wr]  xsdb with the mock board model (no hardware)      (~2 min)     gate: RESULT:
#   tools/eta_all.sh run [rd|wr] [secs]   xsdb on the LXB board                     (~3 min)     gate: RESULT:
#   tools/eta_all.sh all          hls + build rd + build wr + voxel + dry rd
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WROOT='D:\claude_workspace\pov3d\zynq_pov\eta_test'          # Windows view of $ROOT
VIVADO_ENV='call C:\Xilinx\Vivado\2024.2\settings64.bat'
HLS='C:\Xilinx\Vitis_HLS\2024.2\bin\vitis_hls.bat'
XSDB='D:\Vitis\2024.2\bin\xsdb.bat'
cd "$ROOT" || exit 1

gate() {  # gate <logfile> <regex> <what>
    if grep -aq "$2" "$1"; then echo "=== OK: $3 ($(grep -a "$2" "$1" | tail -1 | cut -c1-140))"; else echo "=== FAIL: $3 -- '$2' not in $1"; exit 1; fi
}
stage_hls() {
    cmd.exe /c "cd /d $WROOT\\hls && set ETA_VARIANT=all&& set ETA_CSIM=1&& $HLS -f run_eta_hls.tcl -nolog" > hls/_hls_run.log 2>&1
    gate hls/_hls_run.log "ETA_HLS_OK rd" "HLS rd (II=1, ap_ctrl_hs, csim TB_PASS)"
    gate hls/_hls_run.log "ETA_HLS_OK wr" "HLS wr"
}
stage_build() {
    local v="${1:-rd}"; shift || true
    cmd.exe /c "cd /d $WROOT && $VIVADO_ENV && vivado -mode batch -nojournal -log build_eta_$v.log -source tools\\build_eta.tcl -tclargs $v $*" > "_full_$v.out" 2>&1
    gate "_full_$v.out" "DDR_INIT_MATCH" "ps7_init DDR block == golden hello_zynq ($v)"
    gate "_full_$v.out" "BUILD_ETA_OK" "bitstream $v (timing met)"
}
stage_voxel() { python3 tools/gen_voxel.py > build_common/_gen.log 2>&1 || { cat build_common/_gen.log; exit 1; }; gate build_common/_gen.log "wrote .*voxel_expect.tcl" "voxel.bin + expectations"; }
stage_dry()  { local v="${1:-rd}"; cmd.exe /c "cd /d $WROOT && $XSDB tools\\_mock_xsdb.tcl $v quick" 2>&1 | tr -d '\r' | tee "_dry_$v.log"; gate "_dry_$v.log" "RESULT:" "dry run $v reached a verdict (mock board)"; }
stage_run()  { local v="${1:-rd}"; local secs="${2:-6}"; cmd.exe /c "cd /d $WROOT && $XSDB tools\\run_eta.tcl $v $secs" 2>&1 | tr -d '\r' | tee "run_eta_$v.log"; gate "run_eta_$v.log" "RESULT:" "board run $v reached a verdict"; }

case "${1:-}" in
    hls)   stage_hls ;;
    build) shift; stage_build "$@" ;;
    voxel) mkdir -p build_common; stage_voxel ;;
    dry)   shift; stage_dry "$@" ;;
    run)   shift; stage_run "$@" ;;
    all)   stage_hls; stage_build rd; stage_build wr; mkdir -p build_common; stage_voxel; stage_dry rd ;;
    *)     sed -n '2,9p' "$0"; exit 1 ;;
esac
