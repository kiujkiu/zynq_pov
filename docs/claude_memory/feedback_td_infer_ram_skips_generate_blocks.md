---
name: feedback_td_infer_ram_skips_generate_blocks
description: 🔴 标题的表述是错的 — 有毒的是 generate-FOR 不是 generate; generate-if 与模块作用域逐位等价(2026-08-27 九变体对照实测); 且失败时 TD 一条 WARNING 都不发
metadata:
  type: feedback
---

# 🔴 标题写错了: 有毒的是 **generate-for**, 不是 generate

> **2026-08-27 九变体对照实测把这条规则精确化了。原结论方向对(抽成独立模块有效),
> 但适用范围写宽了一倍, 而且"为什么有效"的理由也是错的。**
> 工程在 `dr1v90/td_ramprobe/`(9 个变体共用同一个量具顶层, 变体之间唯一差别是数组的声明作用域)。
>
> | 变体 | Inferred RAMs | eram20k | reg |
> |---|---|---|---|
> | 模块作用域(基准) | 1 | 1 | 130 |
> | **generate-if** | 1 | 1 | **130 ← 与基准逐位相同** |
> | generate-if 里 9 个数组 | 9 | 9 | 130 |
> | 模块作用域摊开 9 个 | 9 | 9 | 130 |
> | **generate-for(只展开 1 份)** | **0** | **0** | **16546** |
> | generate-for 里不用 genvar(常量索引) | 0 | 0 | 16546 |
> | generate-for 展开 9 份 | 0 | 0 | **147874** |
> | for 里套 if, 数组在 if 里 | 0 | 0 | 16546 |
> | 独立模块被 for 例化 9 次(现行修法) | 1 | **9** | 130 |
>
> **精确条件**: TD 按**声明作用域链**判定 —— 数组声明处往上数, 只要经过一次
> genvar 展开的作用域(generate-for), 就静默推不出 RAM; 经过多少层 generate-if 都不影响。
> 三个边界都实测过: **与循环次数无关**(展开 1 次照样死) / **与用不用 genvar 无关**
> (常量索引照样死) / **向下传染**(for 里套 if, if 里的数组也死)。
>
> 🔴 **修法不变, 但理由要改**: 抽成独立模块之所以有效, **不是"离开了 generate"**,
> 而是数组回到了**子模块的模块作用域**。用 generate-for **例化**子模块完全无害。
> ⇒ 现行 `panel_engine_2047.v` 的写法是对的, 不用动。
>
> ✅ 顺带: `lz4_engine_axi.v` 的 pd/ps/ga/gl 在 **generate-if** 里, 与基准同类,
> TD 推出 6 个 RAM 是**预期行为不是侥幸**。但若将来有人把它们挪进 generate-for
> (比如做多路引擎时按 lane 展开), 会静默多出约 2452 个触发器, **日志一声不吭**。

## 🔴 两条量具陷阱 (2026-08-27 新增, 比规则本身更值得记)

**a) `Inferred N RAMs` 数的是"源码里不同的数组声明", 不是实例数。**
独立模块那档实测 `Inferred 1 RAMs` 却落了 **9 块 eram20k**; td_pov 修复后
`fb_lane_ram` 被例化 18 次, 日志同样只写 `Inferred 1 RAMs`。
⇒ **只看 N 会把"成功"误读成"只成了一个"。判据必须 `Inferred N` + `#eram20k` + `#reg`
三个一起看, 缺一会误判。**

**b) 🔴 失败时 TD 一条 WARNING 都不发。**
失败档的日志 WARNING 行数与健康档**完全一样**(都只有 `hdl_warning_level` 那行参数回显),
ERROR 0 条, 照样出 `.db`、能一路走到 bitgen。
⇒ 唯一可用的早期告警是 **`#reg` 突然暴涨**(9 份那档 147874 已经超过器件的 104960 —— 
**它本身就放不下**, 却依然不报错)。
⇒ **任何带数组的 TD 工程, 都把 `#eram20k` 和 `#reg` 加进自动判据。**
这是本项目"判据全绿不等于没问题"清单上的又一条, 与 [[feedback_only_synthesis_catches_it]]
里的 HDL-5007 位宽不符、SYN-5025 未驱动网静默当 0 是同一类。

---

## 以下是 2026-08-07 的原始记录 (现象与修法仍然有效, 只是适用范围要按上面收窄)

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
