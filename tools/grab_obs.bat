@echo off
set FF=C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\Lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe
"%FF%" -hide_banner -y -f dshow -i "video=OBS Virtual Camera" -frames:v 15 -update 1 D:\workspace\zynq_pov\hdmi_obs.jpg
