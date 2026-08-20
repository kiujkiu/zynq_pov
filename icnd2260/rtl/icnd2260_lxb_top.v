//-----------------------------------------------------------------------------
// icnd2260_lxb_top.v
//-----------------------------------------------------------------------------
// 鹿小班 (XC7Z020-CLG484) + ICND2260 转接板 zynq-lxb_2260_V0.1 首次点亮顶层
//
// 纯 PL, 不依赖 PS: 时钟取板载 PL_CLK_50M (M19), 复位由 MMCM locked 派生,
// 帧缓存用 $readmemh 初始化成测试图。JTAG 下载 bit 即跑, 不用 Vitis / ps7_init。
//
// 转接板实测网表 (从 SCH/LKS_FOC.SchDoc 抽出, 见 docs/00_board_and_protocol.md):
//   FPGA ─┬ R_P/R_N   (L3P/L3N_33)   ─ 100Ω 差分终端 R10 ─ J1.34/35
//         ├ G_P/G_N   (L9P/L9N_33)   ─ 100Ω R9           ─ J1.31/32
//         ├ B_P/B_N   (L7P/L7N_33)   ─ 100Ω R8           ─ J1.28/29
//         ├ CLK_P/N   (L8P/L8N_33)   ─ 100Ω R7           ─ J1.25/26
//         ├ DCLK      (L23N_33)      ─ 33Ω  R5           ─ J1.21
//         ├ SYNC      (L12N_33)      ─ 33Ω  R12          ─ J1.23
//         ├ ACK       (L24N_33)      ─ 100Ω R11          ─ J1.22   (输入)
//         ├ EN_3V8    (L19P_33)      ─ 1k R2  ─ U1.EN, 100k 下拉 R14
//         └ EN_2V8    (L19N_33)      ─ 1k R13 ─ U2.EN, 100k 下拉 R15
//
// 🔴 电气前提 (未上板验证, 见 docs 待确认项 Q2):
//   本设计按 **TTL 3 通道** 发数 —— 芯片的 SDI_R1/G1/B1 就是差分对的 P 侧球
//   (D1/E1/F1), 用 LVCMOS33 单端驱动即可, 不需要 LVDS 驱动器。
//   N 侧 (SDI_R2/G2/B2) 在 3 通道模式下被芯片忽略, 这里**驱动成与 P 侧同电平**,
//   让跨接的 100Ω (R7~R10) 两端等电位 ⇒ 零电流。切勿把 N 侧驱动成 P 的反相,
//   那样每根线会灌 33 mA。CLK_P/N 同理, 静态拉低。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_lxb_top #(
    parameter integer NLANE      = 3,
    parameter integer PIX        = 40,
    parameter integer LINES      = 48,
    parameter integer CASCADE    = 1,
    // DCLK 相位: 0 = 与数据同沿 (手册「上升沿开始、下降沿结束」的字面实现)
    //            1 = 反相 (数据眼中心对齐时钟沿, 首光打不出来时先试这个)
    parameter integer DCLK_INV   = 0,
    // 1 = DCLK 用 90° 相移时钟输出 (需要更细的相位再开)
    parameter integer DCLK_Q90   = 0,
    parameter integer BLANK_FRAMES = 64
) (
    input  wire clk50,        // M19  PL_CLK_50M

    output wire dclk,         // AA13 J1.21
    output wire sync,         // AA18 J1.23
    input  wire ack,          // AB15 J1.22

    output wire r_p, r_n,     // V22 / W22   SDI_R1 / SDI_R2
    output wire g_p, g_n,     // Y20 / Y21   SDI_G1 / SDI_G2
    output wire b_p, b_n,     // AA22/ AB22  SDI_B1 / SDI_B2
    output wire clk_p, clk_n, // AA21/ AB21  L_CKIP / L_CKIN (TTL 模式不用)

    output wire en_3v8,       // V14
    output wire en_2v8,       // V15

    output wire [1:0] led     // P20 / P21 板载 PL LED, 高电平点亮
);

    localparam integer TOTAL_PIX = PIX * LINES * CASCADE;
    localparam integer FB_AW     = (TOTAL_PIX <= 2048) ? 11 : 12;

    // ---------------------------------------------------------------------
    // 时钟: 50 MHz -> 25 MHz (DCLK 域). 手册 FDCLK Max = 25 MHz (TTL-DDR)
    // ---------------------------------------------------------------------
    wire clkfb, clkfb_buf;
    wire clk25_raw, clk25q_raw;
    wire clk25, clk25q;
    wire mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH        ("OPTIMIZED"),
        .CLKIN1_PERIOD    (20.000),      // 50 MHz
        .CLKFBOUT_MULT_F  (16.000),      // VCO = 800 MHz
        .DIVCLK_DIVIDE    (1),
        .CLKOUT0_DIVIDE_F (32.000),      // 25 MHz, 0°
        .CLKOUT1_DIVIDE   (32),          // 25 MHz, 90°
        .CLKOUT1_PHASE    (90.000),
        .STARTUP_WAIT     ("FALSE")
    ) u_mmcm (
        .CLKIN1   (clk50),
        .CLKFBIN  (clkfb_buf),
        .CLKFBOUT (clkfb),
        .CLKOUT0  (clk25_raw),
        .CLKOUT1  (clk25q_raw),
        .CLKOUT2  (), .CLKOUT3  (), .CLKOUT4 (), .CLKOUT5 (), .CLKOUT6 (),
        .CLKOUT0B (), .CLKOUT1B (), .CLKOUT2B (), .CLKOUT3B (), .CLKFBOUTB (),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    BUFG u_bufg_fb (.I(clkfb),      .O(clkfb_buf));
    BUFG u_bufg_0  (.I(clk25_raw),  .O(clk25));
    BUFG u_bufg_90 (.I(clk25q_raw), .O(clk25q));

    // ---- 复位: locked 之后再放开 256 拍 ----------------------------------
    reg [7:0] por_cnt = 8'd0;
    reg       rst_n   = 1'b0;
    always @(posedge clk25) begin
        if (!mmcm_locked) begin
            por_cnt <= 8'd0;
            rst_n   <= 1'b0;
        end else if (!por_cnt[7]) begin
            por_cnt <= por_cnt + 8'd1;
        end else begin
            rst_n <= 1'b1;
        end
    end

    // ---------------------------------------------------------------------
    // 帧缓存: TOTAL_PIX x 48 bit ({B,G,R} 各 16 bit)
    // ---------------------------------------------------------------------
    wire [FB_AW-1:0]     fb_addr;
    reg  [16*NLANE-1:0]  fb_q;
    (* ram_style = "block" *) reg [16*NLANE-1:0] fb [0:TOTAL_PIX-1];

    initial $readmemh("icnd2260_fb.mem", fb);
    always @(posedge clk25) fb_q <= fb[fb_addr];

    // ---------------------------------------------------------------------
    // 序列器 + 发送器
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

    // 本顶层不带调试核, 调试口全接常量 (行为与加调试口之前完全一致)
    wire        dbg_reg_we    = 1'b0;
    wire [7:0]  dbg_reg_addr  = 8'h00;
    wire [15:0] dbg_reg_data  = 16'h0000;
    wire        dbg_probe_en  = 1'b0;
    wire [7:0]  dbg_probe_off = 8'h00;
    wire [3:0]  dbg_probe_dev = 4'h0;
    wire [3:0]  dbg_ph;
    wire [1:0]  dbg_sub;

    icnd2260_seq #(
        .NLANE        (NLANE),
        .PIX_PER_LINE (PIX),
        .LINES        (LINES),
        .CASCADE      (CASCADE),
        .BLANK_FRAMES (BLANK_FRAMES),
        .FB_AW        (FB_AW)
    ) u_seq (
        .clk (clk25), .rst_n (rst_n),
        .en_3v8 (en_3v8), .en_2v8 (en_2v8), .out_en (out_en),
        .fb_addr (fb_addr), .fb_q (fb_q),
        .cmd_valid (cmd_valid), .cmd_ready (cmd_ready), .cmd_kind (cmd_kind),
        .cmd_device (cmd_device), .cmd_offset (cmd_offset),
        .cmd_length (cmd_length), .cmd_rows (cmd_rows), .cmd_cascade (cmd_cascade),
        .pl_next (pl_next), .pl_data (pl_data), .pl_last (pl_last),
        .tx_busy (tx_busy), .running (running), .frame_cnt (frame_cnt),
        .dbg_reg_we (dbg_reg_we), .dbg_reg_addr (dbg_reg_addr),
        .dbg_reg_data (dbg_reg_data),
        .dbg_probe_en (dbg_probe_en), .dbg_probe_off (dbg_probe_off),
        .dbg_probe_dev (dbg_probe_dev),
        .dbg_ph (dbg_ph), .dbg_sub (dbg_sub)
    );

    icnd2260_tx #(.NLANE (NLANE)) u_tx (
        .clk (clk25), .rst_n (rst_n),
        .cmd_valid (cmd_valid), .cmd_ready (cmd_ready), .cmd_kind (cmd_kind),
        .cmd_device (cmd_device), .cmd_offset (cmd_offset),
        .cmd_length (cmd_length), .cmd_rows (cmd_rows), .cmd_cascade (cmd_cascade),
        .pl_next (pl_next), .pl_data (pl_data), .pl_last (pl_last),
        .bit_r (bit_r), .bit_f (bit_f), .isync (isync), .busy (tx_busy)
    );

    // ---------------------------------------------------------------------
    // IOB: 三根数据 + DCLK 走 ODDR, 电源没稳 (out_en=0) 之前全部压 0
    // ---------------------------------------------------------------------
    wire [NLANE-1:0] d_r = bit_r & {NLANE{out_en}};
    wire [NLANE-1:0] d_f = bit_f & {NLANE{out_en}};
    wire [NLANE-1:0] lane_p, lane_n;

    // ⚠ 每个物理管脚各自一个 ODDR。一个 ODDR 扇出到两个 port 会让它的输出需要
    //   通用布线, 而 OLOGIC 里的单元只能直连 IOB ⇒ place 报
    //   [Shape Builder 18-152] "cannot be placed in site OLOGIC_X0Y0"。踩过一次。
    genvar gi;
    generate
        for (gi = 0; gi < NLANE; gi = gi + 1) begin : g_lane
            ODDR #(
                .DDR_CLK_EDGE ("SAME_EDGE"),
                .INIT (1'b0), .SRTYPE ("SYNC")
            ) u_oddr_p (
                .Q (lane_p[gi]), .C (clk25), .CE (1'b1),
                .D1 (d_r[gi]), .D2 (d_f[gi]), .R (1'b0), .S (1'b0)
            );
            ODDR #(
                .DDR_CLK_EDGE ("SAME_EDGE"),
                .INIT (1'b0), .SRTYPE ("SYNC")
            ) u_oddr_n (
                .Q (lane_n[gi]), .C (clk25), .CE (1'b1),
                .D1 (d_r[gi]), .D2 (d_f[gi]), .R (1'b0), .S (1'b0)
            );
        end
    endgenerate

    // DCLK: 常数输入的时钟转发, 相位可选
    wire dclk_src = (DCLK_Q90 != 0) ? clk25q : clk25;
    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE"), .INIT (1'b0), .SRTYPE ("SYNC")
    ) u_oddr_dclk (
        .Q  (dclk), .C (dclk_src), .CE (1'b1),
        .D1 ((DCLK_INV != 0) ? 1'b0 : 1'b1),
        .D2 ((DCLK_INV != 0) ? 1'b1 : 1'b0),
        .R  (~out_en), .S (1'b0)      // 电源没稳时 DCLK 压 0
    );

    // lane0=R, lane1=G, lane2=B; N 侧镜像 P 侧 ⇒ 跨接的 100Ω 两端等电位
    assign r_p = lane_p[0];
    assign g_p = lane_p[1];
    assign b_p = lane_p[2];
    assign r_n = lane_n[0];
    assign g_n = lane_n[1];
    assign b_n = lane_n[2];

    // TTL 模式不用 LVDS 时钟对, 静态拉低 (两端等电位, R7 不流电流)
    assign clk_p = 1'b0;
    assign clk_n = 1'b0;

    // I_SYNC 也要落进 IOB 寄存器 —— 直接从 fabric 组合输出的话, 实测通路 9.5 ns,
    // 而数据脚只有 2.7 ns, 两者 ~6.7 ns 偏斜。虽然 20 ns 的位时间扛得住, 但没必要。
    // 代价: I_SYNC 比数据晚一拍 ⇒ LEAD 从 17 拍变 16 拍, 仍满足手册「不少于 16」。
    (* IOB = "TRUE" *) reg sync_q;
    always @(posedge clk25) sync_q <= out_en ? isync : 1'b0;
    assign sync = sync_q;

    // ---------------------------------------------------------------------
    // 板载 LED: [0] = 心跳 (进入正常显示后 ~1.5 Hz), [1] = ACK 上有过跳变
    // ---------------------------------------------------------------------
    reg [23:0] hb = 24'd0;
    always @(posedge clk25) hb <= hb + 24'd1;

    // ---- ACK 回传解调 (与 LVDS 版同一个模块) -----------------------------
    wire ack_crc_ok;
    icnd2260_ack_rx #(.CLK_HZ (25_000_000), .MAX_WORDS (4)) u_ack (
        .clk (clk25), .rst_n (rst_n), .ack_pin (ack),
        .frame_valid (), .frame_ok (), .crc_ok (ack_crc_ok), .frame_err (),
        .f_ack (), .f_dev (), .f_off (), .f_len (), .f_data0 (),
        .f_crc_rx (), .f_crc_calc (), .f_nbits (), .busy ()
    );

    reg ack_ok_sticky = 1'b0;
    always @(posedge clk25) begin
        if (!rst_n) ack_ok_sticky <= 1'b0;
        else if (ack_crc_ok) ack_ok_sticky <= 1'b1;
    end

    assign led[0] = running ? hb[23] : 1'b1;   // 没跑起来 = 常亮
    assign led[1] = ack_ok_sticky;             // 亮 = 收到过 CRC 正确的 ACK 回包

endmodule

`default_nettype wire
