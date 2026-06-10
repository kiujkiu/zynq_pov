from PIL import Image
from collections import Counter
im = Image.open(r'D:\claude_workspace\pov3d\zynq_pov\tools\anime_crop.png').convert('RGB')
w, h = im.size
s = min(w, h)
im = im.crop(((w-s)//2, (h-s)//2, (w-s)//2+s, (h-s)//2+s))
im = im.resize((128, 128))
px = im.load()
# corners (should be background)
print('TL', px[0,0], 'TR', px[127,0], 'BL', px[0,127], 'BR', px[127,127])
# center sample
print('Center', px[64,64])
# top color stats
samples = [px[x,y] for y in range(0,128,4) for x in range(0,128,4)]
c = Counter(samples)
print('top 5 colors:', c.most_common(5))
