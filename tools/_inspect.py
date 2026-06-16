from PIL import Image
import numpy as np
im = Image.open(r'D:\claude_workspace\pov3d\zynq_pov\tools\earth_political.png').convert('LA')
a = np.asarray(im)  # H,W,2 (L, alpha)
L, A = a[...,0], a[...,1]
print('size', im.size)
print('alpha:透明(0)占比 %.1f%%  不透明(255)占比 %.1f%%' % ((A<128).mean()*100,(A>=128).mean()*100))
op = L[A>=128]
print('不透明区灰度直方:')
for lo in range(0,256,32):
    c = ((op>=lo)&(op<lo+32)).sum()
    print('  [%3d-%3d): %d' % (lo,lo+32,c))
