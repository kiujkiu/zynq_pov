"""半像素交错切片 (右屏 panel1 物理 +0.5px) — 利用两屏机械错位把有效分辨率翻倍.

物理背景 (从 macha/pov3d/assembly_stack.py 推):
  两块 128x64 panel 拼 128x128 逻辑屏, 绕竖轴 (assembly Z) 旋转扫体积.
  panel 平面在 assembly 的 Y-Z 平面 (front face X=0 = 转轴平面):
    panel 宽 = assembly Y  (水平, 在 rotor 帧里就是 slicer 的径向 d)
    panel 高 = assembly Z  (= 转轴方向 = slicer 的竖直 wy)
  '+Y screen' = panel1 = viewer's RIGHT, 相对 '-Y screen'=panel2=LEFT:
    +1mm Y (panel 宽方向) → slicer 径向 d  +0.5 px  (pitch 2mm)
    +1mm Z (panel 高方向) → slicer 竖直 wy +0.5 px
  => 右屏 (panel1, fwi 8192..16383) 在 d 和 wy 各 +0.5; 左屏不变.
     左屏采整数格, 右屏采 +0.5 格 → 交错 → 径向 + 竖直有效分辨率各翻倍 (≈256).

径向 +0.5 是 panel 帧里的固定 d 偏移 (NOT 世界 z 平移): 偏移随 rotor 一起转,
所以是 d += 0.5, 旋转后 wx += 0.5·cosθ, wz += 0.5·sinθ. 从几何推, 不是拍脑袋.

256³ 方案 (1 unit = 半个旧 voxel):
  体素化到 256³ (旧 128³ 每格 ×2). 左屏采偶数格, 右屏采奇数(+1)格.
  LUT 仍是 16384×int16 (d, wy) 但用 256³ 坐标:
    左屏 fwi<8192 :  d=(col-64)*2,     wy=(127-row)*2
    右屏 fwi>=8192:  d=(col-64)*2 + 1, wy=(127-row)*2 + 1
  采样公式 center 64→128, grid 128→256:
    wx = round(d·cosθ)+128 ; wz = round(d·sinθ)+128 ; wy 直接用 (已是 256 坐标)
    采样 vox256[wx][wy][wz], 阈值, pack (不变).
  取整约定: d 已是整数 (含 +1), round 只作用于 d·cos/d·sin. clip 到 [0,255].

无交错 128³ 路径保留 (旧 LUT / 旧 generator 不动). 这是新文件 + 开关.

用法:
  python _gen_interleave.py lut                 # 写 transform_lut_il.bin (256³ 交错版)
  python _gen_interleave.py globe [N=720]       # 写 globe_slices_il_<N>.bin
  python _gen_interleave.py verify              # 数值对比 (无 PC, 纯 LUT 内自洽)
"""
import os, sys, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from display_128x128 import transform_for_panel1, transform_for_panel2, pack_panel_bin
import display_128x128 as dm

TOOLS = os.path.dirname(os.path.abspath(__file__))
LUT_IL = os.path.join(TOOLS, 'transform_lut_il.bin')


# ---------------------------------------------------------------------------
# 1) 交错 LUT (256³ 坐标). 复用 _gen_transform_lut 的几何追踪, 只改坐标缩放/偏移.
# ---------------------------------------------------------------------------
def build_il_lut():
    idx = np.arange(128 * 128, dtype=np.int32).reshape(128, 128)
    enc = np.zeros((128, 128, 3), np.uint8)
    enc[..., 0] = (idx >> 8).astype(np.uint8)
    enc[..., 1] = (idx & 0xFF).astype(np.uint8)
    img = Image.fromarray(enc).rotate(180)
    L = img.crop((0, 0, 64, 128)); Rc = img.crop((64, 0, 128, 128))
    fx = Image.new('RGB', (128, 128)); fx.paste(Rc, (0, 0)); fx.paste(L, (64, 0))
    p1 = np.asarray(transform_for_panel1(fx.crop((64, 0, 128, 128))))
    p2 = np.asarray(transform_for_panel2(fx.crop((0, 0, 64, 128))))

    lut_d = np.zeros(16384, np.int16)
    lut_wy = np.zeros(16384, np.int16)

    def decode(pan, base, half_off):
        # half_off = 0 (左屏整数格) 或 1 (右屏 +0.5 → 256 坐标里 +1)
        for hw_row in range(64):
            for hw_col in range(128):
                px = pan[hw_row, hw_col]
                src = (int(px[0]) << 8) | int(px[1])
                row, col = src // 128, src % 128
                blk = base + (0 if hw_row < 32 else 4096)
                fwi = blk + (hw_row % 32) * 128 + hw_col
                lut_d[fwi] = (col - 64) * 2 + half_off          # 256³ 径向坐标
                lut_wy[fwi] = (127 - row) * 2 + half_off        # 256³ 竖直坐标

    decode(p2, 0, 0)        # 左屏 panel2: 偶数格
    decode(p1, 8192, 1)     # 右屏 panel1: +0.5 → 奇数格
    LUT = np.stack([lut_d, lut_wy], axis=1).astype(np.int16)
    return LUT


def cmd_lut():
    LUT = build_il_lut()
    LUT.tofile(LUT_IL)
    print(f'wrote {LUT_IL}: {LUT.nbytes} bytes (16384 x int16 d,wy in 256^3 coords)')
    print('  left (fwi<8192)  d,wy even  ; right (fwi>=8192) d,wy odd (+0.5px)')


# ---------------------------------------------------------------------------
# 2) 256³ 地球体素化 (同 _gen_globe_slices 几何, 全部尺寸 ×2)
# ---------------------------------------------------------------------------
def build_globe_vox256():
    G2, R2, TH2 = 256, 120, 6   # 旧 R=60 TH=3 → ×2
    EARTH = os.path.join(TOOLS, 'earth_clean.jpg')
    earth = np.asarray(Image.open(EARTH).convert('RGB'))
    H, W = earth.shape[:2]
    ax = np.arange(G2) - 128.0
    X, Y, Z = np.meshgrid(ax, ax, ax, indexing='ij')
    rr = np.sqrt(X * X + Y * Y + Z * Z)
    inside = (rr <= R2) & (rr >= R2 - TH2)
    rs = np.where(rr < 1e-3, 1.0, rr)
    lat = np.arcsin(np.clip(Y / rs, -1, 1)); lon = np.arctan2(Z, X)
    u = (((lon + math.pi) / (2 * math.pi)) * W).astype(np.int32) % W
    v = np.clip((((math.pi / 2 - lat) / math.pi) * (H - 1)).astype(np.int32), 0, H - 1)
    samp = earth[v, u]
    r_ = samp[..., 0].astype(np.int32); g_ = samp[..., 1].astype(np.int32); b_ = samp[..., 2].astype(np.int32)
    ocean = (b_ > g_ + 10) & (b_ > r_ + 10)
    ice = (r_ > 170) & (g_ > 170) & (b_ > 170)
    vox = np.zeros((G2, G2, G2, 3), np.uint8)
    vox[inside] = [0, 255, 0]
    vox[inside & ocean] = [0, 0, 255]
    vox[inside & ice] = [255, 255, 255]
    return vox


def slice_via_lut256(LUT, vox256, a, n_slices):
    """用交错 LUT (256³) 渲一片, 返回 panel-order 128x128 RGB (uint8 0/255)."""
    th = 2 * math.pi * a / n_slices
    c, s = math.cos(th), math.sin(th)
    d = LUT[:, 0].astype(np.float64)
    wy = np.clip(LUT[:, 1].astype(np.int32), 0, 255)
    wx = np.clip(np.rint(d * c).astype(np.int32) + 128, 0, 255)
    wz = np.clip(np.rint(d * s).astype(np.int32) + 128, 0, 255)
    rgb = vox256[wx, wy, wz]          # [16384][3], fwi 顺序
    return rgb


def cmd_globe(n_slices):
    dm.R_GAIN = dm.G_GAIN = dm.B_GAIN = 1.00
    LUT = build_il_lut()
    vox = build_globe_vox256()
    # fwi 顺序直接就是 t2,b2,t1,b1 的 word 排列 -> 直接 pack 成 1-bit lane word.
    out = bytearray()
    for a in range(n_slices):
        rgb = slice_via_lut256(LUT, vox, a, n_slices)
        on = (rgb >= 128)
        Gb, Bb, Rb = on[:, 1], on[:, 2], on[:, 0]
        lane = (Gb.astype(np.uint32)) | (Bb.astype(np.uint32) << 1) | (Rb.astype(np.uint32) << 2)
        lane = lane.reshape(2048, 8)
        word = np.zeros(2048, np.uint32)
        for k in range(8):
            word |= lane[:, k] << (k * 3)
        out += word.astype('<u4').tobytes()
        if a % 90 == 0:
            print(f'slice {a}: {int(on.any(axis=1).sum())} lit')
    OUT = os.path.join(TOOLS, f'globe_slices_il_{n_slices}.bin')
    open(OUT, 'wb').write(bytes(out))
    print(f'{OUT}: {len(out)} bytes ({n_slices} interleaved globe slices)')


def cmd_verify():
    LUT = build_il_lut()
    # 自洽: 左屏 d,wy 必偶, 右屏必奇; 旧 LUT 关系 d_il = d_old*2 (左) / *2+1 (右)
    dL, wL = LUT[:8192, 0], LUT[:8192, 1]
    dR, wR = LUT[8192:, 0], LUT[8192:, 1]
    okL = np.all(dL % 2 == 0) and np.all(wL % 2 == 0)
    okR = np.all(dR % 2 == 1) and np.all(wR % 2 == 1)
    # 跟旧 LUT 比对偶数部分应当一致
    old = np.fromfile(os.path.join(TOOLS, 'transform_lut.bin'), dtype=np.int16).reshape(16384, 2)
    matchL = np.array_equal(dL, old[:8192, 0] * 2) and np.array_equal(wL, old[:8192, 1] * 2)
    matchR = np.array_equal(dR, old[8192:, 0] * 2 + 1) and np.array_equal(wR, old[8192:, 1] * 2 + 1)
    print('left even :', okL, ' right odd :', okR)
    print('left == old*2 :', matchL, ' right == old*2+1 :', matchR)
    print('VERIFY:', 'OK' if (okL and okR and matchL and matchR) else 'FAIL')


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'lut'
    if cmd == 'lut':
        cmd_lut()
    elif cmd == 'globe':
        cmd_globe(int(sys.argv[2]) if len(sys.argv) > 2 else 720)
    elif cmd == 'verify':
        cmd_verify()
    else:
        print('usage: _gen_interleave.py [lut|globe N|verify]')
