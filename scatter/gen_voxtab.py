#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_voxtab.py — PC 侧: 点云 → 体素网格 → **VXT1 体素表** (+ 黄金网格 + 压缩研究)

这是 scatter 环节的发送端。做三件事:
  1. 体素化 (与 mlkpai_fs03/tools/gen_anime_slices.py 的 voxel_grid 同一算法:
     采样点平均 + ssaa 覆盖率抗锯齿), 落成 pov_slice_v2.h 约定的 (z,x,y) RGB565 网格;
  2. 把网格的占据格编码成 VXT1 体素表 (见 ../scatter/vox_table.h);
  3. 顺便导出**黄金网格**给 vox_bench 做逐字节对拍。

🔴 y 轴约定 (最容易搞错、也最容易看出来的一条):
   pov_slice_v2 对 y **直拷不翻转**, 体素 y 与面板行号同向 (自上而下);
   而 gen_anime_slices.py 读体素用 `gy = (H-1) - arange(H)` (体素 y 向上)。
   ⇒ 本工具写网格时做 **vy = (Y-1) - gy**。搞反了成像就上下颠倒。
   由 vox_bench 的取向自检逐字节验证 (见 --slice-ref 输出)。

用法:
  python3 gen_voxtab.py --points ../anime_points.bin --cfg target \\
          --frames 8 --out /tmp/vt --golden 2 --study
"""
import argparse
import math
import os
import struct
import sys
import time
import zlib

import numpy as np

CFG = {
    '1bit':   dict(XZ=160, Y=180),      # 现有 ICND2049 屏, 9.2 MB 网格
    'target': dict(XZ=192, Y=216),      # ICND2260 目标, 15.9 MB 网格
}

VXT_MAGIC = b'VXT1'
VXT_HDR_BYTES = 24
VXT_FLAG_KEY = 1 << 0


# ─────────────────────────── 体素化 (与 gen_anime_slices 同算法) ───────────

def points_from_bin(path):
    """point_t 16 B: int16 x,y,z,pad + u8 r,g,b,pad + int32 pad"""
    raw = open(path, 'rb').read()
    n = len(raw) // 16
    dt = np.dtype([('x', '<i2'), ('y', '<i2'), ('z', '<i2'), ('p0', '<i2'),
                   ('r', 'u1'), ('g', 'u1'), ('b', 'u1'), ('p1', 'u1'),
                   ('p2', '<i4')])
    pts = np.frombuffer(raw, dtype=dt, count=n)
    xyz = np.stack([pts['x'], pts['y'], pts['z']], axis=1).astype(np.float32)
    col = np.stack([pts['r'], pts['g'], pts['b']], axis=1).astype(np.float32)
    return xyz, col


def color_adjust(col, brighten=1.5, gamma=0.9, saturation=2.0):
    """gen_anime_slices.color_adjust 的逐字等价搬运 (顺序: gamma → brighten → sat)。"""
    c = col.astype(np.float32)
    if gamma != 1.0:
        c = 255.0 * np.power(np.clip(c / 255.0, 0, 1), gamma)
    if brighten != 1.0:
        mx = c.max(axis=1, keepdims=True)
        tgt = np.minimum(255.0, mx * brighten)
        ratio = np.where(mx > 0, tgt / np.maximum(mx, 1e-6), 1.0)
        c = np.minimum(255.0, c * ratio)
    if saturation != 1.0:
        v = c.max(axis=1)
        mn = c.min(axis=1)
        s = np.where(v > 0, (v - mn) / np.maximum(v, 1e-6), 0.0)
        s2 = np.minimum(1.0, s * saturation)
        k = np.where(s > 1e-6, s2 / np.maximum(s, 1e-6), 1.0)[:, None]
        c = v[:, None] - (v[:, None] - c) * k
    return np.clip(c, 0, 255)


def normalize_points(xyz, XZ, Y, z_stretch=1.0, verbose=True):
    """居中 + 等比缩放到 (±R_BUDGET, ±H_BUDGET, ±R_BUDGET)。同 gen_anime_slices。"""
    R_BUDGET = XZ // 2 - 1.0
    H_BUDGET = Y // 2 - 1.0
    p = xyz.copy()
    cmin, cmax = p.min(axis=0), p.max(axis=0)
    p -= (cmin + cmax) / 2
    p[:, 2] *= z_stretch
    hx, hy, hz = (np.abs(p[:, i]).max() for i in range(3))
    s = min(R_BUDGET / max(hx, 1e-6), H_BUDGET / max(hy, 1e-6), R_BUDGET / max(hz, 1e-6))
    p *= s
    if verbose:
        print(f'[vox] scale={s:.3f} extents x±{hx*s:.1f} y±{hy*s:.1f} z±{hz*s:.1f}',
              flush=True)
    return p


def densify(p, col, n_target, cell=2.0, seed=1234):
    """点云表面上采样 (numpy only, 无 scipy)。

    🔴 为什么需要它: 手上两个 .bin 只有 10.0 万 / 12.9 万个点, 而
    **占据体素数 ≤ 采样点数** —— 用它们直接体素化, 占据格数被点数封顶,
    永远到不了"满屏 13-22 万"。PC 真实管线 (gen_anime_slices) 是从 GLB 采
    **180 万**点的; 本机没有 pygltflib, 拿不到 GLB, 所以在点云上补采样。

    做法: 用 cell 大小的空间哈希把点分组, 组内随机取两点做线性插值 (位置和
    颜色都插)。两点同格 ⇒ 距离 ≤ ~1.7·cell 体素, 插出来的点仍贴在表面上。
    ⚠ 这是**合成加密**, 不是真采样: 薄壳两侧的点若同格, 插值点会落进壳内
    (最多 cell 体素的误差)。用于负载/压缩量级评估足够, 不用于成像质量结论。
    """
    n0 = len(p)
    if n_target <= n0:
        return p, col
    rng = np.random.default_rng(seed)
    q = np.floor(p / cell).astype(np.int64)
    key = (q[:, 0] * 73856093) ^ (q[:, 1] * 19349663) ^ (q[:, 2] * 83492791)
    order = np.argsort(key, kind='stable')
    ks = key[order]
    # 每个点所在组的 [start, end)
    starts = np.searchsorted(ks, ks, 'left')
    ends = np.searchsorted(ks, ks, 'right')
    grp_start = np.empty(n0, np.int64); grp_start[order] = starts
    grp_end = np.empty(n0, np.int64); grp_end[order] = ends

    m = n_target - n0
    i = rng.integers(0, n0, m)
    j = order[grp_start[i] + (rng.random(m) * (grp_end[i] - grp_start[i])).astype(np.int64)]
    t = rng.random((m, 1)).astype(np.float32)
    np_ = p[i] * (1 - t) + p[j] * t
    nc = col[i] * (1 - t) + col[j] * t
    print(f'[dens] {n0} → {n_target} 点 (哈希格 {cell} 体素, 组内线性插值)', flush=True)
    return np.concatenate([p, np_]), np.concatenate([col, nc])


def jitter_fill(p, col, k, sigma, seed=99):
    """每个点复制 k 份并加 sigma 体素的高斯抖动 —— 把"1 点/格"的稀疏点云补成
    连续表面。sigma ≤ 0.8 体素时厚度只增 ±1 格, 主要作用是填同一表面上的空洞。
    ⚠ 同样是**合成加密**, 见 densify() 的免责说明。"""
    if k <= 1:
        return p, col
    rng = np.random.default_rng(seed)
    pr = np.repeat(p, k, axis=0) + rng.normal(0, sigma, (len(p) * k, 3)).astype(np.float32)
    cr = np.repeat(col, k, axis=0)
    print(f'[jit] {len(p)} → {len(pr)} 点 (×{k}, σ={sigma} 体素)', flush=True)
    return pr, cr


def voxel_grid_rgb(p, col, XZ, Y, ssaa=3, verbose=True):
    """归一化点 → (gx,gy,gz) 浮点颜色格 (XZ,Y,XZ,3)。gen_anime_slices.voxel_grid 同算法:
    格内颜色平均 + ssaa 细分覆盖率把边缘体素调暗 (抗锯齿折进颜色)。"""
    gx = np.clip(np.rint(p[:, 0]).astype(np.int32) + XZ // 2, 0, XZ - 1)
    gy = np.clip(np.rint(p[:, 1]).astype(np.int32) + Y // 2, 0, Y - 1)
    gz = np.clip(np.rint(p[:, 2]).astype(np.int32) + XZ // 2, 0, XZ - 1)
    acc = np.zeros((XZ, Y, XZ, 3), np.float32)
    cnt = np.zeros((XZ, Y, XZ), np.float32)
    np.add.at(acc, (gx, gy, gz), col)
    np.add.at(cnt, (gx, gy, gz), 1.0)
    occ = cnt > 0
    acc[occ] /= cnt[occ][:, None]
    if ssaa > 1:
        n = int(ssaa)
        f = np.rint(p * n).astype(np.int64)
        subs = np.unique(f, axis=0)
        mx = np.clip((subs[:, 0] + n // 2) // n + XZ // 2, 0, XZ - 1).astype(np.int32)
        my = np.clip((subs[:, 1] + n // 2) // n + Y // 2, 0, Y - 1).astype(np.int32)
        mz = np.clip((subs[:, 2] + n // 2) // n + XZ // 2, 0, XZ - 1).astype(np.int32)
        cov = np.zeros((XZ, Y, XZ), np.float32)
        np.add.at(cov, (mx, my, mz), 1.0)
        np.clip(cov / float(n * n), 0.0, 1.0, out=cov)
        acc *= cov[:, :, :, None]
        if verbose:
            e = cov[occ]
            print(f'[vox] ssaa{n} coverage mean={e.mean():.2f} '
                  f'edge(<0.67)={(e < 0.67).mean():.0%}', flush=True)
    return acc


def to_grid565(acc, XZ, Y):
    """(gx,gy,gz,3) float → pov_slice_v2 布局的 RGB565 一维网格。

    🔴 两件事同时做:
      · 轴序 (gx,gy,gz) → idx = (vz*XZ + vx)*Y + vy   (y 最内维)
      · **y 翻转** vy = (Y-1) - gy  (体素 y 向上 → 面板行自上而下)
    """
    r = np.clip(acc[..., 0], 0, 255).astype(np.uint16) >> 3
    g = np.clip(acc[..., 1], 0, 255).astype(np.uint16) >> 2
    b = np.clip(acc[..., 2], 0, 255).astype(np.uint16) >> 3
    v565 = (r << 11) | (g << 5) | b                    # (gx, gy, gz)
    v565 = v565[:, ::-1, :]                            # y 翻转
    grid = np.transpose(v565, (2, 0, 1))               # → (vz, vx, vy)
    return np.ascontiguousarray(grid).reshape(-1)


# ─────────────────────────── VXT1 编码 ─────────────────────────────────────

def varint_encode(vals):
    """LEB128 批量编码 (纯 numpy, 无 python 循环 —— 15 万个值 python 循环要 ~0.1 s)。
    vals 必须是 uint32 且 < 2^28 (索引 < 2^23, 满足)。"""
    v = np.asarray(vals, np.uint32)
    if v.size == 0:
        return b''
    b0 = (v & 0x7F).astype(np.uint8)
    b1 = ((v >> 7) & 0x7F).astype(np.uint8)
    b2 = ((v >> 14) & 0x7F).astype(np.uint8)
    b3 = ((v >> 21) & 0x7F).astype(np.uint8)
    nb = np.ones(v.size, np.int8)
    nb[v >= (1 << 7)] = 2
    nb[v >= (1 << 14)] = 3
    nb[v >= (1 << 21)] = 4
    b0 |= np.where(nb > 1, 0x80, 0).astype(np.uint8)
    b1 |= np.where(nb > 2, 0x80, 0).astype(np.uint8)
    b2 |= np.where(nb > 3, 0x80, 0).astype(np.uint8)
    cols = np.stack([b0, b1, b2, b3], axis=1)          # (N,4)
    keep = np.arange(4)[None, :] < nb[:, None]
    return cols[keep].tobytes()


def encode_vxt1(idx, col565, XZ, Y, seq=0, key=False):
    """占据索引(升序) + RGB565 → VXT1 体字节。"""
    assert idx.dtype == np.uint32 or idx.dtype == np.int64 or idx.dtype == np.int32
    idx = idx.astype(np.uint32)
    prev = np.empty(idx.size, np.int64)
    prev[0] = -1
    prev[1:] = idx[:-1].astype(np.int64)
    delta_m1 = (idx.astype(np.int64) - prev - 1).astype(np.uint32)
    ip = varint_encode(delta_m1)
    flags = VXT_FLAG_KEY if key else 0
    hdr = struct.pack('<4sHHIIHHI', VXT_MAGIC, XZ, Y, idx.size, len(ip),
                      flags, seq & 0xFFFF, 0)
    assert len(hdr) == VXT_HDR_BYTES
    return hdr + col565.astype('<u2').tobytes() + ip


# ─────────────────────────── 压缩研究 ──────────────────────────────────────

def _lz4_size(buf):
    """用 lz4 CLI 量 HC12 压缩体积 (本机无 liblz4 x86 开发包)。失败返回 0。"""
    import shutil
    import subprocess
    import tempfile
    if not shutil.which('lz4'):
        return 0
    with tempfile.TemporaryDirectory() as d:
        fi, fo = os.path.join(d, 'i'), os.path.join(d, 'o')
        open(fi, 'wb').write(buf)
        r = subprocess.run(['lz4', '-12', '-f', '-q', '--no-frame-crc', fi, fo],
                           capture_output=True)
        if r.returncode != 0:
            return 0
        return os.path.getsize(fo)


def study(idx, col565, tag):
    """几种候选编码的实测体积对比 (B/体素)。判据: 板端解码要快 + 压缩比要够。"""
    n = idx.size
    idx = idx.astype(np.uint32)
    prev = np.empty(n, np.int64); prev[0] = -1; prev[1:] = idx[:-1]
    d = (idx.astype(np.int64) - prev - 1).astype(np.uint32)
    col = col565.astype('<u2').tobytes()

    rows = []

    def add(name, nbytes, note=''):
        rows.append((name, nbytes, nbytes / n, 6.0 * n / nbytes, note))

    inter = np.empty((n, 3), np.uint16)
    inter[:, 0] = idx & 0xFFFF
    inter[:, 1] = idx >> 16
    inter[:, 2] = col565
    raw_inter = inter.tobytes()
    add('A 交错 u32idx+u16col (基准)', len(raw_inter))
    add('B 分平面 u32idx | u16col', n * 4 + n * 2)
    add('C 分平面 u32delta | u16col', n * 4 + n * 2)

    vi = varint_encode(d)
    add('D **VXT1** varint(delta) | u16col', len(vi) + n * 2,
        f'索引 {len(vi)/n:.2f} B/格')

    # 转义 u8: delta-1 < 255 → 1 字节; 否则 0xFF + u32 LE
    big = d >= 255
    esc = 5 * int(big.sum()) + int((~big).sum())
    add('E 转义u8(delta) | u16col', esc + n * 2, f'超 255 的占 {100*big.mean():.2f}%')

    for lvl in (6, 9):
        add(f'F A 整体 zlib-{lvl} (会话记录里的 2.36 B/格 就是这条)',
            len(zlib.compress(raw_inter, lvl)))
    for lvl in (6, 9):
        z = len(zlib.compress(vi, lvl)) + len(zlib.compress(col, lvl))
        add(f'G D 两平面各自 zlib-{lvl}', z)
    z1 = len(zlib.compress(vi + col, 6))
    add('H D 两平面拼一起 zlib-6', z1)

    # 🔴 板端实际用的是 **LZ4**, 不是 zlib —— A9 实测解压快 4 倍 (204.6 vs 51.6 MB/s,
    # 见 protocol.h 的 PVS_FLAG_LZ4)。所以 LZ4 那一行才是真正要看的压缩比。
    # 本机没有 liblz4 的 x86 头/库, 用 CLI 量体积 (帧格式比 raw block 多 ~19 B, 可忽略)。
    l4 = _lz4_size(vi) + _lz4_size(col)
    if l4:
        add('I D 两平面各自 lz4-HC12 (**板端真正用的**)', l4)
    l4a = _lz4_size(raw_inter)
    if l4a:
        add('J A 整体 lz4-HC12', l4a)

    print(f'\n=== 编码对比 [{tag}] n_vox={n} ===')
    print(f'{"方案":<46} {"字节":>10} {"B/格":>7} {"压缩比":>7}  说明')
    for name, nb, bpv, ratio, note in rows:
        print(f'{name:<46} {nb:>10} {bpv:>7.2f} {ratio:>6.2f}×  {note}')
    return rows


# ─────────────────────────── 主流程 ────────────────────────────────────────

def rot_y(p, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    q = p.copy()
    q[:, 0] = c * p[:, 0] + s * p[:, 2]
    q[:, 2] = -s * p[:, 0] + c * p[:, 2]
    return q


def main():
    ap = argparse.ArgumentParser()
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument('--points', default=os.path.join(here, '..', 'anime_points.bin'))
    ap.add_argument('--cfg', choices=CFG, default='target')
    ap.add_argument('--frames', type=int, default=8)
    ap.add_argument('--spin-deg', type=float, default=2.0,
                    help='相邻内容帧的模型转角 (900RPM/15fps 下 30°/s 的姿态更新 = 2°/帧)')
    ap.add_argument('--ssaa', type=int, default=3)
    ap.add_argument('--densify', type=int, default=0, metavar='N',
                    help='把点云上采样到 N 个点 (见 densify(); 0 = 关)。'
                         '手上的 .bin 只有 10-13 万点, 而占据体素数 ≤ 点数, '
                         '不加密根本到不了满屏 15 万格的负载')
    ap.add_argument('--dens-cell', type=float, default=2.0)
    ap.add_argument('--jitter', type=int, default=0, metavar='K',
                    help='每点复制 K 份加高斯抖动, 把稀疏表面补密 (见 jitter_fill)')
    ap.add_argument('--jitter-sigma', type=float, default=0.7)
    ap.add_argument('--z-stretch', type=float, default=1.0)
    ap.add_argument('--golden', type=int, default=2, help='导出几帧黄金网格 (每帧 16 MB)')
    ap.add_argument('--study', action='store_true', help='跑编码对比表')
    ap.add_argument('--out', required=True)
    a = ap.parse_args()

    XZ, Y = CFG[a.cfg]['XZ'], CFG[a.cfg]['Y']
    cells = XZ * XZ * Y
    os.makedirs(a.out, exist_ok=True)
    print(f'[cfg] {a.cfg}: 网格 {XZ}×{XZ}×{Y} = {cells} 格 = {cells*2/1048576:.2f} MB')

    xyz, col = points_from_bin(a.points)
    print(f'[pts] {os.path.basename(a.points)}: {len(xyz)} 点', flush=True)
    col = color_adjust(col)
    base = normalize_points(xyz, XZ, Y, a.z_stretch)
    if a.densify:
        base, col = densify(base, col, a.densify, a.dens_cell)
    if a.jitter:
        base, col = jitter_fill(base, col, a.jitter, a.jitter_sigma)

    man = []
    prev_idx = None
    for f in range(a.frames):
        p = base if f == 0 else rot_y(base, f * a.spin_deg)
        acc = voxel_grid_rgb(p, col, XZ, Y, a.ssaa, verbose=(f == 0))
        grid = to_grid565(acc, XZ, Y)
        nz = np.flatnonzero(grid).astype(np.uint32)
        c565 = grid[nz]
        body = encode_vxt1(nz, c565, XZ, Y, seq=f, key=(f == 0))

        ov = 0
        if prev_idx is not None:
            ov = np.intersect1d(prev_idx, nz, assume_unique=True).size
        prev_idx = nz

        vp = os.path.join(a.out, f'f{f:03d}.vxt')
        open(vp, 'wb').write(body)
        gp = ''
        if f < a.golden:
            gp = f'g{f:03d}.bin'
            grid.astype('<u2').tofile(os.path.join(a.out, gp))
        man.append((f'f{f:03d}.vxt', gp, nz.size))
        print(f'[f{f:03d}] 占据 {nz.size:6d} ({100.0*nz.size/cells:.2f}%)  '
              f'VXT1 {len(body):8d} B = {len(body)/nz.size:.2f} B/格  '
              f'与上帧重叠 {100.0*ov/max(nz.size,1):5.1f}%', flush=True)

        if a.study and f == 0:
            study(nz, c565, os.path.basename(a.points))

    with open(os.path.join(a.out, 'manifest.txt'), 'w') as fh:
        fh.write(f'{XZ} {Y} {len(man)}\n')
        for vxt, g, n in man:
            fh.write(f'{vxt} {g or "-"} {n}\n')
    print(f'[out] {a.out}/  {len(man)} 帧 + manifest.txt')


if __name__ == '__main__':
    main()
