import struct
import numpy as np
data = open('tools/fb_anime_128_top1.bin','rb').read()
words = struct.unpack('<4096I', data)
# word: byte0=B byte1=R byte2=G
vals = [(w>>8 & 0x3F, w>>16 & 0x3F, w & 0x3F) for w in words if w != 0]  # (R,G,B)
arr = np.array(vals)
print(f'nonzero px: {len(arr)}')
# 金发候选: R 高且 R>G>B
gold = arr[(arr[:,0]>20)&(arr[:,0]>arr[:,1])&(arr[:,1]>arr[:,2])]
print(f'gold-ish px: {len(gold)}, mean RGB6 = {gold.mean(axis=0).round(1) if len(gold) else "none"}')
print('value histogram R:', np.histogram(arr[:,0], bins=[0,8,16,24,32,40,48,56,64])[0])
print('max RGB:', arr.max(axis=0))
