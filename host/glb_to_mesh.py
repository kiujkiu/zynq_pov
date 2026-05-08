"""GLB → quadric-decimated mesh + per-vertex colors.

策略 (使用 fast_simplification 业界标准 quadric decimation):
1. 复用 glb_to_points.load_glb 拿原始 triangles + texture
2. 构 全 mesh: 顶点 dedup, 顶点 area-weighted 累加 baseColor (texture 重心 sample)
3. fast_simplification.simplify 做 quadric 简化到目标三角数
4. 简化后的新顶点对原始顶点做 KDTree 最近邻, 转移颜色
5. 后处理 gamma/brighten/saturation, 输出 (verts, faces)
"""
import math
import numpy as np

from glb_to_points import load_glb


def build_simplified_mesh(glb_path, target_tris=4096, target_scale=40, z_stretch=1.0,
                          brighten=1.0, gamma=1.0, saturation=1.0, verbose=True):
    """Return (vertices, faces).

    vertices: list of (x, y, z, r, g, b) float coords + u8 colors.
    faces: list of (i0, i1, i2) indices.
    """
    triangles = load_glb(glb_path, verbose=verbose)
    n_orig = len(triangles)
    if verbose:
        print(f"[mesh] {n_orig} original triangles")

    # 1) Compute AABB & normalization
    all_pts = np.array([p for t in triangles for p in t[:3]], dtype=np.float32)
    cmin, cmax = all_pts.min(axis=0), all_pts.max(axis=0)
    center = (cmin + cmax) / 2
    span = (cmax - cmin).max()
    if span <= 0:
        return [], []
    scale = (2 * target_scale) / span

    # 2) Build full mesh with vertex dedup + per-vertex color baking.
    # Dominant-tri color: 每顶点保留接触它的"最大 area" tri 的 uv-sample 颜色,
    # 而不是 area-weighted 平均. 防 area-weighted 把鲜艳颜色和邻居白色稀释.
    DEDUP_QUANT = 0.05
    vert_map = {}
    verts_pos = []      # (x, y, z) float
    verts_col = []      # [r, g, b, max_area_seen]
    faces_idx = []
    print_every = max(1, n_orig // 20)
    for i, (p0, p1, p2, color_info) in enumerate(triangles):
        if verbose and i % print_every == 0:
            print(f"  build {i}/{n_orig}...")
        e1 = (p1 - p0).astype(np.float32)
        e2 = (p2 - p0).astype(np.float32)
        area = 0.5 * float(np.linalg.norm(np.cross(e1, e2)))
        if area <= 0:
            continue
        # Per-vertex uv sample (not centroid), area-weighted: 让顶点颜色更贴近
        # 该顶点真实纹理 sample, 而不是邻居 tri 平均色.
        if color_info[0] == "tex":
            _, tex, uv0, uv1, uv2 = color_info
            uvs_per_vert = (uv0, uv1, uv2)
            cols_per_vert = []
            for uv in uvs_per_vert:
                tx = int((uv[0] % 1.0) * tex.shape[1]) % tex.shape[1]
                ty = int((1.0 - (uv[1] % 1.0)) * tex.shape[0]) % tex.shape[0]
                px = tex[ty, tx]
                cols_per_vert.append((float(px[0]), float(px[1]), float(px[2])))
        else:
            c_solid = (float(color_info[1][0]),
                       float(color_info[1][1]),
                       float(color_info[1][2]))
            cols_per_vert = (c_solid, c_solid, c_solid)

        tri_idx = []
        for k_v, p_raw in enumerate((p0, p1, p2)):
            n = (p_raw - center) * scale
            n = n.astype(np.float32)
            n[2] *= z_stretch
            qkey = (int(round(n[0] / DEDUP_QUANT)),
                    int(round(n[1] / DEDUP_QUANT)),
                    int(round(n[2] / DEDUP_QUANT)))
            v_idx = vert_map.get(qkey)
            if v_idx is None:
                v_idx = len(verts_pos)
                vert_map[qkey] = v_idx
                verts_pos.append([float(n[0]), float(n[1]), float(n[2])])
                verts_col.append([0.0, 0.0, 0.0, 0.0])
            cr, cg, cb = cols_per_vert[k_v]
            # Saturation-weighted dominant: weight = area * (1 + 5*sat), 让
            # 鲜艳/中性两端 (黑帽 / 白领 / 蓝披风) 都能 win 邻居. 没有这个
            # 加权时, 大 tri 总赢, 小 detail 区域 (帽/领) 颜色被衣服稀释.
            mx = max(cr, cg, cb); mn = min(cr, cg, cb)
            sat = (mx - mn) / 255.0 if mx > 0 else 0.0
            # 极暗 (帽子) 或极亮 (领) 也 boost: deviation from mid-gray
            mid_dev = abs((mx + mn) / 510.0 - 0.5) * 2.0
            weight = area * (1.0 + 5.0 * sat + 2.0 * mid_dev)
            if weight > verts_col[v_idx][3]:
                verts_col[v_idx][0] = cr
                verts_col[v_idx][1] = cg
                verts_col[v_idx][2] = cb
                verts_col[v_idx][3] = weight
            tri_idx.append(v_idx)
        if tri_idx[0] == tri_idx[1] or tri_idx[1] == tri_idx[2] or tri_idx[0] == tri_idx[2]:
            continue
        faces_idx.append(tuple(tri_idx))

    if verbose:
        print(f"[mesh] post-build: {len(verts_pos)} verts, {len(faces_idx)} faces")

    # 3) Quadric decimation
    import fast_simplification
    verts_arr = np.array(verts_pos, dtype=np.float32)
    faces_arr = np.array(faces_idx, dtype=np.uint32)
    if len(faces_idx) > target_tris:
        target_reduction = 1.0 - float(target_tris) / len(faces_idx)
        if verbose:
            print(f"[mesh] decimating: target_reduction={target_reduction:.4f} "
                  f"({len(faces_idx)} → {target_tris})")
        new_verts, new_faces = fast_simplification.simplify(
            verts_arr, faces_arr, target_reduction=target_reduction)
    else:
        new_verts, new_faces = verts_arr, faces_arr
    if verbose:
        print(f"[mesh] post-decimate: {len(new_verts)} verts, {len(new_faces)} faces")

    # 4) Color transfer: nearest-old-vertex KDTree
    from scipy.spatial import cKDTree
    tree = cKDTree(verts_arr)
    _, nn_idx = tree.query(new_verts, k=1)

    # 5) Output verts with post-process
    out_verts = []
    import colorsys
    for i, (vx, vy, vz) in enumerate(new_verts):
        old_i = int(nn_idx[i])
        rs, gs, bs, ws = verts_col[old_i]
        if ws <= 0:
            r = g = b = 0
        else:
            # Dominant baking: rs/gs/bs 已是颜色不是 sum, ws 只标记是否有 tri 接触
            r = int(rs); g = int(gs); b = int(bs)
        if gamma != 1.0 and gamma > 0:
            r = int(255 * pow(max(0, r) / 255.0, gamma))
            g = int(255 * pow(max(0, g) / 255.0, gamma))
            b = int(255 * pow(max(0, b) / 255.0, gamma))
        if brighten != 1.0:
            mx = max(r, g, b)
            if mx > 0:
                tgt = min(255, int(mx * brighten))
                k = tgt / mx
                r = int(r * k); g = int(g * k); b = int(b * k)
        if saturation != 1.0:
            h, s, v_ = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            s = min(1.0, s * saturation)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v_)
            r, g, b = int(r2*255), int(g2*255), int(b2*255)
        r = max(0, min(255, r)); g = max(0, min(255, g)); b = max(0, min(255, b))
        out_verts.append((float(vx), float(vy), float(vz), r, g, b))

    out_faces = [tuple(int(x) for x in f) for f in new_faces]
    return out_verts, out_faces


def build_simplified_mesh_per_tri(glb_path, target_tris=6000, target_scale=40,
                                   z_stretch=1.0, brighten=1.0, gamma=1.0,
                                   saturation=1.6, verbose=True):
    """v2: 每 tri 自己一个 RGB (per-tri flat shading), 不走顶点色 baking.

    Return:
        verts_xyz: list of (x, y, z) float
        tris_with_color: list of (i0, i1, i2, r, g, b)

    每 tri 的颜色 = 简化后该 tri 的 centroid 落在原 mesh 哪个 tri 内 (KDTree
    最近邻 centroid), 取该原 tri centroid uv-sample texture color. 这样
    高对比 detail (黑帽/白领) 不被顶点 baking 邻居稀释.
    """
    import colorsys
    import fast_simplification
    from scipy.spatial import cKDTree

    triangles = load_glb(glb_path, verbose=verbose)
    n_orig = len(triangles)
    if verbose:
        print(f"[mesh-v2] {n_orig} original triangles")

    all_pts = np.array([p for t in triangles for p in t[:3]], dtype=np.float32)
    cmin, cmax = all_pts.min(axis=0), all_pts.max(axis=0)
    center = (cmin + cmax) / 2
    span = (cmax - cmin).max()
    if span <= 0:
        return [], []
    scale = (2 * target_scale) / span

    # 1) 全 mesh: 顶点 dedup + per-tri centroid color (no per-vertex baking)
    DEDUP_QUANT = 0.05
    vert_map = {}
    verts_pos = []          # (x, y, z) 归一化坐标
    faces_idx = []          # (i0, i1, i2)
    orig_tri_centroids = [] # 用于后续 KDTree (归一化坐标)
    orig_tri_colors = []    # (r, g, b) per original tri
    print_every = max(1, n_orig // 20)
    for i, (p0, p1, p2, color_info) in enumerate(triangles):
        if verbose and i % print_every == 0:
            print(f"  build {i}/{n_orig}...")
        e1 = (p1 - p0).astype(np.float32)
        e2 = (p2 - p0).astype(np.float32)
        area = 0.5 * float(np.linalg.norm(np.cross(e1, e2)))
        if area <= 0:
            continue

        if color_info[0] == "tex":
            _, tex, uv0, uv1, uv2 = color_info
            uv = (uv0 + uv1 + uv2) / 3.0
            tx = int((uv[0] % 1.0) * tex.shape[1]) % tex.shape[1]
            ty = int((1.0 - (uv[1] % 1.0)) * tex.shape[0]) % tex.shape[0]
            px = tex[ty, tx]
            cr, cg, cb = float(px[0]), float(px[1]), float(px[2])
        else:
            cr, cg, cb = (float(color_info[1][0]),
                          float(color_info[1][1]),
                          float(color_info[1][2]))

        tri_idx = []
        norm_pts = []
        for p_raw in (p0, p1, p2):
            n = (p_raw - center) * scale
            n = n.astype(np.float32)
            n[2] *= z_stretch
            qkey = (int(round(n[0] / DEDUP_QUANT)),
                    int(round(n[1] / DEDUP_QUANT)),
                    int(round(n[2] / DEDUP_QUANT)))
            v_idx = vert_map.get(qkey)
            if v_idx is None:
                v_idx = len(verts_pos)
                vert_map[qkey] = v_idx
                verts_pos.append([float(n[0]), float(n[1]), float(n[2])])
            tri_idx.append(v_idx)
            norm_pts.append(n)
        if tri_idx[0] == tri_idx[1] or tri_idx[1] == tri_idx[2] or tri_idx[0] == tri_idx[2]:
            continue
        faces_idx.append(tuple(tri_idx))
        centroid = (norm_pts[0] + norm_pts[1] + norm_pts[2]) / 3.0
        orig_tri_centroids.append([float(centroid[0]), float(centroid[1]), float(centroid[2])])
        orig_tri_colors.append((cr, cg, cb))

    if verbose:
        print(f"[mesh-v2] post-build: {len(verts_pos)} verts, {len(faces_idx)} faces")

    # 2) Quadric decimation
    verts_arr = np.array(verts_pos, dtype=np.float32)
    faces_arr = np.array(faces_idx, dtype=np.uint32)
    if len(faces_idx) > target_tris:
        target_reduction = 1.0 - float(target_tris) / len(faces_idx)
        if verbose:
            print(f"[mesh-v2] decimating: target_reduction={target_reduction:.4f} "
                  f"({len(faces_idx)} → {target_tris})")
        new_verts, new_faces = fast_simplification.simplify(
            verts_arr, faces_arr, target_reduction=target_reduction)
    else:
        new_verts, new_faces = verts_arr, faces_arr
    if verbose:
        print(f"[mesh-v2] post-decimate: {len(new_verts)} verts, {len(new_faces)} faces")

    # 3) Per-tri color transfer: 新 tri centroid → 最近原 tri centroid 颜色
    orig_centroids_arr = np.array(orig_tri_centroids, dtype=np.float32)
    tree = cKDTree(orig_centroids_arr)
    new_tri_centroids = np.zeros((len(new_faces), 3), dtype=np.float32)
    for i, f in enumerate(new_faces):
        v0 = new_verts[f[0]]; v1 = new_verts[f[1]]; v2 = new_verts[f[2]]
        new_tri_centroids[i] = (v0 + v1 + v2) / 3.0
    _, nn_idx = tree.query(new_tri_centroids, k=1)

    # 4) Output: 顶点只 xyz, tri 自带 RGB (post-process gamma/brighten/sat)
    out_verts = [tuple(float(c) for c in v) for v in new_verts]
    out_tris = []
    for i, f in enumerate(new_faces):
        cr, cg, cb = orig_tri_colors[int(nn_idx[i])]
        r = int(cr); g = int(cg); b = int(cb)
        if gamma != 1.0 and gamma > 0:
            r = int(255 * pow(max(0, r) / 255.0, gamma))
            g = int(255 * pow(max(0, g) / 255.0, gamma))
            b = int(255 * pow(max(0, b) / 255.0, gamma))
        if brighten != 1.0:
            mx = max(r, g, b)
            if mx > 0:
                tgt = min(255, int(mx * brighten))
                k = tgt / mx
                r = int(r * k); g = int(g * k); b = int(b * k)
        if saturation != 1.0:
            h, s, v_ = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            s = min(1.0, s * saturation)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v_)
            r, g, b = int(r2*255), int(g2*255), int(b2*255)
        r = max(0, min(255, r)); g = max(0, min(255, g)); b = max(0, min(255, b))
        out_tris.append((int(f[0]), int(f[1]), int(f[2]), r, g, b))
    return out_verts, out_tris


if __name__ == "__main__":
    import sys
    glb = sys.argv[1] if len(sys.argv) > 1 else "anime_62459.glb"
    nt = int(sys.argv[2]) if len(sys.argv) > 2 else 4096
    verts, faces = build_simplified_mesh(glb, target_tris=nt, target_scale=40,
                                          z_stretch=1.0, brighten=1.5, gamma=0.85,
                                          saturation=1.5)
    print(f"verts={len(verts)} tris={len(faces)}")
    print(f"sample v0={verts[0]}")
