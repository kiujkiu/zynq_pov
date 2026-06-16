import math
N=720
cos=[round(math.cos(2*math.pi*a/N)*32768) for a in range(N)]
sin=[round(math.sin(2*math.pi*a/N)*32768) for a in range(N)]
cos=[max(-32768,min(32767,v)) for v in cos]
sin=[max(-32768,min(32767,v)) for v in sin]
def emit(name,arr):
    s=f"static const int16_t {name}[{N}] = {{\n"
    for i in range(0,N,12):
        s+="    "+", ".join(f"{v:6d}" for v in arr[i:i+12])+",\n"
    s+="};\n"
    return s
hdr="/* cos_sin_q15.h - 720-entry Q15 cos/sin LUT. cos/sin(2*pi*a/720)*32768.\n"
hdr+=" * round(d*cos) = (d*COS_Q15[a] + (1<<14)) >> 15 等价 PC 端 np.rint(d*cosθ). */\n"
hdr+="#ifndef COS_SIN_Q15_H\n#define COS_SIN_Q15_H\n#include <stdint.h>\n\n"
hdr+=emit("COS_Q15",cos)+"\n"+emit("SIN_Q15",sin)+"\n#endif\n"
open(r'D:\claude_workspace\pov3d\zynq_pov\02_hello_zynq\hls_pov\cos_sin_q15.h','w').write(hdr)
print("wrote cos_sin_q15.h",N,"entries; COS_Q15[0]",cos[0],"SIN_Q15[180]",sin[180])
