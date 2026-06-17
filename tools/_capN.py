import imageio_ffmpeg, subprocess, os, sys
ff = imageio_ffmpeg.get_ffmpeg_exe()
out_path = sys.argv[1]
r = subprocess.run([ff,"-hide_banner","-y","-f","dshow","-video_size","1920x1080","-framerate","30",
    "-i","video=Insta360 Link 2 Pro","-ss","1.2","-frames:v","1","-update","1",out_path],
    capture_output=True,text=True,timeout=20,encoding="utf-8",errors="ignore")
print("size", os.path.getsize(out_path) if os.path.exists(out_path) else "MISSING")
