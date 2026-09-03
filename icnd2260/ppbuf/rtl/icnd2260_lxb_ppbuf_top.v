//-----------------------------------------------------------------------------
// icnd2260_lxb_ppbuf_top.v
//-----------------------------------------------------------------------------
// 「切片不落 DDR」拓扑的第一步验证顶层 (鹿小班 + 单颗 ICND2260 40x45, mini-LVDS)。
//
// 与 icnd2260_lxb_lvds_top.v 的唯一实质差别: 帧缓存 ROM 换成
//     pat_writer (wr_clk 域, 顶替渲染 IP) --64bit--> slice_ppbuf (乒乓, 跨域) --16bit--> 序列器
// 序列器 (icnd2260_seq.v) 与发送器 (icnd2260_lvds_tx.v) **一行不改**:
//   * 相位锁靠顶层门住 VSYNC 指令的 valid/ready (seq 在 P_WAIT 里举着 cmd_valid 等)
//   * 片 tick 来自 angle_tracker (假模式, 周期 VIO 可调; 真转子时接 sensor_in)
// 片上自检: 读侧按 (disp_tag, 列号) 重算期望像素与 BRAM 读出逐拍比对 -> mismatch_cnt。
//   它与 underrun/overrun/drop/stale 四个计数器一起, 是这条链在 11,000 fps 下
//   「每片内容确实不同且正确」的硬判据; 相机的帧相位条纹只是第二判据。
//
// 时钟: clkbit = VCO/CLK_DIV (位时钟), clkwr = VCO/WR_DIV (顶替渲染 IP 的 ap_clk)。
//   两者同源但频率不同, XDC 里声明为异步组; 跨域只走 slice_ppbuf 里的 toggle 握手。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_lxb_ppbuf_top #(
    parameter integer NLANE   = 3,
    parameter integer PIX     = 40,
    parameter integer LINES   = 45,
    parameter integer CASCADE = 1,      // 本拓扑每链一颗
    parameter integer CLK_DIV = 6,      // 166.67 MHz
    parameter integer WR_DIV  = 8,      // 125 MHz (顶替 150MHz ap_clk)
    parameter integer VCO_MULT_X8 = 160,
    parameter integer CLK_PHASE_X8 = 720,
    parameter integer CLK_SAME_TREE = 0,
    parameter integer BLANK_FRAMES = 64,
    parameter integer RAIL_STAGGER   = 25_000,
    parameter integer RAIL_SETTLE    = 500_000,
    // 🔴 整表刷新一帧要多花 7,854 拍 (47 us) => 装不进 110.6 us 的片槽, 会每 64 片欠载一次。
    //    第一步先关掉 (量产要改成供应商那种每帧 16 个寄存器的滚动刷新)。
    parameter integer REG_REFRESH_FR = 1_000_000,
    parameter integer VID_CRC = 1,
    parameter integer NSLICE  = 603,
    parameter integer TICK_INIT = 18425,  // 166.67MHz / 9,045 fps
    parameter          REG_MEM = "icnd2260_regs_vendor.mem",
    parameter integer DEBUG = 0
) (
    input  wire clk50,
    output wire clk_p, clk_n,
    output wire b_p,   b_n,
    output wire g_p,   g_n,
    output wire r_p,   r_n,
    output wire sync,
    input  wire ack,          // 本板未接, 仅为 XDC 保留
    output wire dclk,
    output wire en_3v8,
    output wire en_2v8,
    output wire [1:0] led
);
    localparam integer TOTAL_PIX = PIX * LINES * CASCADE;
    localparam integer BITCLK_HZ = (50_000_000/8) * VCO_MULT_X8 / CLK_DIV;
    function integer clog2(input integer v);
        integer i; begin clog2 = 0; for (i = v - 1; i > 0; i = i >> 1) clog2 = clog2 + 1; end
    endfunction
    localparam integer FB_AW     = clog2(TOTAL_PIX);
    localparam real    CLK_PHASE = CLK_PHASE_X8 / 8.0;
    localparam integer TAGW = 10;

    // ---------------------------------------------------------------------
    // 时钟
    // ---------------------------------------------------------------------
    wire clkfb, clkfb_buf, clkbit_raw, clkbit90_raw, clkwr_raw;
    wire clkbit, clkbit90, clkwr, mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"), .CLKIN1_PERIOD(20.000),
        .CLKFBOUT_MULT_F(VCO_MULT_X8/8.0), .DIVCLK_DIVIDE(1),
        .CLKOUT0_DIVIDE_F(CLK_DIV), .CLKOUT1_DIVIDE(CLK_DIV), .CLKOUT1_PHASE(CLK_PHASE),
        .CLKOUT2_DIVIDE(WR_DIV), .STARTUP_WAIT("FALSE")
    ) u_mmcm (
        .CLKIN1(clk50), .CLKFBIN(clkfb_buf), .CLKFBOUT(clkfb),
        .CLKOUT0(clkbit_raw), .CLKOUT1(clkbit90_raw), .CLKOUT2(clkwr_raw),
        .CLKOUT3(), .CLKOUT4(), .CLKOUT5(), .CLKOUT6(),
        .CLKOUT0B(), .CLKOUT1B(), .CLKOUT2B(), .CLKOUT3B(), .CLKFBOUTB(),
        .LOCKED(mmcm_locked), .PWRDWN(1'b0), .RST(1'b0)
    );
    BUFG u_bufg_fb (.I(clkfb),        .O(clkfb_buf));
    BUFG u_bufg_0  (.I(clkbit_raw),   .O(clkbit));
    BUFG u_bufg_90 (.I(clkbit90_raw), .O(clkbit90));
    BUFG u_bufg_wr (.I(clkwr_raw),    .O(clkwr));

    reg [7:0] por_cnt = 8'd0;
    reg       rst_n   = 1'b0;
    always @(posedge clkbit) begin
        if (!mmcm_locked) begin por_cnt <= 8'd0; rst_n <= 1'b0; end
        else if (!por_cnt[7]) por_cnt <= por_cnt + 8'd1;
        else                  rst_n   <= 1'b1;
    end

    // ---- 调试口 ---------------------------------------------------------
    wire        dbg_reg_we;
    wire [7:0]  dbg_reg_addr;
    wire [15:0] dbg_reg_data;
    wire        dbg_soft_rst;
    wire [3:0]  dbg_pn_inv;
    wire        dbg_crc_refl, dbg_crc_lsb, dbg_vhead_copy, dbg_ck_free;
    wire [15:0] dbg_pat_lvl;
    wire [1:0]  dbg_pat_mode;
    wire [23:0] dbg_tick_period;
    wire [15:0] dbg_wr_stall;
    wire [15:0] dbg_late_max;
    wire        dbg_sensor_en;
    wire        dbg_stats_clr;
    wire [3:0]  dbg_ph; wire [1:0] dbg_sub;

    wire rst_n_eff = rst_n & ~dbg_soft_rst;
    // 转子光电/霍尔 (1 脉冲/圈)。鹿小班+转接板上还没引脚, 第一步只跑假模式;
    // 接真传感器时改成顶层输入 + XDC 约束, 并在 VIO 把 sensor_en 置 1。
    wire sensor_in = 1'b0;

    // ---------------------------------------------------------------------
    // 序列器 + 发送器 (原封不动)
    // ---------------------------------------------------------------------
    wire                 cmd_valid, cmd_ready, tx_busy;
    wire [2:0]           cmd_kind;
    wire [3:0]           cmd_device, cmd_cascade;
    wire [7:0]           cmd_offset, cmd_length, cmd_rows;
    wire                 pl_next, pl_last;
    wire [16*NLANE-1:0]  pl_data;
    wire                 out_en, running;
    wire [31:0]          frame_cnt;
    wire [NLANE-1:0]     bit_r, bit_f;
    wire                 isync;
    wire [FB_AW-1:0]     fb_addr;
    wire                 frame_go;

    wire cmd_valid_g, cmd_ready_g;
    wire [16*NLANE-1:0] fb_q;
    wire rd_valid, tracker_locked;
    wire [TAGW-1:0] disp_tag;
    wire [1:0]  st0, st1;
    wire [15:0] underrun_cnt, overrun_cnt, drop_cnt, stale_cnt;
    wire [31:0] fill_cnt, mismatch_cnt, cmp_cnt;

    icnd2260_seq #(
        .NLANE(NLANE), .PIX_PER_LINE(PIX), .LINES(LINES), .CASCADE(CASCADE),
        .BLANK_FRAMES(BLANK_FRAMES), .FRAME_GAP(0),
        .RAIL_STAGGER(RAIL_STAGGER), .RAIL_SETTLE(RAIL_SETTLE),
        .REG_REFRESH_FR(REG_REFRESH_FR), .READ_PROBE_FR(0), .QUIET_CYCLES(0),
        .FB_AW(FB_AW), .REG_MEM(REG_MEM)
    ) u_seq (
        .clk(clkbit), .rst_n(rst_n_eff),
        .en_3v8(en_3v8), .en_2v8(en_2v8), .out_en(out_en),
        .fb_addr(fb_addr), .fb_q(fb_q),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready_g), .cmd_kind(cmd_kind),
        .cmd_device(cmd_device), .cmd_offset(cmd_offset),
        .cmd_length(cmd_length), .cmd_rows(cmd_rows), .cmd_cascade(cmd_cascade),
        .pl_next(pl_next), .pl_data(pl_data), .pl_last(pl_last),
        .tx_busy(tx_busy), .running(running), .frame_cnt(frame_cnt),
        .dbg_reg_we(dbg_reg_we), .dbg_reg_addr(dbg_reg_addr), .dbg_reg_data(dbg_reg_data),
        .dbg_probe_en(1'b0), .dbg_probe_off(8'h00), .dbg_probe_dev(4'h0), .dbg_minimal(1'b0),
        .dbg_frame_gap(24'd0), .quiet(), .dbg_ph(dbg_ph), .dbg_sub(dbg_sub)
    );

    icnd2260_lvds_tx #(.PIX_BW8(0), .NLANE(NLANE), .VID_CRC(VID_CRC),
                       .WORDS_PER_CHIP(PIX * LINES)) u_tx (
        .clk(clkbit), .rst_n(rst_n_eff),
        .cmd_valid(cmd_valid_g), .cmd_ready(cmd_ready), .cmd_kind(cmd_kind),
        .cmd_device(cmd_device), .cmd_offset(cmd_offset),
        .cmd_length(cmd_length), .cmd_rows(cmd_rows), .cmd_cascade(cmd_cascade),
        .pl_next(pl_next), .pl_data(pl_data), .pl_last(pl_last),
        .crc_refl(dbg_crc_refl), .crc_lsb_tx(dbg_crc_lsb), .vhead_copy(dbg_vhead_copy),
        .bit_r(bit_r), .bit_f(bit_f), .isync(isync), .busy(tx_busy)
    );

    // ---------------------------------------------------------------------
    // 直供胶水: 角度跟踪 + 乒乓缓冲 + 填充器 + VSYNC 门控 + 自检
    // ---------------------------------------------------------------------
    slice_feed #(.PIX(PIX), .LINES(LINES), .FB_AW(FB_AW), .NSLICE(NSLICE), .TAGW(TAGW),
                 .CLK_HZ(BITCLK_HZ)) u_feed (
        .clk(clkbit), .rst_n(rst_n_eff), .running(running), .seq_in_run(dbg_ph == 4'd7), .frame_cnt(frame_cnt),
        .cmd_valid_seq(cmd_valid), .cmd_ready_seq(cmd_ready_g), .cmd_kind(cmd_kind),
        .cmd_valid_tx(cmd_valid_g), .cmd_ready_tx(cmd_ready),
        .fb_addr(fb_addr), .fb_q(fb_q),
        .sensor_in(sensor_in), .sensor_en(dbg_sensor_en), .tick_period(dbg_tick_period), .late_max(dbg_late_max),
        .wr_clk(clkwr), .pat_lvl(dbg_pat_lvl), .pat_mode(dbg_pat_mode), .wr_stall(dbg_wr_stall),
        .stats_clr(dbg_stats_clr), .tracker_locked(tracker_locked), .rd_valid(rd_valid), .reading(),
        .frame_go(frame_go), .disp_tag(disp_tag), .st0(st0), .st1(st1),
        .underrun_cnt(underrun_cnt), .overrun_cnt(overrun_cnt), .drop_cnt(drop_cnt),
        .stale_cnt(stale_cnt), .fill_cnt(fill_cnt), .mismatch_cnt(mismatch_cnt), .cmp_cnt(cmp_cnt)
    );

    // ---------------------------------------------------------------------
    // IOB (与 lvds_top 相同)
    // ---------------------------------------------------------------------
    wire [NLANE-1:0] d_r = (bit_r & {NLANE{out_en}}) ^ dbg_pn_inv[NLANE-1:0];
    wire [NLANE-1:0] d_f = (bit_f & {NLANE{out_en}}) ^ dbg_pn_inv[NLANE-1:0];
    wire [NLANE-1:0] lane_q;
    genvar gi;
    generate for (gi = 0; gi < NLANE; gi = gi + 1) begin : g_lane
        ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC"))
        u_oddr (.Q(lane_q[gi]), .C(clkbit), .CE(1'b1), .D1(d_r[gi]), .D2(d_f[gi]), .R(1'b0), .S(1'b0));
    end endgenerate
    OBUFDS u_obuf_d0 (.I(lane_q[0]), .O(b_p), .OB(b_n));
    OBUFDS u_obuf_d1 (.I(lane_q[1]), .O(g_p), .OB(g_n));
    OBUFDS u_obuf_d2 (.I(lane_q[2]), .O(r_p), .OB(r_n));

    wire clkfwd;
    wire ck_oddr_c = (CLK_SAME_TREE != 0) ? clkbit : clkbit90;
    reg ck_rst_q = 1'b1, ck_inv_q = 1'b0;
    always @(posedge ck_oddr_c) begin
        ck_rst_q <= dbg_ck_free ? ~(en_2v8 | en_3v8) : ~out_en;
        ck_inv_q <= dbg_pn_inv[3];
    end
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC"))
    u_oddr_ck (.Q(clkfwd), .C(ck_oddr_c), .CE(1'b1), .D1(~ck_inv_q), .D2(ck_inv_q), .R(ck_rst_q), .S(1'b0));
    OBUFDS u_obuf_ck (.I(clkfwd), .O(clk_p), .OB(clk_n));

    (* IOB = "TRUE" *) reg sync_q;
    always @(posedge clkbit) sync_q <= out_en ? isync : 1'b0;
    assign sync = sync_q;
    assign dclk = 1'b0;

    // ---- 硬件测帧率 ------------------------------------------------------
    reg [31:0] sec_cnt = 0, frame_mark = 0, fps_latched = 0;
    always @(posedge clkbit) begin
        if (!rst_n_eff) begin sec_cnt <= 0; frame_mark <= 0; fps_latched <= 0; end
        else if (sec_cnt >= BITCLK_HZ - 1) begin
            sec_cnt <= 0; fps_latched <= frame_cnt - frame_mark; frame_mark <= frame_cnt;
        end else sec_cnt <= sec_cnt + 1;
    end

    // ---------------------------------------------------------------------
    // VIO (DEBUG=1)
    // ---------------------------------------------------------------------
    generate if (DEBUG != 0) begin : g_dbg
        wire [7:0]  o_addr;  wire [15:0] o_data;
        wire [0:0]  o_we_tog, o_soft_rst, o_sensor_en, o_stats_clr;
        wire [3:0]  o_pn_inv, o_crc_mode;
        wire [15:0] o_pat_lvl, o_wr_stall, o_late_max;
        wire [1:0]  o_pat_mode;
        wire [23:0] o_tick_period;
        reg we_tog_d = 1'b0, clr_d = 1'b0;
        always @(posedge clkbit) begin we_tog_d <= o_we_tog[0]; clr_d <= o_stats_clr[0]; end
        assign dbg_reg_we     = (o_we_tog[0] != we_tog_d);
        assign dbg_reg_addr   = o_addr;
        assign dbg_reg_data   = o_data;
        assign dbg_soft_rst   = o_soft_rst[0];
        assign dbg_pn_inv     = o_pn_inv;
        assign dbg_crc_refl   = o_crc_mode[0];
        assign dbg_crc_lsb    = o_crc_mode[1];
        assign dbg_vhead_copy = o_crc_mode[2];
        assign dbg_ck_free    = o_crc_mode[3];
        assign dbg_pat_lvl    = o_pat_lvl;
        assign dbg_pat_mode   = o_pat_mode;
        assign dbg_tick_period= o_tick_period;
        assign dbg_wr_stall   = o_wr_stall;
        assign dbg_late_max   = o_late_max;
        assign dbg_sensor_en  = o_sensor_en[0];
        assign dbg_stats_clr  = (o_stats_clr[0] != clr_d);

        wire [15:0] status = {mmcm_locked, running, out_en, en_3v8, en_2v8, tracker_locked,
                              rd_valid, frame_go, dbg_ph, st0, st1};
        // 探针名 = 网名, hw 脚本按名字找; 拼接要先起名
        wire [31:0] cnt_under_over = {underrun_cnt, overrun_cnt};
        wire [31:0] cnt_drop_stale = {drop_cnt, stale_cnt};

        vio_pp u_vio (
            .clk        (clkbit),
            .probe_in0  (frame_cnt),                       // 32
            .probe_in1  (status),                          // 16
            .probe_in2  (fps_latched),                     // 32
            .probe_in3  (cnt_under_over),                  // 32  [31:16] underrun  [15:0] overrun
            .probe_in4  (cnt_drop_stale),                  // 32  [31:16] drop      [15:0] stale
            .probe_in5  (mismatch_cnt),                    // 32
            .probe_in6  (cmp_cnt),                         // 32
            .probe_in7  (fill_cnt),                        // 32
            .probe_out0 (o_addr),                          // 8   dbg_reg_addr
            .probe_out1 (o_data),                          // 16  dbg_reg_data
            .probe_out2 (o_we_tog),                        // 1
            .probe_out3 (o_soft_rst),                      // 1
            .probe_out4 (o_pn_inv),                        // 4
            .probe_out5 (o_crc_mode),                      // 4   {ck_free,vhead_copy,lsb_tx,refl} INIT 1
            .probe_out6 (o_pat_lvl),                       // 16  INIT 0x0FFF
            .probe_out7 (o_pat_mode),                      // 2
            .probe_out8 (o_tick_period),                   // 24  INIT 18425
            .probe_out9 (o_wr_stall),                      // 16
            .probe_out10(o_sensor_en),                     // 1
            .probe_out11(o_stats_clr),                     // 1  翻一下清零
            .probe_out12(o_late_max)                       // 16 INIT 3500 (= 18425 - 14632 - 293)
        );
    end else begin : g_nodbg
        assign dbg_reg_we = 1'b0; assign dbg_reg_addr = 8'h00; assign dbg_reg_data = 16'h0000;
        assign dbg_soft_rst = 1'b0; assign dbg_pn_inv = 4'h0;
        assign dbg_crc_refl = 1'b1; assign dbg_crc_lsb = 1'b0; assign dbg_vhead_copy = 1'b0; assign dbg_ck_free = 1'b0;
        assign dbg_pat_lvl = 16'h0FFF; assign dbg_pat_mode = 2'd0;
        assign dbg_tick_period = TICK_INIT[23:0]; assign dbg_wr_stall = 16'd0;
        assign dbg_sensor_en = 1'b0; assign dbg_stats_clr = 1'b0; assign dbg_late_max = 16'd3500;
    end endgenerate

    assign led[0] = running ? frame_cnt[7] : 1'b1;
    assign led[1] = (underrun_cnt != 0) | (mismatch_cnt != 0);   // 亮 = 链上出过错

endmodule

`default_nettype wire
