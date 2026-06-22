# 128x64 数字棋盘: 8列x4行=32格, 16x16/格, HSV唯一色+白色3x5数字。
# 输出: chess32.png 预览 + _fb_load.tcl (mwr 灌 fb + 开 use_fb)
import colorsys, os
W,H,CELL = 128,64,16
GX,GY = W//CELL, H//CELL   # 8 x 4 = 32
FB_BASE = 0x40028000

DIGITS = {
 '0':['111','101','101','101','111'],'1':['010','110','010','010','111'],
 '2':['111','001','111','100','111'],'3':['111','001','111','001','111'],
 '4':['101','101','111','001','001'],'5':['111','100','111','001','111'],
 '6':['111','100','111','101','111'],'7':['111','001','010','100','100'],
 '8':['111','101','111','101','111'],'9':['111','101','111','001','111'],}

px = [[(0,0,0)]*W for _ in range(H)]
def putdigit(ch,x,y,col):
    if ch not in DIGITS: return
    for dy,row in enumerate(DIGITS[ch]):
        for dx,c in enumerate(row):
            if c=='1' and 0<=x+dx<W and 0<=y+dy<H: px[y+dy][x+dx]=col

for gy in range(GY):
    for gx in range(GX):
        idx=gy*GX+gx
        PAL=[(255,0,0),(0,255,0),(0,0,255),(255,255,0),(255,0,255),(0,255,255)]
        cc=PAL[idx%6]   # 1-bit 饱和色循环 (bit0 必置位)
        x0,y0=gx*CELL,gy*CELL
        for yy in range(CELL):
            for xx in range(CELL):
                px[y0+yy][x0+xx]=cc
        # 数字: 十位+个位, 白色, 左上角
        tens,ones=idx//10,idx%10
        wx=x0+2
        if tens>0: putdigit(str(tens),wx,y0+2,(255,255,255)); wx+=4
        putdigit(str(ones),wx,y0+2,(255,255,255))

# 预览 png
try:
    from PIL import Image
    im=Image.new('RGB',(W,H))
    for y in range(H):
        for x in range(W): im.putpixel((x,y),px[y][x])
    im.resize((W*6,H*6),Image.NEAREST).save(r'D:\claude_workspace\pov3d\zynq_pov_icnd2047\chess32.png')
    print("preview chess32.png saved")
except Exception as e: print("png skip:",e)

# 打包 24-bit word: bits[21:16]=B6 [13:8]=G6 [5:0]=R6 (6-bit BCM, IP色序重映射处理lane)
def word(r,g,b):
    r6,g6,b6=r>>2,g>>2,b>>2
    return (b6<<16)|(g6<<8)|r6
words=[]
for row in range(H):
    for col in range(W):
        r,g,b=px[row][col]; words.append(word(r,g,b))
print("words=",len(words))

# 生成 tcl: connect+灌fb(分块mwr)+开 use_fb
lines=[]
lines.append('connect')
lines.append('after 500')
lines.append('targets -set -nocase -filter {name =~ "*Cortex*#0*" || name =~ "ARM*#0"}')
lines.append('configparams force-mem-access 1')
CH=512
for i in range(0,len(words),CH):
    chunk=words[i:i+CH]
    vals=' '.join('0x%06X'%w for w in chunk)
    addr=FB_BASE+i*4
    lines.append('mwr -force 0x%08X {%s} %d'%(addr,vals,len(chunk)))
lines.append('mwr -force 0x40020000 0')         # disable
lines.append('mwr -force 0x40020008 127')       # PARAM width-1=127, col_shift=0
lines.append('mwr -force 0x40020014 16')        # TUNIT
lines.append('mwr -force 0x40020000 0x2561')     # en|use_fb(0x20)|overlap(0x40)|addr(0x500)|planes=1(0x2000)
lines.append('after 300')
lines.append('puts "FB loaded. CTRL=[format 0x%X [mrd -force -value 0x40020000]] fb_we=[expr {[mrd -force -value 0x40020018]}]"')
lines.append('exit')
open(r'D:\claude_workspace\pov3d\zynq_pov_icnd2047\tools\_fb_load.tcl','w').write('\n'.join(lines)+'\n')
print("_fb_load.tcl written, chunks=",(len(words)+CH-1)//CH)
