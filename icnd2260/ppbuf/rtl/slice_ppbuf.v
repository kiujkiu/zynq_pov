//-----------------------------------------------------------------------------
// slice_ppbuf.v -- 切片片上乒乓缓冲 + 片号相位锁 (「切片不落 DDR」拓扑的核心件)
//-----------------------------------------------------------------------------
// 一颗 ICND2260 一片 = NPX 像素 (40x45 样板 1800, 目标 40x48 1920) x RGB565 16 bit。
// 存成 64 位字 (4 px/字) : 写口 64 位 (渲染 IP AXIS 一拍 4 px), 读口 64 位 + 4:1 选道。
//   1800 px -> 450 字, 1920 px -> 480 字 ; 双 bank 各 <= 512 字 => 每颗 2 个 RAMB36 (512x72 SDP)。
//
// 两个时钟域:
//   clk    (位时钟 clkbit, 序列器/发送器) : bank 状态机 / 相位锁 / 读口
//   wr_clk (渲染 IP ap_clk, 第一步用 MMCM 另一路) : 写口 + 填充器
// 跨域只有两根 toggle (fill_req_tog -> / <- fill_ack_tog) 和随之稳定的 fill_bank/fill_tag。
//
// 控制链 (谁产生 / 谁消费):
//   tick, slice_idx   角度跟踪器 -> 本模块      「现在该显示第 slice_idx 片」
//   frame_go          本模块 -> 顶层门控        「允许序列器发 VSYNC 开始这一片」
//   frame_start       顶层 (cmd_valid&ready&VSYNC&running) -> 本模块  「序列器已开始这片」
//   frame_done        顶层 (frame_cnt 变化) -> 本模块  「这片发完, bank 可释放」
//   fill_req/bank/tag 本模块 -> 填充器 (渲染 IP 的 ap_start + phase)  「把第 tag 片渲染进 bank」
//   fill_done         填充器 -> 本模块 (ap_done)
//
// 调度规则: 一有空 bank 且无填充在途, 就下发 next_tag; next_tag 顺序 +1, 但若它不在
//   (slice_idx+1 .. slice_idx+LEAD_MAX) 里就重同步为 slice_idx+1 (渲染卡住后自愈)。
// 显示规则: tick 到达 -> 找 tag==slice_idx 且 FULL 的 bank -> frame_go;
//   若该 bank 还在 FILLING -> 等它 (晚起, 吃帧间空闲); 若没有 -> 补黑一片 (underrun)。
//   FULL 但 tag 已过期 (不在 slice_idx..slice_idx+LEAD_MAX) -> 释放 (stale)。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module slice_ppbuf #(
    parameter integer NCHAIN   = 1,      // 每面链数 (目标 24); 各链一对 bank, 同一 fb_addr 锁步读
    parameter integer NPX      = 1800,   // 每颗每片像素数, 必须是 4 的倍数
    parameter integer FB_AW    = 11,     // 序列器 fb_addr 位宽
    parameter integer TAGW     = 10,     // 片号位宽 (603 档 -> 10 位)
    parameter integer NSLICE   = 603,    // 片/圈
    parameter integer LEAD_MAX = 2       // 渲染最多超前显示几片 (= bank 数)
) (
    // ---- 读侧 / 控制侧 (clk = 位时钟) ---------------------------------------
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 tick,          // 1 拍脉冲: 下一片开始
    input  wire [TAGW-1:0]      slice_idx,     // tick 时刻的片号 (tick 之间恒定)
    input  wire                 frame_start,   // 1 拍: 序列器的 VSYNC 已被发送器接走
    input  wire                 frame_done,    // 1 拍: 序列器发完一片
    input  wire                 stats_clr,     // 1 拍: 计数器清零
    input  wire [15:0]          late_max,      // tick 后最多等多少拍让 FILLING 的 bank 填完 (晚起上限)
                                               //   = 片周期 - 帧长 - 余量; 超过就补黑, 保住下一片不被拖晚
    input  wire [FB_AW-1:0]     fb_addr,       // 序列器读地址 (像素)
    output wire [16*NCHAIN-1:0] px_q,          // 1 拍延迟, 每链 RGB565; 补黑帧恒 0
    output reg                  frame_go,      // 电平: 允许序列器开始下一片, frame_start 清
    output reg                  rd_valid,      // 当前片是真数据 (0 = 补黑)
    output wire                 reading,       // 正在从 bank 读一片真数据 (frame_start..frame_done)
    output reg  [TAGW-1:0]      disp_tag,      // 当前片号
    output reg  [15:0]          underrun_cnt,  // 补黑片数
    output reg  [15:0]          overrun_cnt,   // tick 来时上一片还没发完 (序列器慢)
    output reg  [15:0]          drop_cnt,      // tick 来时上一 tick 的片还没开始 (整片丢)
    output reg  [15:0]          stale_cnt,     // 过期 bank 释放次数
    output reg  [31:0]          fill_cnt,      // 完成的填充次数
    output wire [1:0]           dbg_st0,
    output wire [1:0]           dbg_st1,
    // ---- 写侧 (wr_clk = 渲染 IP 时钟) -----------------------------------------
    input  wire                 wr_clk,
    input  wire                 wr_rst_n,
    output wire                 fill_req,      // 电平: 请填 fill_bank <- 第 fill_tag 片; 保持到 fill_done
    output reg                  fill_bank,
    output reg  [TAGW-1:0]      fill_tag,
    input  wire                 fill_done,     // 1 拍 (wr_clk): 填完
    input  wire                 wr_en,
    input  wire [4:0]           wr_chain,      // 这一拍写哪条链 (0..NCHAIN-1)
    input  wire [8:0]           wr_addr,       // 64 位字地址 (0 .. NPX/4-1)
    input  wire [63:0]          wr_data        // {px3, px2, px1, px0}, px0 = 低 16 位 = 低地址
);
    localparam integer NWORDS = NPX / 4;
    localparam integer AW     = 9;               // 512 字/bank
    localparam [1:0] B_FREE = 2'd0, B_FILLING = 2'd1, B_FULL = 2'd2, B_READING = 2'd3;

    initial begin
        if (NPX % 4 != 0 || NWORDS > 512) begin
            $display("[slice_ppbuf] NPX=%0d 不合法 (须 4 的倍数且 <= 2048)", NPX);
            $fatal(1);
        end
    end

    // ---------------------------------------------------------------------
    // 存储: 每链 2 bank x 512 字 x 64 bit, 写 wr_clk / 读 clk (双时钟简单双口)
    //   目标 24 链: 24 x (1024x64) => 24 x 2 RAMB36 (512x72 SDP) / 面
    // ---------------------------------------------------------------------
    reg        rd_bank;
    genvar gc;
    generate for (gc = 0; gc < NCHAIN; gc = gc + 1) begin : g_chain
        (* ram_style = "block" *) reg [63:0] mem [0:2*512-1];
        reg [63:0] word_q;
        reg [1:0]  lane_q;
        always @(posedge wr_clk)
            if (wr_en && wr_chain == gc) mem[{fill_bank, wr_addr}] <= wr_data;
        always @(posedge clk) begin
            word_q <= mem[{rd_bank, fb_addr[FB_AW-1:2]}];
            lane_q <= fb_addr[1:0];
        end
        wire [15:0] px_raw = word_q[16*lane_q +: 16];
        assign px_q[16*gc +: 16] = rd_valid ? px_raw : 16'h0000;
    end endgenerate

    // ---------------------------------------------------------------------
    // 跨域握手
    // ---------------------------------------------------------------------
    reg  req_tog;                       // clk 域
    reg  [1:0] req_sync;                // -> wr_clk
    reg  ack_tog_w;                     // wr_clk 域
    reg  [1:0] ack_sync;                // -> clk
    (* ASYNC_REG = "TRUE" *) reg [1:0] req_sync_r, ack_sync_r;

    always @(posedge wr_clk) begin
        if (!wr_rst_n) begin req_sync_r <= 2'b00; ack_tog_w <= 1'b0; end
        else begin
            req_sync_r <= {req_sync_r[0], req_tog};
            if (fill_done) ack_tog_w <= ~ack_tog_w;
        end
    end
    assign fill_req = req_sync_r[1] ^ ack_tog_w;

    always @(posedge clk) begin
        if (!rst_n) ack_sync_r <= 2'b00;
        else        ack_sync_r <= {ack_sync_r[0], ack_tog_w};
    end
    wire fill_busy = req_tog ^ ack_sync_r[1];
    reg  fill_busy_d;

    // ---------------------------------------------------------------------
    // bank 状态机 + 相位锁 (clk 域)
    // ---------------------------------------------------------------------
    reg [1:0]      st   [0:1];
    reg [TAGW-1:0] tag  [0:1];
    reg [TAGW-1:0] next_tag;
    reg            tick_pend;
    reg [TAGW-1:0] want_idx;
    reg            frame_busy;
    reg [15:0]     late_cnt;
    assign reading = frame_busy & rd_valid;

    function [TAGW-1:0] mod_inc(input [TAGW-1:0] v);
        mod_inc = (v == NSLICE - 1) ? {TAGW{1'b0}} : v + 1'b1;
    endfunction
    // (a - b) mod NSLICE
    function [TAGW-1:0] mod_sub(input [TAGW-1:0] a, input [TAGW-1:0] b);
        reg [TAGW:0] d;
        begin
            d = {1'b0, a} - {1'b0, b};
            mod_sub = d[TAGW] ? (d[TAGW-1:0] + NSLICE) : d[TAGW-1:0];
        end
    endfunction

    // 🔴 模减法 + 比较有 9 级逻辑, 6 ns 下放不下 (首次布线 WNS -1.633, 路径 tag -> underrun_cnt CE)。
    //    先寄存一拍再用: tag/want_idx/next_tag 变化后决策晚一拍, 靠 tick_d 挡住那一拍。
    reg [TAGW-1:0] d0_r, d1_r, dn_r;
    reg            tick_d;
    //    (这四个寄存器只在这里赋值, 不进主块的复位分支 —— 两处驱动会被综合判 multi-driven)
    always @(posedge clk) begin
        d0_r   <= mod_sub(tag[0], want_idx);
        d1_r   <= mod_sub(tag[1], want_idx);
        dn_r   <= mod_sub(next_tag, slice_idx);
        tick_d <= rst_n & tick;
    end
    wire            hit0   = (st[0] != B_FREE) && (d0_r == 0);
    wire            hit1   = (st[1] != B_FREE) && (d1_r == 0);
    wire            stale0 = (st[0] == B_FULL) && (d0_r > LEAD_MAX);
    wire            stale1 = (st[1] == B_FULL) && (d1_r > LEAD_MAX);
    wire            next_ok = (dn_r != 0) && (dn_r <= LEAD_MAX);

    assign dbg_st0 = st[0];
    assign dbg_st1 = st[1];

    integer b;
    always @(posedge clk) begin
        if (!rst_n) begin
            st[0] <= B_FREE; st[1] <= B_FREE; tag[0] <= 0; tag[1] <= 0;
            next_tag <= 1; tick_pend <= 1'b0; want_idx <= 0; frame_busy <= 1'b0; late_cnt <= 16'd0;
            frame_go <= 1'b0; rd_valid <= 1'b0; rd_bank <= 1'b0; disp_tag <= 0;
            req_tog <= 1'b0; fill_bank <= 1'b0; fill_tag <= 0; fill_busy_d <= 1'b0;
            underrun_cnt <= 0; overrun_cnt <= 0; drop_cnt <= 0; stale_cnt <= 0; fill_cnt <= 0;
        end else begin
            fill_busy_d <= fill_busy;

            if (stats_clr) begin
                underrun_cnt <= 0; overrun_cnt <= 0; drop_cnt <= 0; stale_cnt <= 0; fill_cnt <= 0;
            end

            // ---- 填充完成: FILLING -> FULL ----
            if (fill_busy_d && !fill_busy) begin
                st[fill_bank] <= B_FULL;
                fill_cnt <= fill_cnt + 1;
            end

            // ---- 序列器边界 ----
            if (frame_start) begin frame_go <= 1'b0; frame_busy <= 1'b1; end
            if (frame_done && frame_busy) begin
                frame_busy <= 1'b0;
                if (rd_valid) st[rd_bank] <= B_FREE;
            end

            // ---- tick: 记下要显示的片 ----
            if (tick) begin
                if (tick_pend)  drop_cnt    <= drop_cnt + 1;      // 上一 tick 的片根本没开始
                if (frame_busy) overrun_cnt <= overrun_cnt + 1;   // 上一片还没发完
                tick_pend <= 1'b1;
                want_idx  <= slice_idx;
                late_cnt  <= 16'd0;
            end else if (tick_pend && late_cnt != 16'hFFFF) late_cnt <= late_cnt + 16'd1;

            // ---- 选 bank / 补黑 (要等上一片发完, 且序列器还没被放行) ----
            if (tick_pend && !frame_busy && !frame_go && !tick && !tick_d) begin
                // 过期的 FULL bank 立刻释放, 让调度器能马上重填
                if (stale0) begin st[0] <= B_FREE; stale_cnt <= stale_cnt + 1; end
                if (stale1) begin st[1] <= B_FREE; stale_cnt <= stale_cnt + 1; end
                if (hit0 && st[0] == B_FULL) begin
                    rd_bank <= 1'b0; st[0] <= B_READING; rd_valid <= 1'b1;
                    disp_tag <= want_idx; frame_go <= 1'b1; tick_pend <= 1'b0;
                end else if (hit1 && st[1] == B_FULL) begin
                    rd_bank <= 1'b1; st[1] <= B_READING; rd_valid <= 1'b1;
                    disp_tag <= want_idx; frame_go <= 1'b1; tick_pend <= 1'b0;
                end else if (((hit0 && st[0] == B_FILLING) || (hit1 && st[1] == B_FILLING))
                             && late_cnt < late_max) begin
                    // 还在填且没超晚起上限: 等它变 FULL (吃的是帧间空闲)
                end else begin
                    rd_valid <= 1'b0; disp_tag <= want_idx; frame_go <= 1'b1;
                    tick_pend <= 1'b0; underrun_cnt <= underrun_cnt + 1;
                end
            end

            // ---- 调度: 有空 bank 且无填充在途 -> 下发 ----
            if (!fill_busy && !fill_busy_d && !tick && !tick_d) begin
                if (st[0] == B_FREE || st[1] == B_FREE) begin
                    fill_bank <= (st[0] == B_FREE) ? 1'b0 : 1'b1;
                    if (st[0] == B_FREE) st[0] <= B_FILLING; else st[1] <= B_FILLING;
                    if (next_ok) begin
                        fill_tag <= next_tag;           next_tag <= mod_inc(next_tag);
                    end else begin
                        fill_tag <= mod_inc(slice_idx); next_tag <= mod_inc(mod_inc(slice_idx));
                    end
                    if (st[0] == B_FREE) tag[0] <= next_ok ? next_tag : mod_inc(slice_idx);
                    else                 tag[1] <= next_ok ? next_tag : mod_inc(slice_idx);
                    req_tog <= ~req_tog;
                end
            end
        end
    end

endmodule

`default_nettype wire
