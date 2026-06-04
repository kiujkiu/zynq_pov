"""Generate 122 panel slices from glb model for POV-3D rotor display.

Each slice = silhouette projection of the 3D mesh viewed from angle θ around Y axis.
Output:
  - anime_slices.bin: 122 × (128×64×4 byte) = 2.93 MB, RGB pixel as 24-bit packed in 32-bit word
  - anime_slices_preview.png: contact-sheet preview of 8 sample angles (0, 15, ..., 105)

Coord convention:
  Y = vertical (rotation axis)
  X, Z = horizontal plane (panel rotates around Y)
  Panel at angle θ shows projection onto plane facing direction (cos θ, 0, sin θ)

Usage:
  python panel_slice_gen.py [glb_path] [n_slices]
  default: anime_62459_baked.glb, 122 slices
"""
import sys, struct, os, math
from pathlib import Path
import numpy as np
import trimesh
from PIL import Image

PANEL_W = 128
PANEL_H = 64
N_SLICES_DEFAULT = 122

HERE = Path(__file__).resolve().parent
glb_path = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "anime_62459_baked.glb"
n_slices = int(sys.argv[2]) if len(sys.argv) > 2 else N_SLICES_DEFAULT
out_dir = HERE.parent  # zynq_pov root

print(f"loading {glb_path.name}...")
scene = trimesh.load(str(glb_path), force="scene")
mesh = trimesh.util.concatenate([g for g in scene.geometry.values()])
print(f"  vertices {len(mesh.vertices)}  faces {len(mesh.faces)}")

verts = np.asarray(mesh.vertices, dtype=np.float64)  # (N,3)
faces = np.asarray(mesh.faces, dtype=np.int64)       # (M,3)

# Extract per-vertex color (TextureVisuals → sample texture; ColorVisuals → vertex_colors)
vcolor = None
try:
    # Per-geometry processing (concatenate loses texture). Re-extract from scene.
    all_v, all_f, all_c = [], [], []
    v_offset = 0
    for name, geom in scene.geometry.items():
        gv = np.asarray(geom.vertices)
        gf = np.asarray(geom.faces) + v_offset
        # Try texture sample
        gc = None
        if hasattr(geom.visual, "material") and hasattr(geom.visual, "uv") and geom.visual.uv is not None:
            try:
                tex = np.array(geom.visual.material.baseColorTexture)
                uv = np.asarray(geom.visual.uv)
                th, tw = tex.shape[:2]
                u = np.clip((uv[:, 0] * tw).astype(int), 0, tw - 1)
                v = np.clip(((1 - uv[:, 1]) * th).astype(int), 0, th - 1)
                gc = tex[v, u, :3].astype(np.uint8)
                print(f"  [{name}] texture {tex.shape} sampled → {gc.shape}")
            except Exception as e:
                print(f"  [{name}] texture sample failed: {e}")
        if gc is None and hasattr(geom.visual, "vertex_colors") and geom.visual.vertex_colors is not None:
            gc = np.asarray(geom.visual.vertex_colors)[:, :3].astype(np.uint8)
            print(f"  [{name}] vertex_colors {gc.shape}")
        if gc is None:
            gc = np.full((len(gv), 3), 180, dtype=np.uint8)
            print(f"  [{name}] gray fallback {gc.shape}")
        all_v.append(gv)
        all_f.append(gf)
        all_c.append(gc)
        v_offset += len(gv)
    verts_raw = np.vstack(all_v)
    faces_raw = np.vstack(all_f)
    vcolor = np.vstack(all_c)
    print(f"  combined: verts {len(verts_raw)}  faces {len(faces_raw)}  colors {len(vcolor)}")
    # Override the concatenated mesh
    verts = verts_raw.astype(np.float64)
    faces = faces_raw.astype(np.int64)
except Exception as e:
    print(f"per-geometry path failed: {e}, falling back to gray")
    vcolor = np.full((len(verts), 3), 180, dtype=np.uint8)

# Center model + scale to fit panel
center = (verts.max(axis=0) + verts.min(axis=0)) / 2
verts = verts - center
extents = verts.max(axis=0) - verts.min(axis=0)
print(f"  extents (after center) x={extents[0]:.2f} y={extents[1]:.2f} z={extents[2]:.2f}")

# Scale so Y (height) fills 90% of panel H, X/Z fit panel W
scale_y = (PANEL_H * 0.9) / extents[1]
scale_xz = (PANEL_W * 0.9) / max(extents[0], extents[2])
scale = min(scale_y, scale_xz)
verts = verts * scale
print(f"  scale {scale:.3f}")

# Per-face color = avg of vertex colors
fcolor = vcolor[faces].mean(axis=1).astype(np.uint8)  # (M,3)
# Per-face avg Y (for height) and centroid
face_centroid = verts[faces].mean(axis=1)  # (M,3)


def render_slice(theta):
    """Render one panel slice at angle θ (radians) around Y axis.
    Returns (PANEL_H, PANEL_W, 3) uint8 RGB array.
    """
    # Rotate verts around Y by -θ (so camera at +X sees the model 'turned' by θ)
    c, s = math.cos(-theta), math.sin(-theta)
    Ry = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    rv = verts @ Ry.T  # (N,3) rotated
    # Project: camera at +X looking at -X. Image x = -rv[:,2], image y = -rv[:,1], depth = rv[:,0]
    # Image x centered at PANEL_W/2, image y centered at PANEL_H/2
    proj_x = -rv[:, 2] + PANEL_W / 2.0
    proj_y = -rv[:, 1] + PANEL_H / 2.0
    depth = rv[:, 0]  # higher = closer to camera

    img = np.zeros((PANEL_H, PANEL_W, 3), dtype=np.uint8)
    zbuf = np.full((PANEL_H, PANEL_W), -1e9, dtype=np.float64)

    # For each face, draw bounding box pixels (cheap approximation; full triangle raster would be slower)
    fv = faces  # (M,3) vertex indices
    fx = proj_x[fv]  # (M,3)
    fy = proj_y[fv]
    fd = depth[fv].mean(axis=1)  # (M,) face avg depth

    # Bounding box per face
    x_min = np.maximum(0, np.floor(fx.min(axis=1)).astype(int))
    x_max = np.minimum(PANEL_W - 1, np.ceil(fx.max(axis=1)).astype(int))
    y_min = np.maximum(0, np.floor(fy.min(axis=1)).astype(int))
    y_max = np.minimum(PANEL_H - 1, np.ceil(fy.max(axis=1)).astype(int))

    # Sort by depth (back-to-front painter)
    order = np.argsort(fd)
    for i in order:
        if x_max[i] < 0 or y_max[i] < 0 or x_min[i] >= PANEL_W or y_min[i] >= PANEL_H:
            continue
        x0, x1 = x_min[i], x_max[i]
        y0, y1 = y_min[i], y_max[i]
        d = fd[i]
        mask = zbuf[y0:y1+1, x0:x1+1] < d
        zbuf[y0:y1+1, x0:x1+1] = np.where(mask, d, zbuf[y0:y1+1, x0:x1+1])
        for c in range(3):
            img[y0:y1+1, x0:x1+1, c] = np.where(mask, fcolor[i, c], img[y0:y1+1, x0:x1+1, c])
    return img


# Render all slices
print(f"\nrendering {n_slices} slices...")
slices_packed = bytearray()
preview_frames = []
sample_indices = [int(n_slices * k / 8) for k in range(8)]

for i in range(n_slices):
    theta = 2 * math.pi * i / n_slices
    img = render_slice(theta)
    # Pack as 32-bit word per pixel: R[7:0] | G[15:8] | B[23:16]
    for y in range(PANEL_H):
        for x in range(PANEL_W):
            r, g, b = img[y, x]
            slices_packed += struct.pack("<I", int(r) | (int(g) << 8) | (int(b) << 16))
    if i in sample_indices:
        preview_frames.append((i, Image.fromarray(img)))
    if (i + 1) % 16 == 0 or i == n_slices - 1:
        print(f"  slice {i+1}/{n_slices}  bin so far {len(slices_packed)/1024:.0f} KB")

# Save binary
bin_path = out_dir / "anime_slices.bin"
with open(bin_path, "wb") as f:
    f.write(slices_packed)
print(f"\nwrote {bin_path}  {len(slices_packed)/1024:.0f} KB")

# Build preview contact sheet (2 rows × 4 cols, each cell PANEL_W × PANEL_H)
sheet_w = PANEL_W * 4
sheet_h = PANEL_H * 2
sheet = Image.new("RGB", (sheet_w, sheet_h), (32, 32, 32))
for j, (i, im) in enumerate(preview_frames):
    cx = (j % 4) * PANEL_W
    cy = (j // 4) * PANEL_H
    sheet.paste(im, (cx, cy))
preview_path = out_dir / "anime_slices_preview.png"
sheet.save(preview_path)
print(f"wrote {preview_path}  ({sheet_w}×{sheet_h}, sampling angles {sample_indices})")
