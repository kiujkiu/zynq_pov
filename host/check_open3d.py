try:
    import open3d
    print("open3d", open3d.__version__, "OK")
except ImportError:
    print("NOT INSTALLED")
try:
    import trimesh
    m = trimesh.creation.box()
    m2 = m.simplify_quadric_decimation(4)
    print("trimesh decimation OK")
except Exception as e:
    print(f"trimesh decimation: {e}")
