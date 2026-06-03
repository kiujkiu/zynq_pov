#!/usr/bin/env bash
# Restore Claude Code config + memory on a fresh machine / account.
# Usage: bash RESTORE.sh
#
# Restores:
#   - ~/.claude/settings.json          (statusLine + permissions + hooks)
#   - ~/.claude/statusline_with_bars.py
#   - ~/.claude/projects/-mnt-d-claude-workspace-pov3d/memory/  (auto-memory)
#
# Does NOT touch:
#   - ~/.claude/.credentials.json  (account-specific, leave Claude Code to handle)
#   - ~/.claude/hooks/             (codexflow_stop_notify.js may not exist on new machine)
#
# Prereqs:
#   - claude (Claude Code CLI) installed and logged in once
#   - npm i -g ccusage   (for the statusline base output)
#   - python3
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST_CFG="$HOME/.claude"
DEST_MEM="$HOME/.claude/projects/-mnt-d-claude-workspace-pov3d/memory"

echo "[1/4] Backing up any existing ~/.claude/settings.json"
[ -f "$DEST_CFG/settings.json" ] && cp "$DEST_CFG/settings.json" "$DEST_CFG/settings.json.bak.$(date +%s)"

echo "[2/4] Copying settings.json + statusline_with_bars.py"
mkdir -p "$DEST_CFG"
cp "$SRC/settings.json" "$DEST_CFG/settings.json"
cp "$SRC/statusline_with_bars.py" "$DEST_CFG/statusline_with_bars.py"
chmod +x "$DEST_CFG/statusline_with_bars.py"

echo "[3/4] Copying memory directory"
mkdir -p "$DEST_MEM"
cp -r "$SRC/memory/." "$DEST_MEM/"

echo "[4/4] Checking deps"
command -v ccusage >/dev/null || echo "  WARN: ccusage not in PATH. Run: npm i -g ccusage"
command -v python3 >/dev/null || echo "  WARN: python3 not found"

echo
echo "Done. Open a new Claude Code window to see the 4 progress bars."
echo "If settings.json references a hook that doesn't exist on this machine,"
echo "edit it and remove the 'hooks' block:"
echo "    nano $DEST_CFG/settings.json"
