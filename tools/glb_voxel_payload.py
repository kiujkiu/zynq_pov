#!/usr/bin/env python3
"""真实 glb 模型 → 192×216×192 表面体素化 → 体素表 → lz4-HC12 → 每帧字节 / Mbps。

纯 numpy + pillow (WSL 没 pygltflib/trimesh)。glb = 12B 头 + JSON chunk + BIN chunk, 自己解。
体素化: 每个三角形按面积(体素²)撒 ~K 个随机重心点 → 取整 → 去重 (first-wins)。
  和 host/glb_to_points.py 的 voxelize_mesh (三角形质心一票, 丢最小 30%) 不同 —— 那是
  给老面阵做的稀疏化, 这里要的是 192 分辨率下真实壳体有多少体素。
颜色: baseColorTexture[uv] × baseColorFactor (或 COLOR_0), 再乘单光 half-lambert
  (生产链路 povstream 也打光, 打光会让颜色流熵变高, 不打反而偏乐观)。
"""
import sys, json, struct, io, math, numpy as np, lz4.block, zlib
from PIL import Image

GX, GY, GZ = 192, 216, 192
K_SAMPLES = 4.0            # 每体素² 面积撒几个点
FPS_LIST = (5, 10, 15)

def parse_glb(path):
    b = open(path,'rb').read()
    magic, ver, length = struct.unpack_from('<III', b, 0); assert magic == 0x46546C67, 'not glb'
    off, js, bin_ = 12, None, b''
    while off < length:
        clen, ctype = struct.unpack_from('<II', b, off); off += 8
        chunk = b[off:off+clen]; off += clen
        if ctype == 0x4E4F534A: js = json.loads(chunk)
        elif ctype == 0x004E4942: bin_ = chunk
    return js, bin_

DT = {5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}
def accessor(js, bin_, ai):
    acc = js['accessors'][ai]; bv = js['bufferViews'][acc['bufferView']]
    dt, nc = DT[acc['componentType']], NC[acc['type']]
    start = bv.get('byteOffset',0) + acc.get('byteOffset',0); tight = nc*np.dtype(dt).itemsize
    stride = bv.get('byteStride', 0)
    if stride and stride != tight:
        raw = np.frombuffer(bin_, np.uint8, stride*(acc['count']-1)+tight, start)
        sel = np.arange(acc['count'])[:,None]*stride + np.arange(tight)[None,:]
        a = raw[sel].copy().view(dt).reshape(acc['count'], nc)
    else:
        a = np.frombuffer(bin_, dt, acc['count']*nc, start).reshape(acc['count'], nc)
    if acc.get('normalized') and dt != np.float32:
        a = a.astype(np.float32) / np.iinfo(dt).max
    return a

def node_mat(n):
    if 'matrix' in n: return np.array(n['matrix'], np.float64).reshape(4,4).T
    m = np.eye(4)
    if 's' in n or 'scale' in n:      m = np.diag([*n['scale'],1.0]) @ m
    if 'rotation' in n:
        x,y,z,w = n['rotation']
        r = np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),0],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),0],
                      [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y),0],[0,0,0,1]]); m = r @ m
    if 'translation' in n:
        t = np.eye(4); t[:3,3] = n['translation']; m = t @ m
    return m

def instances(js):
    out = []
    def walk(ni, pm):
        n = js['nodes'][ni]; w = pm @ node_mat(n)
        if 'mesh' in n: out.append((w, n['mesh']))
        for c in n.get('children', []): walk(c, w)
    roots = js['scenes'][js.get('scene',0)]['nodes'] if js.get('scenes') else range(len(js.get('nodes',[])))
    for r in roots: walk(r, np.eye(4))
    return out

def texture_of(js, bin_, mi, cache):
    """→ (np.uint8 HxWx4 或 None, texcoord set, baseColorFactor)"""
    if mi is None: return None, 0, np.ones(4, np.float32)
    mat = js['materials'][mi]; pbr = mat.get('pbrMetallicRoughness', {})
    fac = np.array(pbr.get('baseColorFactor', [1,1,1,1]), np.float32)
    bct = pbr.get('baseColorTexture')
    if not bct: return None, 0, fac
    src = js['textures'][bct['index']].get('source')
    if src is None: return None, 0, fac
    if src not in cache:
        img = js['images'][src]
        if 'bufferView' not in img: cache[src] = None
        else:
            bv = js['bufferViews'][img['bufferView']]
            data = bin_[bv.get('byteOffset',0): bv.get('byteOffset',0)+bv['byteLength']]
            try: cache[src] = np.asarray(Image.open(io.BytesIO(data)).convert('RGBA'))
            except Exception as e: print(f'  纹理解码失败 {e}'); cache[src] = None
    return cache[src], bct.get('texCoord', 0), fac

def voxelize(path, k=K_SAMPLES, seed=1):
    js, bin_ = parse_glb(path)
    req = js.get('extensionsRequired', [])
    if any('draco' in e.lower() for e in req): raise SystemExit(f'{path}: Draco 压缩, 解不了')
    rng = np.random.default_rng(seed); cache = {}
    tris = []  # (P0,P1,P2 世界坐标 float64 N×3, 颜色 N×3 float 0..1 per-tri(或 None), UV N×3×2, tex)
    for w, mi in instances(js):
        for prim in js['meshes'][mi]['primitives']:
            if prim.get('mode', 4) != 4: continue
            P = accessor(js, bin_, prim['attributes']['POSITION']).astype(np.float64)
            P = (np.c_[P, np.ones(len(P))] @ w.T)[:, :3]
            I = accessor(js, bin_, prim['indices']).ravel().astype(np.int64) if 'indices' in prim else np.arange(len(P))
            I = I[: len(I)//3*3].reshape(-1,3)
            tex, tcs, fac = texture_of(js, bin_, prim.get('material'), cache)
            uvk = f'TEXCOORD_{tcs}'
            UV = accessor(js, bin_, prim['attributes'][uvk]).astype(np.float32) if (tex is not None and uvk in prim['attributes']) else None
            if UV is None: tex = None
            VC = accessor(js, bin_, prim['attributes']['COLOR_0']).astype(np.float32)[:, :3] if 'COLOR_0' in prim['attributes'] else None
            tris.append((P[I], (UV[I] if UV is not None else None), (VC[I] if VC is not None else None), tex, fac[:3]))
    if not tris: raise SystemExit('无三角形')
    allP = np.concatenate([t[0].reshape(-1,3) for t in tris])
    lo, hi = allP.min(0), allP.max(0); ctr = (lo+hi)/2; span = hi-lo
    s = min(GX/span[0], GY/span[1], GZ/span[2]) * 0.999   # 填满: glTF Y 向上 = 我们的 216 轴
    ntri = sum(len(t[0]) for t in tris)
    vox_idx, vox_rgb = [], []
    light = np.array([0.3,0.7,0.6]); light /= np.linalg.norm(light)
    for P, UV, VC, tex, fac in tris:
        P = (P - ctr) * s                                    # 三角形 N×3×3, 体素单位, 原点在中心
        e1, e2 = P[:,1]-P[:,0], P[:,2]-P[:,0]
        nrm = np.cross(e1, e2); area2 = np.linalg.norm(nrm, axis=1)
        keep = area2 > 1e-9; P, e1, e2, nrm, area2 = P[keep], e1[keep], e2[keep], nrm[keep], area2[keep]
        if UV is not None: UV = UV[keep]
        if VC is not None: VC = VC[keep]
        nrm = nrm / area2[:,None]
        ns = np.ceil(area2/2 * k).astype(np.int64) + 1     # 每三角形撒点数
        ti = np.repeat(np.arange(len(P)), ns); N = len(ti)
        r1, r2 = rng.random(N), rng.random(N); sq = np.sqrt(r1)
        bw = np.stack([1-sq, sq*(1-r2), sq*r2], 1)           # 均匀重心
        pts = np.einsum('nk,nkd->nd', bw, P[ti])
        # 颜色
        if tex is not None:
            uv = np.einsum('nk,nkd->nd', bw, UV[ti]); H, W = tex.shape[:2]
            tx = (np.floor((uv[:,0] % 1.0) * W).astype(np.int64)) % W; ty = (np.floor((uv[:,1] % 1.0) * H).astype(np.int64)) % H
            px = tex[ty, tx].astype(np.float32) / 255.0
            rgb = px[:, :3] * fac; alpha_ok = px[:, 3] >= 0.5
        elif VC is not None:
            rgb = np.einsum('nk,nkd->nd', bw, VC[ti]) * fac; alpha_ok = np.ones(N, bool)
        else:
            rgb = np.broadcast_to(fac, (N,3)).copy(); alpha_ok = np.ones(N, bool)
        # 单光 half-lambert
        lam = 0.5 + 0.5 * (nrm[ti] @ light)
        rgb = np.clip(rgb * lam[:,None], 0, 1)
        g = np.round(pts).astype(np.int64) + [GX//2, GY//2, GZ//2]
        ok = alpha_ok & (g[:,0]>=0)&(g[:,0]<GX)&(g[:,1]>=0)&(g[:,1]<GY)&(g[:,2]>=0)&(g[:,2]<GZ)
        g, rgb = g[ok], rgb[ok]
        vox_idx.append(((g[:,1]*GZ + g[:,2])*GX + g[:,0]).astype(np.uint32))
        vox_rgb.append((np.round(rgb*255).astype(np.uint16)))
    idx = np.concatenate(vox_idx); rgb = np.concatenate(vox_rgb)
    _, first = np.unique(idx, return_index=True)
    idx, rgb = idx[first], rgb[first]
    r565 = ((rgb[:,0]>>3)<<11) | ((rgb[:,1]>>2)<<5) | (rgb[:,2]>>3)
    return idx, r565.astype(np.uint16), ntri, span*s

def varint(a):
    out = bytearray()
    for v in a.tolist():
        while v >= 0x80: out.append((v & 0x7f) | 0x80); v >>= 7
        out.append(v)
    return bytes(out)

def lz4hc(b): return len(lz4.block.compress(b, mode='high_compression', compression=12, store_size=False))

def report(name, idx, rgb, ntri, dims):
    n = len(idx); o = np.argsort(idx); si, sr = idx[o], rgb[o]
    d = np.diff(si, prepend=np.uint32(0)).astype(np.uint32)
    layouts = {
        'A raw 6B 未排序': [np.c_[idx.view(np.uint16).reshape(-1,2), rgb].astype('<u2').tobytes()],
        'B sorted d32+rgb 交错': [np.c_[d.view(np.uint16).reshape(-1,2), sr].astype('<u2').tobytes()],
        'C split d32 | rgb': [d.astype('<u4').tobytes(), sr.astype('<u2').tobytes()],
        'D split varint | rgb': [varint(d), sr.astype('<u2').tobytes()],
    }
    print(f"\n{'='*86}\n{name}: {ntri:,} 三角形, 填满后尺寸 {dims[0]:.0f}×{dims[1]:.0f}×{dims[2]:.0f} → **{n:,} 体素** ({n/(GX*GY*GZ)*100:.2f}% 网格), 未压 {n*6/1e6:.2f} MB")
    print(f"  颜色流单独 lz4: {lz4hc(sr.astype('<u2').tobytes()):,} B / {n*2:,} B = {n*2/lz4hc(sr.astype('<u2').tobytes()):.2f}×   索引流(varint)单独 lz4: {lz4hc(varint(d)):,} B")
    print(f"  {'布局':<24}{'压缩':<9}{'字节':>10}{'比':>7} |" + "".join(f"   @{f}fps" for f in FPS_LIST) + "   Mbps[余量对110]")
    rows = {}
    for lname, parts in layouts.items():
        for cname, fn in (('lz4hc12', lz4hc), ('zlib9', lambda b: len(zlib.compress(b,9)))):
            sz = sum(fn(p) for p in parts); rows[(lname,cname)] = sz
            cells = " ".join(f"{sz*8*f/1e6:6.1f}[{110/(sz*8*f/1e6):4.1f}×]" for f in FPS_LIST)
            print(f"  {lname:<24}{cname:<9}{sz:>10,}{n*6/sz:>6.1f}× | {cells}")
    return n, rows

if __name__ == '__main__':
    k = K_SAMPLES; paths = []
    for a in sys.argv[1:]:
        if a.startswith('--k='): k = float(a[4:])
        else: paths.append(a)
    summary = []
    for p in paths:
        idx, rgb, ntri, dims = voxelize(p, k)
        n, rows = report(p.split('/')[-1], idx, rgb, ntri, dims)
        summary.append((p.split('/')[-1], n, rows[('D split varint | rgb','lz4hc12')], rows[('B sorted d32+rgb 交错','lz4hc12')]))
    print(f"\n{'='*86}\n汇总 (lz4-HC12):\n  {'模型':<14}{'体素':>10}{'D布局 B/帧':>12}{'@5fps':>8}{'@15fps':>9}  |{'B布局 B/帧':>12}{'@15fps':>9}")
    for name, n, dsz, bsz in summary:
        print(f"  {name:<14}{n:>10,}{dsz:>12,}{dsz*40/1e6:>7.1f}M{dsz*120/1e6:>8.1f}M  |{bsz:>12,}{bsz*120/1e6:>8.1f}M")
