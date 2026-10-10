#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_slice_ref.py — 端到端取向自检: scatter 出的网格切出来的片, 与
**gen_anime_slices.py 的读法**算出来的片逐字节比。

为什么这一步不可省 (也是整条链路最容易错、错了最难发现的一处):
  · pov_slice_v2 对 y **直拷不翻转** (体素 y = 面板行号, 自上而下);
  · gen_anime_slices.py 读体素用 `gy = (H-1) - arange(H)` (体素 y 向上)。
  两边差一个 y 翻转。gen_voxtab.py 在**写网格时**把它翻好 (vy = (Y-1) - gy)。
  翻错了模型就上下颠倒 —— 而"网格逐字节相同"这个判据根本查不出来
  (黄金网格是同一个工具生成的, 两边一起错)。所以必须拿**独立的 Python 参考读法**
  再对一次。

参考侧刻意用与 pov_slice_v2.cpp **逐位相同的 Q8 定点** (同 gen_pv2_golden.py 的做法),
这样任何不一致都是真 bug, 不是量化差异。

用法:
  ./vox_slice_check <目录> 8 0 1 0
  python3 check_slice_ref.py <目录> --slots 8 --off-q8 0 --mirror 1 --phase 0
"""
import argparse
import math
import os
import sys

import numpy as np


def q8_lut(n):
    cos8 = np.array([int(round(256 * math.cos(2 * math.pi * i / n))) for i in range(n)], np.int64)
    sin8 = np.array([int(round(256 * math.sin(2 * math.pi * i / n))) for i in range(n)], np.int64)
    return cos8, sin8


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dir')
    ap.add_argument('--slots', type=int, default=8)
    ap.add_argument('--off-q8', type=int, default=0)
    ap.add_argument('--mirror', type=int, default=1)
    ap.add_argument('--phase', type=int, default=0)
    a = ap.parse_args()

    man = open(os.path.join(a.dir, 'manifest.txt')).read().split()
    XZ, Y = int(man[0]), int(man[1])
    gold = man[4]
    if gold == '-':
        sys.exit('✗ 该目录没有黄金网格 (gen_voxtab.py --golden 0?)')
    N = 360 if XZ == 160 else 603          # 与 pov_slice_v2.h 的 PV2_LUT_N 一致
    W, H = XZ, Y                           # 面板尺寸 == 网格 xz / y

    grid = np.fromfile(os.path.join(a.dir, gold), '<u2').reshape(XZ, XZ, Y)  # (vz,vx,vy)

    # 🔴 还原成 gen_anime_slices.py 的体素坐标系 vox[gx, gy, gz] (体素 y 向上):
    #    to_grid565 做的是 grid[vz][vx][vy] = v565[gx=vx][gy=(Y-1)-vy][gz=vz]
    vox = np.transpose(grid, (1, 2, 0))[:, ::-1, :]        # (gx, gy, gz)

    cos8, sin8 = q8_lut(N)
    got = np.fromfile(os.path.join(a.dir, 'slices_from_scatter.bin'), '<u2')
    need = a.slots * W * H
    if got.size != need:
        sys.exit(f'✗ slices_from_scatter.bin 有 {got.size} 元素, 期望 {need} '
                 f'— 先跑 ./vox_slice_check <目录> {a.slots} {a.off_q8} {a.mirror} {a.phase}')
    got = got.reshape(a.slots, W, H)                       # 列优先 slot[px][py]

    D = np.arange(W, dtype=np.int64) - W // 2              # u = px - PV2_CX
    if a.mirror:
        D = -D
    gy = (H - 1) - np.arange(H)                            # ← gen_anime_slices 的读法

    bad_tot = 0
    for k in range(a.slots):
        ang = (a.phase + k) % N
        cs, sn = int(cos8[ang]), int(sin8[ang])
        # 与 pov_slice_v2.cpp 完全一致: 偏移分量先算 Q8, 求和后 +128>>8 只取整一次
        off_x = -((a.off_q8 * sn) >> 8)
        off_z = ((a.off_q8 * cs) >> 8)
        rx = ((D * cs + off_x + 128) >> 8) + XZ // 2
        rz = ((D * sn + off_z + 128) >> 8) + XZ // 2
        inside = (rx >= 0) & (rx < XZ) & (rz >= 0) & (rz < XZ)
        rxc, rzc = np.where(inside, rx, 0), np.where(inside, rz, 0)
        # 参考: 观察者视角 img[row=py][col=px], 用 gen_anime_slices 的 gy 索引
        img = vox[rxc[None, :], gy[:, None], rzc[None, :]]
        img = np.where(inside[None, :], img, 0)
        ref = img.T                                        # → slot[px][py]
        bad = int((ref != got[k]).sum())
        bad_tot += bad
        if bad:
            i0 = np.argwhere(ref != got[k])[0]
            print(f'  片{k} ✗ {bad}/{W*H} 不符, 首个 px={i0[0]} py={i0[1]} '
                  f'得 0x{got[k][tuple(i0)]:04X} 期望 0x{ref[tuple(i0)]:04X}')

    if bad_tot:
        print(f'\n✗ 取向自检失败: {bad_tot} 个像素不符')
        sys.exit(1)
    print(f'✅ 取向自检通过: {a.slots} 片 × {W}×{H} 逐字节相同 '
          f'(off_q8={a.off_q8} mirror={a.mirror} phase={a.phase})')
    print('   ⇒ scatter 写入的 y 方向与 gen_anime_slices.py 的读法一致, 不会上下颠倒')


if __name__ == '__main__':
    main()
