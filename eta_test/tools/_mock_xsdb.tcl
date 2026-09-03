# _mock_xsdb.tcl -- dry-run harness for run_eta.tcl WITHOUT a board.
# Replaces the xsdb commands (connect/targets/rst/fpga/mrd/mwr/dow/...) with a behavioural model of
# eta_mon + the two gauge IPs (80 us/slice, wall-clock driven), then sources run_eta.tcl.
# Purpose: catch Tcl/logic bugs in run_eta.tcl before touching hardware. Not a substitute for the board.
#   cmd.exe /c "cd /d D:\claude_workspace\pov3d\zynq_pov\eta_test && D:\Vitis\2024.2\bin\xsdb.bat tools\_mock_xsdb.tcl rd quick"
# Expected: script reaches "RESULT: GO ..." with eta ~0.97 (2 x 82,944 B / 80 us) and no ETA_ABORT.

set ::MOCK(f) 150.0e6
set ::MOCK(us_per_slice) 80.0
set ::MOCK(t0) [clock microseconds]
array set ::MEM {}
set ::MOCK(vox) ""
set ::MOCK(voxbase) 0
set ::MOCK(ctrl) 0
foreach k {cyc0 done0 done1 busy0 busy1 both0} { set ::MOCK($k) 0 }
foreach k {s_cyc s_done0 s_done1 s_busy0 s_busy1 s_both snaps} { set ::MOCK($k) 0 }
foreach i {0 1} { set ::MOCK(run$i) 0 ; set ::MOCK(tstart$i) 0 ; set ::MOCK(acc_busy$i) 0 ; set ::MOCK(acc_done$i) 0 }
set ::MOCK(tboth) 0 ; set ::MOCK(acc_both) 0
set ::MOCK(tclr) $::MOCK(t0)

proc mock_now {} { return [clock microseconds] }
proc mock_cyc {t} { global MOCK ; return [expr {int(($t - $MOCK(tclr)) * $MOCK(f) / 1e6) & 0xFFFFFFFF}] }
proc mock_ipreg {base off} { global MEM ; set a [expr {$base + $off}] ; return [expr {[info exists MEM($a)] ? $MEM($a) : 0}] }
proc mock_nslots {i} { global REG ETA ; return [mock_ipreg $ETA(ip$i) $REG(N_SLOTS)] }
proc mock_settle {} {
    # fold elapsed run time into accumulators (called on every ctrl change and read)
    global MOCK
    set now [mock_now]
    foreach i {0 1} {
        if {$MOCK(run$i)} {
            set dt [expr {$now - $MOCK(tstart$i)}]
            set MOCK(acc_busy$i) [expr {$MOCK(acc_busy$i) + $dt}]
            set n [mock_nslots $i] ; if {$n < 1} { set n 1 }
            set MOCK(acc_done$i) [expr {$MOCK(acc_done$i) + $dt / ($MOCK(us_per_slice) * $n)}]
            set MOCK(tstart$i) $now
        }
    }
    if {$MOCK(run0) && $MOCK(run1)} { set MOCK(acc_both) [expr {$MOCK(acc_both) + ($now - $MOCK(tboth))}] ; set MOCK(tboth) $now }
}
proc mock_counters {} {
    global MOCK
    mock_settle
    set f $MOCK(f)
    return [list [mock_cyc [mock_now]] [expr {int($MOCK(acc_done0))}] [expr {int($MOCK(acc_done1))}] \
        [expr {int($MOCK(acc_busy0) * $f / 1e6) & 0xFFFFFFFF}] [expr {int($MOCK(acc_busy1) * $f / 1e6) & 0xFFFFFFFF}] \
        [expr {int($MOCK(acc_both) * $f / 1e6) & 0xFFFFFFFF}]]
}
proc mock_ctrl_write {v} {
    global MOCK
    set old $MOCK(ctrl)
    mock_settle
    set now [mock_now]
    if {($v & 8) && !($old & 8)} {                     ;# clear
        set MOCK(tclr) $now
        foreach i {0 1} { set MOCK(acc_busy$i) 0 ; set MOCK(acc_done$i) 0 ; set MOCK(tstart$i) $now }
        set MOCK(acc_both) 0 ; set MOCK(tboth) $now
    }
    foreach i {0 1} {
        set bit [expr {($v >> (1 + $i)) & 1}]
        if {$bit && !$MOCK(run$i)} { set MOCK(run$i) 1 ; set MOCK(tstart$i) $now }
        if {!$bit && $MOCK(run$i)} { set MOCK(run$i) 0 }
    }
    if {$MOCK(run0) && $MOCK(run1)} { set MOCK(tboth) $now }
    if {($v & 1) && !($old & 1)} {                     ;# snapshot
        lassign [mock_counters] MOCK(s_cyc) MOCK(s_done0) MOCK(s_done1) MOCK(s_busy0) MOCK(s_busy1) MOCK(s_both)
        incr MOCK(snaps)
    }
    set MOCK(ctrl) $v
}
proc mock_gpio_read {} {
    global MOCK
    set sel [expr {($MOCK(ctrl) >> 4) & 0xF}]
    switch $sel {
        0 { return $MOCK(s_cyc) } 1 { return $MOCK(s_done0) } 2 { return $MOCK(s_done1) }
        3 { return $MOCK(s_busy0) } 4 { return $MOCK(s_busy1) } 5 { return $MOCK(s_both) }
        6 { return 0xE7A00001 } 7 { return $MOCK(ctrl) } 8 { return [mock_cyc [mock_now]] }
        9 { return [expr {($MOCK(run0) ? 0 : 4) | ($MOCK(run1) ? 0 : 8) | ($MOCK(ctrl) & 6)}] }
        10 { return $MOCK(snaps) }
        11 { return [expr {int(($MOCK(s_done0) > 0 ? $MOCK(s_done0) - 1 : 0) * [mock_nslots 0] * $MOCK(us_per_slice) * $MOCK(f) / 1e6) & 0xFFFFFFFF}] }
        12 { return [expr {$MOCK(s_done0) > 0 ? $MOCK(s_done0) - 1 : 0}] }
        13 { return [expr {int(($MOCK(s_done1) > 0 ? $MOCK(s_done1) - 1 : 0) * [mock_nslots 1] * $MOCK(us_per_slice) * $MOCK(f) / 1e6) & 0xFFFFFFFF}] }
        14 { return [expr {$MOCK(s_done1) > 0 ? $MOCK(s_done1) - 1 : 0}] }
        default { return [expr {0xDEAD0000 | $sel}] }
    }
}
proc mock_xor {i} {
    global REG ETA EXPECT
    set ph [mock_ipreg $ETA(ip$i) $REG(PHASE)] ; set n [mock_ipreg $ETA(ip$i) $REG(N_SLOTS)]
    if {[info exists EXPECT(xor,$ph,$n)]} { return $EXPECT(xor,$ph,$n) }
    return 0x0
}

# ---- xsdb command stand-ins ----
proc connect {args} { return "tcfchan#0" }
proc targets {args} { return "  1  APU\n     2  ARM Cortex-A9 MPCore #0 (Running)\n     3  ARM Cortex-A9 MPCore #1 (Running)\n  4  xc7z020" }
proc rst {args} {}
proc fpga {args} { puts "mock: fpga $args" }
proc ps7_init {} { puts "mock: ps7_init" }
proc ps7_post_config {} { puts "mock: ps7_post_config" }
proc stop {} {}
proc mask_write {addr mask val} { global MEM ; set a [expr {$addr}] ; set old [expr {[info exists MEM($a)] ? $MEM($a) : 0}] ; set MEM($a) [expr {($old & ~$mask) | ($val & $mask)}] }
proc mask_read {addr mask} { global MEM ; set a [expr {$addr}] ; return [expr {([info exists MEM($a)] ? $MEM($a) : 0xFFFFFFFF) & $mask}] }
proc dow {args} {
    global MOCK
    if {[lindex $args 0] eq "-data"} {
        set fh [open [lindex $args 1] rb] ; set MOCK(vox) [read $fh] ; close $fh
        set MOCK(voxbase) [expr {[lindex $args 2]}]
        foreach a [array names ::MEM] { if {$a >= $MOCK(voxbase) && $a < $MOCK(voxbase) + [string length $MOCK(vox)]} { unset ::MEM($a) } }
        puts "mock: dow -data [string length $MOCK(vox)] bytes at [lindex $args 2]"
    }
}
proc mwr {args} {
    global MEM ETA REG MOCK
    if {[lindex $args 0] eq "-force"} { set args [lrange $args 1 end] }
    lassign $args a v
    set a [expr {$a}] ; set v [expr {$v}]
    if {$a == $ETA(gpio)} { mock_ctrl_write $v ; return }
    set MEM($a) $v
}
proc mrd {args} {
    global MEM ETA REG MOCK
    if {[lindex $args 0] ne "-value"} {
        # ps7_init.tcl style: mrd <addr> -> "ADDR:   VALUE"; PLL lock / DDR poll registers read as all-ones
        set a [expr {[lindex $args 0]}]
        set v [expr {[info exists MEM($a)] ? $MEM($a) : 0xFFFFFFFF}]
        if {$a == 0xF8007080} { set v 0x30000000 }     ;# silicon 3.0
        return [format "%08X:   %08X\n" $a $v]
    }
    set a [expr {[lindex $args 1]}] ; set n [expr {[llength $args] > 2 ? [lindex $args 2] : 1}]
    set out {}
    for {set i 0} {$i < $n} {incr i} {
        set ad [expr {$a + 4*$i}]
        if {$ad == $ETA(gpio) + 8} { lappend out [mock_gpio_read] ; continue }
        set hit 0
        foreach ip {0 1} {
            if {[info exists REG(XOR_OUT)] && $ad == $ETA(ip$ip) + $REG(XOR_OUT)}     { lappend out [expr {[mock_xor $ip] & 0xFFFFFFFF}] ; set hit 1 }
            if {[info exists REG(XOR_OUT)] && $ad == $ETA(ip$ip) + $REG(XOR_OUT) + 4} { lappend out [expr {([mock_xor $ip] >> 32) & 0xFFFFFFFF}] ; set hit 1 }
        }
        if {$hit} continue
        if {$MOCK(vox) ne "" && $ad >= $MOCK(voxbase) && $ad + 4 <= $MOCK(voxbase) + [string length $MOCK(vox)] && ![info exists MEM($ad)]} {
            binary scan [string range $MOCK(vox) [expr {$ad - $MOCK(voxbase)}] [expr {$ad - $MOCK(voxbase) + 3}]] iu w
            lappend out $w ; continue
        }
        # wr-variant slot content: pretend the IP copied slice 0 (angle 0) into slot 0
        if {[info exists ::SLOT0_BASE] && $ad >= $::SLOT0_BASE && $ad < $::SLOT0_BASE + 82944 && $MOCK(vox) ne ""} {
            set o [expr {$ad - $::SLOT0_BASE + $::EXPECT(seq_off)}]
            binary scan [string range $MOCK(vox) $o [expr {$o + 3}]] iu w ; lappend out $w ; continue
        }
        lappend out [expr {[info exists MEM($ad)] ? $MEM($ad) : 0}]
    }
    return $out
}
set argv [lrange $argv 0 end]
source [file join [file dirname [info script]] run_eta.tcl]
