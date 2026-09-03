//-----------------------------------------------------------------------------
// slice_feed.v -- 「直供」胶水: 角度跟踪 + 乒乓缓冲 + 填充器 + VSYNC 门控 + 读侧自检
//-----------------------------------------------------------------------------
// 把 icnd2260_seq 的帧缓存口 (fb_addr/fb_q) 和指令口 (cmd_valid/cmd_ready/cmd_kind)
// 接到本模块, seq/tx 本身一行不改。顶层与测试台共用这一份, 避免胶水两处漂移。
//
// 第一步 (本文件默认): 填充器 = pat_writer (每片不同的帧相位条纹)。
// 后续换渲染 IP 时只换 pat_writer 这一个例化: fill_req->ap_start, fill_tag->phase,
// AXIS 64 位 -> wr_en/wr_addr/wr_data, ap_done->fill_done。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module slice_feed #(
    parameter integer PIX     = 40,
    parameter integer LINES   = 45,
    parameter integer FB_AW   = 11,
    parameter integer NSLICE  = 603,
    parameter integer TAGW    = 10,
    parameter integer CLK_HZ  = 166_666_666
) (
    input  wire              clk,            // 位时钟
    input  wire              rst_n,
    input  wire              running,        // seq 已进入正常显示
    input  wire              seq_in_run,     // seq 状态机在 P_RUN (dbg_ph == 7): 真正开始等第一片
    input  wire [31:0]       frame_cnt,      // seq 帧计数 (变化 = 一片发完)
    // ---- 指令口门控: seq -> 本模块 -> tx ----
    input  wire              cmd_valid_seq,
    output wire              cmd_ready_seq,
    input  wire [2:0]        cmd_kind,
    output wire              cmd_valid_tx,
    input  wire              cmd_ready_tx,
    // ---- 帧缓存口 ----
    input  wire [FB_AW-1:0]  fb_addr,
    output wire [47:0]       fb_q,           // {B,G,R} 各 16 bit 左对齐, 低 16 位 = R
    // ---- 转子 ----
    input  wire              sensor_in,
    input  wire              sensor_en,      // 0 = 假模式 (tick_period 定周期)
    input  wire [23:0]       tick_period,
    input  wire [15:0]       late_max,       // 晚起上限 (拍), 见 slice_ppbuf
    // ---- 填充器 (wr_clk 域) ----
    input  wire              wr_clk,
    input  wire [15:0]       pat_lvl,
    input  wire [1:0]        pat_mode,
    input  wire [15:0]       wr_stall,
    // ---- 统计 ----
    input  wire              stats_clr,
    output wire              tracker_locked,
    output wire              rd_valid,
    output wire              reading,
    output wire              frame_go,
    output wire [TAGW-1:0]   disp_tag,
    output wire [1:0]        st0, st1,
    output wire [15:0]       underrun_cnt, overrun_cnt, drop_cnt, stale_cnt,
    output wire [31:0]       fill_cnt, mismatch_cnt, cmp_cnt
);
    localparam [2:0] KIND_VSYNC = 3'd0;

    // ---- VSYNC 门控 (相位锁) ----
    wire hold = running & (cmd_kind == KIND_VSYNC) & ~frame_go;
    assign cmd_valid_tx  = cmd_valid_seq & ~hold;
    assign cmd_ready_seq = cmd_ready_tx  & ~hold;
    wire frame_start = cmd_valid_tx & cmd_ready_tx & (cmd_kind == KIND_VSYNC) & running;

    reg [31:0] frame_cnt_d = 0;
    always @(posedge clk) frame_cnt_d <= frame_cnt;
    wire frame_done = (frame_cnt != frame_cnt_d);

    // ---- 角度跟踪 ----
    wire [15:0] slice_idx16;
    angle_tracker #(.CLK_HZ(CLK_HZ)) u_trk (
        .clk(clk), .rst_n(rst_n), .sensor_in(sensor_in),
        .fake_en(~sensor_en), .fake_period({8'd0, tick_period}),
        .n_slices(NSLICE[15:0]), .slice_idx(slice_idx16), .rev_period(), .locked(tracker_locked)
    );
    reg [TAGW-1:0] slice_idx_d = 0;
    always @(posedge clk) slice_idx_d <= slice_idx16[TAGW-1:0];
    wire tick = (slice_idx16[TAGW-1:0] != slice_idx_d);

    // ---- 乒乓缓冲 (seq 真正到 P_RUN 之前保持复位) ----
    //   ⚠ 不能用 running: 它在最后一帧空屏还在发的时候就已经是 1 (P_WAIT && ph_next==P_RUN),
    //     那时放开会让第一片被空屏帧挡住、晚起一整帧, 白吃一次 overrun。
    reg run_seen = 1'b0;
    always @(posedge clk) begin
        if (!rst_n) run_seen <= 1'b0;
        else if (seq_in_run) run_seen <= 1'b1;
    end
    wire rst_n_pp = rst_n & run_seen;
    (* ASYNC_REG = "TRUE" *) reg [1:0] wr_rst_sync = 2'b00;
    always @(posedge wr_clk) wr_rst_sync <= {wr_rst_sync[0], rst_n_pp};
    wire wr_rst_n = wr_rst_sync[1];

    wire fill_req, fill_bank, fill_done, wr_en;
    wire [TAGW-1:0] fill_tag;
    wire [8:0]  wr_addr; wire [63:0] wr_data;
    wire [15:0] px_q;

    slice_ppbuf #(.NCHAIN(1), .NPX(PIX*LINES), .FB_AW(FB_AW), .TAGW(TAGW), .NSLICE(NSLICE), .LEAD_MAX(2)) u_pp (
        .clk(clk), .rst_n(rst_n_pp), .tick(tick), .slice_idx(slice_idx16[TAGW-1:0]),
        .frame_start(frame_start), .frame_done(frame_done), .stats_clr(stats_clr), .late_max(late_max),
        .fb_addr(fb_addr), .px_q(px_q), .frame_go(frame_go), .rd_valid(rd_valid), .reading(reading), .disp_tag(disp_tag),
        .underrun_cnt(underrun_cnt), .overrun_cnt(overrun_cnt), .drop_cnt(drop_cnt),
        .stale_cnt(stale_cnt), .fill_cnt(fill_cnt), .dbg_st0(st0), .dbg_st1(st1),
        .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .fill_req(fill_req), .fill_bank(fill_bank),
        .fill_tag(fill_tag), .fill_done(fill_done), .wr_en(wr_en), .wr_chain(5'd0), .wr_addr(wr_addr), .wr_data(wr_data)
    );

    pat_writer #(.NPX(PIX*LINES), .PIX(PIX), .NSTRIPE(8), .TAGW(TAGW)) u_wr (
        .wr_clk(wr_clk), .wr_rst_n(wr_rst_n), .fill_req(fill_req), .fill_tag(fill_tag),
        .pat_lvl(pat_lvl), .pat_mode(pat_mode), .wr_stall(wr_stall),
        .fill_done(fill_done), .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data)
    );

    // RGB565 -> 三通道 16 bit 左对齐。字序 {B,G,R}, 低 16 位 = R = lane0 (2026-09-01 首光实测)
    assign fb_q = {{px_q[4:0], 11'b0}, {px_q[10:5], 10'b0}, {px_q[15:11], 11'b0}};

    // ---- 读侧自检 ----
    //   列计数沿用 lvds_top mode 7 那套 (标志先寄存一级打断进位链) => 比 fb_addr 晚 2 拍;
    //   px_q 比 fb_addr 晚 1 拍 -> 再延 1 拍; disp_tag/reading 同样延 2 拍对齐。
    //   只在 reading (frame_start..frame_done 且真数据) 期间比: 帧间空闲时 bank 已释放, 可能正被重填。
    localparam integer NSTRIPE = 8, STRIPE_W = PIX / NSTRIPE;
    reg [FB_AW-1:0] fb_addr_d = 0;
    reg  chk_frame0 = 1'b0, chk_adv = 1'b0;
    reg  [6:0]  chk_col = 7'd0;
    reg  [15:0] px_q_d = 16'h0;
    reg  rd_valid_d = 1'b0, rd_valid_dd = 1'b0;
    reg  reading_d = 1'b0, reading_dd = 1'b0;
    reg  [TAGW-1:0] tag_d = 0, tag_dd = 0;
    always @(posedge clk) begin
        fb_addr_d  <= fb_addr;
        chk_frame0 <= (fb_addr == {FB_AW{1'b0}});
        chk_adv    <= (fb_addr != fb_addr_d);
        if (chk_frame0)      chk_col <= 7'd0;
        else if (chk_adv)    chk_col <= (chk_col == PIX-1) ? 7'd0 : chk_col + 7'd1;
        px_q_d      <= px_q;
        rd_valid_d  <= rd_valid;  rd_valid_dd <= rd_valid_d;
        reading_d   <= reading;   reading_dd  <= reading_d;
        tag_d       <= disp_tag;  tag_dd      <= tag_d;
    end
    wire [2:0]  chk_stripe = chk_col / STRIPE_W;
    wire        chk_on  = (pat_mode == 2'd1) || (pat_mode == 2'd0 && chk_stripe == tag_dd[2:0]);
    wire [15:0] chk_exp = (pat_mode == 2'd3) ? {tag_dd[4:0], 11'b0} :
                          chk_on ? {pat_lvl[15:11], pat_lvl[15:10], pat_lvl[15:11]} : 16'h0;
    reg [31:0] mism = 0, cmpc = 0;
    always @(posedge clk) begin
        if (!rst_n_pp || stats_clr) begin mism <= 0; cmpc <= 0; end
        else if (reading_dd && reading_d && reading) begin
            cmpc <= cmpc + 1;
            if (px_q_d != chk_exp) mism <= mism + 1;
        end
    end
    assign mismatch_cnt = mism;
    assign cmp_cnt = cmpc;
endmodule

`default_nettype wire
