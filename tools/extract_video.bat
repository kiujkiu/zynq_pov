@echo off
set FF=C:\Users\kiujkiu\AppData\Local\Programs\Python\Python312\Lib\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe
set IN=%1
"%FF%" -hide_banner -y -i %IN% -vf fps=2 -frames:v 12 D:\workspace\zynq_pov\video_frames\f_%%02d.jpg
