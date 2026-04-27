"""Voxelize a point cloud into a 3D grid, then sparse-encode for transmission.

For an LED-panel POV display:
  - World axis Y is vertical (rotation axis)
  - At each rotation θ, render a thin radial slab through the volume
  - Slab geometry (in world coords): x*cos(θ) + z*sin(θ) ∈ [-half, half]
    (so for any rotation, we sample voxels along a rotated x-axis line)

Voxel grid resolution choices:
  64³ →   262 144 cells × 4 B = 1 MB dense
  96³ →   884 736           = 3.4 MB
  128³ → 2 097 152          = 8 MB

Sparse encoding: only emit non-empty cells.
  Each entry: (idx21, rgb16) packed in 5 bytes (idx21 = z*RES²+y*RES+x, rgb16 = RGB565)
  For 5000 points → ~3000 unique 64³ voxels → ~15 KB on wire.
  (Comparable to point-cloud 5B compressed: 25 KB)

Public API:
    voxel_grid = voxelize(points, res=64, world_extent=128)
    sparse_buf = encode_sparse(voxel_grid)
    slice_img  = render_slice(voxel_grid, theta_deg, slab_half=2,
                              panel_w=106, panel_h=120)
"""
import numpy as np


# ---------------------------------------------------------------------- #
# Voxelization                                                           #
# ---------------------------------------------------------------------- #

def voxelize(points, res=64, world_extent=128):
    """Build a 3D voxel grid from quantized points.

    points: list of (x, y, z, r, g, b) in int8 ranges (typical x,y,z in
            [-127, 127] from glb_to_points.normalize_and_quantize).
    res:    voxel grid edge length.
    world_extent: world-coord range mapped onto [0, res). Default 128 covers
                  ±64 ≈ the typical normalized model extent.

    Returns:
      grid : numpy uint16 array (res, res, res) of RGB565 (0 = empty).
             Indexed grid[z, y, x]. Multiple points landing in same cell
             are averaged (color sum / count → quantized to 565).
    """
    if not points:
        return np.zeros((res, res, res), dtype=np.uint16)

    arr = np.array(points, dtype=np.int32)  # (N, 6)
    xs = arr[:, 0]; ys = arr[:, 1]; zs = arr[:, 2]
    rs = arr[:, 3]; gs = arr[:, 4]; bs = arr[:, 5]

    # Map world coord ∈ [-extent/2, extent/2] → voxel index ∈ [0, res)
    half = world_extent // 2
    ix = ((xs.astype(np.float32) + half) * res / world_extent).astype(np.int32)
    iy = ((ys.astype(np.float32) + half) * res / world_extent).astype(np.int32)
    iz = ((zs.astype(np.float32) + half) * res / world_extent).astype(np.int32)

    # Clip to grid
    in_range = (ix >= 0) & (ix < res) & (iy >= 0) & (iy < res) & (iz >= 0) & (iz < res)
    ix = ix[in_range]; iy = iy[in_range]; iz = iz[in_range]
    rs = rs[in_range]; gs = gs[in_range]; bs = bs[in_range]

    # Accumulate: sum colors per cell, count, average at end
    flat_idx = (iz * res + iy) * res + ix     # linear index
    n_cells = res * res * res
    sum_r = np.bincount(flat_idx, weights=rs, minlength=n_cells)
    sum_g = np.bincount(flat_idx, weights=gs, minlength=n_cells)
    sum_b = np.bincount(flat_idx, weights=bs, minlength=n_cells)
    count = np.bincount(flat_idx, minlength=n_cells)

    avg_r = np.zeros(n_cells, dtype=np.uint8)
    avg_g = np.zeros(n_cells, dtype=np.uint8)
    avg_b = np.zeros(n_cells, dtype=np.uint8)
    nz = count > 0
    avg_r[nz] = (sum_r[nz] / count[nz]).astype(np.uint8)
    avg_g[nz] = (sum_g[nz] / count[nz]).astype(np.uint8)
    avg_b[nz] = (sum_b[nz] / count[nz]).astype(np.uint8)

    # Pack to RGB565
    r5 = (avg_r.astype(np.uint16) >> 3) & 0x1F
    g6 = (avg_g.astype(np.uint16) >> 2) & 0x3F
    b5 = (avg_b.astype(np.uint16) >> 3) & 0x1F
    rgb565 = (r5 << 11) | (g6 << 5) | b5
    # Empty cells (count=0) explicitly zero — but if a point HAD black color
    # (0,0,0) → rgb565=0 → indistinguishable from empty. Acceptable artifact.
    rgb565[~nz] = 0

    grid = rgb565.reshape(res, res, res)
    return grid


# ---------------------------------------------------------------------- #
# Sparse encoding for wire                                               #
# ---------------------------------------------------------------------- #

def encode_sparse(grid):
    """Return bytes: u32 magic 'VXSP' + u16 res + u32 n_cells + (idx21+rgb16)*N.

    idx21 packed into 24 bits (3 bytes little-endian) for res ≤ 128 (128³=2M).
    rgb16 = 2 bytes RGB565.
    Per-cell footprint: 5 bytes."""
    res = grid.shape[0]
    nz_mask = grid != 0
    indices = np.where(nz_mask.flatten())[0]
    rgbs = grid.flatten()[indices]

    # Header: magic 'VXSP' + res + n_cells
    import struct
    hdr = struct.pack("<IHI", 0x50535856, res, len(indices))   # 'VXSP'

    # Body: pack each cell into 5 bytes
    body = bytearray(len(indices) * 5)
    for i, (idx, rgb) in enumerate(zip(indices, rgbs)):
        off = i * 5
        body[off]     = idx & 0xFF
        body[off + 1] = (idx >> 8) & 0xFF
        body[off + 2] = (idx >> 16) & 0xFF
        body[off + 3] = rgb & 0xFF
        body[off + 4] = (rgb >> 8) & 0xFF

    return hdr + bytes(body)


def decode_sparse(buf):
    """Inverse of encode_sparse — returns numpy grid."""
    import struct
    magic, res, n = struct.unpack_from("<IHI", buf, 0)
    if magic != 0x50535856:
        raise ValueError(f"bad magic 0x{magic:08x}")
    grid = np.zeros((res, res, res), dtype=np.uint16)
    flat = grid.flatten()
    body_off = 4 + 2 + 4
    for i in range(n):
        off = body_off + i * 5
        idx = buf[off] | (buf[off + 1] << 8) | (buf[off + 2] << 16)
        rgb = buf[off + 3] | (buf[off + 4] << 8)
        flat[idx] = rgb
    return flat.reshape(res, res, res)


# ---------------------------------------------------------------------- #
# Slice rendering (preview)                                              #
# ---------------------------------------------------------------------- #

def render_slice(grid, theta_deg, slab_half=2, panel_w=106, panel_h=120):
    """Render one POV-style slice from the voxel grid.

    Slab geometry: thin radial plane through volume at rotation θ (around Y axis).
    For any voxel with world coords (x, y, z), it belongs to the slice when:
        |x*cos(θ) - z*sin(θ)| ≤ slab_half      (perpendicular distance to slice plane)
    The slice plane spans the rotated x-axis; LED-panel x = x*sin(θ)+z*cos(θ).

    Output: panel_h × panel_w × 3 uint8 image (BGR).
    """
    res = grid.shape[0]
    # Build voxel coordinate arrays
    zz, yy, xx = np.meshgrid(np.arange(res), np.arange(res), np.arange(res),
                              indexing='ij')
    # Center coords [-res/2, res/2)
    cx = xx - res // 2
    cy = yy - res // 2
    cz = zz - res // 2

    th = np.deg2rad(theta_deg)
    co = np.cos(th); sn = np.sin(th)

    # perpendicular distance to slab plane
    # (slab plane: { x*cos+z*sin = 0 }, i.e. world rotated 90° around y axis)
    # Original cpu_render_panel uses: rz = -x*s + z*c, slab if |rz| ≤ half
    rz = -cx * sn + cz * co
    in_slab = np.abs(rz) <= slab_half

    # Panel coords: rx = x*c + z*s (rotated x), y unchanged
    rx = cx * co + cz * sn

    # Map (rx, cy) into panel pixel space
    px = (rx + panel_w / 2).astype(np.int32)
    py = (panel_h / 2 - cy).astype(np.int32)

    # Mask: in slab AND in panel bounds AND voxel non-empty
    mask = (in_slab & (px >= 0) & (px < panel_w) & (py >= 0) & (py < panel_h)
            & (grid != 0))

    img = np.zeros((panel_h, panel_w, 3), dtype=np.uint8)
    sel_z = zz[mask]
    sel_y = yy[mask]
    sel_x = xx[mask]
    sel_px = px[mask]
    sel_py = py[mask]
    sel_rgb = grid[sel_z, sel_y, sel_x]

    # Unpack RGB565 → 888
    r = ((sel_rgb >> 11) & 0x1F).astype(np.uint16)
    g = ((sel_rgb >> 5) & 0x3F).astype(np.uint16)
    b = (sel_rgb & 0x1F).astype(np.uint16)
    r8 = ((r << 3) | (r >> 2)).astype(np.uint8)
    g8 = ((g << 2) | (g >> 4)).astype(np.uint8)
    b8 = ((b << 3) | (b >> 2)).astype(np.uint8)

    img[sel_py, sel_px, 0] = b8
    img[sel_py, sel_px, 1] = g8
    img[sel_py, sel_px, 2] = r8
    return img


# ---------------------------------------------------------------------- #
# CLI / quick test                                                       #
# ---------------------------------------------------------------------- #
if __name__ == "__main__":
    import os, sys
    HERE = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, HERE)
    from glb_to_points import sample_glb

    glb = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "anime_34.glb")
    n_pts = int(sys.argv[2]) if len(sys.argv) > 2 else 5000
    res = int(sys.argv[3]) if len(sys.argv) > 3 else 64

    print(f"sampling {n_pts} points from {os.path.basename(glb)}...")
    np.random.seed(42)
    pts = sample_glb(glb, n_points=n_pts, target_scale=40,
                     color_mode="keep", brighten=1.5, gamma=0.8,
                     lighting="lambert", ambient=0.4,
                     z_stretch=5.0, verbose=False)

    print(f"voxelizing into {res}³ grid...")
    grid = voxelize(pts, res=res, world_extent=128)
    nz = (grid != 0).sum()
    total = res * res * res
    print(f"  occupied cells: {nz} / {total} ({100*nz/total:.2f}% density)")

    buf = encode_sparse(grid)
    print(f"sparse encoded: {len(buf)} bytes  (vs 5B-pt cloud {16 + 5*n_pts} B)")

    # Roundtrip
    g2 = decode_sparse(buf)
    assert np.array_equal(grid, g2), "encode/decode roundtrip mismatch"
    print("  roundtrip OK")

    # Render a few slice samples — write as PNG for visual sanity
    try:
        from PIL import Image
        for ang in (0, 45, 90, 135, 180):
            img = render_slice(grid, ang, slab_half=2)
            out = os.path.join(HERE, f"voxel_slice_{ang:03d}.png")
            Image.fromarray(img[:, :, ::-1]).save(out)  # BGR → RGB
            nz_pix = (img.sum(axis=2) > 0).sum()
            print(f"  angle {ang:3d}°  → {out}  ({nz_pix} non-zero pixels)")
    except ImportError:
        print("  (PIL not available, skipping PNG dump)")
