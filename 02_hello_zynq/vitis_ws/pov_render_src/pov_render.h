/* pov_render.h — POV-3D 点云→切片渲染 (纯计算, 无硬件依赖, 可移植 Linux).
 *
 * 把 PC 端 (tools/_gen_transform_lut.py 的 slice_via_lut + _pack_compact.py)
 * 做的切片生成搬到 Zynq ARM Cortex-A9 裸机。算法逐字节对齐 PC 管线。
 *
 * 数据约定 (与 tools/ 一致):
 *  - point_t: 16 字节小端: int16 x,y,z,pad0; uint8 r,g,b,pad1; int32 pad2
 *  - vox:     128^3 × 3 uint8, 线性下标 ((vx*128+vy)*128+vz)*3 + ch
 *  - LUT:     16384 × (int16 d, int16 wy), transform_lut.bin
 *  - slice:   2048 × uint32 compact, lane k(0..7)=fwi(j*8+k); word|=lane<<(k*3)
 *             lane bit0=G, bit1=B, bit2=R
 *
 * 定点/浮点切换: 定义 POV_USE_FLOAT 使用 double cos/sin (与 numpy 完全一致,
 *               用于 host 验证基准); 默认用 Q15 定点表 (裸机无 FPU 软浮点慢).
 */
#ifndef POV_RENDER_H
#define POV_RENDER_H

#include <stdint.h>
#include <stddef.h>

#define POV_GRID      128                       /* 体素网格边长 */
#define POV_VOX_BYTES (POV_GRID*POV_GRID*POV_GRID*3) /* 6,291,456 (6 MB) */
#define POV_NFWI      16384                      /* full_word_index 数量 */
#define POV_SLICE_WORDS 2048                     /* 每片 uint32 数 */
#define POV_SLICE_BYTES (POV_SLICE_WORDS*4)      /* 8192 (8 KB) */

#ifdef __cplusplus
extern "C" {
#endif

/* 点云结构 (16 字节, 小端). pad 字段保留对齐, 计算只用 x,y,z,r,g,b. */
typedef struct {
    int16_t  x, y, z, pad0;
    uint8_t  r, g, b, pad1;
    int32_t  pad2;
} pov_point_t;

/* LUT 单元: d (-64..63), wy (0..127). */
typedef struct {
    int16_t d;
    int16_t wy;
} pov_lut_t;

/* 体素化: pts[n] → vox (128^3×3). 调用方负责清零 vox (last-write 语义).
 * vx=clip(x+64,0,127) 同 vy/vz; vox[((vx*128+vy)*128+vz)*3 + ch] = RGB. */
void pov_voxelize(const pov_point_t *pts, int n, uint8_t *vox);

/* 单角度切片: vox + lut → out[2048]. angle 0..n_slices-1.
 * out 必须 2048 个 uint32 空间; 函数内部全部覆写 (无需预清零). */
void pov_gen_slice(const uint8_t *vox, const int16_t *lut,
                   int angle, int n_slices, uint32_t *out);

/* 全部 n_slices 片: slices 须 n_slices*2048 个 uint32 (n_slices*8KB). */
void pov_gen_all(const uint8_t *vox, const int16_t *lut,
                 int n_slices, uint32_t *slices);

#ifdef __cplusplus
}
#endif

#endif /* POV_RENDER_H */
