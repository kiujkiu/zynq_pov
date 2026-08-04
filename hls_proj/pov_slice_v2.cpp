/* pov_slice_v2.cpp — ICND2260 双面 POV 体素切片器 HLS top
 * 架构说明见 pov_slice_v2.h 文件头 / memory project_pov3d_hls_slicer_arch。
 */
#include "pov_slice_v2.h"
#include "pov_slice_v2_lut.h"

void pov_slice_v2(
    const uint64_t *voxel,
    uint64_t *slot_base,
    int phase,
    int slot_start,
    int n_slots,
    int axis_off_q8,
    int mirror_u
) {
    /* 🔴 端口按 **64 位** 声明, 不指望 max_widen_bitwidth 自动加宽。
     * 2026-08-04 实测: 用 uint16* + max_widen_bitwidth=64 时 widen **没生效**
     * (内层 `inside ? voxel[..] : 0` 三元条件破坏了纯拷贝模式), 结果 1 元素/拍
     * = 41,472 cycle/片。改 64 位端口后 PV2_VOX_Y=216 恰好 /4=54 拍, 确定性 4 元素/拍。
     *
     * 读写分两个 bundle → BD 接不同 HP 端口, 读写真并行。 */
#pragma HLS INTERFACE m_axi port=voxel     offset=slave bundle=vox \
    depth=1990656 max_read_burst_length=64 num_read_outstanding=16
#pragma HLS INTERFACE m_axi port=slot_base offset=slave bundle=out \
    depth=6251904 max_write_burst_length=64 num_write_outstanding=16
#pragma HLS INTERFACE s_axilite port=voxel       bundle=control
#pragma HLS INTERFACE s_axilite port=slot_base   bundle=control
#pragma HLS INTERFACE s_axilite port=phase       bundle=control
#pragma HLS INTERFACE s_axilite port=slot_start  bundle=control
#pragma HLS INTERFACE s_axilite port=n_slots     bundle=control
#pragma HLS INTERFACE s_axilite port=axis_off_q8 bundle=control
#pragma HLS INTERFACE s_axilite port=mirror_u    bundle=control
#pragma HLS INTERFACE s_axilite port=return      bundle=control

    if (n_slots   < 0) n_slots   = 0;
    if (slot_start < 0) slot_start = 0;

SLICES:
    for (int s = 0; s < n_slots; s++) {
#pragma HLS LOOP_TRIPCOUNT min=151 max=603

        const int g = slot_start + s;
        int angle = (phase + g) % PV2_NUM_ANGLES;
        if (angle < 0) angle += PV2_NUM_ANGLES;

        const int cs = (int)PV2_COS8[angle];
        const int sn = (int)PV2_SIN8[angle];

        /* 偏移分量与列无关, 每片算一次。世界坐标与 gen_anime_slices.py 一致:
         *   world = u·û(θ) + axis_off·n̂(θ),  û=(cos,sin), n̂=(-sin,cos)
         *   ⇒ wx = u·cos - axis_off·sin
         *     wz = u·sin + axis_off·cos
         *
         * 🔴 全程保持 Q8, **只在最后取整一次** —— Python 参考是
         *   `np.rint(D*c - axis_off*s)`, 对**和**取整。若分开右移会各截断一次,
         *   产生系统性半像素偏差, 对拍必然对不上。
         * axis_off_q8 已是 Q8, 乘 Q8 的 sn/cs 得 Q16, 故 >>8 回到 Q8。 */
        const int off_x_q8 = -((axis_off_q8 * sn) >> 8);
        const int off_z_q8 =  ((axis_off_q8 * cs) >> 8);

        uint64_t *slot = slot_base + (long)g * PV2_SLOT_BEATS;

COLUMNS:
        for (int px = 0; px < PV2_PANEL_W; px++) {
#pragma HLS LOOP_TRIPCOUNT min=192 max=192

            int u = px - PV2_CX;
            if (mirror_u) u = -u;

            /* Q8 求和后四舍五入一次 (+128 再 >>8), 与 Python 的 np.rint 对齐 */
            const int rx = ((u * cs + off_x_q8 + 128) >> 8) + PV2_VOX_HALF;
            const int rz = ((u * sn + off_z_q8 + 128) >> 8) + PV2_VOX_HALF;

            const bool inside = (rx >= 0) && (rx < PV2_VOX_XZ)
                             && (rz >= 0) && (rz < PV2_VOX_XZ);

            /* 🔴 地址先 clamp 再无条件读, 把三元条件挪到读**之后**。
             * 这样内层是纯连续拷贝, HLS 能推出定长突发; 越界列(偏心面中心盲柱 /
             * 旋转出界)靠 `inside` 把读回来的值换成 0, 而不是跳过读。 */
            const int vx = inside ? rx : 0;
            const int vz = inside ? rz : 0;

            /* 整列一根连续柱子 —— 读写两端都是 PV2_COL_BEATS 拍的连续突发 */
            const long src = ((long)vz * PV2_VOX_XZ + vx) * PV2_COL_BEATS;
            const long dst = (long)px * PV2_COL_BEATS;

COPY_COLUMN:
            for (int b = 0; b < PV2_COL_BEATS; b++) {
#pragma HLS LOOP_TRIPCOUNT min=54 max=54
#pragma HLS PIPELINE II=1
                const uint64_t v = voxel[src + b];
                slot[dst + b] = inside ? v : (uint64_t)0;
            }
        }
    }
}
