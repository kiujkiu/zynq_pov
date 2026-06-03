#!/usr/bin/env python3
"""Wrap ccusage statusline and append 5h / 7d rate-limit progress bars.

Claude Code pipes a JSON blob to the statusline command. For Pro/Max
subscribers it includes `rate_limits.five_hour.used_percentage` and
`rate_limits.seven_day.used_percentage`. We forward stdin to ccusage and
append two compact bars based on those fields. Falls back silently when
the fields are missing (e.g. API-key auth or before first response).
"""
import json
import os
import subprocess
import sys

CCUSAGE = "/home/kiujkiu/.npm-global/bin/ccusage"
BAR_WIDTH = 10
FILLED = "█"
EMPTY = "░"


def bar(pct: float) -> str:
    pct = max(0.0, min(100.0, pct))
    filled = int(round(pct * BAR_WIDTH / 100.0))
    return FILLED * filled + EMPTY * (BAR_WIDTH - filled)


def color(pct: float, text: str) -> str:
    if pct >= 90:
        code = "31"  # red
    elif pct >= 70:
        code = "33"  # yellow
    else:
        code = "32"  # green
    return f"\x1b[{code}m{text}\x1b[0m"


def fmt_reset_clock(ts: int, short: bool) -> str:
    try:
        import datetime as dt
        d = dt.datetime.fromtimestamp(int(ts)).astimezone()
        return d.strftime("%H:%M") if short else d.strftime("%m-%d %H:%M")
    except Exception:
        return ""


def fmt_remaining(secs: int) -> str:
    secs = max(0, int(secs))
    if secs < 3600:
        return f"{secs // 60}m"
    if secs < 86400:
        return f"{secs // 3600}h{(secs % 3600) // 60:02d}m"
    return f"{secs // 86400}d{(secs % 86400) // 3600}h"


def time_bar(resets_at, window_secs: int) -> tuple:
    """Return (elapsed_pct, remaining_str, reset_clock_str) or (None,None,None)."""
    if not resets_at:
        return None, None, None
    import time
    now = int(time.time())
    remaining = int(resets_at) - now
    if remaining < 0:
        remaining = 0
    elapsed = window_secs - remaining
    pct = max(0.0, min(100.0, elapsed * 100.0 / window_secs))
    short = window_secs <= 6 * 3600
    return pct, fmt_remaining(remaining), fmt_reset_clock(resets_at, short)


def main() -> None:
    raw = sys.stdin.read()

    try:
        with open("/tmp/claude_statusline_last.json", "w", encoding="utf-8") as fp:
            fp.write(raw)
    except Exception:
        pass

    try:
        proc = subprocess.run(
            [CCUSAGE, "statusline"],
            input=raw,
            capture_output=True,
            text=True,
            timeout=5,
        )
        base = proc.stdout.rstrip("\n")
    except Exception as e:
        base = f"[ccusage err: {e}]"

    try:
        data = json.loads(raw) if raw.strip() else {}
    except Exception:
        data = {}

    rl = data.get("rate_limits") or {}
    fh = rl.get("five_hour") or {}
    sd = rl.get("seven_day") or {}

    EMPTY_BAR = EMPTY * BAR_WIDTH
    DIM = "\x1b[2m"
    RESET = "\x1b[0m"

    extras = []
    fh_pct = fh.get("used_percentage")
    if isinstance(fh_pct, (int, float)):
        extras.append(color(fh_pct, f"5h用 {bar(fh_pct)} {fh_pct:.0f}%"))
    else:
        extras.append(f"{DIM}5h用 {EMPTY_BAR} --{RESET}")

    sd_pct = sd.get("used_percentage")
    if isinstance(sd_pct, (int, float)):
        extras.append(color(sd_pct, f"7d用 {bar(sd_pct)} {sd_pct:.0f}%"))
    else:
        extras.append(f"{DIM}7d用 {EMPTY_BAR} --{RESET}")

    fh_t_pct, fh_left, fh_clock = time_bar(fh.get("resets_at"), 5 * 3600)
    if fh_t_pct is not None:
        extras.append(f"\x1b[36m5h时 {bar(fh_t_pct)} 余{fh_left} ↻{fh_clock}{RESET}")
    else:
        extras.append(f"{DIM}5h时 {EMPTY_BAR} 余-- ↻--{RESET}")

    sd_t_pct, sd_left, sd_clock = time_bar(sd.get("resets_at"), 7 * 86400)
    if sd_t_pct is not None:
        extras.append(f"\x1b[36m7d时 {bar(sd_t_pct)} 余{sd_left} ↻{sd_clock}{RESET}")
    else:
        extras.append(f"{DIM}7d时 {EMPTY_BAR} 余-- ↻--{RESET}")

    print(f"{base} | " + " | ".join(extras), end="")


if __name__ == "__main__":
    main()
