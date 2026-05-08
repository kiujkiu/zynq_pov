"""Mesh → angle slice (POV-3D B 路径).

坐标约定 (与 GLB y-up 一致):
  y = height (LED 板高度方向, 不旋转)
  (x, z) = horizontal plane (LED 板绕 y 轴旋转, θ 是绕 y 的角度)
  rotated coord: x' = x cos θ + z sin θ;  z' = -x sin θ + z cos θ
  切平面 = { z' = 0 }  即 LED 板物理位置 (x', y) 平面

切平面 ∩ mesh = 一组线段 (closed loops). 用 scanline fill 在 (x', y) 切片
fb 上着色: 每行 y 找穿越 z'=0 的 segment 的 x'-crossings, 排序配对填充.

实体填充策略 (scanline fill):
1. 收集 angle θ 切平面上所有 mesh ∩ plane 的线段端点 (model coord, 带颜色)
2. 对每行 z: 找所有穿越该 z 的 segment, 在线性插值得 x-crossings
3. 排序 x-crossings, 偶/奇配对 → 配对内部填充 (inside-outside rule)
4. 填充颜色 = 左右边界颜色线性插值 (Gouraud)

适用前提: 切平面与 mesh 交线是闭环 (manifold mesh 自动满足).
"""
import math
import numpy as np


def slice_mesh_at_angle(verts, tris, angle_deg,
                        slice_w, slice_h,
                        x_half, y_min, y_max):
    """Return slice_h × slice_w × 3 uint8 array (filled cross-section).

    verts: array of (x,y,z,r,g,b)  — float xyz model coord (y-up), u8 rgb
    tris:  iterable of (i0,i1,i2)
    angle_deg: 0..360 (绕 y 轴旋转角)
    切平面: 旋转后 z'=0, slice 像素 = (x', y)
    """
    c = math.cos(math.radians(angle_deg))
    s = math.sin(math.radians(angle_deg))
    sx = slice_w / (2.0 * x_half)
    sy = slice_h / (y_max - y_min)
    fb = np.zeros((slice_h, slice_w, 3), dtype=np.uint8)

    # Phase 1: 收集 segments. z' = -x sin θ + z cos θ; x' = x cos θ + z sin θ
    segs = []  # (xa, ya_h, ra, ga, ba, xb, yb_h, rb, gb, bb)
    for (i0, i1, i2) in tris:
        v0 = verts[i0]; v1 = verts[i1]; v2 = verts[i2]
        z0p = -v0[0]*s + v0[2]*c
        z1p = -v1[0]*s + v1[2]*c
        z2p = -v2[0]*s + v2[2]*c
        n_pos = (1 if z0p > 0 else 0) + (1 if z1p > 0 else 0) + (1 if z2p > 0 else 0)
        if n_pos == 0 or n_pos == 3:
            continue
        crossings = []
        for (va, vb, za_v, zb_v) in (
                (v0, v1, z0p, z1p),
                (v1, v2, z1p, z2p),
                (v2, v0, z2p, z0p)):
            if (za_v > 0) != (zb_v > 0):
                if za_v == zb_v:
                    continue
                t = za_v / (za_v - zb_v)
                xp = (va[0]*c + va[2]*s) + t * ((vb[0]*c + vb[2]*s) - (va[0]*c + va[2]*s))
                yh = va[1] + t * (vb[1] - va[1])
                r  = va[3] + t * (vb[3] - va[3])
                g  = va[4] + t * (vb[4] - va[4])
                b  = va[5] + t * (vb[5] - va[5])
                crossings.append((xp, yh, r, g, b))
        if len(crossings) == 2:
            (xa, ya_h, ra, ga, ba) = crossings[0]
            (xb, yb_h, rb, gb, bb) = crossings[1]
            segs.append((xa, ya_h, ra, ga, ba, xb, yb_h, rb, gb, bb))

    if not segs:
        return fb
    segs_np = np.array(segs, dtype=np.float32)
    # columns: 0 xa, 1 ya_h, 2 ra, 3 ga, 4 ba, 5 xb, 6 yb_h, 7 rb, 8 gb, 9 bb

    # Phase 2: scanline fill per pixel row (像素 y 对应 model y_h)
    # y_pix=0 顶部 = y_max, y_pix=slice_h-1 底部 = y_min
    for y_pix in range(slice_h):
        yh = y_max - (y_pix + 0.5) / sy
        ya_arr = segs_np[:, 1]; yb_arr = segs_np[:, 6]
        cross = (ya_arr - yh) * (yb_arr - yh) <= 0
        cross &= (ya_arr != yb_arr)
        if not np.any(cross):
            continue
        sub = segs_np[cross]
        t = (yh - sub[:, 1]) / (sub[:, 6] - sub[:, 1])
        xp = sub[:, 0] + t * (sub[:, 5] - sub[:, 0])
        rp = sub[:, 2] + t * (sub[:, 7] - sub[:, 2])
        gp = sub[:, 3] + t * (sub[:, 8] - sub[:, 3])
        bp = sub[:, 4] + t * (sub[:, 9] - sub[:, 4])
        # 排序
        order = np.argsort(xp)
        xp_s = xp[order]; rp_s = rp[order]; gp_s = gp[order]; bp_s = bp[order]
        # 配对填充 (i, i+1)
        for i in range(0, len(xp_s) - 1, 2):
            xa_m = xp_s[i]; xb_m = xp_s[i+1]
            ra_v = rp_s[i]; ga_v = gp_s[i]; ba_v = bp_s[i]
            rb_v = rp_s[i+1]; gb_v = gp_s[i+1]; bb_v = bp_s[i+1]
            x_pix_a = int((xa_m + x_half) * sx)
            x_pix_b = int((xb_m + x_half) * sx)
            if x_pix_a > x_pix_b:
                x_pix_a, x_pix_b = x_pix_b, x_pix_a
                ra_v, rb_v = rb_v, ra_v
                ga_v, gb_v = gb_v, ga_v
                ba_v, bb_v = bb_v, ba_v
            x_pix_a = max(0, x_pix_a)
            x_pix_b = min(slice_w - 1, x_pix_b)
            if x_pix_a > x_pix_b:
                continue
            n = x_pix_b - x_pix_a + 1
            ts = np.arange(n, dtype=np.float32) / max(1, n - 1)
            r_arr = np.clip(ra_v + ts * (rb_v - ra_v), 0, 255).astype(np.uint8)
            g_arr = np.clip(ga_v + ts * (gb_v - ga_v), 0, 255).astype(np.uint8)
            b_arr = np.clip(ba_v + ts * (bb_v - ba_v), 0, 255).astype(np.uint8)
            fb[y_pix, x_pix_a:x_pix_b+1, 0] = r_arr
            fb[y_pix, x_pix_a:x_pix_b+1, 1] = g_arr
            fb[y_pix, x_pix_a:x_pix_b+1, 2] = b_arr
    return fb


def slice_mesh_grid(verts, tris, n_angles,
                    slice_w, slice_h,
                    x_half, y_min, y_max,
                    progress=False):
    out = []
    for k in range(n_angles):
        ang = k * 360.0 / n_angles
        out.append(slice_mesh_at_angle(verts, tris, ang, slice_w, slice_h,
                                       x_half, y_min, y_max))
        if progress and (k % max(1, n_angles // 12) == 0):
            print(f"  slice {k}/{n_angles} ang={ang:.1f}°")
    return out


if __name__ == "__main__":
    import os
    import sys
    import time
    from PIL import Image

    HERE = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, HERE)
    from glb_to_mesh import build_simplified_mesh

    glb = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "anime_62459.glb")
    target_tris = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
    n_angles = int(sys.argv[3]) if len(sys.argv) > 3 else 24
    out_dir = os.path.join(HERE, "out_slices")
    os.makedirs(out_dir, exist_ok=True)

    print(f"build mesh {os.path.basename(glb)} target_tris={target_tris}...")
    verts, faces = build_simplified_mesh(glb, target_tris=target_tris,
                                          target_scale=40, z_stretch=1.0,
                                          brighten=1.0, gamma=1.0,
                                          saturation=1.6, verbose=False)
    print(f"  {len(verts)} verts, {len(faces)} tris")

    xs = [v[0] for v in verts]; ys = [v[1] for v in verts]; zs = [v[2] for v in verts]
    # 旋转半径 = max(|x|,|z|) (绕 y 轴), y 是高度
    x_half = max(abs(min(xs)), abs(max(xs)), abs(min(zs)), abs(max(zs))) * 1.1
    y_min  = min(ys) - 2; y_max  = max(ys) + 2
    print(f"  rot_half={x_half:.1f}  y(height)=[{y_min:.1f},{y_max:.1f}]")

    SLICE_W, SLICE_H = 160, 180
    print(f"slicing {n_angles} angles @ {SLICE_W}×{SLICE_H} (filled)...")
    t0 = time.time()
    slices = slice_mesh_grid(verts, faces, n_angles, SLICE_W, SLICE_H,
                             x_half, y_min, y_max, progress=True)
    dt = time.time() - t0
    print(f"  done in {dt:.2f}s ({dt/n_angles*1000:.1f} ms/slice)")

    cols = 4
    rows = (n_angles + cols - 1) // cols
    grid = np.zeros((rows * SLICE_H, cols * SLICE_W, 3), dtype=np.uint8)
    for k, fb in enumerate(slices):
        c = k % cols; r = k // cols
        grid[r*SLICE_H:(r+1)*SLICE_H, c*SLICE_W:(c+1)*SLICE_W] = fb

    Image.fromarray(grid).save(os.path.join(out_dir, "mesh_slice_grid.png"))
    print(f"saved {out_dir}/mesh_slice_grid.png")
    for k in (0, n_angles // 4, n_angles // 2, 3 * n_angles // 4):
        Image.fromarray(slices[k]).save(os.path.join(out_dir, f"mesh_slice_{k:03d}.png"))
    print("done.")
