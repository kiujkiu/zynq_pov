try:
    import trimesh, numpy, serial, pygltflib
    print("deps OK:",
          "trimesh", trimesh.__version__,
          "numpy", numpy.__version__,
          "pyserial", serial.__version__)
except Exception as e:
    print("ERR:", e)
