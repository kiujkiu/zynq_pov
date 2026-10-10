#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""vb358_budget.py — 验证板口径 (vb358) 载荷 / 链路 / DR1M90 切片工作量预算 (2026-10-10, 1.4.2)

载荷: 真实 glb (aibrain-app/glb_models) 用 zynq_pov/tools/glb_voxel_payload.py 的表面体素化,
     网格换成 160×180×160 (验证板), 再走**主机真编码器** pov_profile (RGB565 → 圆柱裁剪 → VXT1)
     → lz4-HC12 raw block (= povstream --codec lz4 线上字节)。另可加 povstream 渲好的 VXT1 目录。
口径: 24 Hz / 720 RPM / 358 片 / 双面 / 内容 10–12 fps / WiFi 实测 159 Mbps / DDR 实测 1.79 GB/s
     / A35 拷贝 8.4 MB 11 ms (= 0.76 GB/s, D3 实测)。

用法: python3 vb358_budget.py [--glb-dir DIR] [--vxt-dir DIR ...]
"""
import argparse
import ctypes
import glob
import os
import sys
import types

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '..', '..', 'mlkpai_fs03', 'tools')))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '..', 'tools')))
import pov_profile as pvp                          # noqa: E402

# glb_voxel_payload 顶层 import lz4.block (本机 WSL 没有 python-lz4) —— 只借它的体素化, 塞个桩
sys.modules.setdefault('lz4', types.ModuleType('lz4'))
sys.modules.setdefault('lz4.block', types.ModuleType('lz4.block'))
import glb_voxel_payload as gvp                    # noqa: E402

WIFI_MBPS = 159.0          # DR1M90 TCP 实测
DDR_GBPS = 1.79            # X1 实测双口 PL 读 (DDRC 天花板)
CPY_GBPS = 8.4e6 / 11e-3 / 1e9   # D3: 8.4 MB 整帧拷贝 11 ms
FPS = (10, 12)

_lz4 = None


def lz4_hc(buf, level=12):
    global _lz4
    if _lz4 is None:
        _lz4 = ctypes.CDLL('liblz4.so.1')
        _lz4.LZ4_compressBound.argtypes = [ctypes.c_int]
        _lz4.LZ4_compress_HC.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int,
                                         ctypes.c_int, ctypes.c_int]
    cap = _lz4.LZ4_compressBound(len(buf))
    dst = ctypes.create_string_buffer(cap)
    n = _lz4.LZ4_compress_HC(buf, dst, len(buf), cap, level)
    assert n > 0
    return n


def glb_body(path, prof):
    W, H = prof['W'], prof['H']
    gvp.GX, gvp.GY, gvp.GZ = W, H, W
    idx, r565, _ntri, _dims = gvp.voxelize(path)
    gx = idx % W
    gz = (idx // W) % W
    gy = idx // (W * W)
    v = np.zeros((W, H, W), np.uint16)
    v[gx, gy, gz] = r565                    # glb 工具 Y 向上 = gas 约定
    v = np.where(pvp.cylinder_mask(prof)[:, None, :], v, 0).astype(np.uint16)
    return pvp.encode_vxt1(pvp.grid_from_gas(v), W, H, key=True), int(np.count_nonzero(v))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--profile', default='vb358')
    ap.add_argument('--glb-dir', default=os.path.join(HERE, '..', '..', 'aibrain-app', 'glb_models'))
    ap.add_argument('--vxt-dir', action='append', default=[],
                    help='povstream render --profile vb358 产出的目录 (取最大帧)')
    a = ap.parse_args()
    prof = pvp.get_profile(a.profile)
    W, H, N = prof['W'], prof['H'], prof['n_slices']
    print(pvp.describe(prof))

    rows = []
    for p in sorted(glob.glob(os.path.join(a.glb_dir, '*.glb'))):
        body, nv = glb_body(p, prof)
        rows.append((os.path.basename(p)[:-4], nv, len(body), lz4_hc(body)))
    # 病态上界: 整圆柱壳 (r 77..80, 满高) + 随机色 (颜色流不可压)
    c = np.arange(W) - W / 2.0
    rho = np.hypot(c[:, None], c[None, :])
    shell = (rho >= 77) & (rho < 80)
    rng = np.random.default_rng(7)
    v = np.where(shell[:, None, :], rng.integers(1, 65536, (W, H, W)), 0).astype(np.uint16)
    body = pvp.encode_vxt1(pvp.grid_from_gas(v), W, H, key=True)
    rows.append(('病态: 圆柱壳+随机色', int(np.count_nonzero(v)), len(body), lz4_hc(body)))
    for d in a.vxt_dir:
        best = None
        for p in sorted(glob.glob(os.path.join(d, '*.vxt'))):
            b = open(p, 'rb').read()
            r = (os.path.basename(os.path.normpath(d)), int(np.frombuffer(b, '<u4', 1, 8)[0]),
                 len(b), lz4_hc(b))
            best = r if best is None or r[3] > best[3] else best
        if best:
            rows.append(best)

    print(f'\n## 载荷 (每内容帧, lz4-HC12 = 线上字节) vs WiFi {WIFI_MBPS:g} Mbps')
    print(f'| 内容 | 体素 | VXT1 原始 B | lz4 B | B/体素 | ' +
          ' | '.join(f'@{f}fps Mbps (余量)' for f in FPS) + ' |')
    print('|---|---|---|---|---|' + '---|' * len(FPS))
    for name, nv, raw, lz in rows:
        cells = ' | '.join(f'{lz * 8 * f / 1e6:.1f} ({WIFI_MBPS / (lz * 8 * f / 1e6):.1f}×)'
                           for f in FPS)
        print(f'| {name} | {nv:,} | {raw:,} | {lz:,} | {lz / max(nv, 1):.2f} | {cells} |')

    slice_b = W * H * 2
    rps = prof['rpm'] / 60.0
    disp = 2 * N * rps                             # 两面 slice/s
    print(f'\n## DR1M90 切片工作量 (RGB565 {W}×{H} = {slice_b:,} B/片; {N} 片 × {rps:g} rev/s '
          f'= {N * rps:,.0f} slice/s/面, 两面 {disp:,.0f}; 每片时隙 {1e6 / (N * rps):.1f} µs/面)')
    disp_bw = disp * slice_b / 1e9
    print(f'- PL 显示读切片 (恒定): {disp_bw:.3f} GB/s')
    for f in FPS:
        n_sl = 2 * N * f
        gen = n_sl * slice_b / 1e9                 # 切片写 (+ 同量体素列读)
        cpu_ms = 2 * N * slice_b / (CPY_GBPS * 1e9) * 1e3
        tot_ddr = disp_bw + 2 * gen
        print(f'- 内容 {f} fps, **CPU 切进 DDR**: {n_sl:,} 片/s, 写 {gen:.3f} + 读体素 {gen:.3f} GB/s '
              f'+ 显示 {disp_bw:.3f} = **{tot_ddr:.2f} GB/s = DDR 实测 {DDR_GBPS} 的 '
              f'{100 * tot_ddr / DDR_GBPS:.0f}%**; A35 按拷贝速率 {CPY_GBPS:.2f} GB/s 估 '
              f'{cpu_ms:.0f} ms/内容帧 = 单核 {cpu_ms * f / 10:.0f}%')
    print(f'- **PL 直供切片** (pov_slice_v2 读体素网格→直接喂显示, 切片不落 DDR): '
          f'DDR 只剩体素列读 {disp_bw:.3f} GB/s = {100 * disp_bw / DDR_GBPS:.0f}% '
          f'(+ scatter 每帧几 MB, 可忽略)')


if __name__ == '__main__':
    main()
