try:
    import scipy.ndimage as N
    print("scipy OK")
except Exception as e:
    print("NO scipy:", e)
