"""Mesh → point cloud sampler.

Inputs supported (auto-detected by suffix):
  .obj    — Wavefront OBJ (vertex+face text format, no lib needed)
  None    — if no file given, use built-in "anime figure" placeholder

Samples N points uniformly across triangle surfaces (area-weighted).
Returns a list of (x, y, z, r, g, b) tuples in our int16/uint8 range.
"""
import math
import random
import sys


def load_obj(path):
    """Parse vertices + faces from a text OBJ. Returns (verts, faces).
    verts: list of (x, y, z) floats
    faces: list of (i0, i1, i2) integer triples (0-indexed)
    """
    verts = []
    faces = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if parts[0] == "v" and len(parts) >= 4:
                verts.append((float(parts[1]), float(parts[2]), float(parts[3])))
            elif parts[0] == "f" and len(parts) >= 4:
                # "f 1/1/1 2/2/2 3/3/3" or "f 1 2 3"
                idx = [int(p.split("/")[0]) - 1 for p in parts[1:]]
                # Triangulate fan: v0-v1-v2, v0-v2-v3, ...
                for i in range(1, len(idx) - 1):
                    faces.append((idx[0], idx[i], idx[i + 1]))
    return verts, faces


def _builtin_anime_figure():
    """Very simple 'cat-ear girl' silhouette: body + head + ears.
    Returns (verts, faces, face_colors).
    """
    verts = []
    faces = []
    colors = []

    def box(cx, cy, cz, sx, sy, sz, color):
        """Axis-aligned box, 8 vertices, 12 triangles."""
        base = len(verts)
        for dx in (-1, 1):
            for dy in (-1, 1):
                for dz in (-1, 1):
                    verts.append((cx + dx * sx / 2, cy + dy * sy / 2, cz + dz * sz / 2))
        # 6 faces × 2 triangles = 12
        tris = [
            (0,1,3),(0,3,2),      # -X
            (4,6,7),(4,7,5),      # +X
            (0,4,5),(0,5,1),      # -Y
            (2,3,7),(2,7,6),      # +Y
            (0,2,6),(0,6,4),      # -Z
            (1,5,7),(1,7,3),      # +Z
        ]
        for t in tris:
            faces.append((base + t[0], base + t[1], base + t[2]))
            colors.append(color)

    # Body (pink sweater)
    box(0, -5, 0, 16, 20, 10, (255, 150, 180))
    # Head (skin)
    box(0, 15, 0, 14, 14, 14, (255, 220, 180))
    # Left ear (pink)
    box(-5, 25, 0, 4, 6, 4, (255, 150, 180))
    # Right ear
    box(5, 25, 0, 4, 6, 4, (255, 150, 180))
    # Hair back (dark purple)
    box(0, 18, -6, 14, 14, 4, (80, 40, 120))

    return verts, faces, colors


def _sample_triangles(verts, faces, face_colors, n_total):
    """Area-weighted uniform sampling on triangle surfaces.
    Returns [(x,y,z,r,g,b), ...] with x/y/z as floats in original scale.
    """
    # compute areas
    areas = []
    for (i0, i1, i2) in faces:
        p0 = verts[i0]; p1 = verts[i1]; p2 = verts[i2]
        ax = p1[0] - p0[0]; ay = p1[1] - p0[1]; az = p1[2] - p0[2]
        bx = p2[0] - p0[0]; by = p2[1] - p0[1]; bz = p2[2] - p0[2]
        # cross product magnitude / 2
        cx = ay*bz - az*by
        cy = az*bx - ax*bz
        cz = ax*by - ay*bx
        area = 0.5 * math.sqrt(cx*cx + cy*cy + cz*cz)
        areas.append(area)
    total = sum(areas)
    if total <= 0:
        return []
    # cumulative probabilities
    cum = [0.0]
    for a in areas:
        cum.append(cum[-1] + a / total)

    out = []
    for _ in range(n_total):
        r = random.random()
        # binary search
        lo, hi = 0, len(cum) - 1
        while lo < hi - 1:
            mid = (lo + hi) // 2
            if cum[mid] <= r:
                lo = mid
            else:
                hi = mid
        face_idx = lo
        # pick uniform point in triangle (barycentric)
        u = random.random()
        v = random.random()
        if u + v > 1:
            u = 1 - u; v = 1 - v
        w = 1 - u - v
        p0 = verts[faces[face_idx][0]]
        p1 = verts[faces[face_idx][1]]
        p2 = verts[faces[face_idx][2]]
        x = w*p0[0] + u*p1[0] + v*p2[0]
        y = w*p0[1] + u*p1[1] + v*p2[1]
        z = w*p0[2] + u*p1[2] + v*p2[2]
        r_, g_, b_ = face_colors[face_idx] if face_colors else (255, 255, 255)
        out.append((x, y, z, r_, g_, b_))
    return out


def normalize_and_quantize(points, target_scale=40):
    """Scale points so max dimension fits into int16 range [-target, target],
    and clip r/g/b to uint8. Returns tuples of (int x, int y, int z, int r, int g, int b)."""
    if not points:
        return []
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    zs = [p[2] for p in points]
    cx = (max(xs) + min(xs)) / 2
    cy = (max(ys) + min(ys)) / 2
    cz = (max(zs) + min(zs)) / 2
    span = max(max(xs)-min(xs), max(ys)-min(ys), max(zs)-min(zs))
    if span <= 0:
        span = 1
    scale = (2 * target_scale) / span
    out = []
    for (x, y, z, r, g, b) in points:
        ix = int(round((x - cx) * scale))
        iy = int(round((y - cy) * scale))
        iz = int(round((z - cz) * scale))
        ix = max(-128, min(127, ix))
        iy = max(-128, min(127, iy))
        iz = max(-128, min(127, iz))
        out.append((ix, iy, iz, int(r) & 0xFF, int(g) & 0xFF, int(b) & 0xFF))
    return out


def sample_mesh(path_or_none, n_points=500, target_scale=40):
    """Top-level API: given OBJ path (or None for builtin), return point list."""
    if path_or_none:
        verts, faces = load_obj(path_or_none)
        # OBJ files don't have per-face color; use a default palette by face normal.
        # Simpler: just pick a gradient based on Y.
        if not verts:
            print(f"[mesh] empty file: {path_or_none}", file=sys.stderr)
            return []
        ymin = min(v[1] for v in verts)
        ymax = max(v[1] for v in verts)
        yspan = (ymax - ymin) if ymax > ymin else 1.0
        colors = []
        for (i0, i1, i2) in faces:
            yavg = (verts[i0][1] + verts[i1][1] + verts[i2][1]) / 3
            t = (yavg - ymin) / yspan   # 0..1
            # palette: blue (low) -> white (high)
            r = int(180 + 75 * t); g = int(180 + 75 * t); b = int(255)
            colors.append((r, g, b))
    else:
        verts, faces, colors = _builtin_anime_figure()
    pts = _sample_triangles(verts, faces, colors, n_points)
    return normalize_and_quantize(pts, target_scale)


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else None
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 500
    pts = sample_mesh(path, n)
    print(f"Generated {len(pts)} points from {path or 'builtin anime figure'}")
    for p in pts[:6]:
        print(" ", p)
