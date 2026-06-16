"""Q15 定点 cos/sin + round-half-away, 跟 HLS cos_sin_q15.h / pov_proj.cpp 逐位一致.
让 PC 切片生成跟板端 HLS 输出 100% 逐字节对齐 (消除浮点 np.rint vs 定点的 ±1 voxel 差)."""
import math
import numpy as np

N = 720
# 跟 _gen_q15_cossin.py 完全一致: round(cos*32768) 再 clamp int16 (cos0=32768→32767)
COS_Q15 = np.array([max(-32768, min(32767, round(math.cos(2*math.pi*a/N)*32768))) for a in range(N)], dtype=np.int64)
SIN_Q15 = np.array([max(-32768, min(32767, round(math.sin(2*math.pi*a/N)*32768))) for a in range(N)], dtype=np.int64)

def q15_round(prod):
    """(prod>=0)? (prod+0x4000)>>15 : -(((-prod)+0x4000)>>15)  对称舍入, 同 pov_proj.cpp q15_round."""
    prod = np.asarray(prod, dtype=np.int64)
    pos = (prod + (1 << 14)) >> 15
    neg = -(((-prod) + (1 << 14)) >> 15)
    return np.where(prod >= 0, pos, neg)

def sample_xz(DD, a):
    """给径向 DD(int) 和角度 a, 返回 (wx偏移前, wz偏移前) 的 Q15 取整值(未 +center). 等价 HLS."""
    return q15_round(DD * int(COS_Q15[a])), q15_round(DD * int(SIN_Q15[a]))
