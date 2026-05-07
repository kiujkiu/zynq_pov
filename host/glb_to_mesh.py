"""GLB → simplified triangle mesh + per-vertex colors.

策略 (不依赖 trimesh decimation):
1. 复用 glb_to_points.load_glb 拿原始 triangles + texture
2. 按 area 排序, 保留 top N 大三角 (~1024)
3. 顶点 dedup (网格用相同坐标的顶点应该 share)
4. 每三角 sample texture 重心拿 baseColor, 顶点颜色 = 入射三角颜色 area-weighted average
5. 输出 (vertices: list of (x,y,z,r,g,b), faces: list of (i0,i1,i2))

仅几何 + 顶点色, 没 normal/tangent/uv. 板端做 Gouraud shading: barycentric color interp.
"""
import math
import numpy as np

from glb_to_points import load_glb


def build_simplified_mesh(glb_path, target_tris=1024, target_scale=40, z_stretch=1.0,
                          brighten=1.0, gamma=1.0, saturation=1.0, verbose=True):
    """Return (vertices, faces).

    vertices: list of (x, y, z, r, g, b) — coords ±target_scale (will fit int8 ±127),
              colors u8.
    faces: list of (i0, i1, i2) — indices into vertices.
    """
    triangles = load_glb(glb_path, verbose=verbose)
    n_orig = len(triangles)
    if verbose:
        print(f"[mesh] {n_orig} original triangles")

    # 1) Compute AABB and normalization
    all_pts = np.array([p for t in triangles for p in t[:3]], dtype=np.float32)
    cmin, cmax = all_pts.min(axis=0), all_pts.max(axis=0)
    center = (cmin + cmax) / 2
    span = (cmax - cmin).max()
    if span <= 0:
        return [], []
    scale = (2 * target_scale) / span

    # 2) Pre-compute area + centroid color for every triangle
    areas = np.zeros(n_orig, dtype=np.float32)
    centroids = np.zeros((n_orig, 3), dtype=np.float32)
    colors = np.zeros((n_orig, 3), dtype=np.float32)
    print_every = max(1, n_orig // 20)
    for i, (p0, p1, p2, color_info) in enumerate(triangles):
        if verbose and i % print_every == 0:
            print(f"  prep {i}/{n_orig}...")
        e1 = (p1 - p0).astype(np.float32)
        e2 = (p2 - p0).astype(np.float32)
        areas[i] = 0.5 * float(np.linalg.norm(np.cross(e1, e2)))
        centroids[i] = (p0 + p1 + p2) / 3.0
        if color_info[0] == "tex":
            _, tex, uv0, uv1, uv2 = color_info
            uv = (uv0 + uv1 + uv2) / 3
            tx = int((uv[0] % 1.0) * tex.shape[1]) % tex.shape[1]
            ty = int((1.0 - (uv[1] % 1.0)) * tex.shape[0]) % tex.shape[0]
            px = tex[ty, tx]
            colors[i] = (float(px[0]), float(px[1]), float(px[2]))
        else:
            c = color_info[1]
            colors[i] = (float(c[0]), float(c[1]), float(c[2]))

    # 3) Keep top N by area
    if n_orig > target_tris:
        # Sort indices by area desc
        order = np.argsort(-areas)
        keep_idx = order[:target_tris]
    else:
        keep_idx = np.arange(n_orig)
    if verbose:
        print(f"[mesh] keep top {len(keep_idx)} triangles by area "
              f"(area_thresh={areas[keep_idx[-1]]:.5f})")

    # 4) Build vertex list with dedup, accumulate per-vertex color (area-weighted)
    #    Vertex key: rounded normalized coords (avoid float comparison issues)
    DEDUP_QUANT = 0.25  # vertices within 0.25 model unit merge
    vert_map = {}        # quantized_xyz tuple → vertex idx
    vertices = []        # list of (x, y, z, accum_r, accum_g, accum_b, accum_w)
    faces = []
    for kidx in keep_idx:
        p0, p1, p2, _ = triangles[kidx]
        col = colors[kidx]
        area = areas[kidx]
        tri_idx = []
        for p_raw in (p0, p1, p2):
            n = (p_raw - center) * scale
            n = n.astype(np.float32)
            n[2] *= z_stretch
            qkey = (int(round(n[0] / DEDUP_QUANT)),
                    int(round(n[1] / DEDUP_QUANT)),
                    int(round(n[2] / DEDUP_QUANT)))
            v_idx = vert_map.get(qkey)
            if v_idx is None:
                v_idx = len(vertices)
                vert_map[qkey] = v_idx
                vertices.append([float(n[0]), float(n[1]), float(n[2]),
                                 0.0, 0.0, 0.0, 0.0])
            v = vertices[v_idx]
            v[3] += col[0] * area
            v[4] += col[1] * area
            v[5] += col[2] * area
            v[6] += area
            tri_idx.append(v_idx)
        faces.append(tuple(tri_idx))

    # 5) Finalize per-vertex colors + apply post (gamma/brighten/saturation)
    out_verts = []
    import colorsys
    for v in vertices:
        x, y, z, rs, gs, bs, ws = v
        if ws <= 0:
            r = g = b = 0
        else:
            r = int(rs / ws); g = int(gs / ws); b = int(bs / ws)
        # gamma
        if gamma != 1.0 and gamma > 0:
            r = int(255 * pow(max(0, r) / 255.0, gamma))
            g = int(255 * pow(max(0, g) / 255.0, gamma))
            b = int(255 * pow(max(0, b) / 255.0, gamma))
        # brighten (按 max-channel 等比放大不爆色相)
        if brighten != 1.0:
            mx = max(r, g, b)
            if mx > 0:
                tgt = min(255, int(mx * brighten))
                k = tgt / mx
                r = int(r * k); g = int(g * k); b = int(b * k)
        # saturation
        if saturation != 1.0:
            h, s, v_ = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            s = min(1.0, s * saturation)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v_)
            r, g, b = int(r2*255), int(g2*255), int(b2*255)
        r = max(0, min(255, r)); g = max(0, min(255, g)); b = max(0, min(255, b))
        # Clip coords to int8
        ix = max(-128, min(127, int(round(x))))
        iy = max(-128, min(127, int(round(y))))
        iz = max(-128, min(127, int(round(z))))
        out_verts.append((ix, iy, iz, r, g, b))

    if verbose:
        print(f"[mesh] {len(out_verts)} unique verts (dedup quant {DEDUP_QUANT}u), "
              f"{len(faces)} triangles")
    return out_verts, faces


if __name__ == "__main__":
    import sys
    glb = sys.argv[1] if len(sys.argv) > 1 else "anime_62459.glb"
    nt = int(sys.argv[2]) if len(sys.argv) > 2 else 1024
    verts, faces = build_simplified_mesh(glb, target_tris=nt, target_scale=40,
                                          z_stretch=1.0, brighten=1.5, gamma=0.85,
                                          saturation=1.5)
    print(f"verts={len(verts)} tris={len(faces)}")
    print(f"sample v0={verts[0]}")
    print(f"sample tri0={faces[0]}")
