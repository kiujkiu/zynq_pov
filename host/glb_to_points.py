"""Load a glTF/glb file, sample its triangles, return point cloud.

Minimal implementation:
- Uses pygltflib for parsing.
- Reads all mesh primitives (POSITION + optional COLOR_0 + optional TEXCOORD_0).
- Applies node transformations (local-to-world).
- Samples points uniformly on triangle surfaces (area-weighted).

Does NOT handle skinning animations (static snapshot of the bind pose).
For the real anime idle animation we'd need skin + joints evaluation.
"""
import sys
import math
import struct
import random
import io

import numpy as np
from pygltflib import GLTF2
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


def _get_accessor_data(gltf, accessor_idx):
    """Read typed data from a glTF accessor. Returns numpy array."""
    acc = gltf.accessors[accessor_idx]
    bv = gltf.bufferViews[acc.bufferView]
    # glb embedded binary
    buf = gltf.binary_blob()
    # componentType: 5120=BYTE, 5121=UBYTE, 5122=SHORT, 5123=USHORT,
    #                5125=UINT, 5126=FLOAT
    dtype_map = {
        5120: np.int8, 5121: np.uint8,
        5122: np.int16, 5123: np.uint16,
        5125: np.uint32, 5126: np.float32,
    }
    # type: SCALAR/VEC2/VEC3/VEC4/MAT4
    count_map = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    dtype = dtype_map[acc.componentType]
    ncomp = count_map[acc.type]
    start = (bv.byteOffset or 0) + (acc.byteOffset or 0)
    nbytes = acc.count * ncomp * np.dtype(dtype).itemsize
    arr = np.frombuffer(buf[start:start + nbytes], dtype=dtype)
    return arr.reshape(acc.count, ncomp).copy()


def _node_matrix(node):
    """Return 4x4 local transform as numpy."""
    if node.matrix:
        return np.array(node.matrix, dtype=np.float32).reshape(4, 4).T  # glTF is column-major
    m = np.eye(4, dtype=np.float32)
    if node.translation:
        t = np.eye(4, dtype=np.float32)
        t[0, 3], t[1, 3], t[2, 3] = node.translation
        m = t @ m
    if node.rotation:
        q = node.rotation  # [x,y,z,w]
        x, y, z, w = q
        r = np.array([
            [1-2*(y*y+z*z),   2*(x*y-z*w),    2*(x*z+y*w),    0],
            [2*(x*y+z*w),     1-2*(x*x+z*z),  2*(y*z-x*w),    0],
            [2*(x*z-y*w),     2*(y*z+x*w),    1-2*(x*x+y*y),  0],
            [0,               0,              0,              1],
        ], dtype=np.float32)
        m = r @ m
    if node.scale:
        s = np.diag([*node.scale, 1.0]).astype(np.float32)
        m = s @ m
    return m


def _walk_nodes(gltf, node_idx, parent_mat, out):
    """Recursively accumulate (world_matrix, mesh_idx) pairs."""
    node = gltf.nodes[node_idx]
    world = parent_mat @ _node_matrix(node)
    if node.mesh is not None:
        out.append((world, node.mesh))
    if node.children:
        for c in node.children:
            _walk_nodes(gltf, c, world, out)


def _decode_image(gltf, image_idx):
    """Return Pillow Image decoded from glb's embedded image data."""
    if not HAS_PIL:
        return None
    img_def = gltf.images[image_idx]
    if img_def.bufferView is None:
        return None
    bv = gltf.bufferViews[img_def.bufferView]
    buf = gltf.binary_blob()
    start = bv.byteOffset or 0
    data = buf[start:start + bv.byteLength]
    try:
        im = Image.open(io.BytesIO(data)).convert("RGB")
        return im
    except Exception as e:
        print(f"  image decode failed: {e}")
        return None


def _mat_texture(gltf, mat_idx):
    """Return (Pillow image, texcoord_set_index) or (None, None) for material."""
    if mat_idx is None or mat_idx >= len(gltf.materials):
        return None, None
    mat = gltf.materials[mat_idx]
    pbr = mat.pbrMetallicRoughness
    if not pbr or not pbr.baseColorTexture:
        return None, None
    tex_idx = pbr.baseColorTexture.index
    tex = gltf.textures[tex_idx]
    if tex.source is None:
        return None, None
    im = _decode_image(gltf, tex.source)
    texcoord = pbr.baseColorTexture.texCoord or 0
    return im, texcoord


def load_glb(path, verbose=False):
    """Return list of triangles with texture+UV or flat color.
    Each triangle: (p0, p1, p2, sampler) where sampler is a callable
    sampler(bary_u, bary_v, bary_w) -> (r, g, b)."""
    gltf = GLTF2().load(path)
    if verbose:
        print(f"[glb] {len(gltf.meshes)} meshes, {len(gltf.nodes)} nodes")

    # Gather all instances (mesh_idx + world matrix)
    instances = []
    scene = gltf.scenes[gltf.scene or 0]
    for n in scene.nodes:
        _walk_nodes(gltf, n, np.eye(4, dtype=np.float32), instances)

    triangles = []
    # texture cache
    tex_cache = {}
    for (world, mesh_idx) in instances:
        mesh = gltf.meshes[mesh_idx]
        for prim in mesh.primitives:
            if prim.attributes.POSITION is None or prim.indices is None:
                continue
            positions = _get_accessor_data(gltf, prim.attributes.POSITION).astype(np.float32)
            hom = np.hstack([positions, np.ones((positions.shape[0], 1), dtype=np.float32)])
            world_pos = (world @ hom.T).T[:, :3]
            indices = _get_accessor_data(gltf, prim.indices).flatten()

            # Try texture first
            tex_im = None
            tex_np = None
            uvs = None
            if prim.material not in tex_cache:
                tex_cache[prim.material] = _mat_texture(gltf, prim.material)
            tex_im, texcoord_set = tex_cache[prim.material]
            if tex_im is not None:
                uv_attr_name = f"TEXCOORD_{texcoord_set}"
                uv_attr = getattr(prim.attributes, uv_attr_name, None)
                if uv_attr is not None:
                    uvs = _get_accessor_data(gltf, uv_attr).astype(np.float32)
                    tex_np = np.array(tex_im)  # HxWx3 uint8
                else:
                    tex_im = None

            # Fallback flat color from material.baseColorFactor
            default_color = (255, 180, 200)
            if prim.material is not None and prim.material < len(gltf.materials):
                mat = gltf.materials[prim.material]
                if mat.pbrMetallicRoughness and mat.pbrMetallicRoughness.baseColorFactor:
                    bc = mat.pbrMetallicRoughness.baseColorFactor
                    default_color = (int(bc[0]*255), int(bc[1]*255), int(bc[2]*255))

            # Per-vertex colors override
            vertex_colors = None
            if prim.attributes.COLOR_0 is not None:
                vc = _get_accessor_data(gltf, prim.attributes.COLOR_0).astype(np.float32)
                if vc.max() > 2:
                    vc = vc / 255.0
                vertex_colors = np.clip(vc[:, :3] * 255, 0, 255).astype(np.int32)

            for ti in range(0, len(indices), 3):
                i0, i1, i2 = indices[ti], indices[ti+1], indices[ti+2]
                p0 = world_pos[i0]; p1 = world_pos[i1]; p2 = world_pos[i2]
                if tex_np is not None and uvs is not None:
                    # store UV + texture ref
                    triangles.append((p0, p1, p2, ("tex", tex_np, uvs[i0], uvs[i1], uvs[i2])))
                elif vertex_colors is not None:
                    c = (vertex_colors[i0] + vertex_colors[i1] + vertex_colors[i2]) // 3
                    triangles.append((p0, p1, p2, ("flat", (int(c[0]), int(c[1]), int(c[2])))))
                else:
                    triangles.append((p0, p1, p2, ("flat", default_color)))

    if verbose:
        textured = sum(1 for t in triangles if t[3][0] == "tex")
        print(f"[glb] total {len(triangles)} tris ({textured} textured)")
    return triangles


def sample_triangles(triangles, n_total,
                     lighting="none", ambient=0.35,
                     light_dir=(0.3, 0.7, 0.6)):
    """Area-weighted uniform sampling. Handles textured + flat triangles.

    lighting:
      'none'         — raw albedo (default, keeps prior behavior)
      'lambert'      — intensity = ambient + (1-ambient) * max(0, n·l)
      'half-lambert' — intensity = ambient + (1-ambient) * (0.5 + 0.5*n·l)^2
                       (Valve-style, prevents pure black on grazing faces)
    ambient: floor brightness 0..1 — even back-faces get this fraction.
    light_dir: world-space light direction (will be normalized).
    """
    if not triangles:
        return []
    areas = np.zeros(len(triangles), dtype=np.float32)
    for i, (p0, p1, p2, _c) in enumerate(triangles):
        e1 = p1 - p0; e2 = p2 - p0
        cross = np.cross(e1, e2)
        areas[i] = 0.5 * np.linalg.norm(cross)
    total = areas.sum()
    if total <= 0:
        return []
    probs = areas / total
    cum = np.cumsum(probs)

    face_r = np.random.random(n_total)
    face_idx = np.searchsorted(cum, face_r)
    u = np.random.random(n_total)
    v = np.random.random(n_total)
    mask = u + v > 1
    u = np.where(mask, 1 - u, u)
    v = np.where(mask, 1 - v, v)
    w = 1 - u - v

    # Face normals for shading. n_dot_l is precomputed per-face since we sample
    # flat-shaded points (per-vertex normals would smooth this out, but POV
    # display is too low-res to notice and area-weighted samples don't carry
    # vertex normal interpolation — this is good enough as a "pre-bake").
    normals = np.zeros((len(triangles), 3), dtype=np.float32)
    for i, (p0, p1, p2, _c) in enumerate(triangles):
        e1 = p1 - p0; e2 = p2 - p0
        n = np.cross(e1, e2)
        nl = np.linalg.norm(n)
        if nl > 0:
            normals[i] = n / nl

    light = np.array(light_dir, dtype=np.float32)
    lnorm = np.linalg.norm(light)
    if lnorm > 0:
        light = light / lnorm
    ndl_face = np.clip(normals @ light, -1.0, 1.0)  # per-face cosine

    if lighting == "lambert":
        intensity_face = ambient + (1.0 - ambient) * np.maximum(ndl_face, 0.0)
    elif lighting == "half-lambert":
        hl = (0.5 + 0.5 * ndl_face) ** 2
        intensity_face = ambient + (1.0 - ambient) * hl
    elif lighting == "studio":
        # 3-light studio setup with HDR-style overexposure for dim PBR albedos.
        # Front-facing surfaces get intensity > 2.0, back faces stay at ambient,
        # gives clear color contrast. RGB > 255 clamp in quantize.
        key_dir  = np.array([ 0.3,  0.7,  0.6], dtype=np.float32)
        fill_dir = np.array([-0.5,  0.3,  0.4], dtype=np.float32)
        rim_dir  = np.array([ 0.0,  1.0,  0.0], dtype=np.float32)
        for d in (key_dir, fill_dir, rim_dir):
            d /= np.linalg.norm(d)
        # half-Lambert for back faces (avoid total black), boosted weights
        hl_k = (0.5 + 0.5 * (normals @ key_dir))  ** 2
        hl_f = (0.5 + 0.5 * (normals @ fill_dir)) ** 2
        hl_r = np.maximum(normals @ rim_dir, 0.0)
        intensity_face = ambient + 2.5 * hl_k + 1.0 * hl_f + 0.4 * hl_r
    else:  # 'none'
        intensity_face = np.ones(len(triangles), dtype=np.float32)

    out = []
    for k in range(n_total):
        ti = int(face_idx[k])
        p0, p1, p2, color_info = triangles[ti]
        bw = float(w[k]); bu = float(u[k]); bv = float(v[k])
        p = bw * p0 + bu * p1 + bv * p2
        if color_info[0] == "tex":
            _, tex, uv0, uv1, uv2 = color_info
            uv = bw * uv0 + bu * uv1 + bv * uv2
            tx = int((uv[0] % 1.0) * tex.shape[1]) % tex.shape[1]
            ty = int((1.0 - (uv[1] % 1.0)) * tex.shape[0]) % tex.shape[0]
            px = tex[ty, tx]
            r_, g_, b_ = int(px[0]), int(px[1]), int(px[2])
        else:
            _, c = color_info
            r_, g_, b_ = c
        intens = float(intensity_face[ti])
        if intens != 1.0:
            r_ = max(0, min(255, int(r_ * intens)))
            g_ = max(0, min(255, int(g_ * intens)))
            b_ = max(0, min(255, int(b_ * intens)))
        out.append((float(p[0]), float(p[1]), float(p[2]), r_, g_, b_))
    return out


def normalize_and_quantize(points, target_scale=40, color_mode="height", brighten=1.0, gamma=1.0,
                            z_stretch=1.0, crop_top_frac=0.0):
    """color_mode:
      'height'  : Y-axis gradient (default, anime palette)
      'uniform' : all points pink  — avoids weird segmentation
      'random'  : random palette (more visual life)
      'keep'    : don't touch colors (from glb texture/material)
    brighten: multiplier for rgb values, clipped to 255 (1.0=no change, 2.0=double).
    z_stretch: multiply quantized z by this factor (clamped to [-127,127]) so
      thin anime models don't look squished at 90°/270° rotation.
    crop_top_frac: 0.0 = no crop (whole model). 0.25 = keep top 25% of Y range
      (head only for upright character). After crop, points are re-normalized
      so the cropped region fills the ±target_scale voxel space → voxel
      resolution effectively concentrated on visible region.
    """
    if not points:
        return []
    arr = np.array([[p[0], p[1], p[2]] for p in points], dtype=np.float32)

    # Optional Y-crop: keep only top fraction of Y range (head for upright models).
    if crop_top_frac > 0.0:
        y_min, y_max = arr[:, 1].min(), arr[:, 1].max()
        y_threshold = y_max - (y_max - y_min) * crop_top_frac
        keep_mask = arr[:, 1] >= y_threshold
        arr = arr[keep_mask]
        points = [points[i] for i, k in enumerate(keep_mask) if k]
        if not points:
            return []

    cmin = arr.min(axis=0)
    cmax = arr.max(axis=0)
    center = (cmin + cmax) / 2
    span = (cmax - cmin).max()
    if span <= 0:
        span = 1.0
    scale = (2 * target_scale) / span
    ymin, ymax = cmin[1], cmax[1]
    yspan = max(ymax - ymin, 1e-6)

    # random palette for 'random' mode
    import random as _rnd
    RAND_PAL = [
        (255, 100, 100), (255, 200, 100), (255, 255, 100),
        (100, 255, 100), (100, 255, 255), (100, 150, 255),
        (200, 100, 255), (255, 100, 200),
    ]

    def height_palette(t):
        if t < 0.25:      return (100, 140, 220)
        if t < 0.55:      return (240, 150, 180)
        if t < 0.75:      return (255, 220, 180)
        return (90, 60, 130)

    out = []
    for (x, y, z, r, g, b) in points:
        ix = int(round((x - center[0]) * scale))
        iy = int(round((y - center[1]) * scale))
        iz = int(round((z - center[2]) * scale * z_stretch))
        ix = max(-127, min(127, ix))
        iy = max(-127, min(127, iy))
        iz = max(-127, min(127, iz))
        if color_mode == "height":
            t = (y - ymin) / yspan
            r, g, b = height_palette(t)
        elif color_mode == "uniform":
            r, g, b = 240, 160, 200   # soft pink
        elif color_mode == "random":
            r, g, b = _rnd.choice(RAND_PAL)
        # else 'keep': use whatever came from glb material
        if gamma != 1.0 and gamma > 0:
            r = int(255 * pow(r / 255.0, gamma))
            g = int(255 * pow(g / 255.0, gamma))
            b = int(255 * pow(b / 255.0, gamma))
        if brighten != 1.0:
            # Hue-preserving boost: scale so MAX channel (after boost) caps
            # at 255 but keep ratio between channels.
            mx = max(r, g, b)
            if mx > 0:
                target = min(255, int(mx * brighten))
                ratio = target / mx
                r = min(255, int(r * ratio))
                g = min(255, int(g * ratio))
                b = min(255, int(b * ratio))
        out.append((ix, iy, iz, int(r) & 0xFF, int(g) & 0xFF, int(b) & 0xFF))
    return out


def sample_glb(path, n_points=500, target_scale=40, verbose=True,
               color_mode="height", brighten=1.0, gamma=1.0,
               lighting="none", ambient=0.35,
               light_dir=(0.3, 0.7, 0.6),
               z_stretch=1.0, crop_top_frac=0.0):
    triangles = load_glb(path, verbose=verbose)
    points = sample_triangles(triangles, n_points,
                              lighting=lighting, ambient=ambient,
                              light_dir=light_dir)
    return normalize_and_quantize(points, target_scale, color_mode=color_mode,
                                  brighten=brighten, gamma=gamma,
                                  z_stretch=z_stretch,
                                  crop_top_frac=crop_top_frac)


if __name__ == "__main__":
    path = sys.argv[1]
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 500
    pts = sample_glb(path, n_points=n)
    print(f"Sampled {len(pts)} points")
    for p in pts[:8]:
        print(" ", p)
