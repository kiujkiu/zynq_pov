@echo off
set FF=C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\Lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe
"%FF%" -hide_banner -y -f dshow -rtbufsize 64M -i "video=OBS Virtual Camera" -t 5.0 -vf "fps=1/0.417" -frames:v 12 D:\workspace\zynq_pov\sweep_%%02d.jpg
