#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""vb358_e2e.py — 验证板口径 (vb358) 离线端到端对拍, 不碰板子 (2026-10-10, 任务 1.4.2)

链路 (除了 WiFi 本身, 每一段都是真代码):
  主机 pov_profile.py (mlkpai_fs03/tools, povstream --profile vb358 用的同一份)
     体素 → RGB565 → 圆柱裁剪 → VXT1 体
  → 板端 C: vox_scatter.c (增量清理, 跨帧) → pov_slice_v2.cpp (-DPV2_CFG_VB358, 358 档 Q8 表)
     面A phase 0 / 面B phase 179 (+13.4mm), 每帧切满 358 × 2 片   [vb_slice_all]
  ↔ 独立浮点参考 (本文件, float64 三角函数, 不用 Q8 表/不用 C 代码):
     面A: θ_g, 垂距 0;  面B: **按物理推** —— 背对背装、从反侧看 ⇒ θ_g、垂距 −13.4mm、
     手性取反 (memory project_pov3d_v31_dualface_geometry_solved), 不经过 "phase=179" 这条路。

三层判据:
  ① 几何探针 (满网格, 每格颜色 = 1+gx+160·gz / 1+gy): 从 C 输出**直接读出**每列采到哪根
     体素柱, 与浮点理想采样点比 —— 最大误差、最近邻命中率、越出 "0.5 + Q8 误差上界" 的列数 (须 0)。
  ② 内容逐字节: C 输出 == 主机网格按 ① 读出的坐标取值 (须 0 不符) —— 验 VXT1/scatter/增量清理/裁剪。
  ③ 内容 vs 浮点参考: 不符像素数 (只允许出现在 ① 判为 Q8 舍入差的列上, "无法解释" 须 0)。
另报: 用 gas (povstream 2047 渲染) 的列中心约定 u = px-79.5 时的系统误差 (切片器是 u = px-80)。

用法:
  make CFG=vb358 vb_slice_all && python3 vb358_e2e.py [--work DIR] [--host-dir povstream渲的VXT1目录]
"""
import argparse
import ctypes
import json
import math
import os
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '..', '..', 'mlkpai_fs03', 'tools')))
import pov_profile as pvp      # noqa: E402  (被测的主机编码器)


# ─────────────────────────── 测试体 (gas 坐标: [gx, gy↑, gz]) ────────────────

def centers(W, H):
    c = np.arange(W) - W / 2.0
    y = np.arange(H) - H / 2.0
    return (c[:, None, None], y[None, :, None], c[None, None, :])


def hsv(h):
    h = (h % 1.0) * 6.0
    i = np.floor(h).astype(int) % 6
    f = h - np.floor(h)
    q, t = 1 - f, f
    o, z = np.ones_like(f), np.zeros_like(f)
    r = np.choose(i, [o, q, z, z, t, o])
    g = np.choose(i, [t, o, o, q, z, z])
    b = np.choose(i, [z, z, t, o, o, q])
    return np.stack([r, g, b], -1) * 255.0


def vol_probe_xz(W, H):
    gx = np.arange(W)[:, None, None]
    gz = np.arange(W)[None, None, :]
    return np.broadcast_to(1 + gx + W * gz, (W, H, W)).astype(np.uint16)


def vol_probe_y(W, H):
    return np.broadcast_to(1 + np.arange(H)[None, :, None], (W, H, W)).astype(np.uint16)


def vol_cube(W, H, ang_deg):
    """轴对齐立方体壳 (ang=0) + 绕 y 小角度旋转的后续帧; 面按法向着色 x红 y绿 z蓝;
    外加一颗偏心实心小方块 (破对称) 和一根落在网格角上的柱 (显示圆柱外, 应被裁掉且不影响显示)。"""
    x, y, z = centers(W, H)
    a = math.radians(ang_deg)
    qx = (x - 8) * math.cos(a) - (z + 6) * math.sin(a)
    qz = (x - 8) * math.sin(a) + (z + 6) * math.cos(a)
    qy = y + 0 * x
    m = np.maximum(np.maximum(np.abs(qx), np.abs(qy)), np.abs(qz))
    shell = (m <= 40) & (m > 38.5)
    ax = np.argmax(np.stack(np.broadcast_arrays(np.abs(qx), np.abs(qy), np.abs(qz))), 0)
    col = np.zeros((W, H, W, 3))
    for k in range(3):
        col[..., k] = np.where(shell & (ax == k), 230.0, 0.0)
    small = (np.abs(x + 45) <= 6) & (np.abs(y - 55) <= 6) & (np.abs(z - 30) <= 6)
    col[small] = (255, 200, 40)
    corner = (np.abs(x + 79) <= 1) & (np.abs(z + 79) <= 1) & (np.abs(y) < 60)
    col[np.broadcast_to(corner, (W, H, W))] = (255, 255, 255)
    return col


def vol_helix(W, H, phase):
    """管半径 5 的螺旋 (半径 50, 2.5 圈, 色相沿长度变)。"""
    x, y, z = centers(W, H)
    R, turns, rt = 50.0, 2.5, 5.0
    t = (y + 80.0) / 160.0
    phi_h = 2 * math.pi * turns * t + phase
    rho = np.hypot(x, z)
    dphi = np.angle(np.exp(1j * (np.arctan2(z, x) - phi_h)))
    pitch = 160.0 / (2 * math.pi * turns * R)            # dy/ds 的斜率
    d = np.hypot(rho - R, R * dphi / math.sqrt(1 + pitch ** 2))
    tube = (d <= rt) & (np.abs(y) <= 82)
    col = hsv(t + 0 * x) * tube[..., None]
    return np.broadcast_to(col, (W, H, W, 3))


def vol_checker(W, H, rot_deg):
    """圆柱壳棋盘 (r 60..63, 24 扇区 × 每 15 px 一行) + 底面圆盘棋盘 (y = -84)。"""
    x, y, z = centers(W, H)
    rho = np.hypot(x, z)
    phi = (np.degrees(np.arctan2(z, x)) + rot_deg) % 360.0
    sector = np.floor(phi / 15.0).astype(int)
    row = np.floor((y + 90) / 15.0).astype(int)
    wall = (rho >= 60) & (rho < 63) & (np.abs(y) <= 75)
    floor_ = (np.abs(y + 84) <= 1) & (rho < 60)
    cell = np.floor((x + 80) / 10).astype(int) + np.floor((z + 80) / 10).astype(int)
    col = np.zeros((W, H, W, 3))
    on_w = wall & ((sector + row) % 2 == 0)
    on_f = floor_ & (cell % 2 == 0)
    col[np.broadcast_to(on_w, col.shape[:3])] = (255, 80, 0)
    col[np.broadcast_to(on_f, col.shape[:3])] = (0, 160, 255)
    return col


# ─────────────────────────── 独立浮点参考 ───────────────────────────────────

def ideal_columns(prof, face, c_off):
    """→ (xf, zf): (N, W) 每片每列的理想采样点 (体素索引空间, 浮点)。
    c_off: 列中心约定, u = px - c_off (切片器 W/2, gas (W-1)/2)。
    面B 走**物理推导**: θ_g, 垂距 −d, 手性取反 —— 不用 phase。"""
    W, N = prof['W'], prof['n_slices']
    g = np.arange(N)[:, None]
    th = 2 * math.pi * g / N
    u = np.arange(W)[None, :] - c_off
    mirror = bool(face['mirror_u'])
    d = face['axis_off_px']
    if face['phase'] != 0:                    # 面B: 背对背 ⇒ 垂距取负 + 手性翻转
        assert face['phase'] * 2 == N, 'phase 必须是半圈 (N 偶数)'
        d, mirror = -d, not mirror
    if mirror:
        u = -u
    x = u * np.cos(th) - d * np.sin(th)
    z = u * np.sin(th) + d * np.cos(th)
    return x + W / 2.0, z + W / 2.0


def q8_tol(prof, face):
    """Q8 定点相对浮点的采样点误差上界 (每轴, px): |u|·Δcos + |d|·Δsin + 截断。"""
    W = prof['W']
    u = np.abs(np.arange(W) - W / 2.0) + 0.5
    return (u + abs(face['axis_off_px'])) * (0.5 / 256) + 2.0 / 256


# ─────────────────────────── 杂项 ───────────────────────────────────────────

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


def colstore(v565):
    """gas (gx, gy↑, gz) → [gx, gz, py] (py = 面板行, 自上而下) 方便按列取。"""
    return np.ascontiguousarray(np.transpose(v565[:, ::-1, :], (0, 2, 1)))


def run_harness(prof, faces, files, out):
    exe = os.path.join(HERE, 'vb_slice_all')
    if not os.path.exists(exe):
        sys.exit('先 make CFG=vb358 vb_slice_all')
    fa, fb = faces
    cmd = [exe, out, str(prof['n_slices']),
           str(fa['axis_off_q8']), str(fa['mirror_u']), str(fa['phase']),
           str(fb['axis_off_q8']), str(fb['mirror_u']), str(fb['phase'])] + files
    r = subprocess.run(cmd, capture_output=True, text=True)
    print(r.stdout.rstrip())
    if r.returncode:
        sys.exit(r.stderr)
    W, H, N = prof['W'], prof['H'], prof['n_slices']
    return np.memmap(out, np.uint16, 'r').reshape(len(files), 2, N, W, H)


# ─────────────────────────── 主流程 ─────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--profile', default='vb358')
    ap.add_argument('--work', default=os.environ.get('TMPDIR', '/tmp') + '/vb358_e2e')
    ap.add_argument('--host-dir', default=None,
                    help='另验一个 povstream render --profile vb358 产出的 VXT1 目录')
    ap.add_argument('--json', default=None, help='结果另存 JSON')
    a = ap.parse_args()

    prof = pvp.get_profile(a.profile)
    faces = pvp.face_params(prof)
    W, H, N = prof['W'], prof['H'], prof['n_slices']
    print(pvp.describe(prof))
    os.makedirs(a.work, exist_ok=True)
    res = {'profile': pvp.meta_dict(prof)}

    # ---- 帧序列: 探针 2 帧 + 内容 8 帧, 一条序列跑完 (scatter 增量清理跨帧) ----
    # (名, 生成器, 是否 RGB565 探针) —— 惰性生成, 一个 float 体 110 MB
    seq = [('probe_xz', lambda: vol_probe_xz(W, H), True),
           ('probe_y', lambda: vol_probe_y(W, H), True)]
    for ang in (0, 5, 10):
        seq.append((f'cube@{ang}°', lambda ang=ang: vol_cube(W, H, ang), False))
    for ph in (0.0, 0.4, 0.8):
        seq.append((f'helix@{ph}', lambda ph=ph: vol_helix(W, H, ph), False))
    for rot in (0.0, 7.5):
        seq.append((f'checker@{rot}°', lambda rot=rot: vol_checker(W, H, rot), False))

    files, v565s, budget = [], [], []
    mask = pvp.cylinder_mask(prof)
    for i, (name, gen, is_probe) in enumerate(seq):
        if not is_probe:
            flt = gen()
            body = pvp.vxt1_from_gas_float(flt, prof, seq=i, key=(i == 0))   # 主机真路径
            v565 = pvp.rgb565_from_float(flt)                                # 参考用: **未裁剪**
            del flt
        else:
            v565 = gen()
            vv = np.where(mask[:, None, :], v565, 0).astype(np.uint16)
            body = pvp.encode_vxt1(pvp.grid_from_gas(vv), W, H, seq=i, key=(i == 0))
        p = os.path.join(a.work, f'f{i:02d}.vxt')
        open(p, 'wb').write(body)
        files.append(p)
        v565s.append(v565)
        n_vox = int(np.frombuffer(body, '<u4', 1, 8)[0])
        n_raw = int(np.count_nonzero(v565))
        lz = lz4_hc(body)
        budget.append(dict(name=name, n_vox=n_vox, n_vox_uncropped=n_raw,
                           vxt_bytes=len(body), lz4hc12=lz))
        print(f'[host] {name:<14} 体素 {n_vox:>9,} (裁前 {n_raw:,})  VXT1 {len(body):>10,} B  '
              f'lz4-HC12 {lz:>9,} B')

    out = os.path.join(a.work, 'slices.bin')
    t0 = time.time()
    S = run_harness(prof, faces, files, out)
    print(f'[c] {time.time() - t0:.1f}s')

    # ---- ① 几何: 探针读出每列采样坐标 ----
    ok_all = True
    coord = []
    for f, face in enumerate(faces):
        pxz = S[0, f].astype(np.int64)                       # (N, W, H)
        col0 = pxz[:, :, 0]
        assert (pxz == col0[:, :, None]).all(), '探针 xz: 同一列各行不一致 (列不是整根柱子)'
        inside = col0 != 0
        gx = np.where(inside, (col0 - 1) % W, -1)
        gz = np.where(inside, (col0 - 1) // W, -1)
        py = S[1, f].astype(np.int64)
        y_ok = bool((py[inside] == (H - np.arange(H))[None, :].repeat(inside.sum(), 0)).all())
        y_out = bool((py[~inside] == 0).all())
        coord.append((gx, gz, inside))

        r = {}
        for tag, c_off in (('slicer', W / 2.0), ('gas', (W - 1) / 2.0)):
            xf, zf = ideal_columns(prof, face, c_off)
            nx, nz = np.rint(xf), np.rint(zf)
            ins_ref = (nx >= 0) & (nx < W) & (nz >= 0) & (nz < W)
            both = inside & ins_ref
            ex = np.abs(gx - xf)[both]
            ez = np.abs(gz - zf)[both]
            cheb = np.maximum(ex, ez)
            eucl = np.hypot(gx - xf, gz - zf)[both]
            near = ((gx == nx) & (gz == nz))[both]
            tol = np.broadcast_to(q8_tol(prof, face)[None, :], xf.shape)[both]
            viol = int(((ex > 0.5 + tol + 1e-9) | (ez > 0.5 + tol + 1e-9)).sum())
            dmask = inside != ins_ref
            dis = int(dmask.sum())
            # 网格边沿上的内外分歧: 理想点离 −0.5 / W−0.5 边界不到 Q8 误差 ⇒ 舍入差, 可解释
            tolf = np.broadcast_to(q8_tol(prof, face)[None, :], xf.shape)
            near_edge = np.zeros_like(dmask)
            for q in (xf, zf):
                near_edge |= (np.abs(q + 0.5) <= tolf) | (np.abs(q - (W - 0.5)) <= tolf)
            dis_unexpl = int((dmask & ~near_edge).sum())
            r[tag] = dict(cols=int(both.sum()), nearest_pct=round(100 * near.mean(), 4),
                          max_cheb=round(float(cheb.max()), 4),
                          max_eucl=round(float(eucl.max()), 4),
                          mean_eucl=round(float(eucl.mean()), 4),
                          viol=viol, inside_disagree=dis, inside_disagree_unexpl=dis_unexpl)
        r['y_flip_ok'] = y_ok and y_out
        print(f'[① 几何 面{face["name"]}] 切片器约定 u=px-80: {r["slicer"]["cols"]:,} 列, '
              f'最近邻命中 {r["slicer"]["nearest_pct"]}%, 最大误差 cheb {r["slicer"]["max_cheb"]} / '
              f'eucl {r["slicer"]["max_eucl"]} px, 超 Q8 上界 {r["slicer"]["viol"]} 列, '
              f'内外判定不一致 {r["slicer"]["inside_disagree"]} 列 (均在网格边沿 Q8 舍入带内: '
              f'{"是" if r["slicer"]["inside_disagree_unexpl"] == 0 else "否!"}); y 翻转 '
              f'{"✓" if r["y_flip_ok"] else "✗"}')
        print(f'             gas 约定 u=px-79.5: 最近邻命中 {r["gas"]["nearest_pct"]}%, '
              f'最大 eucl {r["gas"]["max_eucl"]} px, 平均 {r["gas"]["mean_eucl"]} px '
              f'(切片器 {r["slicer"]["mean_eucl"]})')
        ok_all &= r['slicer']['viol'] == 0 and r['y_flip_ok'] \
            and r['slicer']['inside_disagree_unexpl'] == 0
        res[f'geom_{face["name"]}'] = r

    # ---- ②③ 内容 ----
    res['content'] = []
    for i in range(2, len(seq)):
        cs = colstore(v565s[i])
        row = dict(name=seq[i][0])
        for f, face in enumerate(faces):
            gx, gz, inside = coord[f]
            pred = np.where(inside[..., None], cs[np.maximum(gx, 0), np.maximum(gz, 0)], 0)
            got = S[i, f]
            bad_pred = int((pred != got).sum())
            xf, zf = ideal_columns(prof, face, W / 2.0)
            nx, nz = np.rint(xf).astype(int), np.rint(zf).astype(int)
            ins = (nx >= 0) & (nx < W) & (nz >= 0) & (nz < W)
            ref = np.where(ins[..., None], cs[np.clip(nx, 0, W - 1), np.clip(nz, 0, W - 1)], 0)
            diff = ref != got
            same_col = (gx == nx) & (gz == nz) & (inside == ins)
            unexplained = int((diff & same_col[..., None]).sum())
            lit = int((got != 0).sum())
            row[face['name']] = dict(lit_px=lit, bad_vs_pred=bad_pred,
                                     bad_vs_float=int(diff.sum()),
                                     bad_vs_float_pct=round(100 * diff.sum() / max(lit, 1), 3),
                                     unexplained=unexplained)
            ok_all &= bad_pred == 0 and unexplained == 0
        res['content'].append(row)
        print(f'[②③ {row["name"]:<12}] ' + '  '.join(
            f'面{k}: 亮 {v["lit_px"]:,} px, C≠预测 {v["bad_vs_pred"]}, C≠浮点 {v["bad_vs_float"]:,} '
            f'({v["bad_vs_float_pct"]}% 亮像素), 不可解释 {v["unexplained"]}'
            for k, v in row.items() if k != 'name'))

    # ---- 可选: povstream 真实产物 ----
    if a.host_dir:
        hf = sorted(os.path.join(a.host_dir, x) for x in os.listdir(a.host_dir)
                    if x.endswith('.vxt'))
        meta = json.load(open(os.path.join(a.host_dir, 'meta.json')))
        assert meta['profile']['n_slices'] == N and meta['profile']['faces'] == faces, \
            'povstream 目录的 profile 与本次不一致'
        Sh = run_harness(prof, faces, hf, os.path.join(a.work, 'host_slices.bin'))
        bad = 0
        for i, p in enumerate(hf):
            _, idx, col = pvp.decode_vxt1(open(p, 'rb').read())
            grid = np.zeros(W * W * H, np.uint16)
            grid[idx] = col
            g3 = grid.reshape(W, W, H)                     # (vz, vx, py)
            for f in range(2):
                gx, gz, inside = coord[f]
                pred = np.where(inside[..., None], g3[np.maximum(gz, 0), np.maximum(gx, 0)], 0)
                bad += int((pred != Sh[i, f]).sum())
        res['host_dir'] = dict(dir=a.host_dir, frames=len(hf), bad=bad)
        print(f'[host-dir] {a.host_dir}: {len(hf)} 帧 × 2 面 × {N} 片, C≠Python 解码预测 {bad}')
        ok_all &= bad == 0

    res['budget'] = budget
    res['pass'] = bool(ok_all)
    if a.json:
        json.dump(res, open(a.json, 'w'), indent=1, ensure_ascii=False)
    print('\n' + ('✅ PASS' if ok_all else '✗ FAIL') + f' — {len(seq)} 帧 × 2 面 × {N} 片')
    for p in files + [out]:
        os.remove(p)
    sys.exit(0 if ok_all else 1)


if __name__ == '__main__':
    main()
