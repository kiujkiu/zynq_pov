"""host 验证: ARM 板端切片算法 (pov_render.c) vs PC 管线 compact 输出。

把 02_hello_zynq/vitis_ws/pov_render_src 的 pov_render.c 用 host gcc 编译,
对同一份 anime_points.bin + transform_lut.bin 生成 720 片 compact, 跟
tools/anime_slices_720_compact.bin (PC 管线 _gen_anime_slices + _pack_compact
的输出) 逐字节比对。

跑两个后端:
  - FLOAT  (默认):            double cos/sin + rint, 逐字节全等 (裸机也用这个)。
  - FIXED  (-DPOV_USE_FIXED): Q15 纯整数版, 报告字节/bit 差异量 (亚像素)。

用法: python3 tools/_verify_arm.py
依赖: gcc (host WSL 有)。纯 stdlib, 不需 numpy。
"""
import os, subprocess, sys, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC  = os.path.join(ROOT, "02_hello_zynq", "vitis_ws", "pov_render_src")
PTS  = os.path.join(ROOT, "anime_points.bin")
LUT  = os.path.join(ROOT, "tools", "transform_lut.bin")
REF  = os.path.join(ROOT, "tools", "anime_slices_720_compact.bin")
TMP  = "/tmp/_pov_verify"
os.makedirs(TMP, exist_ok=True)
N = 720

def build(name, extra):
    out = os.path.join(TMP, name)
    cmd = ["gcc", "-O2", *extra, "-o", out,
           os.path.join(SRC, "host_render.c"),
           os.path.join(SRC, "pov_render.c"), "-lm"]
    subprocess.run(cmd, check=True)
    return out

def run(exe, tag):
    out = os.path.join(TMP, f"slices_{tag}.bin")
    subprocess.run([exe, PTS, LUT, out, str(N)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return out

POPC = bytes(bin(i).count("1") for i in range(256))

def compare(path, tag):
    a = open(path, "rb").read()
    b = open(REF,  "rb").read()
    if len(a) != len(b):
        print(f"[{tag}] SIZE MISMATCH {len(a)} vs {len(b)}")
        return False
    nbytes = sum(1 for x, y in zip(a, b) if x != y)
    if nbytes == 0:
        print(f"[{tag}] BYTE-EXACT MATCH ({len(a)} bytes, {N} slices)")
        return True
    # 量化 bit 级差异 (uint32 word)
    nwords = len(a) // 4
    nbits = 0; bad_words = 0; bad_slices = set()
    for w in range(nwords):
        xa = struct.unpack_from("<I", a, w*4)[0]
        xb = struct.unpack_from("<I", b, w*4)[0]
        x = xa ^ xb
        if x:
            bad_words += 1
            bad_slices.add(w // 2048)
            nbits += POPC[x & 0xFF] + POPC[(x>>8)&0xFF] + POPC[(x>>16)&0xFF] + POPC[(x>>24)&0xFF]
    print(f"[{tag}] DIFFERS: {nbytes}/{len(a)} bytes, {bad_words}/{nwords} words, "
          f"{nbits} lit-bits across {len(bad_slices)}/{N} slices")
    print(f"        bit-diff rate = {nbits/(nwords*32)*100:.4f}% of all bits")
    return False

if __name__ == "__main__":
    print("== building host_render (float + fixed) ==")
    fexe = build("host_render_f", [])               # 默认浮点
    xexe = build("host_render_x", ["-DPOV_USE_FIXED"])
    print("== FLOAT backend (default, numpy-exact) ==")
    ok_f = compare(run(fexe, "float"), "FLOAT")
    print("== FIXED backend (Q15, -DPOV_USE_FIXED) ==")
    ok_x = compare(run(xexe, "fixed"), "FIXED")
    # FLOAT 必须全等; FIXED 差异只要可量化可接受 (1-bit 显示, 边界 ±1px)
    sys.exit(0 if ok_f else 1)
