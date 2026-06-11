"""重生成 8x8 棋盘 bin, 逻辑源图整体转 180 度 (修上下颠倒)."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from display_128x128 import write_panels

OUT_DIR = r'D:\claude_workspace\pov3d\zynq_pov\tools'
src = Image.open(os.path.join(OUT_DIR, 'chess_8x8_src.png')).convert('RGB')
src = src.rotate(180)   # 修上下颠倒 + 数字正立 (check2 验证好)
# 再把左右两个 64 宽半幅整块交换 (不内部镜像), 修 R180 引入的左右对调
L = src.crop((0, 0, 64, 128))
R = src.crop((64, 0, 128, 128))
swapped = Image.new('RGB', (128, 128))
swapped.paste(R, (0, 0))
swapped.paste(L, (64, 0))
write_panels(swapped, OUT_DIR)
print("regenerated chess bins: rotate180 + swap halves")
