import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from display_128x128 import write_panels
img = Image.new('RGB',(128,128))
for y in range(128):
    c = (255,255,0) if y < 64 else (187,165,88)   # 满黄 / 发色金
    for x in range(128):
        img.putpixel((x,y), c)
img = img.rotate(180)
L = img.crop((0,0,64,128)); R = img.crop((64,0,128,128))
fixed = Image.new('RGB',(128,128)); fixed.paste(R,(0,0)); fixed.paste(L,(64,0))
write_panels(fixed, r'D:\claude_workspace\pov3d\zynq_pov\tools')
print("yellow test: top=full yellow, bottom=hair gold")
