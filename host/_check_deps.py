import sys
try:
    import trimesh; print(f"trimesh {trimesh.__version__}")
except Exception as e: print(f"trimesh: {e}")
try:
    import numpy; print(f"numpy {numpy.__version__}")
except Exception as e: print(f"numpy: {e}")
try:
    import PIL; print(f"PIL {PIL.__version__}")
except Exception as e: print(f"PIL: {e}")
try:
    import pyrender; print(f"pyrender {pyrender.__version__}")
except Exception as e: print(f"pyrender: {e}")
try:
    import pygltflib; print(f"pygltflib {pygltflib.__version__}")
except Exception as e: print(f"pygltflib: {e}")
print(f"python {sys.version}")
