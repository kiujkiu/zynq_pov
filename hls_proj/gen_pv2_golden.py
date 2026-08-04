#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_pv2_golden.py — 给 pov_slice_v2 生成对拍用的体素网格 + 黄金切片 (2026-08-04).

对拍策略 (为什么这么设计):
  黄金参考用**与 HLS 完全相同的定点算法** (同一张 Q8 LUT、同样的 +128>>8 取整),
  这样任何不一致都是**真 bug**, 而不是量化差异。
  另外单独跟浮点参考比一次, 把 Q8 量化误差量化出来 (只报告, 不作为判据)。

体素内容刻意做成**三重不对称**, 让旋转/镜像/偏心三类错误都必然暴露:
  · x 方向: 红块只在 x>0 一侧          → 镜像错 (mirror_u) 会翻过来
  · z 方向: 绿块只在 z>0 一侧          → 旋转方向错 (θ 反向) 会翻过来
  · y 方向: 亮度自上而下线性渐变        → y 翻转错会看出来
  · 轴心附近一根蓝柱                    → 偏心 (axis_off) 错会挪位/消失

用法:
    python3 gen_pv2_golden.py --cfg 1bit   # 160×180 / 360 档 (手上这块屏)
    python3 gen_pv2_golden.py --cfg target # 192×216 / 603 档
"""
import argparse
import math
import os
import struct
import sys

import numpy as np

CFG = {
    '1bit':   dict(W=160, H=180, N=360),
    'target': dict(W=192, H=216, N=603),
}

# 对拍覆盖的配置组合: (axis_off_mm, mirror_u)。13.4mm 是 v3.1 面B 的垂距。
CASES = [(0.0, 0), (0.0, 1), (13.4, 0), (13.4, 1)]
N_SLOTS = 8          # 每个 case 对拍几片
PITCH_MM = None      # 由 --pitch 或按屏宽推


def q8_lut(n):
    """与 pov_slice_v2_lut_*.h 逐位相同的 Q8 表。"""
    cos8 = np.array([int(round(256 * math.cos(2 * math.pi * i / n))) for i in range(n)], np.int64)
    sin8 = np.array([int(round(256 * math.sin(2 * math.pi * i / n))) for i in range(n)], np.int64)
    return cos8, sin8


def make_voxels(W, H):
    """(z, x, y) 布局的 RGB565 体素网格。y 与面板行号同向 (自上而下), 见 pov_slice_v2.h 约定。"""
    XZ, Y, half = W, H, W // 2
    vox = np.zeros((XZ, XZ, Y), np.uint16)          # [vz][vx][vy]
    vz, vx, vy = np.meshgrid(np.arange(XZ) - half,
                             np.arange(XZ) - half,
                             np.arange(Y), indexing='ij')
    r2 = vz * vz + vx * vx
    # y 渐变亮度 0.35..1.0 (自上而下变亮 → 上下颠倒能看出来)
    lum = 0.35 + 0.65 * (vy / max(Y - 1, 1))

    def rgb565(r, g, b):
        return ((np.clip(r, 0, 255).astype(np.uint16) >> 3) << 11) | \
               ((np.clip(g, 0, 255).astype(np.uint16) >> 2) << 5) | \
               (np.clip(b, 0, 255).astype(np.uint16) >> 3)

    # ① 红块: 只在 x>0 一侧, 半径中段 → 镜像错必然暴露
    m = (vx > half * 0.25) & (vx < half * 0.75) & (np.abs(vz) < half * 0.20) \
        & (vy > Y * 0.20) & (vy < Y * 0.80)
    vox[m] = rgb565(255 * lum, 0, 0)[m]

    # ② 绿块: 只在 z>0 一侧 → 旋转方向错必然暴露
    m = (vz > half * 0.30) & (vz < half * 0.80) & (np.abs(vx) < half * 0.18) \
        & (vy > Y * 0.30) & (vy < Y * 0.70)
    vox[m] = rgb565(0, 255 * lum, 0)[m]

    # ③ 蓝柱: 紧贴轴心 (r < 8px) → 偏心面应当**打不到**它 (中心盲柱)
    m = (r2 < 8 * 8) & (vy > Y * 0.10) & (vy < Y * 0.90)
    vox[m] = rgb565(0, 0, 255 * lum)[m]

    # ④ 白环: 外沿, 验证最外圈没被裁掉
    m = (r2 > (half - 4) ** 2) & (r2 < (half - 1) ** 2) & (vy > Y * 0.45) & (vy < Y * 0.55)
    vox[m] = rgb565(255 * lum, 255 * lum, 255 * lum)[m]
    return vox


def slice_fixed(vox, W, H, cos8, sin8, angle, axis_off_q8, mirror_u):
    """与 pov_slice_v2.cpp **逐位相同**的定点切片。返回列优先 uint16 [px*H + py]。"""
    XZ, Y, half, cx = W, H, W // 2, W // 2
    cs, sn = int(cos8[angle]), int(sin8[angle])
    off_x_q8 = -((axis_off_q8 * sn) >> 8)      # Python >> 与 C 有符号 >> 同为算术右移
    off_z_q8 = ((axis_off_q8 * cs) >> 8)
    out = np.zeros((W, Y), np.uint16)
    for px in range(W):
        u = px - cx
        if mirror_u:
            u = -u
        rx = ((u * cs + off_x_q8 + 128) >> 8) + half
        rz = ((u * sn + off_z_q8 + 128) >> 8) + half
        if 0 <= rx < XZ and 0 <= rz < XZ:
            out[px] = vox[rz, rx]              # 整列直拷, 不翻转
    return out.reshape(-1)


def slice_float(vox, W, H, n_angles, angle, axis_off_px, mirror_u):
    """浮点参考, 只用来量化 Q8 误差 (不作判据)。"""
    XZ, half, cx = W, W // 2, W // 2
    th = 2 * math.pi * angle / n_angles
    c, s = math.cos(th), math.sin(th)
    out = np.zeros((W, H), np.uint16)
    for px in range(W):
        u = float(px - cx)
        if mirror_u:
            u = -u
        rx = int(np.rint(u * c - axis_off_px * s)) + half
        rz = int(np.rint(u * s + axis_off_px * c)) + half
        if 0 <= rx < XZ and 0 <= rz < XZ:
            out[px] = vox[rz, rx]
    return out.reshape(-1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cfg', choices=CFG, default='1bit')
    ap.add_argument('--out', default=None, help='输出目录 (默认 golden_<cfg>)')
    ap.add_argument('--phase', type=int, default=0)
    a = ap.parse_args()

    W, H, N = CFG[a.cfg]['W'], CFG[a.cfg]['H'], CFG[a.cfg]['N']
    pitch = 150.0 / W                       # 屏宽固定 150mm
    outdir = a.out or f'golden_{a.cfg}'
    os.makedirs(outdir, exist_ok=True)

    print(f'[cfg] {a.cfg}: 面板 {W}×{H}, {N} 档角度, 像素间距 {pitch:.5f} mm')
    if H % 4:
        sys.exit(f'PV2_PANEL_H={H} 不能被 4 整除 — 64 位端口一拍 4 个 RGB565')

    cos8, sin8 = q8_lut(N)
    vox = make_voxels(W, H)
    vox.tofile(os.path.join(outdir, 'voxels.bin'))
    nz = int((vox != 0).sum())
    print(f'[vox] (z,x,y) {vox.shape} = {vox.nbytes/1048576:.2f} MB, 非零 {nz} ({100*nz/vox.size:.2f}%)')

    manifest = []
    worst_q8 = 0
    for ci, (off_mm, mir) in enumerate(CASES):
        off_px = off_mm / pitch
        off_q8 = int(round(off_px * 256))
        buf = []
        for k in range(N_SLOTS):
            ang = (a.phase + k) % N
            fx = slice_fixed(vox, W, H, cos8, sin8, ang, off_q8, mir)
            buf.append(fx)
            fl = slice_float(vox, W, H, N, ang, off_px, mir)
            d = int((fx != fl).sum())
            worst_q8 = max(worst_q8, d)
        np.concatenate(buf).tofile(os.path.join(outdir, f'golden_case{ci}.bin'))
        manifest.append((off_q8, mir))
        print(f'[case{ci}] axis_off={off_mm:.1f}mm ({off_px:.3f}px, q8={off_q8})  '
              f'mirror_u={mir}  → {N_SLOTS} 片')

    with open(os.path.join(outdir, 'cases.txt'), 'w') as f:
        f.write(f'{W} {H} {N} {a.phase} {N_SLOTS} {len(manifest)}\n')
        for off_q8, mir in manifest:
            f.write(f'{off_q8} {mir}\n')

    px_tot = W * H * N_SLOTS
    print(f'[q8] 定点 vs 浮点最大差异 {worst_q8}/{px_tot} 像素 '
          f'({100*worst_q8/px_tot:.3f}%) — 仅供参考, 判据是定点逐位相同')
    print(f'[out] {outdir}/  voxels.bin + golden_case*.bin + cases.txt')


if __name__ == '__main__':
    main()
