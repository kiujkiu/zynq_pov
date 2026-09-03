//-----------------------------------------------------------------------------
// pat_writer.v -- 第一步验证用「每片内容不同」的图案填充器 (顶替渲染 IP)
//-----------------------------------------------------------------------------
// 工作在 wr_clk 域。收到 fill_req (电平) 就把第 fill_tag 片写进 bank:
//   帧相位条纹 (与 icnd2260_lxb_lvds_top.v 的 mode 7 同一判据, 已上板验证过量法):
//   40 列切 8 条竖带 (每条 5 列), 第 tag 片只点亮第 (tag mod 8) 条。
//   芯片每片都显示 => 8 条 1/8 占空全亮; 相机 1/2000 s 下亮 4~5 条 (9,045 fps)。
//   像素 RGB565 = 亮: {lvl[15:11], lvl[15:10], lvl[15:11]}  灭: 0
// 一拍写 4 px (一个 64 位字), 450 字 = 450 拍 (无 stall)。
// wr_stall: 每字之间再等 wr_stall 拍 —— 用来把填充器拖慢, 逼出 underrun 验证检测链
//   (量具要先证明自己会报错)。目标口径下渲染 IP 一片 ~69~94 us, 对应 stall≈9 @125MHz。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module pat_writer #(
    parameter integer NPX     = 1800,
    parameter integer PIX     = 40,       // 每扫描行像素数 (须是 4 的倍数)
    parameter integer NSTRIPE = 8,
    parameter integer TAGW    = 10
) (
    input  wire            wr_clk,
    input  wire            wr_rst_n,
    input  wire            fill_req,
    input  wire [TAGW-1:0] fill_tag,
    input  wire [15:0]     pat_lvl,      // 亮度 (线上 16 bit 口径, 取高位)
    input  wire [1:0]      pat_mode,     // 0=相位条纹 1=全亮 2=全灭 3=tag 灰阶(低 5 位 -> R)
    input  wire [15:0]     wr_stall,
    output reg             fill_done,    // 1 拍
    output reg             wr_en,
    output reg  [8:0]      wr_addr,
    output reg  [63:0]     wr_data
);
    localparam integer NWORDS   = NPX / 4;
    localparam integer STRIPE_W = PIX / NSTRIPE;

    function [2:0] stripe_of(input [6:0] col);
        stripe_of = col / STRIPE_W;
    endfunction

    function [15:0] px_of(input on);
        px_of = on ? {pat_lvl[15:11], pat_lvl[15:10], pat_lvl[15:11]} : 16'h0000;
    endfunction

    reg [1:0]  st;
    reg [6:0]  col;          // 当前字第 0 个像素的列号 (0..PIX-4, 步进 4)
    reg [15:0] stall_cnt;
    reg        req_d;

    wire [2:0] tsel = fill_tag[2:0];
    wire on0 = (pat_mode == 2'd1) || (pat_mode == 2'd0 && stripe_of(col    ) == tsel);
    wire on1 = (pat_mode == 2'd1) || (pat_mode == 2'd0 && stripe_of(col + 1) == tsel);
    wire on2 = (pat_mode == 2'd1) || (pat_mode == 2'd0 && stripe_of(col + 2) == tsel);
    wire on3 = (pat_mode == 2'd1) || (pat_mode == 2'd0 && stripe_of(col + 3) == tsel);
    wire [15:0] gray = {fill_tag[4:0], 11'b0};
    wire [63:0] word = (pat_mode == 2'd3) ? {4{gray}}
                                          : {px_of(on3), px_of(on2), px_of(on1), px_of(on0)};

    always @(posedge wr_clk) begin
        if (!wr_rst_n) begin
            st <= 2'd0; wr_en <= 1'b0; wr_addr <= 9'd0; wr_data <= 64'd0;
            col <= 7'd0; stall_cnt <= 16'd0; fill_done <= 1'b0; req_d <= 1'b0;
        end else begin
            wr_en <= 1'b0; fill_done <= 1'b0;
            req_d <= fill_req;
            case (st)
            2'd0: if (fill_req && !req_d) begin      // 上升沿开始
                      wr_addr <= 9'd0; col <= 7'd0; stall_cnt <= 16'd0; st <= 2'd1;
                  end
            2'd1: begin                              // 写一个字
                      wr_en   <= 1'b1;
                      wr_data <= word;
                      col     <= (col >= PIX - 4) ? 7'd0 : col + 7'd4;
                      st      <= 2'd2;
                  end
            2'd2: begin                              // stall / 推进地址
                      if (stall_cnt < wr_stall) stall_cnt <= stall_cnt + 16'd1;
                      else begin
                          stall_cnt <= 16'd0;
                          if (wr_addr == NWORDS - 1) begin st <= 2'd3; end
                          else begin wr_addr <= wr_addr + 9'd1; st <= 2'd1; end
                      end
                  end
            2'd3: begin fill_done <= 1'b1; st <= 2'd0; end   // 最后一个字已落, 报完成
            endcase
        end
    end
endmodule

`default_nettype wire
