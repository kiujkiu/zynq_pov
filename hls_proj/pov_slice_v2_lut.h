/* pov_slice_v2_lut.h — 按 PV2_LUT_N 选表 (表本身由 tools/gen_pv2_lut.py 生成) */
#ifndef POV_SLICE_V2_LUT_H
#define POV_SLICE_V2_LUT_H
#include "pov_slice_v2.h"

#if PV2_LUT_N == 360
#  include "pov_slice_v2_lut_360.h"
#elif PV2_LUT_N == 603
#  include "pov_slice_v2_lut_603.h"
#else
#  error "没有对应 PV2_LUT_N 的 LUT, 用 tools/gen_pv2_lut.py 生成"
#endif

/* PV2_NUM_ANGLES 在 pov_slice_v2.h 里定义 */
#endif
