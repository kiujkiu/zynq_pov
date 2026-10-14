# soak8h v0_8h_1014_2345: PASS

- **S1_duration** ✅ board ran the full 480 min (wall clock on the board; health rows span >= 477 min), uptime monotonic (no reboot)
  - health rows 465, span 478.8 min, monotonic True, "480 min done" True
- **S2_alive** ✅ voxslice never died/restarted; PL stall 0 (1 s monitor)
  - stalls 0 deaths 0
- **S3_completion** ✅ every 10 s window completion A and B >= 99 %; per hour un-completed slices <= 0.1 % (KR7.1)
  - windows 2878 (>= 2592), below 99 %: 0, min A/B 100.0/100.0 %, worst hour 0.0012 %, hourly (incomplete %, miss+late %): h0 0.0011/0.0047, h1 0.0012/0.0046, h2 0.0011/0.0045, h3 0.0011/0.0048, h4 0.0011/0.0048, h5 0.0012/0.0047, h6 0.0011/0.0045, h7 0.0011/0.0049
- **S4_pl_errors** ✅ PL grid-switch failures 0; on-board verify same >= 1, different 0; backend error / RRESP 0
  - failures 0, verify 204/0, error windows 0
- **S5_stream** ✅ all pushes: voxlive rc 0, frames / push time >= 14.0 fps, NAK 0; a connection lost by error is re-made within 60 s (auto reconnect)
  - pushes 11 (rc 0,0,0,0,0,0,0,0,0,0,0), 353980 frames / 24163 s = 14.65 fps, connections 11, lost by error 0 (re-made after  s); NAK lines 0
- **S6_hold_back** ✅ after every push: keep the last frame, back to the local demo 300 s later
  - holds 11, backs 11, delays 300,300,300,300,300,300,300,300,300,300,300
- **S7_network** ✅ ping loss <= 2 %, longest outage <= 5 min; povnetd + povstat present in every health row
  - ping 961 probes, lost 0, longest 0 s; rows without povnetd/povstat 0
- **S8_memory** ✅ voxslice VmRSS growth <= 8 MB, MemAvailable drop <= 32 MB (median of first/last 10 min)
  - voxslice RSS 33.6 -> 33.6 MB, MemAvailable 305 -> 302 MB
- **S9_restored** ✅ board back to the boot default (card voxslice --pl, slice.mode pl)
  - restore=ok; vs=14697 cmd=/mnt/mmcblk0p1/pov/vs/voxslice_aarch64 ... --local-fps 10 --stat 60 --idle-ctl /tmp/vs/vs.mode --oe-w0 32 --idle-oe 8,4,2 --idle-b-slot 1 --stream-hold 300 --pl --pl-lut /mnt/mmcblk0p1/pov/pls/lut_pl --cpu-rx 0 --cpu-slice 1 --max-fps 15  slice.mo
