//-----------------------------------------------------------------------------
// icnd2260_ack_rx_tb.v -- ACK 回传解调器的自校验测试台
//-----------------------------------------------------------------------------
// TB 自己按手册第 12 页的波形**造**一段 ACK 回传 (脉宽编码), 喂给解调器, 对拍拆包结果。
// CRC 由 TB 独立算一遍 (不复用 DUT 的函数结果), 所以能抓出覆盖范围/位序写错。
//
// 造波形的规则 (与手册一致):
//   idle 高 -> start 低 (>1us) -> 每位: 先高 w1 后低 w2, w1>w2 为 1 -> idle 高 (>10us)
//   CHKSUM 按「从 LSB 开始回传」发, 其余域高位先发。
//
// 用例:
//   1. 正常帧 (1 个寄存器) —— 字段与 CRC 全对
//   2. 正常帧 (4 个寄存器) —— 变长也要对
//   3. 故意把 CRC 改错一位 —— crc_ok 必须为 0 (证明校验有牙)
//   4. 一段毛刺 (短低脉冲) —— 不能被当成 start 而误触发
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_ack_rx_tb;

    localparam integer CLK_HZ = 41_666_667;
    localparam real    TCLK   = 24.0;          // ns, = 1/41.667MHz

    reg clk = 1'b0, rst_n = 1'b0;
    always #(TCLK/2.0) clk = ~clk;

    reg ack_pin = 1'b1;                        // 空闲高

    wire        frame_valid, frame_ok, crc_ok, frame_err, busy;
    wire [3:0]  f_ack, f_dev;
    wire [7:0]  f_off, f_len;
    wire [15:0] f_data0, f_crc_rx, f_crc_calc;
    wire [8:0]  f_nbits;

    icnd2260_ack_rx #(.CLK_HZ (CLK_HZ), .MAX_WORDS (4), .REV_CRC (1)) dut (
        .clk (clk), .rst_n (rst_n), .ack_pin (ack_pin),
        .frame_valid (frame_valid), .frame_ok (frame_ok), .crc_ok (crc_ok),
        .frame_err (frame_err),
        .f_ack (f_ack), .f_dev (f_dev), .f_off (f_off), .f_len (f_len),
        .f_data0 (f_data0), .f_crc_rx (f_crc_rx), .f_crc_calc (f_crc_calc),
        .f_nbits (f_nbits), .busy (busy)
    );

    integer errors = 0;
    task fail(input [255:0] tag);
        begin
            $display("[FAIL @%0t] %0s", $time, tag);
            errors = errors + 1;
        end
    endtask

    // ---- TB 侧独立 CRC ---------------------------------------------------
    function [15:0] crc_step(input [15:0] c, input b);
        reg fb;
        begin
            fb       = c[15] ^ b;
            crc_step = {c[14:0], 1'b0};
            if (fb) crc_step = crc_step ^ 16'h1021;
        end
    endfunction

    // ---- 造波形 ----------------------------------------------------------
    task send_bit(input b);
        begin
            // 总长 2us: 1 -> w1=1.4us/w2=0.6us; 0 -> w1=0.6us/w2=1.4us
            ack_pin = 1'b1;  #(b ? 1400 : 600);
            ack_pin = 1'b0;  #(b ? 600  : 1400);
        end
    endtask

    reg [0:511] bits;      // 按到达顺序
    integer     nbits;

    task push(input [15:0] v, input integer n);
        integer j;
        begin
            for (j = n - 1; j >= 0; j = j - 1) begin
                bits[nbits] = v[j];
                nbits = nbits + 1;
            end
        end
    endtask

    // 组一帧: ACK/DEV/OFF/LEN + nword 个数据 + CRC(LSB 先发)
    task build(input [3:0] ac, input [3:0] dv, input [7:0] off,
               input integer nword, input [15:0] d0, input corrupt);
        integer j;
        reg [15:0] c;
        begin
            nbits = 0;
            push({12'h0, ac}, 4);
            push({12'h0, dv}, 4);
            push({8'h0, off}, 8);
            push({8'h0, nword[7:0] - 8'd1}, 8);
            for (j = 0; j < nword; j = j + 1)
                push(d0 + j[15:0], 16);
            // CRC 覆盖上面所有位
            c = 16'hFFFF;
            for (j = 0; j < nbits; j = j + 1) c = crc_step(c, bits[j]);
            if (corrupt) c = c ^ 16'h0040;
            // 🔴 从 LSB 开始回传
            for (j = 0; j < 16; j = j + 1) begin
                bits[nbits] = c[j];
                nbits = nbits + 1;
            end
        end
    endtask

    task send_frame;
        integer j;
        begin
            ack_pin = 1'b1;  #15000;      // idle >10us
            ack_pin = 1'b0;  #2000;       // start >1us
            for (j = 0; j < nbits; j = j + 1) send_bit(bits[j]);
            ack_pin = 1'b1;  #20000;      // 回 idle, 触发帧尾判定
        end
    endtask

    reg [15:0] exp_crc;
    integer    j2;

    task expect_frame(input [3:0] ac, input [3:0] dv, input [7:0] off,
                      input integer nword, input [15:0] d0, input want_crc_ok,
                      input [255:0] tag);
        begin
            if (!frame_valid_seen)          fail({tag, " no_frame"});
            else begin
                if (f_ack  !== ac)          fail({tag, " ack_field"});
                if (f_dev  !== dv)          fail({tag, " dev_field"});
                if (f_off  !== off)         fail({tag, " off_field"});
                if (f_len  !== nword[7:0]-8'd1) fail({tag, " len_field"});
                if (f_data0!== d0)          fail({tag, " data0"});
                if (f_nbits!== 24 + 16*nword + 16) fail({tag, " nbits"});
                if (crc_ok !== want_crc_ok) begin
                    $display("  crc_rx=%04x crc_calc=%04x", f_crc_rx, f_crc_calc);
                    fail({tag, " crc_ok"});
                end
            end
        end
    endtask

    reg frame_valid_seen = 1'b0;
    reg frame_ok_seen    = 1'b0;
    always @(posedge clk) begin
        if (frame_valid) frame_valid_seen <= 1'b1;
        if (frame_ok)    frame_ok_seen    <= 1'b1;
    end

    initial begin
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        repeat (20) @(posedge clk);

        // ---- 用例 1: 1 个寄存器, CRC 正确 ---------------------------------
        frame_valid_seen = 1'b0;  frame_ok_seen = 1'b0;
        build(4'b0010, 4'h0, 8'h00, 1, 16'h3F3C, 1'b0);
        send_frame;
        repeat (40) @(posedge clk);
        expect_frame(4'b0010, 4'h0, 8'h00, 1, 16'h3F3C, 1'b1, "case1");
        if (!frame_ok_seen) fail("case1_frame_ok_should_be_1");

        // ---- 用例 2: 4 个寄存器 -------------------------------------------
        frame_valid_seen = 1'b0;
        build(4'b0010, 4'h3, 8'h20, 4, 16'h6020, 1'b0);
        send_frame;
        repeat (40) @(posedge clk);
        expect_frame(4'b0010, 4'h3, 8'h20, 4, 16'h6020, 1'b1, "case2");

        // ---- 用例 3: CRC 被改坏 -> crc_ok 必须为 0 ------------------------
        frame_valid_seen = 1'b0;
        build(4'b0010, 4'h0, 8'h00, 1, 16'h1234, 1'b1);
        send_frame;
        repeat (40) @(posedge clk);
        expect_frame(4'b0010, 4'h0, 8'h00, 1, 16'h1234, 1'b0, "case3_corrupt");

        // ---- 用例 3b: 头部码不对 -> frame_ok 必须为 0 ---------------------
        // 悬空脚放大噪声解出来的垃圾帧就是靠这道闸挡掉的 (上板实测过 18k 帧/秒)
        frame_valid_seen = 1'b0;  frame_ok_seen = 1'b0;
        build(4'b1011, 4'h0, 8'h00, 1, 16'h1234, 1'b0);   // ACK 码 1011, 不是 0010
        send_frame;
        repeat (40) @(posedge clk);
        if (!frame_valid_seen) fail("case3b_no_frame");
        if (frame_ok_seen)     fail("case3b_frame_ok_should_be_0");

        // ---- 用例 4: 毛刺不能触发 ----------------------------------------
        frame_valid_seen = 1'b0;
        ack_pin = 1'b1;  #15000;
        ack_pin = 1'b0;  #300;        // 300ns << 1us
        ack_pin = 1'b1;  #15000;
        if (frame_valid_seen) fail("case4_glitch_triggered_frame");

        $display("-----------------------------------------------------------");
        if (errors == 0) $display("*** PASS ***");
        else begin
            $display("*** FAIL: %0d ***", errors);
            $fatal(1);
        end
        $finish;
    end

    initial begin
        #50_000_000;
        $display("*** TIMEOUT ***");
        $fatal(1);
    end

endmodule

`default_nettype wire
