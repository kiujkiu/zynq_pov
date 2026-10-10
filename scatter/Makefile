# scatter/Makefile — x86 离线对拍与计时 (不涉及板子)
#
# 目标配置 (192×216, 15.9 MB 网格):   make
# 1bit 验证配置 (160×180, 9.2 MB):     make CFG=1bit
# 2260 验证板 (160×180 / 358 片):      make CFG=vb358 vb_slice_all   (+ vb_slice_all_a64 交叉编)
CC      ?= gcc
CFLAGS  ?= -O2 -std=gnu99 -Wall -Wextra -Wno-unknown-pragmas
LDFLAGS ?=

ifeq ($(CFG),1bit)
CFLAGS += -DPV2_CFG_1BIT
endif
ifeq ($(CFG),vb358)
CFLAGS += -DPV2_CFG_VB358
endif

all: vox_bench vox_slice_check

vox_bench: vox_bench.c vox_scatter.c vox_table.h ../hls_proj/pov_slice_v2.h
	$(CC) $(CFLAGS) -o $@ vox_bench.c vox_scatter.c $(LDFLAGS)

# 🔴 pov_slice_v2.cpp **只读不改** —— 这里用 gcc -x c 直接编它 (文件本身是 C 兼容的,
# 只需补 stdbool; #pragma HLS 在非 HLS 编译器下被忽略, 故 -Wno-unknown-pragmas)。
vox_slice_check: vox_slice_check.c vox_scatter.c ../hls_proj/pov_slice_v2.cpp
	$(CC) $(CFLAGS) -I../hls_proj -o $@ vox_slice_check.c vox_scatter.c \
	    -x c ../hls_proj/pov_slice_v2.cpp -include stdbool.h $(LDFLAGS)

# 验证板端到端 (vb358_e2e.py 调它): VXT1 序列 → scatter → 全角度双面切片
vb_slice_all: vb_slice_all.c vox_scatter.c ../hls_proj/pov_slice_v2.cpp ../hls_proj/pov_slice_v2_lut_358.h
	$(CC) $(CFLAGS) -I../hls_proj -o $@ vb_slice_all.c vox_scatter.c \
	    -x c ../hls_proj/pov_slice_v2.cpp -include stdbool.h $(LDFLAGS)

# 同一份源码给 DR1M90 (aarch64 / A35) 交叉编 —— 只证明能编, 不在本机跑
vb_slice_all_a64: vb_slice_all.c vox_scatter.c ../hls_proj/pov_slice_v2.cpp
	aarch64-linux-gnu-gcc $(CFLAGS) -static -I../hls_proj -o $@ vb_slice_all.c vox_scatter.c \
	    -x c ../hls_proj/pov_slice_v2.cpp -include stdbool.h $(LDFLAGS)

clean:
	rm -f vox_bench vox_slice_check vb_slice_all vb_slice_all_a64

.PHONY: all clean
