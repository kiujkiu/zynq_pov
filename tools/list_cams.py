import imageio_ffmpeg, subprocess
r = subprocess.run(
    [imageio_ffmpeg.get_ffmpeg_exe(), '-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'],
    capture_output=True, text=True, encoding='utf-8', errors='ignore'
)
print(r.stderr)
