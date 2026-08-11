---
name: feedback_td_infer_ram_skips_generate_blocks
description: TD 5.9.1 的 RAM 推断进不了 generate 块; 数组声明在 generate 里会静默变成触发器(Inferred 0 RAMs), 挪到模块作用域即可
metadata:
  type: feedback
---

# TD 的 RAM 推断进不了 generate 块 (2026-08-07 实测)

## 现象

`panel_engine_2047.v` 的每 lane 帧缓冲是这么写的（Vivado 上推成 18 个 RAMB18E1）：

```verilog
generate for (gi = 0; gi < LANES; gi = gi + 1) begin: g_fb
    reg [31:0] mem [0:511];
    reg [31:0] dout;
    always @(posedge clk) begin
        if (fb_we && fb_wlane == gi[3:0]) mem[fb_waddr] <= fb_wdata;
        dout <= mem[fb_raddr];
    end
    assign fb_dout_flat[gi*32 +: 32] = dout;
end endgenerate
```

TD 5.9.1 综合日志：

```
RUN-1001 :   infer_ram   |   on   |   on            <- 开关本来就是开的
HDL-1100 : Inferred 0 RAMs.
SYN-1032 : 310701/636 useful/useless nets, 309099/19 useful/useless insts
```

⇒ 9 个数组**全部变成触发器**：9 × 512 × 32 × 2 引擎 = **294,912 个 FF**，
而 DR1V90 一共只有 **104,960** 个寄存器。综合到 30 万个实例, 根本放不下。

**注意它不报错也不告警**, 只是在日志里一行 `Inferred 0 RAMs` ——
不专门去看的话, 会一路跑到布局失败才发现, 而那时的错误信息指向的是资源不足, 不是根因。

## 根因与对照证据

同一个工程里 `lz4_decode_core.v` 的 64 KB 历史窗:

```verilog
reg [7:0] hist [0:HIST_SIZE-1];      // <- 模块作用域
always @(posedge clk) begin
    if (hist_we) hist[hist_wa] <= hist_wd;
    if (hist_re) rd_data <= hist[rd_addr_q];
end
```

**正确推成 28 个 eram20k。** 模板本身没问题 —— **差别只在数组声明的位置**。

## 修法

把数组抽进一个独立模块（模块作用域声明），在 generate 里例化它：

```verilog
module fb_lane_ram #(parameter AW=9, DW=32)(
    input wire clk, input wire we,
    input wire [AW-1:0] waddr, input wire [DW-1:0] wdata,
    input wire [AW-1:0] raddr, output reg [DW-1:0] dout);
    reg [DW-1:0] mem [0:(1<<AW)-1];
    always @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
        dout <= mem[raddr];
    end
endmodule
```

行为**逐拍等价**：同地址读写仍是 read-before-write（两条都是非阻塞赋值）。

⚠ 这是 DR1 移植中**唯一**需要改 `panel_engine_2047.v` 的地方
（其余 4 个 RTL 文件仍与 Zynq 版 md5 逐字节相同）。加 `syn_ramstyle` 之类的属性
同样要动文件, 所以抽模块反而是最干净的改法。

## 通用教训

**综合完先 grep 日志里的推断结果, 别等布局失败。** 值得每次都查的三行:
- `Inferred N RAMs` —— N 与预期数组个数对不上就是出事了
- `#eram` / `#reg` / `#slice` 的实际占用
- `#pad reg` —— ODDR 有没有落进 IOL（[[project_dr1_rtl_port_step1]] 里那条）

相关：[[project_dr1_parity_plan]] [[project_lz4_pl_decoder]]
