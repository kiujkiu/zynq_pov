# run_eta.tcl -- xsdb: bring up the eta bit on the LXB board, prove the gauge, run the test matrix,
#                print eta and the GO/no-go verdict. ASCII only (Windows Tcl).
#
# Run (WSL, board on JTAG, boot-mode switch irrelevant: everything is loaded over JTAG):
#   cd /mnt/d/claude_workspace/pov3d/zynq_pov/eta_test
#   python3 tools/gen_voxel.py                                   (once: build_common/voxel.bin + voxel_expect.tcl)
#   cmd.exe /c "D:\Vitis\2024.2\bin\xsdb.bat tools\run_eta.tcl rd" 2>&1 | tee run_eta_rd.log
#   args: <variant rd|wr> [window_secs=6] [quick]
#
# Steps and how each proves itself (the script aborts with "ETA_ABORT: ..." when a proof fails):
#   1 JTAG      lists every target; refuses to continue if more than one Zynq is on the chain (burned the
#               wrong board before, memory project_lxb_icnd2260_bringup)
#   2 PL+PS     rst -system; fpga -file (PCAP); ps7_init (DDR); ps7_post_config (releases FCLK_RESET)
#   3 gauge     sel=6 must read MAGIC 0xE7A00001 (GPIO->eta_mon path); live cycle counter must move;
#               f_clk measured against the host clock over 4 s must be within 2% of eta_regs FCLK
#   4 DDR       write/readback pattern; dow -data voxel.bin; readback of 2 spots vs the file
#   5 IP regs   every register written is read back
#   6 matrix    each row: clear -> start (both IPs in ONE write) -> settle -> snapshot A -> window -> snapshot B
#               -> stop -> wait idle -> (rd) XOR vs host expectation / (wr) slot content vs voxel
#   7 verdict   DUAL row: both IPs wall us/slice <= 110.6 and overlap >= 0.98 -> GO; <= 92.2 -> GO with 20% margin
#
# eta = (sum over IPs of slices/s x 82,944 B) / 2.1333 GB/s   (DDR3-1066 x 16 bit peak, the board's number)

set here [file normalize [file dirname [info script]]]
set root [file normalize $here/..]
set variant "rd" ; set WIN 6 ; set QUICK 0
if {$argc > 0} { set variant [lindex $argv 0] }
if {$argc > 1} { set WIN [lindex $argv 1] }
foreach a $argv { if {$a eq "quick"} { set QUICK 1 ; set WIN 2 } }
if {$WIN > 20} { set WIN 20 }   ;# 32-bit counters wrap at 28.6 s @150 MHz
set build $root/build_eta_$variant
if {![file exists $build/eta_regs.tcl]} { puts "ETA_ABORT: $build/eta_regs.tcl missing -- run tools/build_eta.tcl $variant first" ; exit 1 }
source $build/eta_regs.tcl
if {![file exists $root/build_common/voxel_expect.tcl]} { puts "ETA_ABORT: run python3 tools/gen_voxel.py first" ; exit 1 }
source $root/build_common/voxel_expect.tcl
set VOXFILE $root/build_common/voxel.bin
if {![file exists $ETA(bit)]} { puts "ETA_ABORT: bit missing $ETA(bit)" ; exit 1 }
if {!$ETA(ddr_init_match)} { puts "ETA_ABORT: build_eta reported DDR_INIT_MISMATCH; refusing to init DDR with unverified settings" ; exit 1 }

set VOX_BASE   0x10000000       ;# 16 MB voxel grid (15,925,248 B used)
set SLOT0_BASE 0x12000000       ;# wr variant only: 603 x 82,944 B = 50 MB per IP
set SLOT1_BASE 0x16000000
set SCRATCH    0x1F000000
set SLOT_BYTES $EXPECT(slot_bytes)
set DDR_PEAK   2133333333.0     ;# B/s
set F          [expr {double($ETA(fclk_hz))}]
set GP_OUT     [expr {$ETA(gpio) + 0x0}]
set GP_IN      [expr {$ETA(gpio) + 0x8}]
set LOGTAG [expr {[info exists ::MOCK] ? "MOCKRUN_" : ""}]     ;# dry runs must never look like board results
set LOG [open $build/eta_result_${LOGTAG}[clock format [clock seconds] -format %Y%m%d_%H%M%S].txt w]
proc out {s} { global LOG ; puts $s ; puts $LOG $s ; flush $LOG }
proc abort {s} { out "ETA_ABORT: $s" ; exit 1 }
proc hex {v} { return [format 0x%08X [expr {$v & 0xFFFFFFFF}]] }
proc rd32 {a} { return [expr {[lindex [mrd -force -value [hex $a] 1] 0] & 0xFFFFFFFF}] }
proc wr32 {a v} { mwr -force [hex $a] [hex $v] }
proc d32 {b a} { return [expr {($b - $a) & 0xFFFFFFFF}] }

# ---- 1. JTAG ------------------------------------------------------------------------------
connect
after 1000
set tl [targets]
out "=== targets ===\n$tl"
set nzynq [regexp -all {xc7z} $tl]
if {$nzynq != 1} { abort "expected exactly one xc7z device on JTAG, found $nzynq (unplug the other board)" }

# ---- 2. PL + PS bring-up (same order as tools/dl_pl_only.tcl, proven on this board) -------------
targets -set -nocase -filter {name =~ "APU*"}
rst -system
after 1000
out "=== fpga -file $ETA(bit) ==="
fpga -file $ETA(bit)
source $ETA(psinit)
ps7_init
ps7_post_config
targets -set -nocase -filter {name =~ "ARM*#0"}
catch { stop }
out "=== PS7 init done, ARM#0 halted; PL running on FCLK0=$ETA(fclk_hz) Hz ==="

# ---- 3. gauge self-test -------------------------------------------------------------------
set CTRL 0
proc gctrl {v} { global CTRL GP_OUT ; set CTRL $v ; wr32 $GP_OUT $v }
proc gread {sel} { global CTRL GP_IN ; gctrl [expr {($CTRL & 0x0F) | ($sel << 4)}] ; return [rd32 $GP_IN] }
set magic [gread 6]
if {$magic != 0xE7A00001} { abort [format "eta_mon MAGIC readback 0x%08X != 0xE7A00001 (GPIO->mon path broken / wrong bit)" $magic] }
set echo [gread 7]
if {($echo & 0xF0) != 0x70} { abort [format "ctrl echo 0x%08X does not reflect sel=7" $echo] }
set c0 [gread 8] ; after 50 ; set c1 [gread 8]
if {$c0 == $c1} { abort "live cycle counter is not moving (FCLK0 stopped? reset stuck?)" }
set st [gread 9]
out [format "=== gauge ok: MAGIC ok, echo ok, live cyc moving, status=0x%02X (idle0=%d idle1=%d) ===" $st [expr {($st>>2)&1}] [expr {($st>>3)&1}]]
if {(($st >> 2) & 1) != 1 || (($st >> 3) & 1) != 1} { abort "IPs not idle after reset" }
# f_clk against the host clock (JTAG latency ~ms over 4 s => <0.2 %)
set t0 [clock microseconds] ; set k0 [gread 8]
after 4000
set t1 [clock microseconds] ; set k1 [gread 8]
set fmeas [expr {[d32 $k1 $k0] * 1.0e6 / ($t1 - $t0)}]
out [format "=== f_clk measured %.3f MHz vs configured %.3f MHz (%.2f %%) ===" [expr {$fmeas/1e6}] [expr {$F/1e6}] [expr {100.0*($fmeas-$F)/$F}]]
if {abs($fmeas - $F) / $F > 0.02} { abort "measured FCLK off by more than 2 % -- counter clock is not what eta_regs says" }

# ---- 4. DDR ---------------------------------------------------------------------------------
foreach {a v} [list $SCRATCH 0xA5C3F00F [expr {$SCRATCH+4}] 0x5A3C0FF0 $VOX_BASE 0x12345678] { wr32 $a $v }
foreach {a v} [list $SCRATCH 0xA5C3F00F [expr {$SCRATCH+4}] 0x5A3C0FF0 $VOX_BASE 0x12345678] {
    set g [rd32 $a] ; if {$g != $v} { abort [format "DDR readback at 0x%08X: 0x%08X != 0x%08X" $a $g $v] } }
out "=== DDR write/readback ok; downloading voxel grid ($EXPECT(bytes) B) to [hex $VOX_BASE] (~20-40 s over JTAG) ==="
set td0 [clock seconds]
dow -data $VOXFILE [hex $VOX_BASE]
out "=== dow done in [expr {[clock seconds]-$td0}] s ==="
proc check_words {addr want tag} {
    set got [mrd -force -value [hex $addr] [llength $want]]
    for {set i 0} {$i < [llength $want]} {incr i} {
        if {([lindex $got $i] & 0xFFFFFFFF) != [lindex $want $i]} {
            abort [format "%s: word %d at 0x%08X = 0x%08X, expected %s" $tag $i $addr [lindex $got $i] [lindex $want $i]] } }
    out "   $tag ok at [hex $addr]: $want"
}
check_words $VOX_BASE $EXPECT(head) "voxel head"
check_words [expr {$VOX_BASE + $EXPECT(seq_off)}] $EXPECT(seq_head) "voxel slice-0 start"

# ---- 5. IP registers ------------------------------------------------------------------------
proc ipcfg {base phase nslots aoff mir pf slot} {
    global REG ETA VOX_BASE
    set w [list VOXEL $VOX_BASE PHASE $phase N_SLOTS $nslots AXIS_OFF_Q8 $aoff MIRROR_U $mir]
    if {$ETA(variant) eq "rd"} { lappend w PF_COLS $pf } else { lappend w SLOT_BASE $slot SLOT_START 0 }
    foreach {n v} $w { wr32 [expr {$base + $REG($n)}] $v }
    wr32 [expr {$base + $REG(VOXEL) + 4}] 0
    if {$ETA(variant) eq "wr"} { wr32 [expr {$base + $REG(SLOT_BASE) + 4}] 0 }
    foreach {n v} $w {
        set g [rd32 [expr {$base + $REG($n)}]]
        if {$g != ($v & 0xFFFFFFFF)} { abort [format "ip@%s reg %s readback 0x%08X != 0x%08X" [hex $base] $n $g $v] } }
}
proc wait_idle {} {
    for {set i 0} {$i < 200} {incr i} { set s [gread 9] ; if {(($s >> 2) & 3) == 3} { return $i } ; after 10 }
    abort "IPs did not go idle within 2 s after start was dropped"
}

# ---- 6. one measurement --------------------------------------------------------------------
# mask bit0 = run ip0, bit1 = run ip1. Returns list: {us0 us1 eta overlap runs0 runs1}
proc measure {tag mask nslots} {
    global F WIN SLOT_BYTES DDR_PEAK ETA
    set stbits [expr {(($mask & 1) ? 2 : 0) | (($mask & 2) ? 4 : 0)}]
    gctrl 0x8 ; gctrl 0x0                       ;# clear counters (rising edge on bit3), start lines low
    gctrl $stbits                               ;# one write: both ap_start rise on the same clock edge
    after 500                                   ;# settle (first runs, JTAG jitter)
    gctrl $stbits ; gctrl [expr {$stbits | 1}]  ;# snapshot A (rising edge on bit0)
    set SELS {0 1 2 3 4 5 11 12 13 14}
    set A {} ; foreach s $SELS { lappend A [gread $s] }
    gctrl $stbits                               ;# bit0 low again
    after [expr {int($WIN * 1000)}]
    gctrl [expr {$stbits | 1}]                  ;# snapshot B
    set B {} ; foreach s $SELS { lappend B [gread $s] }
    set snaps [gread 10]
    gctrl 0x0                                   ;# drop start: IPs finish the current run and idle
    set polls [wait_idle]
    set d {} ; for {set i 0} {$i < [llength $SELS]} {incr i} { lappend d [d32 [lindex $B $i] [lindex $A $i]] }
    lassign $d cyc done0 done1 busy0 busy1 both per0 pcnt0 per1 pcnt1
    if {$cyc == 0} { abort "$tag: zero cycles between snapshots" }
    set secs [expr {$cyc / $F}]
    set res {}
    foreach i {0 1} done [list $done0 $done1] busy [list $busy0 $busy1] per [list $per0 $per1] pcnt [list $pcnt0 $pcnt1] {
        if {(($mask >> $i) & 1) == 0} { lappend res 0 0 0 ; continue }
        if {$done == 0} { abort "$tag: ip$i completed 0 runs in $secs s (stuck? no DDR response?)" }
        if {$pcnt == 0} { abort "$tag: ip$i has no complete done-to-done period in the window (window too short?)" }
        set slices [expr {$done * $nslots}]
        set us_wall [expr {1e6 * $secs / $slices}]
        set us_busy [expr {1e6 * $busy / $F / $slices}]
        # exact: average done-to-done period over complete runs only (no partial-run edge error)
        set cyc_per_slice [expr {double($per) / $pcnt / $nslots}]
        set us_exact [expr {1e6 * $cyc_per_slice / $F}]
        set MBs [expr {$SLOT_BYTES / $us_exact}]
        lappend res $us_exact $MBs $done
        out [format "   %-11s ip%d: runs=%-5d periods=%-5d  %.1f cyc/slice = %.2f us/slice (exact)   wall %.2f us  busy %.1f %%   %.1f MB/s = %.0f %% of one HP port" \
            $tag $i $done $pcnt $cyc_per_slice $us_exact $us_wall [expr {100.0*$busy/$cyc}] $MBs [expr {100.0*$MBs*1e6/(8.0*$F)}]]
        if {abs($us_wall - $us_exact) / $us_exact > 0.05} { out "   $tag: WARNING wall vs exact differ by >5 % -- runs not back-to-back? (see busy %)" }
    }
    lassign $res us0 MB0 r0 us1 MB1 r1
    # wr variant: every slice is also written back (82,944 B) -> DDR moves 2x the read bytes
    set ddr_mult [expr {$ETA(variant) eq "wr" ? 2.0 : 1.0}]
    set eta [expr {($MB0 + $MB1) * $ddr_mult * 1e6 / $DDR_PEAK}]
    set overlap [expr {double($both) / $cyc}]
    out [format "   %-11s window %.2f s, snapshots=%d, DDR read %.1f MB/s%s => eta = %.3f  (overlap both-busy %.1f %%, idle after %d polls)" \
        $tag $secs $snaps [expr {$MB0+$MB1}] [expr {$ddr_mult > 1 ? " (+ same again written)" : ""}] $eta [expr {100.0*$overlap}] $polls]
    return [list $us0 $us1 $eta $overlap $r0 $r1]
}
proc check_xor {base want tag} {
    global REG
    set lo [rd32 [expr {$base + $REG(XOR_OUT)}]] ; set hi [rd32 [expr {$base + $REG(XOR_OUT) + 4}]]
    set got [format 0x%08X%08X $hi $lo]
    if {[string toupper $got] ne [string toupper $want]} { abort "$tag: XOR readback $got != expected $want -> IP did NOT read the addresses the reference reads" }
    out "   $tag: XOR $got matches host expectation (data path proven)"
}
proc check_slot {slot tag} {
    global VOX_BASE EXPECT
    set got [mrd -force -value [hex $slot] 4]
    for {set i 0} {$i < 4} {incr i} {
        if {([lindex $got $i] & 0xFFFFFFFF) != [lindex $EXPECT(seq_head) $i]} { abort "$tag: slot[$i]=[lindex $got $i] != voxel word [lindex $EXPECT(seq_head) $i]" } }
    set g [rd32 [expr {$slot + $EXPECT(slot_bytes) - 4}]] ; set w [rd32 [expr {$VOX_BASE + $EXPECT(seq_off) + $EXPECT(slot_bytes) - 4}]]
    if {$g != $w} { abort "$tag: last slot word [hex $g] != voxel [hex $w]" }
    out "   $tag: slot content == voxel slice 0 (first 4 + last word)"
}

# ---- 7. matrix -------------------------------------------------------------------------------
out "\n=== eta test matrix: variant=$ETA(variant) f=[expr {$F/1e6}] MHz window=$WIN s  (82,944 B read per slice, DDR peak 2.133 GB/s) ==="
set isrd [expr {$ETA(variant) eq "rd"}]
set PF 2
# --- calibration with one IP: sequential / strided / (rd) no-prefetch -------------------------
ipcfg $ETA(ip0) 0   1 0 0 $PF $SLOT0_BASE ; set r [measure CAL_SEQ 1 1]
if {$isrd} { check_xor $ETA(ip0) $EXPECT(xor,0,1) CAL_SEQ } else { check_slot $SLOT0_BASE CAL_SEQ }
set us_seq [lindex $r 0]
ipcfg $ETA(ip0) 151 1 0 0 $PF $SLOT0_BASE ; set r [measure CAL_STRIDE 1 1]
if {$isrd} { check_xor $ETA(ip0) $EXPECT(xor,151,1) CAL_STRIDE }
set us_str [lindex $r 0]
if {$isrd} {
    ipcfg $ETA(ip0) 0 1 0 0 0 $SLOT0_BASE ; set r [measure CAL_PF0 1 1] ; set us_pf0 [lindex $r 0]
    out [format "   >>> single IP, one slice: sequential %.2f us, strided %.2f us, no-prefetch(as-is IP behaviour) %.2f us; csynth floor 69.1 us" $us_seq $us_str $us_pf0]
}
# --- full 603-slice sweep, single IP ---------------------------------------------------------
ipcfg $ETA(ip0) 0 603 0 0 $PF $SLOT0_BASE ; set r [measure SINGLE 1 603]
if {$isrd} { check_xor $ETA(ip0) $EXPECT(xor,0,603) SINGLE } else { check_slot $SLOT0_BASE SINGLE }
set us_single [lindex $r 0]
# --- THE measurement: both IPs, full sweeps, orthogonal phases -------------------------------
ipcfg $ETA(ip0) 0   603 0 0 $PF $SLOT0_BASE
ipcfg $ETA(ip1) 151 603 0 0 $PF $SLOT1_BASE
set dual [measure DUAL 3 603]
if {$isrd} { check_xor $ETA(ip0) $EXPECT(xor,0,603) DUAL/ip0 ; check_xor $ETA(ip1) $EXPECT(xor,151,603) DUAL/ip1 } else { check_slot $SLOT0_BASE DUAL/ip0 }
if {!$QUICK} {
    ipcfg $ETA(ip1) 0 603 0 0 $PF $SLOT1_BASE ; set dual_same [measure DUAL_SAMEPH 3 603]
    if {$isrd} {
        foreach pf {0 4 6} {
            ipcfg $ETA(ip0) 0 603 0 0 $pf $SLOT0_BASE ; ipcfg $ETA(ip1) 151 603 0 0 $pf $SLOT1_BASE
            set dual_pf($pf) [measure DUAL_PF$pf 3 603]
        }
    }
    # face-B geometry (axis_off 13.4 mm = 4391 q8): some columns clamp to column 0 -> page hits, should not be slower
    ipcfg $ETA(ip0) 0 603 0 0 $PF $SLOT0_BASE ; ipcfg $ETA(ip1) 151 603 4391 1 $PF $SLOT1_BASE
    set dual_b [measure DUAL_FACEB 3 603]
}

# ---- verdict ---------------------------------------------------------------------------------
lassign $dual us0 us1 eta ov
set worst [expr {$us0 > $us1 ? $us0 : $us1}]
out "\n=== VERDICT ($ETA(variant), DUAL: ip0 phase 0 + ip1 phase 151, 603 slices, pf=$PF) ==="
out [format "   ip0 %.2f us/slice   ip1 %.2f us/slice   worst %.2f us   overlap %.1f %%   eta = %.3f (need >= 0.70 bare / >= 0.84 with 20 %% margin)" $us0 $us1 $worst [expr {100*$ov}] $eta]
out [format "   single-IP full sweep %.2f us/slice; dual/single ratio %.2f (1.00 = DDR not the bottleneck at this load)" $us_single [expr {$worst/$us_single}]]
if {$ov < 0.98} {
    out "   RESULT: INVALID -- the two IPs were not running concurrently (overlap < 98 %); look at runs/idle above"
} elseif {$worst <= 110.6 / 1.2} {
    out [format "   RESULT: GO with >=20 %% margin (worst %.1f us <= 92.2 us)" $worst]
} elseif {$worst <= 110.6} {
    out [format "   RESULT: GO (bare): worst %.1f us <= 110.6 us but margin < 20 %%" $worst]
} else {
    out [format "   RESULT: NO-GO at this gauge: worst %.1f us > 110.6 us" $worst]
    if {$isrd} { out "   (if CAL_PF0 ~ CAL_SEQ the IP, not DDR, is the limiter -> see README 'inconclusive' branch)" }
}
out "=== log: [file normalize $build]/eta_result_*.txt ==="
close $LOG
exit 0
