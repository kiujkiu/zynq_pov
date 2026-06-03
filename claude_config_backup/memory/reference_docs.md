---
name: zynq_pov in-repo documentation index
description: Where to find prior debug logs, status snapshots, and how-to-resume guides inside the cloned repo
type: reference
originSessionId: a079e7ff-01aa-4018-abc1-014cf07015a0
---
The repo at `/mnt/d/claude_workspace/pov3d/zynq_pov/` contains its own narrative documentation — read these before assuming repo state from code alone:

- `HOWTO_RESUME.md` — how to rebuild bitstream + ELF on a fresh machine, software versions, dependency list, known issues
- `HOWTO.md` — original how-to
- `STATUS_2026-04-23_EOD.md` — last day's end-of-day state (HDMI black-screen mystery, 4-IP dispatcher status)
- `AUTONOMOUS_RUN_2026-04-25_to_27.md` — schedule for the 36-hour autonomous run authorized on 2026-04-25
- `PROGRESS_HOURLY.md` — hour-by-hour progress log during the autonomous run
- `DEBUG_LOG_2026-04-22.md` — early ARM CPU rendering
- `DEBUG_LOG_2026-04-23.md` — HLS IP synthesis + integration
- `DEBUG_LOG_2026-04-25.md` — anime demo + HDMI capture + GUI + 36-slice grid
- `DEBUG_LOG_2026-04-27.md` — Phase 7: voxelization (256³), UART → 921600, HDMI tearing fix, 1080p30, 4-IP voxel slicer design, QSPI persistence
- `docs/capacity_analysis.html` — bandwidth + LED resolution scaling analysis

When user asks "what was the state of X" or "what did we try for Y", consult the dated debug log, not just the code.
