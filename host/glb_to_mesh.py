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
                                   saturation=1.6, lighting=True, ambient=0.55,
                                   verbose=True):
    """v2: 每 tri 自己一个 RGB (per-tri flat shading), 不走顶点色 baking.

    lighting=True 启用 Simplified PBR + Multi-dir IBL (对应 voxel path Option B):
      4 lights: key(暖) / fill(冷) / sky(冷顶) / ground(暖底), per-channel
      different IBL color → tri color = baseColor * (li_r, li_g, li_b).
      anime baseColor 47% 平均亮度自带提亮 + 立体阴影感, 接近 3D viewer.

    Return:
        verts_xyz: list of (x, y, z) float
        tris_with_color: list of (i0, i1, i2, r, g, b)
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
            # Sample 多点 (barycentric grid) 取 median: 提取该 tri 的"主色",
            # 避免 1px centroid 抓到 texture 高频细节 (头发亮丝 / 暗影 / 高光).
            BARY = ((1/3, 1/3, 1/3),
                    (0.5, 0.25, 0.25), (0.25, 0.5, 0.25), (0.25, 0.25, 0.5),
                    (0.6, 0.2, 0.2),   (0.2, 0.6, 0.2),   (0.2, 0.2, 0.6))
            samples = []
            tex_h, tex_w = tex.shape[0], tex.shape[1]
            for (w0, w1, w2) in BARY:
                uv = w0 * uv0 + w1 * uv1 + w2 * uv2
                tx = int((uv[0] % 1.0) * tex_w) % tex_w
                ty = int((1.0 - (uv[1] % 1.0)) * tex_h) % tex_h
                px = tex[ty, tx]
                samples.append((float(px[0]), float(px[1]), float(px[2])))
            samples_np = np.array(samples, dtype=np.float32)
            med = np.median(samples_np, axis=0)
            cr, cg, cb = float(med[0]), float(med[1]), float(med[2])
        else:
            cr, cg, cb = (float(color_info[1][0]),
                          float(color_info[1][1]),
                          float(color_info[1][2]))

        # Lighting: face normal (cross edges, world space — 用原始未归一化 p0/p1/p2)
        if lighting:
            ed1 = (p1 - p0).astype(np.float32)
            ed2 = (p2 - p0).astype(np.float32)
            n_face = np.cross(ed1, ed2)
            n_len = float(np.linalg.norm(n_face))
            if n_len > 0:
                n_face = n_face / n_len
            else:
                n_face = np.array([0, 1, 0], dtype=np.float32)
            # 4 IBL lights (世界坐标, GLB y-up). 每 light 强度 < 0.5 让总和
            # 范围在 [ambient, ambient + ~1.0] 即 [0.7, 1.7], 不极端.
            li_r = ambient; li_g = ambient; li_b = ambient
            lights = (
                ((0.5, 0.7, 0.5), (0.45, 0.40, 0.32)),    # key 暖
                ((-0.6, 0.4, 0.3), (0.20, 0.25, 0.35)),   # fill 冷
                ((0.0, 1.0, 0.0), (0.22, 0.28, 0.38)),    # sky
                ((0.0, -1.0, 0.0), (0.20, 0.16, 0.12)),   # ground
            )
            for (ld, lc) in lights:
                ldn = np.array(ld, dtype=np.float32)
                ldn = ldn / float(np.linalg.norm(ldn))
                # 双面 lighting: anime mesh winding 不一致, abs(dot) 防止内向
                # normal 的 face 黑化看起来像"缺块". 失少量背面阴影立体感,
                # 但保人物完整.
                intensity = abs(float(np.dot(n_face, ldn)))
                li_r += intensity * lc[0]
                li_g += intensity * lc[1]
                li_b += intensity * lc[2]
            # baseColor anime 平均 47%, 乘 li (~0.7-1.7) 后 ~33%-80%, 加 brighten
            # 在后处理阶段拉到 normal 亮度. 这里 lighting 主要给立体感.
            cr = cr * li_r
            cg = cg * li_g
            cb = cb * li_b

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

    # 3) Per-tri color transfer: 新 tri centroid → 最近 K 个原 tri 颜色 median.
    # 单 NN centroid sample 在 anime 高频 texture (头发丝 / 铠甲花纹) 下丢大色块,
    # top-K median 取邻居 dominant 色, 保留"金发/蓝衣/白甲"等大区域的本色.
    orig_centroids_arr = np.array(orig_tri_centroids, dtype=np.float32)
    orig_colors_arr = np.array(orig_tri_colors, dtype=np.float32)  # (N, 3)
    tree = cKDTree(orig_centroids_arr)
    new_tri_centroids = np.zeros((len(new_faces), 3), dtype=np.float32)
    for i, f in enumerate(new_faces):
        v0 = new_verts[f[0]]; v1 = new_verts[f[1]]; v2 = new_verts[f[2]]
        new_tri_centroids[i] = (v0 + v1 + v2) / 3.0
    K = 32   # 每 simplified tri 平均覆盖 ~80 原 tri, K=32 足够代表
    _, nn_idx_K = tree.query(new_tri_centroids, k=min(K, len(orig_centroids_arr)))
    # nn_idx_K shape: (n_new, K). 取每行 median 颜色.
    nn_colors = orig_colors_arr[nn_idx_K]   # (n_new, K, 3)
    median_colors = np.median(nn_colors, axis=1)   # (n_new, 3)
    # 兼容下方 orig_tri_colors[int(nn_idx[i])] 接口: 把 median_colors 当 lookup table
    nn_idx = np.arange(len(new_faces))     # 直接 i 索引 median_colors
    orig_tri_colors_for_output = median_colors

    # 4) Output: 顶点只 xyz, tri 自带 RGB (post-process gamma/brighten/sat)
    out_verts = [tuple(float(c) for c in v) for v in new_verts]
    out_tris = []
    for i, f in enumerate(new_faces):
        cr, cg, cb = orig_tri_colors_for_output[int(nn_idx[i])]
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


def build_simplified_mesh_textured(glb_path, target_tris=6000, target_scale=40,
                                     z_stretch=1.0, tex_size=256, verbose=True):
    """v3: textured mesh.

    Return:
        verts_xyz_uv: list of (x, y, z, u, v) — float xyz model + float uv 0..1
        tris:         list of (i0, i1, i2)
        tex_rgb:      bytes of tex_size×tex_size×3 (downsampled baseColor)
        tex_w, tex_h
    """
    from PIL import Image
    import fast_simplification
    from scipy.spatial import cKDTree

    triangles = load_glb(glb_path, verbose=verbose)
    n_orig = len(triangles)
    if verbose:
        print(f"[mesh-v3] {n_orig} original triangles")

    # 找 baseColor texture (从首个 textured tri 取). 假设全 mesh 共享一个 tex.
    base_tex = None
    for (_, _, _, color_info) in triangles:
        if color_info[0] == "tex":
            base_tex = color_info[1]
            break
    if base_tex is None:
        raise RuntimeError("v3 textured 需要 GLB 带 baseColor texture")

    all_pts = np.array([p for t in triangles for p in t[:3]], dtype=np.float32)
    cmin, cmax = all_pts.min(axis=0), all_pts.max(axis=0)
    center = (cmin + cmax) / 2
    span = (cmax - cmin).max()
    scale = (2 * target_scale) / span

    # 1) Build mesh + collect per-vertex uv (取该 vertex 首次见到的 uv)
    DEDUP_QUANT = 0.05
    vert_map = {}
    verts_pos = []
    verts_uv = []     # (u, v) per unique vertex
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
        if color_info[0] != "tex":
            continue
        _, _, uv0, uv1, uv2 = color_info
        uvs = (uv0, uv1, uv2)

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
                # 取该顶点首次见到的 uv
                verts_uv.append([float(uvs[k_v][0]), float(uvs[k_v][1])])
            tri_idx.append(v_idx)
        if tri_idx[0] == tri_idx[1] or tri_idx[1] == tri_idx[2] or tri_idx[0] == tri_idx[2]:
            continue
        faces_idx.append(tuple(tri_idx))

    if verbose:
        print(f"[mesh-v3] post-build: {len(verts_pos)} verts, {len(faces_idx)} faces")

    # 2) Quadric decimation
    verts_arr = np.array(verts_pos, dtype=np.float32)
    faces_arr = np.array(faces_idx, dtype=np.uint32)
    if len(faces_idx) > target_tris:
        target_reduction = 1.0 - float(target_tris) / len(faces_idx)
        if verbose:
            print(f"[mesh-v3] decimating: ({len(faces_idx)} → {target_tris})")
        new_verts, new_faces = fast_simplification.simplify(
            verts_arr, faces_arr, target_reduction=target_reduction)
    else:
        new_verts, new_faces = verts_arr, faces_arr
    if verbose:
        print(f"[mesh-v3] post-decimate: {len(new_verts)} verts, {len(new_faces)} faces")

    # 3) UV transfer: 新 vertex KDTree 找最近原 vertex 取 uv.
    orig_uvs_arr = np.array(verts_uv, dtype=np.float32)
    tree = cKDTree(verts_arr)
    _, nn_idx = tree.query(np.array(new_verts), k=1)
    new_uvs = orig_uvs_arr[nn_idx]    # (n_new, 2)

    # 4) Texture downsample 到 tex_size×tex_size
    tex_h_orig, tex_w_orig = base_tex.shape[0], base_tex.shape[1]
    tex_img = Image.fromarray(base_tex[:, :, :3].astype(np.uint8), mode="RGB")
    tex_resized = tex_img.resize((tex_size, tex_size), Image.LANCZOS)
    tex_arr = np.array(tex_resized, dtype=np.uint8)
    if verbose:
        print(f"[mesh-v3] texture {tex_w_orig}×{tex_h_orig} -> {tex_size}×{tex_size}")

    # 5) Output (xyz + uv per vertex, faces idx, texture bytes)
    # GLB UV: v 翻转 (1.0 - v) 让 v=0 在 texture 顶部. host 这里直接传 uv,
    # 板端 sample 时做 v 翻转.
    out_verts = []
    for i, v in enumerate(new_verts):
        u, v_uv = float(new_uvs[i][0]), float(new_uvs[i][1])
        out_verts.append((float(v[0]), float(v[1]), float(v[2]), u, v_uv))
    out_tris = [(int(f[0]), int(f[1]), int(f[2])) for f in new_faces]
    tex_bytes = tex_arr.tobytes()
    return out_verts, out_tris, tex_bytes, tex_size, tex_size


if __name__ == "__main__":
    import sys
    glb = sys.argv[1] if len(sys.argv) > 1 else "anime_62459.glb"
    nt = int(sys.argv[2]) if len(sys.argv) > 2 else 4096
    verts, faces = build_simplified_mesh(glb, target_tris=nt, target_scale=40,
                                          z_stretch=1.0, brighten=1.5, gamma=0.85,
                                          saturation=1.5)
    print(f"verts={len(verts)} tris={len(faces)}")
    print(f"sample v0={verts[0]}")
