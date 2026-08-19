//-----------------------------------------------------------------------------
// icnd2260_ack_rx.v
//-----------------------------------------------------------------------------
// ICND2260 ACK 回传解调器 (脉宽编码 -> 位流 -> 拆包 -> 校验 CRC)
//
// 依据《ICND2260 编程指导 V2.8》第 12 页「ACK 协议」的波形图:
//
//   o_ACK  ────────┐    ┌──┐  ┌─┐   ┌─┐    ┌──┐   ┌───────────
//                  └────┘  └──┘ └───┘ └────┘  └───┘
//          idle(高)  start   w1 w2  w1  w2 ...        idle(高)
//          >10us     >1us(低)
//
//   * **空闲是高电平**, start 是一段 >1us 的低电平
//   * 每一位 = 先高(w1) 后低(w2); **w1 > w2 判 1, w1 < w2 判 0**
//   * 每位总长 1us < w1+w2 < 5us; 帧尾回到高电平 >10us
//   * 判据是**两段的相对长短**, 与绝对速率无关 ⇒ 对芯片时钟偏差天然免疫,
//     CLK_HZ 只用来判「合法/超时」, 不影响判 0/1
//
//   回传内容 = {ACK[3:0], DEVICE[3:0], OFFSET[7:0], LENGTH[7:0],
//               Data0[15:0] … Datan-1[15:0], CHKSUM[15:0]}
//   * ACK[3:0] 默认 4'b0010
//   * LENGTH 是「个数-1」
//   * 数据高位先送 (MSB first)
//   * 🔴 **唯独 CHKSUM 是「从 LSB 开始回传」**(手册原话) —— 与其它域相反,
//     所以下面收到后要按位翻转再比。这条最容易踩, 对不上先试着把 REV_CRC 关掉。
//   * CHECKSUM 覆盖范围: 从 ACK[3:0] 算到最后一个数据字, 初值 0xFFFF
//
// 🔴 CRC 多项式沿用 icnd2260_lvds_tx 里那份从手册 P13 的 LFSR 图反推的
//    CRC-16/CCITT (0x1021)。**本模块就是用来验证那个推断的**:
//    发一条读寄存器指令, 若这里 crc_ok=1 且 data0 等于刚写进去的值, 推断即坐实。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_ack_rx #(
    parameter integer CLK_HZ    = 41_666_667,
    parameter integer MAX_WORDS = 4,     // 最多解多少个 16 位返回值
    parameter integer REV_CRC   = 1      // 1 = CHKSUM 按 LSB 先收 (手册原话)
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ack_pin,          // 直接接引脚, 内部做同步

    output reg         frame_valid,      // 收完一帧, 打一拍脉冲
    output reg         crc_ok,
    output reg         frame_err,        // 位宽越界 / 溢出 / 帧太短
    output reg  [3:0]  f_ack,
    output reg  [3:0]  f_dev,
    output reg  [7:0]  f_off,
    output reg  [7:0]  f_len,
    output reg  [15:0] f_data0,
    output reg  [15:0] f_crc_rx,
    output reg  [15:0] f_crc_calc,
    output reg  [8:0]  f_nbits,
    output wire        busy
);

    localparam integer MAX_BITS = 24 + 16*MAX_WORDS + 16;

    // 时间常数 (拍数)
    localparam integer T_1US  = (CLK_HZ + 999_999)  / 1_000_000;
    localparam integer T_5US  = 5  * T_1US;
    localparam integer T_10US = 10 * T_1US;
    // 帧尾判据: 高电平超过这么久就认为回到 idle (w1 本身 < 5us)
    localparam integer T_END  = 6 * T_1US;

    // ---- 输入同步 --------------------------------------------------------
    reg [2:0] sync;
    always @(posedge clk) sync <= {sync[1:0], ack_pin};
    wire a = sync[2];
    reg  a_d;
    always @(posedge clk) a_d <= a;
    wire rise = a & ~a_d;
    wire fall = ~a & a_d;

    // ---- FSM -------------------------------------------------------------
    localparam [2:0] A_IDLE  = 3'd0,   // 等 start (线上是高, 等一个下降沿)
                     A_START = 3'd1,   // start 低电平, 等上升沿
                     A_W1    = 3'd2,   // 位内高电平段
                     A_W2    = 3'd3,   // 位内低电平段
                     A_CRC   = 3'd4,   // 逐位重算 CRC
                     A_DONE  = 3'd5;

    reg [2:0]  st;
    reg [15:0] w1, w2, tcnt;
    reg [8:0]  nb;
    reg        buf_ [0:MAX_BITS-1];
    reg [8:0]  ci;
    reg [15:0] crc;
    integer    k;

    assign busy = (st != A_IDLE);

    function [15:0] crc_step(input [15:0] c, input b);
        reg fb;
        begin
            fb       = c[15] ^ b;
            crc_step = {c[14:0], 1'b0};
            if (fb) crc_step = crc_step ^ 16'h1021;
        end
    endfunction

    // 取第 i..i+n-1 位 (按到达顺序, 高位先到) 组成的数
    function [15:0] fld(input [8:0] base, input integer n);
        integer j;
        begin
            fld = 16'h0;
            for (j = 0; j < 16; j = j + 1)
                if (j < n) fld = {fld[14:0], buf_[base + j]};
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            st          <= A_IDLE;
            frame_valid <= 1'b0;
            frame_err   <= 1'b0;
            nb          <= 9'd0;
            tcnt        <= 16'd0;
            w1          <= 16'd0;
            w2          <= 16'd0;
            f_nbits     <= 9'd0;
        end else begin
            frame_valid <= 1'b0;

            case (st)
            // ---- 等 start: 线是高的, 等下降沿 -------------------------
            A_IDLE: begin
                nb        <= 9'd0;
                frame_err <= 1'b0;
                if (fall) begin
                    tcnt <= 16'd1;
                    st   <= A_START;
                end
            end

            // ---- start 低电平 (>1us), 上升沿后开始第一位 --------------
            A_START: begin
                tcnt <= tcnt + 16'd1;
                if (rise) begin
                    if (tcnt < T_1US[15:0]) begin
                        st <= A_IDLE;              // 太短, 是毛刺不是 start
                    end else begin
                        tcnt <= 16'd1;
                        st   <= A_W1;
                    end
                end
            end

            // ---- 位内高电平段 w1 --------------------------------------
            A_W1: begin
                tcnt <= tcnt + 16'd1;
                if (fall) begin
                    w1   <= tcnt;
                    tcnt <= 16'd1;
                    st   <= A_W2;
                end else if (tcnt > T_END[15:0]) begin
                    // 高电平超时 ⇒ 回到 idle ⇒ 上一位就是最后一位, 帧结束
                    f_nbits <= nb;
                    if (nb < 9'd56) begin          // 最短一帧 = 24 头 + 16 数据 + 16 CRC
                        frame_err <= 1'b1;
                        st        <= A_IDLE;
                    end else begin
                        crc <= 16'hFFFF;
                        ci  <= 9'd0;
                        st  <= A_CRC;
                    end
                end
            end

            // ---- 位内低电平段 w2, 结束时判 0/1 -------------------------
            A_W2: begin
                tcnt <= tcnt + 16'd1;
                if (rise) begin
                    w2 <= tcnt;
                    if (nb < MAX_BITS[8:0]) begin
                        buf_[nb] <= (w1 > tcnt);   // w1 > w2 ⇒ 1
                        nb       <= nb + 9'd1;
                    end else frame_err <= 1'b1;    // 超出缓冲
                    // 合法性: 1us < w1+w2 < 5us
                    if ((w1 + tcnt) < T_1US[15:0] || (w1 + tcnt) > T_5US[15:0])
                        frame_err <= 1'b1;
                    tcnt <= 16'd1;
                    st   <= A_W1;
                end else if (tcnt > T_10US[15:0]) begin
                    frame_err <= 1'b1;             // 低电平卡住
                    st        <= A_IDLE;
                end
            end

            // ---- 逐位重算 CRC (不含最后 16 位的 CHKSUM) ---------------
            A_CRC: begin
                if (ci < (f_nbits - 9'd16)) begin
                    crc <= crc_step(crc, buf_[ci]);
                    ci  <= ci + 9'd1;
                end else begin
                    st <= A_DONE;
                end
            end

            // ---- 拆包 + 比对 ------------------------------------------
            A_DONE: begin
                f_ack  <= fld(9'd0,  4);
                f_dev  <= fld(9'd4,  4);
                f_off  <= fld(9'd8,  8);
                f_len  <= fld(9'd16, 8);
                f_data0<= fld(9'd24, 16);
                f_crc_calc <= crc;

                // CHKSUM 在最后 16 位; 手册说它是从 LSB 开始回传
                for (k = 0; k < 16; k = k + 1)
                    f_crc_rx[k] <= (REV_CRC != 0) ? buf_[f_nbits - 9'd16 + k[8:0]]
                                                  : buf_[f_nbits - 9'd1  - k[8:0]];

                frame_valid <= 1'b1;
                st          <= A_IDLE;
            end

            default: st <= A_IDLE;
            endcase
        end
    end

    // f_crc_rx / f_crc_calc 在 A_DONE 那拍写入 ⇒ 下一拍比较
    reg valid_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            valid_d <= 1'b0;
            crc_ok  <= 1'b0;
        end else begin
            valid_d <= frame_valid;
            if (valid_d) crc_ok <= (f_crc_rx == f_crc_calc);
        end
    end

endmodule

`default_nettype wire
