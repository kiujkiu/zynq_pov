"""Animation loader: produces a function (t_seconds) -> sampled_points.

Three modes:

1. Procedural rotation (default for static glb/obj):
   build_animator_static(base_pts, period_y_sec=10.0, breath=True)

2. OBJ sequence directory (e.g., model_0001.obj, model_0002.obj, ..., 24fps):
   build_animator_obj_sequence(folder, n_points, fps=24)

3. glTF/glb with keyframe animation (TRS interpolation on root node only —
   no skinning yet). Falls back to procedural if no animation present:
   build_animator_glb(path, n_points, ...)
"""
import os
import math
import glob

from mesh_to_points import sample_mesh
from glb_to_points import sample_glb, load_glb, sample_triangles, normalize_and_quantize


# ---------------------------------------------------------------------- #
def build_animator_static(base_pts, period_y_sec=10.0, breath=True, bob=True):
    """Return f(t) -> point list with Y rotation + optional breathing/bobbing."""
    def at(t):
        if period_y_sec > 0:
            ang = t * 2 * math.pi / period_y_sec
            ca = math.cos(ang); sa = math.sin(ang)
        else:
            ca = 1.0; sa = 0.0
        s = (1.0 + 0.05 * math.sin(t * 2 * math.pi / 3.0)) if breath else 1.0
        yo = (3.0 * math.sin(t * 2 * math.pi / 2.0)) if bob else 0.0
        out = []
        for (x, y, z, r, g, b) in base_pts:
            rx = x * ca - z * sa
            rz = x * sa + z * ca
            nx = max(-127, min(127, int(rx * s)))
            ny = max(-127, min(127, int(y + yo)))
            nz = max(-127, min(127, int(rz * s)))
            out.append((nx, ny, nz, r, g, b))
        return out
    return at


# ---------------------------------------------------------------------- #
def build_animator_obj_sequence(folder, n_points=5000, target_scale=40,
                                 fps=24, color_mode="height"):
    """Frames pre-sampled from a sorted folder of .obj files. f(t) returns
    nearest frame interpolated by playback time."""
    pattern = os.path.join(folder, "*.obj")
    files = sorted(glob.glob(pattern))
    if not files:
        raise RuntimeError(f"no .obj files in {folder}")
    print(f"[anim] {len(files)} OBJ frames @ {fps} fps")
    cached = []
    for f in files:
        pts = sample_mesh(f, n_points=n_points, target_scale=target_scale)
        cached.append(pts)
    period = len(files) / fps
    def at(t):
        idx = int((t % period) * fps) % len(cached)
        return cached[idx]
    return at


# ---------------------------------------------------------------------- #
# glTF animation evaluator — root-node TRS only (no skinning)            #
# ---------------------------------------------------------------------- #

def _evaluate_animation(gltf, anim_idx, t):
    """Returns dict node_idx → (translation, rotation_quat, scale).
    Only handles root-node TRS animation (no skinning)."""
    import numpy as np
    anim = gltf.animations[anim_idx]
    out = {}
    for ch in anim.channels:
        target_node = ch.target.node
        path = ch.target.path
        sampler = anim.samplers[ch.sampler]
        # input: time keyframes, output: TRS values
        from glb_to_points import _get_accessor_data
        times = _get_accessor_data(gltf, sampler.input).flatten()
        values = _get_accessor_data(gltf, sampler.output)

        if times.size == 0:
            continue
        # wrap t within range
        tt = times[0] + ((t - times[0]) % (times[-1] - times[0] + 1e-9))
        # find segment
        idx = max(0, int(np.searchsorted(times, tt, side='right')) - 1)
        idx2 = min(idx + 1, len(times) - 1)
        if idx == idx2:
            v = values[idx]
        else:
            denom = max(times[idx2] - times[idx], 1e-6)
            f = (tt - times[idx]) / denom
            if path == "rotation":
                # spherical-linear approximation: just lerp + renormalize
                v = (1 - f) * values[idx] + f * values[idx2]
                norm = np.linalg.norm(v)
                if norm > 0:
                    v = v / norm
            else:
                v = (1 - f) * values[idx] + f * values[idx2]

        if target_node not in out:
            out[target_node] = {"t": None, "r": None, "s": None}
        if path == "translation":
            out[target_node]["t"] = v
        elif path == "rotation":
            out[target_node]["r"] = v
        elif path == "scale":
            out[target_node]["s"] = v
    return out


def build_animator_glb(path, n_points=5000, target_scale=40,
                       color_mode="height", brighten=1.0, gamma=1.0,
                       fallback_period_y=10.0):
    """If glb has animation, apply node TRS at time t (root only). Otherwise
    fall back to procedural Y-rotation animator."""
    from pygltflib import GLTF2
    g = GLTF2().load(path)
    if not g.animations:
        # static — use procedural animator
        base = sample_glb(path, n_points=n_points, target_scale=target_scale,
                          color_mode=color_mode, brighten=brighten, gamma=gamma,
                          verbose=False)
        return build_animator_static(base, period_y_sec=fallback_period_y)

    # glb has animation — pre-load triangles, store untransformed positions
    triangles = load_glb(path, verbose=False)
    # base sample (positions in original local coords)
    base = sample_triangles(triangles, n_points)
    quantized = normalize_and_quantize(
        base, target_scale=target_scale, color_mode=color_mode,
        brighten=brighten, gamma=gamma)

    print(f"[anim] glb has {len(g.animations)} animation(s); using #0")
    # We only apply node-0 (root) translation/rotation as a coarse approximation.
    def at(t):
        try:
            trs = _evaluate_animation(g, 0, t)
        except Exception as e:
            print(f"[anim] eval err: {e}")
            return quantized
        # apply root rotation (if any) like normal Y rotation
        import numpy as np
        out = []
        # find root TRS
        any_node = next(iter(trs.values()), None) if trs else None
        rot = any_node["r"] if any_node and any_node.get("r") is not None else None
        for (x, y, z, r, g_, b) in quantized:
            if rot is not None:
                # rotate point using quaternion (x,y,z,w)
                qx, qy, qz, qw = rot
                # v' = q * v * q^-1, fast form:
                px, py, pz = float(x), float(y), float(z)
                tx = 2 * (qy * pz - qz * py)
                ty = 2 * (qz * px - qx * pz)
                tz = 2 * (qx * py - qy * px)
                rx = px + qw * tx + (qy * tz - qz * ty)
                ry = py + qw * ty + (qz * tx - qx * tz)
                rz = pz + qw * tz + (qx * ty - qy * tx)
                nx = max(-127, min(127, int(rx)))
                ny = max(-127, min(127, int(ry)))
                nz = max(-127, min(127, int(rz)))
            else:
                nx, ny, nz = x, y, z
            out.append((nx, ny, nz, r, g_, b))
        return out
    return at


# ---------------------------------------------------------------------- #
def build_animator(path_or_folder, n_points=5000, **kw):
    """Top-level: pick mode by extension/dir."""
    if os.path.isdir(path_or_folder):
        return build_animator_obj_sequence(path_or_folder, n_points=n_points, **kw)
    ext = os.path.splitext(path_or_folder)[1].lower()
    if ext in (".glb", ".gltf"):
        return build_animator_glb(path_or_folder, n_points=n_points, **kw)
    # static obj/ply: just procedural
    base = sample_mesh(path_or_folder, n_points=n_points,
                       target_scale=kw.get("target_scale", 40))
    return build_animator_static(base, period_y_sec=kw.get("fallback_period_y", 10.0))


if __name__ == "__main__":
    import sys
    path = sys.argv[1]
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 1000
    f = build_animator(path, n_points=n)
    print(f"animator built. Sample at t=0:")
    pts = f(0.0)
    print(f"  N={len(pts)}, p0={pts[0]}")
    pts2 = f(1.0)
    print(f"  t=1: p0={pts2[0]}")
    diff = sum(1 for a, b in zip(pts, pts2) if a != b)
    print(f"  changed points between t=0 and t=1: {diff}/{len(pts)}")
