/* pov_eta_rd.cpp — DDR 读效率 η 量具: pov_slice_v2 的「只读 + 提前 PF 列预取 + 引脚级启停」变体
 *
 * 为什么不直接拿 pov_slice_v2 测 (三条, 每条单独就够改):
 *   ① 原 IP 每片读 82,944 B **并且写** 82,944 B。「切片不落 DDR」拓扑里 DDR 上只有读流,
 *      两路并发 × 110.6 µs 判据若带上写流 = 3.0 GB/s > 峰值 2.133 ⇒ η=1 也过不了。
 *      本变体去掉 m_axi out, 读回的 64 位字 XOR 累加后经 s_axilite 交回 (不会被优化掉,
 *      且主机能按同一地址算法算出期望值 ⇒ 证明 IP 读的正是那 192×54 拍)。
 *   ② 原 IP 每列只提前 8 拍发读请求 (readreq 在流水第 53 级, 首拍消费在第 61 级,
 *      见 sol_z2 RTL) ⇒ 每列都吃一次完整 DDR 延迟, 空载即擦线 (昨天复核的条件 C2)。
 *      量 DDR 的 η 需要请求方能把口喂饱, 本变体用 hls::burst_maxi 提前 pf_cols 列
 *      发请求 (pf_cols 是运行期寄存器, 0..6; 0 = 复现原 IP 的"发完就等"行为)。
 *   ③ 原 IP 的 ap_start/ap_done 藏在 AXI-Lite 寄存器里, PL 侧看不见 ⇒ 无法硬件计时,
 *      也无法两路同拍启动。本变体 return 用 ap_ctrl_hs ⇒ ap_start/ap_done/ap_idle 是引脚,
 *      由 eta_mon.v 同一拍拉起两路、逐拍计 busy/done。ap_start 保持高电平 = 连续重跑。
 *
 * 地址算法与 pov_slice_v2.cpp 逐字相同 (u→rx,rz→clamp→src), 只是改成"按平坦拍序号 i
 * 推导 (slice, px, beat)", 全部前馈、无循环携带的乘法/ROM 依赖 ⇒ II=1 有保证。
 *
 * 每片读 192 列 × 54 拍 × 8 B = 82,944 B, 与原 IP 完全一致。
 * 依赖 zynq_pov/hls_proj/pov_slice_v2.h + pov_slice_v2_lut.h (默认 target = 192×216/603)。
 */
#include <stdint.h>
#include <hls_burst_maxi.h>
#include "pov_slice_v2.h"
#include "pov_slice_v2_lut.h"

#define ETA_MAX_PF 6            /* <= num_read_outstanding-1 */

void pov_eta_rd(
    hls::burst_maxi<uint64_t> voxel,
    int phase,
    int n_slots,
    int axis_off_q8,
    int mirror_u,
    int pf_cols,
    uint64_t *xor_out
) {
#pragma HLS INTERFACE m_axi port=voxel offset=slave bundle=vox \
    depth=1990656 max_read_burst_length=64 num_read_outstanding=8
#pragma HLS INTERFACE s_axilite port=voxel       bundle=control
#pragma HLS INTERFACE s_axilite port=phase       bundle=control
#pragma HLS INTERFACE s_axilite port=n_slots     bundle=control
#pragma HLS INTERFACE s_axilite port=axis_off_q8 bundle=control
#pragma HLS INTERFACE s_axilite port=mirror_u    bundle=control
#pragma HLS INTERFACE s_axilite port=pf_cols     bundle=control
#pragma HLS INTERFACE s_axilite port=xor_out     bundle=control
#pragma HLS INTERFACE ap_ctrl_hs port=return

    int ns = n_slots;
    if (ns < 0)   ns = 0;
    if (ns > 4095) ns = 4095;                       /* 4095*192*54 拍仍在 int 内 */
    int pf = pf_cols;
    if (pf < 0) pf = 0;
    if (pf > ETA_MAX_PF) pf = ETA_MAX_PF;

    int ang0 = phase % PV2_NUM_ANGLES;
    if (ang0 < 0) ang0 += PV2_NUM_ANGLES;

    const int total_cols  = ns * PV2_PANEL_W;
    const int total_beats = (total_cols + pf) * PV2_COL_BEATS;

    uint64_t acc = 0;

FLAT:
    for (int i = 0; i < total_beats; i++) {
#pragma HLS PIPELINE II=1
#pragma HLS LOOP_TRIPCOUNT min=10476 max=6252228
        /* 平坦拍序号 -> (请求列 k, 列内拍 b); 常数除法 = 乘逆元, 前馈 */
        const int k = i / PV2_COL_BEATS;
        const int b = i - k * PV2_COL_BEATS;

        if (b == 0 && k < total_cols) {
            const int s  = k / PV2_PANEL_W;
            const int px = k - s * PV2_PANEL_W;
            int angle = ang0 + s;                   /* 两者都 < 603, 和 < 1206 */
            if (angle >= PV2_NUM_ANGLES) angle -= PV2_NUM_ANGLES;

            const int cs = (int)PV2_COS8[angle];
            const int sn = (int)PV2_SIN8[angle];
            const int off_x_q8 = -((axis_off_q8 * sn) >> 8);
            const int off_z_q8 =  ((axis_off_q8 * cs) >> 8);

            int u = px - PV2_CX;
            if (mirror_u) u = -u;
            const int rx = ((u * cs + off_x_q8 + 128) >> 8) + PV2_VOX_HALF;
            const int rz = ((u * sn + off_z_q8 + 128) >> 8) + PV2_VOX_HALF;
            const bool inside = (rx >= 0) && (rx < PV2_VOX_XZ)
                             && (rz >= 0) && (rz < PV2_VOX_XZ);
            const int vx = inside ? rx : 0;
            const int vz = inside ? rz : 0;
            const unsigned src = ((unsigned)vz * PV2_VOX_XZ + (unsigned)vx) * PV2_COL_BEATS;
            voxel.read_request(src, PV2_COL_BEATS);
        }

        /* 消费列 k - pf (pf 列之前发出的请求) */
        if (k >= pf) {
            const uint64_t v = voxel.read();
            acc ^= v;
        }
    }
    *xor_out = acc;
}
