## ppbuf_cdc.xdc -- 位时钟 (CLKOUT0/1) 与写时钟 (CLKOUT2) 之间只有 toggle 握手 + 双时钟 BRAM,
## 声明为异步组; 同步器打了 ASYNC_REG。
set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_pins u_mmcm/CLKOUT2]] \
    -group [list [get_clocks -of_objects [get_pins u_mmcm/CLKOUT0]] [get_clocks -of_objects [get_pins u_mmcm/CLKOUT1]]]
