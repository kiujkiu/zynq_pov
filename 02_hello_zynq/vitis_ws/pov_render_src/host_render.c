/* host_render.c — host gcc 驱动: 跑 pov_render.c 生成 720 切片, 写文件。
 * 用于 _verify_arm.py 逐字节比对 PC 管线。
 *
 * 编译 (浮点版, 默认, 与 numpy rint 逐字节一致):
 *   gcc -O2 -o host_render host_render.c pov_render.c -lm
 * 编译 (定点 Q15 版):
 *   gcc -O2 -DPOV_USE_FIXED -o host_render_x host_render.c pov_render.c -lm
 *
 * 用法: host_render <points.bin(raw point_t, 无头)> <lut.bin> <out.bin> [n_slices]
 *   points.bin = 原始 anime_points.bin (无头, 16B/点)
 */
#include <stdio.h>
#include <stdlib.h>
#include "pov_render.h"

int main(int argc, char **argv)
{
    if (argc < 4) {
        fprintf(stderr, "usage: %s points.bin lut.bin out.bin [n_slices]\n", argv[0]);
        return 2;
    }
    int n_slices = (argc > 4) ? atoi(argv[4]) : 720;

    /* 点云 */
    FILE *fp = fopen(argv[1], "rb");
    if (!fp) { perror("points"); return 1; }
    fseek(fp, 0, SEEK_END); long psz = ftell(fp); fseek(fp, 0, SEEK_SET);
    int npts = (int)(psz / 16);
    pov_point_t *pts = malloc((size_t)npts * sizeof(pov_point_t));
    if (fread(pts, 16, (size_t)npts, fp) != (size_t)npts) { fprintf(stderr,"pts read\n"); return 1; }
    fclose(fp);
    fprintf(stderr, "loaded %d points\n", npts);

    /* LUT */
    fp = fopen(argv[2], "rb");
    if (!fp) { perror("lut"); return 1; }
    int16_t *lut = malloc((size_t)POV_NFWI * 2 * sizeof(int16_t));
    if (fread(lut, sizeof(int16_t), (size_t)POV_NFWI*2, fp) != (size_t)POV_NFWI*2) {
        fprintf(stderr, "lut read\n"); return 1;
    }
    fclose(fp);

    /* vox + 切片 */
    uint8_t *vox = calloc(1, POV_VOX_BYTES);
    pov_voxelize(pts, npts, vox);

    uint32_t *slices = malloc((size_t)n_slices * POV_SLICE_BYTES);
    pov_gen_all(vox, lut, n_slices, slices);

    fp = fopen(argv[3], "wb");
    if (!fp) { perror("out"); return 1; }
    fwrite(slices, POV_SLICE_BYTES, (size_t)n_slices, fp);
    fclose(fp);
    fprintf(stderr, "wrote %d slices to %s\n", n_slices, argv[3]);

    free(pts); free(lut); free(vox); free(slices);
    return 0;
}
