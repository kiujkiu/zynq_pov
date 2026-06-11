import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
from display_128x128 import write_panels
img = Image.new('RGB', (128,128), (0,255,0))  # 纯绿, 走 per-panel 增益
write_panels(img, r'D:\claude_workspace\pov3d\zynq_pov\tools')
print("solid green bins written (with PANEL1_BRIGHT gain)")
