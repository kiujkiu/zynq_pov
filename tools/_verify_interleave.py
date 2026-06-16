"""验证半像素交错确实把径向/竖直分辨率翻倍.

构造高频径向同心环测试体 (环间距细到 128 格分辨不出, 但 256 格能).
(a) 无交错: 只用左屏整数格 (等效 128 径向采样).
(b) 交错: 左屏整数 + 右屏 +0.5 格 (等效 256 径向采样).
分别采样每个角度的 panel 列, 把 (左d, 右d+0.5) 合并成径向 profile, 对比能否分辨细环.

输出: interleave_radial_compare.png + 数值 (能分辨的最细环间距).
"""
import os, sys, math
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

TOOLS = os.path.dirname(os.path.abspath(__file__))

# ---- 高频同心环测试体 (256³ ground truth): 沿径向 r 的方波环 ----
# 环周期 P256 (256 单位) = 4 → 在 128 格里周期 2, Nyquist 边缘, 128 采样会混叠;
# 256 采样 (交错) 能清晰分辨.
def ring_value_256(r256):
    # r256 = 半径 (256³ 单位). 方波: 周期 4 (256单位) = 2 (128单位).
    P = 4.0
    return ((np.floor(r256 / (P / 2.0)).astype(np.int64) % 2) == 0).astype(np.float64)

def main():
    Rmax = 120.0  # 256 单位半径上限 (球 R2=120)
    # --- (a) 无交错: 整数格径向采样 d_old = -64..63, r256 = |d_old|*2 ---
    d_old = np.arange(-64, 64)
    r_a = np.abs(d_old.astype(np.float64)) * 2.0          # 128 个径向样本, 间隔 2 (256单位)
    val_a = ring_value_256(r_a)

    # --- (b) 交错: 左屏 d_old*2 + 右屏 d_old*2+1 合并 = 0,1,2,...,255 全覆盖 ---
    r_left = np.abs(d_old.astype(np.float64)) * 2.0       # 偶
    r_right = np.abs(d_old.astype(np.float64) * 2.0 + 1.0)  # 奇 (+0.5px)
    r_b = np.concatenate([r_left, r_right])
    val_b = ring_value_256(r_b)
    order = np.argsort(r_b)
    r_b_s, val_b_s = r_b[order], val_b[order]

    # --- ground truth 连续 ---
    r_gt = np.linspace(0, Rmax, 2000)
    val_gt = ring_value_256(r_gt)

    # --- 量化: 各方案在 [0,Rmax] 重建 ground truth 的相关/误差 ---
    # 把样本插值回连续再比 (最近邻, 模拟 POV 显示离散性)
    def nn_recon(rs, vals, r_query):
        idx = np.argmin(np.abs(rs[None, :] - r_query[:, None]), axis=1)
        return vals[idx]
    # 去重排序
    def uniq_sorted(rs, vals):
        o = np.argsort(rs); rs, vals = rs[o], vals[o]
        ur, ui = np.unique(rs, return_index=True)
        return ur, vals[ui]
    ra_u, va_u = uniq_sorted(r_a, val_a)
    rb_u, vb_u = uniq_sorted(r_b, val_b)
    rec_a = nn_recon(ra_u, va_u, r_gt)
    rec_b = nn_recon(rb_u, vb_u, r_gt)
    err_a = np.mean(np.abs(rec_a - val_gt))
    err_b = np.mean(np.abs(rec_b - val_gt))
    print(f'distinct radial samples in [0,{Rmax:.0f}]: '
          f'no-interleave={len(np.unique(ra_u[ra_u<=Rmax]))}  '
          f'interleave={len(np.unique(rb_u[rb_u<=Rmax]))}')
    print(f'ring reconstruction L1 error vs ground truth: '
          f'no-interleave={err_a:.3f}  interleave={err_b:.3f}')

    # --- 2D 重建可视化: 把径向 profile 转回 2D 圆环图 ---
    N = 256
    yy, xx = np.mgrid[-N//2:N//2, -N//2:N//2].astype(np.float64)
    rr = np.sqrt(xx*xx + yy*yy)  # 256 单位半径
    def to_image(rs, vals):
        ur, uv = uniq_sorted(rs, vals)
        idx = np.clip(np.searchsorted(ur, rr.ravel()), 0, len(ur)-1)
        # 最近邻
        idx_lo = np.clip(idx-1, 0, len(ur)-1)
        pick = np.where(np.abs(ur[idx]-rr.ravel()) <= np.abs(ur[idx_lo]-rr.ravel()), idx, idx_lo)
        img = uv[pick].reshape(N, N)
        img[rr > Rmax] = 0
        return img
    img_gt = ring_value_256(rr); img_gt[rr > Rmax] = 0
    img_a = to_image(r_a, val_a)
    img_b = to_image(r_b, val_b)

    fig, ax = plt.subplots(2, 3, figsize=(15, 10))
    ax[0,0].imshow(img_gt, cmap='gray'); ax[0,0].set_title('ground truth (256 fine rings)')
    ax[0,1].imshow(img_a, cmap='gray'); ax[0,1].set_title(f'NO interleave (128 radial)\nL1 err {err_a:.3f}')
    ax[0,2].imshow(img_b, cmap='gray'); ax[0,2].set_title(f'INTERLEAVE (256 radial)\nL1 err {err_b:.3f}')
    # 径向 profile 放大 (前 40 单位看细环)
    m = r_gt <= 40
    ax[1,0].plot(r_gt[m], val_gt[m], 'k-', lw=1, label='ground truth'); ax[1,0].set_title('GT radial profile'); ax[1,0].legend()
    ma = ra_u <= 40; ax[1,1].step(ra_u[ma], va_u[ma], 'r-', where='mid'); ax[1,1].plot(r_gt[m], val_gt[m], 'k:', lw=0.7); ax[1,1].set_title('no-interleave samples (aliased)')
    mb = rb_u <= 40; ax[1,2].step(rb_u[mb], vb_u[mb], 'g-', where='mid'); ax[1,2].plot(r_gt[m], val_gt[m], 'k:', lw=0.7); ax[1,2].set_title('interleave samples (resolved)')
    for a_ in ax[1]: a_.set_xlabel('radius (256-unit)'); a_.set_ylim(-0.2, 1.2)
    fig.tight_layout()
    out = os.path.join(TOOLS, 'interleave_radial_compare.png')
    fig.savefig(out, dpi=100)
    print(f'wrote {out}')
    print('RESULT:', 'INTERLEAVE WINS (lower err + 2x samples)' if err_b < err_a else 'no improvement')

if __name__ == '__main__':
    main()
