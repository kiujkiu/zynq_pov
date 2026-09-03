#!/usr/bin/env python3
"""量「传体素表」这条链路的真实载荷 —— 判决 08-27 第 3 项, 一直没做。

流程: 点云 → 缩放填满 192×216×192 → 体素化(去重) → 体素表 → lz4-HC12 / zlib-9 → 字节数 → Mbps。
生产口径: povstream.py 用 lz4 block HC12 (不是 frame 格式), 这里照抄。

三种表布局 (压缩比差别很大, 要分开量):
  A raw     (u32 idx, u16 rgb565) × N, 未排序           —— 最朴素
  B sorted  按 idx 排序, idx 差分成 u16, 与 rgb565 交错
  C split   排序差分 idx 一段 + rgb565 一段, 两段分开压  —— lz4 最喜欢的
"""
import struct, sys, numpy as np, lz4.block, zlib

GX, GY, GZ = 192, 216, 192          # 目标面阵: x/z 直径 192, y 高 216
FPS_LIST = (5, 10, 15)
LINK_MBPS = (110, 125)              # Zynq 持续吞吐实测区间

def load(path):
    raw = np.fromfile(path, dtype=np.dtype([('x','<i2'),('y','<i2'),('z','<i2'),('p','<i2'),
                                            ('r','u1'),('g','u1'),('b','u1'),('q','u1'),('pad','<i4')]))
    return raw

def voxelize(raw):
    xyz = np.stack([raw['x'], raw['y'], raw['z']], 1).astype(np.float64)
    # 缩放填满: xz 半径 96, y 半高 108; 等比, 取最紧的那个轴
    ext = np.abs(xyz).max(axis=0)                     # 各轴最大绝对值
    s = min(96/ext[0], 108/ext[1], 96/ext[2])
    g = np.round(xyz*s).astype(np.int64)
    g[:,0] += 96; g[:,1] += 108; g[:,2] += 96
    g = np.clip(g, 0, [GX-1, GY-1, GZ-1])
    idx = (g[:,1]*GZ + g[:,2])*GX + g[:,0]            # y 最外(不参与旋转), 与 hls_slicer_arch 的 y-innermost 建议无关, 这里只影响压缩
    rgb565 = ((raw['r'].astype(np.uint16)>>3)<<11) | ((raw['g'].astype(np.uint16)>>2)<<5) | (raw['b'].astype(np.uint16)>>3)
    # 去重: 同一体素取第一个点
    _, first = np.unique(idx, return_index=True)
    return idx[first].astype(np.uint32), rgb565[first].astype(np.uint16), s

def layouts(idx, rgb):
    out = {}
    out['A raw'] = np.stack([idx.view(np.uint16).reshape(-1,2)[:,0], idx.view(np.uint16).reshape(-1,2)[:,1], rgb],1).astype('<u2').tobytes()
    o = np.argsort(idx); si, sr = idx[o], rgb[o]
    d = np.diff(si, prepend=np.uint32(0)).astype(np.uint32)
    # 差分可能超 u16 (稀疏模型), 用 u32 差分; varint 另算
    dd = d.view(np.uint16).reshape(-1,2)
    out['B sorted+d32'] = np.stack([dd[:,0], dd[:,1], sr.astype('<u2')],1).astype('<u2').tobytes()
    out['C split d32'] = (d.astype('<u4').tobytes(), sr.astype('<u2').tobytes())
    out['D split varint'] = (varint(d), sr.astype('<u2').tobytes())
    return out

def varint(a):
    out = bytearray()
    for v in a.tolist():
        while v >= 0x80: out.append((v & 0x7f) | 0x80); v >>= 7
        out.append(v)
    return bytes(out)

def comp(b):
    if isinstance(b, tuple):
        return {'lz4hc12': sum(len(lz4.block.compress(x, mode='high_compression', compression=12, store_size=False)) for x in b),
                'zlib9':   sum(len(zlib.compress(x, 9)) for x in b)}
    return {'lz4hc12': len(lz4.block.compress(b, mode='high_compression', compression=12, store_size=False)),
            'zlib9':   len(zlib.compress(b, 9))}

for path in sys.argv[1:]:
    raw = load(path); idx, rgb, s = voxelize(raw)
    n = len(idx); rawB = n*6
    ext = np.abs(np.stack([raw['x'],raw['y'],raw['z']],1)).max(axis=0)
    print(f"\n{'='*78}\n{path}: {len(raw):,} 点 (源 |xyz|max={tuple(int(e) for e in ext)}) → 缩放 ×{s:.2f} 填满 → **{n:,} 占据体素** ({n/(GX*GY*GZ)*100:.2f}% 网格) → 未压 {rawB/1e6:.2f} MB")
    print(f"{'布局':<16}{'压缩':<9}{'字节':>10}{'比':>7} |" + "".join(f"  @{f}fps" for f in FPS_LIST) + "   (Mbps; 余量对 110/125)")
    for name, b in layouts(idx, rgb).items():
        for c, sz in comp(b).items():
            cells = []
            for f in FPS_LIST:
                mbps = sz*8*f/1e6
                cells.append(f"{mbps:6.1f}[{110/mbps:4.1f}×]")
            print(f"{name:<16}{c:<9}{sz:>10,}{rawB/sz:>6.1f}× | " + " ".join(cells))
    full = GX*GY*GZ*2
    print(f"(参照: 满网格 RGB565 = {full/1e6:.1f} MB/帧, @15fps = {full*8*15/1e6:,.0f} Mbps —— 不可能实时传)")
