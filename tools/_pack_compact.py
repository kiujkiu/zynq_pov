"""全格式 slice bin (64KB/片) → v7 紧凑格式 (8KB/片).
lane k bit0=B bit1=R bit2=G ← 全格式 word bit0/bit8/bit16."""
import struct, numpy as np
src = np.fromfile(r'D:\claude_workspace\pov3d\zynq_pov\tools\anime_slices_360.bin', dtype='<u4')
n_slices = len(src) // 16384
w = src.reshape(n_slices, 2048, 8)            # 每 8 像素一组
# v7 RTL lane 读序: IP r1<-lane1, g1<-lane2, b1<-lane0 (c_r1=+1/c_g1=+2/c_b1=+0)
# 要等效 v6 (IP r1<-word.bit0, g1<-bit8, b1<-bit16): bit0->lane1, bit8->lane2, bit16->lane0
lanes = (((w >> 0) & 1) << 1) | (((w >> 8) & 1) << 2) | (((w >> 16) & 1) << 0)
shifts = (np.arange(8, dtype=np.uint32) * 3)
packed = (lanes.astype(np.uint32) << shifts).sum(axis=2).astype('<u4')   # [n,2048]
packed.tofile(r'D:\claude_workspace\pov3d\zynq_pov\tools\anime_slices_360_compact.bin')
print(f'{n_slices} slices -> compact {packed.nbytes} bytes ({packed.nbytes//n_slices} B/slice)')
