@echo off
set FF=C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\Lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe
"%FF%" -hide_banner -y -f dshow -rtbufsize 32M -i "video=C1-1 USB3 Video" -frames:v 30 -update 1 D:\workspace\zynq_pov\hdmi_direct.jpg
