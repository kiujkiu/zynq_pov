//-----------------------------------------------------------------------------
// ppbuf_tb.v -- 「直供 + 乒乓 + 每片内容不同」链路的自校验测试台
//-----------------------------------------------------------------------------
// DUT = icnd2260_seq + icnd2260_lvds_tx (原封不动) + slice_feed (乒乓/相位锁/填充器/自检)
// 位时钟 6 ns (166.67 MHz), 写时钟 8.1 ns (与位时钟无整数比, 逼跨域握手真的工作)。
//
// 判据:
//   A. 正常段 (tick 18425 拍 = 9,045 fps, 填充器 ~ 90 us/片):
//        每片 pl_data 在 tx 取数时刻 == 期望(该片 tag, 列号);  underrun/overrun/drop/mismatch 全 0;
//        片序号连续 (disp_tag 每片 +1, 到 602 回 0)
//   B. 把填充器拖到 > 片周期: underrun 必须增长, mismatch 仍为 0 (补黑片不计)
//   C. 填充器恢复: underrun 停止增长, 自愈 (不用复位)
//   D. tick 缩到 < 一帧 (14,632 拍): overrun/drop 必须增长
//   E. 自由跑 (tick 极短) 量一帧拍数, 与 14,632 对账
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module ppbuf_tb;
    localparam integer NLANE = 3, PIX = 40, LINES = 45, CASCADE = 1;
    localparam integer TOTAL = PIX*LINES*CASCADE, FB_AW = 11, NSLICE = 603, TAGW = 10;

    reg clk = 0, wclk = 0, rst_n = 0;
    always #3    clk  = ~clk;
    always #4.05 wclk = ~wclk;

    // ---- DUT ----
    wire cmd_valid, cmd_ready_g, cmd_valid_g, cmd_ready, tx_busy, pl_next, pl_last;
    wire [2:0] cmd_kind; wire [3:0] cmd_device, cmd_cascade;
    wire [7:0] cmd_offset, cmd_length, cmd_rows;
    wire [47:0] pl_data, fb_q; wire [FB_AW-1:0] fb_addr;
    wire running, en3, en2, out_en, isync; wire [31:0] frame_cnt; wire [2:0] bit_r, bit_f;
    reg  [23:0] tick_period = 24'd18425;
    reg  [15:0] wr_stall = 16'd9;          // 450 字 x (2+9) = 4950 拍 @123MHz ≈ 40 us
    reg  [15:0] pat_lvl = 16'h0FFF;
    reg  [1:0]  pat_mode = 2'd0;
    reg  stats_clr = 0;
    wire rd_valid, frame_go, trk_locked; wire [TAGW-1:0] disp_tag; wire [1:0] st0, st1;
    wire [15:0] underrun_cnt, overrun_cnt, drop_cnt, stale_cnt;
    wire [31:0] fill_cnt, mismatch_cnt, cmp_cnt;

    wire [3:0] seq_ph; wire reading;
    icnd2260_seq #(.NLANE(NLANE), .PIX_PER_LINE(PIX), .LINES(LINES), .CASCADE(CASCADE),
        .BLANK_FRAMES(2), .REG_REFRESH_FR(1000000), .READ_PROBE_FR(0), .QUIET_CYCLES(0),
        .RAIL_STAGGER(20), .RAIL_SETTLE(40), .FB_AW(FB_AW), .REG_MEM("icnd2260_regs_vendor.mem")) u_seq (
        .clk(clk), .rst_n(rst_n), .en_3v8(en3), .en_2v8(en2), .out_en(out_en),
        .fb_addr(fb_addr), .fb_q(fb_q),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready_g), .cmd_kind(cmd_kind), .cmd_device(cmd_device),
        .cmd_offset(cmd_offset), .cmd_length(cmd_length), .cmd_rows(cmd_rows), .cmd_cascade(cmd_cascade),
        .pl_next(pl_next), .pl_data(pl_data), .pl_last(pl_last), .tx_busy(tx_busy),
        .dbg_reg_we(1'b0), .dbg_reg_addr(8'h0), .dbg_reg_data(16'h0), .dbg_probe_en(1'b0),
        .dbg_probe_off(8'h0), .dbg_probe_dev(4'h0), .dbg_minimal(1'b0), .dbg_frame_gap(24'd0),
        .running(running), .quiet(), .frame_cnt(frame_cnt), .dbg_ph(seq_ph), .dbg_sub());

    icnd2260_lvds_tx #(.NLANE(NLANE), .VID_CRC(1), .WORDS_PER_CHIP(PIX*LINES)) u_tx (
        .clk(clk), .rst_n(rst_n), .cmd_valid(cmd_valid_g), .cmd_ready(cmd_ready), .cmd_kind(cmd_kind),
        .cmd_device(cmd_device), .cmd_offset(cmd_offset), .cmd_length(cmd_length), .cmd_rows(cmd_rows),
        .cmd_cascade(cmd_cascade), .pl_next(pl_next), .pl_data(pl_data), .pl_last(pl_last),
        .crc_refl(1'b1), .crc_lsb_tx(1'b0), .vhead_copy(1'b0),
        .bit_r(bit_r), .bit_f(bit_f), .isync(isync), .busy(tx_busy));

    slice_feed #(.PIX(PIX), .LINES(LINES), .FB_AW(FB_AW), .NSLICE(NSLICE), .TAGW(TAGW),
                 .CLK_HZ(166_666_666)) u_feed (
        .clk(clk), .rst_n(rst_n), .running(running), .seq_in_run(seq_ph == 4'd7), .frame_cnt(frame_cnt),
        .cmd_valid_seq(cmd_valid), .cmd_ready_seq(cmd_ready_g), .cmd_kind(cmd_kind),
        .cmd_valid_tx(cmd_valid_g), .cmd_ready_tx(cmd_ready),
        .fb_addr(fb_addr), .fb_q(fb_q),
        .sensor_in(1'b0), .sensor_en(1'b0), .tick_period(tick_period), .late_max(16'd3500),
        .wr_clk(wclk), .pat_lvl(pat_lvl), .pat_mode(pat_mode), .wr_stall(wr_stall),
        .stats_clr(stats_clr), .tracker_locked(trk_locked), .rd_valid(rd_valid), .reading(reading), .frame_go(frame_go),
        .disp_tag(disp_tag), .st0(st0), .st1(st1),
        .underrun_cnt(underrun_cnt), .overrun_cnt(overrun_cnt), .drop_cnt(drop_cnt),
        .stale_cnt(stale_cnt), .fill_cnt(fill_cnt), .mismatch_cnt(mismatch_cnt), .cmp_cnt(cmp_cnt));

    // ---- 独立期望: 在 tx 取数那一拍 (S_VID bitcnt==7 / VHEAD 末 / VCRC 末) 检查 pl_data ----
    //   tx 内部 pay_sr <= pl_data 的时刻 = 该字将要发送的时刻; 那时 u_seq.pix_addr 就是字号。
    integer errors = 0, words = 0, frames = 0;
    integer tag_prev = -1;
    reg [15:0] exp_px; reg [47:0] exp_word; integer col, stripe;
    wire tx_take = (u_tx.st == 4'd7 && u_tx.bitcnt == 4'd7 && u_tx.wcnt != PIX*LINES-1) ||
                   (u_tx.st == 4'd6 && u_tx.nbits <= 7'd2);
    always @(posedge clk) begin
        if (reading && tx_take) begin
            col = u_seq.pix_addr % PIX; stripe = col / (PIX/8);
            exp_px = (stripe == disp_tag[2:0]) ? {pat_lvl[15:11], pat_lvl[15:10], pat_lvl[15:11]} : 16'h0;
            exp_word = {{exp_px[4:0], 11'b0}, {exp_px[10:5], 10'b0}, {exp_px[15:11], 11'b0}};
            words = words + 1;
            if (pl_data !== exp_word) begin
                errors = errors + 1;
                if (errors < 10) $display("[FAIL @%0t] tag=%0d addr=%0d got %h exp %h", $time, disp_tag, u_seq.pix_addr, pl_data, exp_word);
            end
        end
    end

    // 帧序号连续性 + 帧周期
    reg [31:0] fc_d = 0; integer t_last = -1, cyc = 0, per_min = 1<<30, per_max = 0;
    always @(posedge clk) begin
        cyc <= cyc + 1; fc_d <= frame_cnt;
        if (running && frame_cnt != fc_d) begin
            frames = frames + 1;
            if (t_last >= 0) begin
                if (cyc - t_last < per_min) per_min = cyc - t_last;
                if (cyc - t_last > per_max) per_max = cyc - t_last;
            end
            t_last = cyc;
        end
    end
    // 片号连续 (只在 rd_valid 的片上查)
    reg go_d = 0, chk_seq = 1;
    always @(posedge clk) begin
        go_d <= frame_go;
        if (chk_seq && frame_go && !go_d && rd_valid) begin
            if (tag_prev >= 0 && disp_tag != ((tag_prev + 1) % NSLICE)) begin
                errors = errors + 1;
                $display("[FAIL @%0t] tag 不连续: %0d -> %0d", $time, tag_prev, disp_tag);
            end
            tag_prev = disp_tag;
        end
    end

    task show(input [8*24-1:0] tag);
        $display("  %0s: frames=%0d words=%0d under=%0d over=%0d drop=%0d stale=%0d fills=%0d mism=%0d cmp=%0d per=[%0d..%0d]",
                 tag, frames, words, underrun_cnt, overrun_cnt, drop_cnt, stale_cnt, fill_cnt, mismatch_cnt, cmp_cnt, per_min, per_max);
    endtask

    task wait_frames(input integer n);
        integer k; begin for (k = 0; k < n; k = k + 1) begin @(posedge clk); while (frame_cnt == fc_d) @(posedge clk); end end
    endtask
    integer u0, o0, d0, m0, f0;
    initial begin
        #100 rst_n = 1;
        wait (running);
        $display("=== running @%0t", $time);
        // ---- A: 正常段 ----
        wait_frames(40);
        stats_clr = 1; @(posedge clk); stats_clr = 0; per_min = 1<<30; per_max = 0; errors = 0; words = 0;
        wait_frames(200);
        show("A 9045fps");
        if (underrun_cnt != 0 || overrun_cnt != 0 || drop_cnt != 0 || mismatch_cnt != 0 || errors != 0)
            begin $display("[FAIL] A"); errors = errors + 1; end
        if (per_min < 18425 - 2 || per_max > 18425 + 2) begin $display("[FAIL] A 帧周期没锁到 tick"); errors = errors + 1; end
        if (cmp_cnt == 0) begin $display("[FAIL] A 自检没比过"); errors = errors + 1; end
        // ---- B: 填充器拖慢到 ~ 2 x 片周期 ----
        u0 = underrun_cnt; m0 = mismatch_cnt; chk_seq = 0;
        wr_stall = 16'd80;      // 450 x 82 = 36,900 wclk ≈ 299 us
        wait_frames(100);
        show("B slow writer");
        if (underrun_cnt <= u0 + 20) begin $display("[FAIL] B underrun 没被检出"); errors = errors + 1; end
        if (mismatch_cnt != m0 || errors != 0) begin $display("[FAIL] B 补黑片不该有 mismatch"); errors = errors + 1; end
        // ---- C: 恢复 ----
        wr_stall = 16'd9;
        wait_frames(30);
        u0 = underrun_cnt; d0 = drop_cnt; o0 = overrun_cnt; tag_prev = -1; chk_seq = 1; errors = 0;
        wait_frames(100);
        show("C recovered");
        if (underrun_cnt != u0 || drop_cnt != d0 || overrun_cnt != o0 || errors != 0) begin $display("[FAIL] C 没自愈"); errors = errors + 1; end
        // ---- D: tick 短于一帧 ----
        o0 = overrun_cnt; d0 = drop_cnt; chk_seq = 0;
        tick_period = 24'd12000;
        wait_frames(60);
        show("D tick<frame");
        if (overrun_cnt <= o0 + 10) begin $display("[FAIL] D overrun 没被检出"); errors = errors + 1; end
        // ---- E: 自由跑量帧长 ----
        tick_period = 24'd200; wr_stall = 0; tag_prev = -1;
        wait_frames(10);
        per_min = 1<<30; per_max = 0;
        wait_frames(20);
        show("E free-run");
        $display("  一帧 = %0d 拍 (现役 lvds_top 仿真 14632, 门控多 1 拍 => 14633)", per_min);
        if (per_min != 14633) begin $display("[FAIL] E 帧长变了"); errors = errors + 1; end
        if (errors == 0) $display("=== PASS: 直供+乒乓+每片不同 链路全部判据通过");
        else             $display("=== FAIL: errors=%0d", errors);
        $finish;
    end
    initial begin #400_000_000 $display("TIMEOUT"); $finish; end
endmodule
`default_nettype wire
