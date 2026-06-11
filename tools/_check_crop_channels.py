import numpy as np
from PIL import Image
img = np.asarray(Image.open('tools/anime_crop.png').convert('RGB')).astype(int)
h,w,_ = img.shape
print(f'size {w}x{h}')
# 四角背景色
print('corner(bg):', img[2,2], img[2,-3], img[-3,2], img[-3,-3])
# 找最亮的暖色区域 (头发候选): 非背景里采样几个区域
bg = np.median(np.array([img[2,2],img[2,-3],img[-3,2],img[-3,-3]]),axis=0)
mask = np.abs(img-bg).sum(axis=2) > 60
ys,xs = np.where(mask)
print(f'fg pixels: {mask.sum()}, bbox y[{ys.min()}:{ys.max()}] x[{xs.min()}:{xs.max()}]')
# 头发 = 人物最顶部 15% 的前景
ytop = ys.min(); ycut = ytop + int((ys.max()-ytop)*0.15)
hair = img[(mask) & (np.arange(h)[:,None] < ycut)[:,:]]
print('hair region mean RGB-as-read:', hair.mean(axis=0).round(0), f'(n={len(hair)})')
# 整体前景均值
print('fg mean RGB-as-read:', img[mask].mean(axis=0).round(0))
# 最亮 10% 前景像素均值 (铠甲/高光)
fg = img[mask]; bright = fg[fg.sum(axis=1) > np.percentile(fg.sum(axis=1), 90)]
print('brightest 10% mean:', bright.mean(axis=0).round(0))
