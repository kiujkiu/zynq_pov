"""Voxel grid file I/O — save/load pre-baked voxel scenes.

File format (.vxg):
    offset  size  field
    0       4     magic 0x47584F56  ("VOXG", little-endian "VOX" + "G")
    4       2     version (1)
    6       2     resolution (typical 256)
    8       4     n_cells
    12      4     reserved
    16      N*5   cells: idx24 + rgb565

Use cases:
    - Save voxelized scene for instant reload (skip glb sample + lighting)
    - Pre-bake high-detail scenes offline, board loads via SD card
    - Share interesting views as small files (~100 KB / 20K cells)

Usage:
    voxel_io.save("hulk.vxg", cells, res=256)
    cells = voxel_io.load("hulk.vxg")
"""
import struct

MAGIC = 0x47584F56
VERSION = 1


def save(path, cells, res=256):
    """cells: iterable of (idx24, rgb565). idx24 = vz*res² + vy*res + vx."""
    cells = list(cells)
    with open(path, "wb") as f:
        f.write(struct.pack("<IHHII", MAGIC, VERSION, res, len(cells), 0))
        body = bytearray(len(cells) * 5)
        for i, (idx, rgb) in enumerate(cells):
            off = i * 5
            body[off]     = idx & 0xFF
            body[off + 1] = (idx >> 8) & 0xFF
            body[off + 2] = (idx >> 16) & 0xFF
            body[off + 3] = rgb & 0xFF
            body[off + 4] = (rgb >> 8) & 0xFF
        f.write(bytes(body))
    print(f"[vxg] saved {len(cells)} cells, {res}^3 grid → {path}")


def load(path):
    """Returns (cells_list, res)."""
    with open(path, "rb") as f:
        header = f.read(16)
        if len(header) != 16:
            raise ValueError(f"{path}: truncated header")
        magic, version, res, n, _resv = struct.unpack("<IHHII", header)
        if magic != MAGIC:
            raise ValueError(f"{path}: bad magic 0x{magic:08x}, expect 0x{MAGIC:08x}")
        if version != VERSION:
            raise ValueError(f"{path}: version {version}, expect {VERSION}")
        body = f.read(n * 5)
        if len(body) != n * 5:
            raise ValueError(f"{path}: body short {len(body)}/{n*5}")
        cells = []
        for i in range(n):
            off = i * 5
            idx = body[off] | (body[off+1] << 8) | (body[off+2] << 16)
            rgb = body[off+3] | (body[off+4] << 8)
            cells.append((idx, rgb))
        print(f"[vxg] loaded {n} cells, {res}^3 grid from {path}")
        return cells, res


if __name__ == "__main__":
    import sys, os
    HERE = os.path.dirname(os.path.abspath(__file__))
    sys.path.insert(0, HERE)

    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print("Usage:")
        print("  python voxel_io.py bake <glb> <out.vxg> [n_pts=100000] [z=1.5]")
        print("  python voxel_io.py info <file.vxg>")
        sys.exit(0)

    cmd = sys.argv[1]
    if cmd == "bake":
        glb = sys.argv[2]
        out = sys.argv[3]
        n_pts = int(sys.argv[4]) if len(sys.argv) > 4 else 100000
        zs = float(sys.argv[5]) if len(sys.argv) > 5 else 1.5

        from glb_to_points import sample_glb
        from test_send_voxel import host_voxelize

        print(f"sampling {n_pts} pts from {glb}...")
        pts = sample_glb(glb, n_points=n_pts, target_scale=40,
                         color_mode="keep", brighten=1.5, gamma=0.8,
                         lighting="studio", ambient=0.3,
                         z_stretch=zs, verbose=False)
        cells = host_voxelize(pts)
        print(f"  → {len(cells)} unique voxel cells")
        save(out, cells, res=256)
    elif cmd == "info":
        path = sys.argv[2]
        cells, res = load(path)
        # Show bounding box stats
        if cells:
            indices = [c[0] for c in cells]
            xs = [i % res for i in indices]
            ys = [(i // res) % res for i in indices]
            zs = [i // (res*res) for i in indices]
            print(f"  bbox: x[{min(xs)}..{max(xs)}] y[{min(ys)}..{max(ys)}] z[{min(zs)}..{max(zs)}]")
            print(f"  density: {100*len(cells)/(res**3):.3f}% of grid")
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
