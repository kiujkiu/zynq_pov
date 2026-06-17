//-----------------------------------------------------------------------------
// icnd2047_panel_seq.v - ICND2047 LED panel PL driver (BCM 6-bit) MVP draft
//
// Replaces hub75e_panel_seq_v2 (FM6124). Drop-in AXI-Lite layout compatible
// (same base 0x40020000, same register offsets CTRL/COLOR/PARAM/STATUS/
// COLOR_BOT/BCM_TUNIT) so existing ARM code keeps working for mode-0 SOLID
// bring-up. BRAM read modes (mode>=1 with use_fb) are stubbed for MVP — only
// SOLID color is exercised, fps measurement first.
//
// ICND2047 protocol vs FM6124 — key differences this module implements:
//
//   1. DDR (double-data-rate) shift register
//      DCLK toggles EVERY aclk cycle (no DCLK_DIV/2 sub-counter).
//      SIN/SDI updates EVERY aclk cycle.
//      Chip samples on BOTH CLK edges → 1 aclk = 1 shifted bit per lane.
//      Effective shift bit rate = aclk frequency (50 Mbps @ 50 MHz aclk).
//      DCLK physical frequency = aclk / 2 = 25 MHz (matches FCLK_MAX in DS).
//
//      In hub75e/FM6124 driver:
//        sub_count counted DCLK_DIV; rgb stable across DCLK_DIV cycles.
//      In ICND2047 driver:
//        no sub_count for shift; col_idx++ every cycle and DCLK toggles every cycle.
//
//   2. LE command word generator (replaces FM6124's single LE pulse)
//      LE is asserted HIGH while DCLK keeps toggling. Total CLK edges (rises
//      + falls combined) counted while LE=H decode to a command:
//         N=3 edges → DATA_LATCH normal       (chip row stays)
//         N=4 edges → DATA_LATCH row advance  (chip row++)
//         N=5 edges → DATA_LATCH first row    (chip row=0)
//      Per-frame sequence (6 planes × 32 rows = 192 latches):
//         row 0  plane 0: N=5     row 0  planes 1..5: N=3
//         row 1+ plane 0: N=4     row 1+ planes 1..5: N=3
//      Implementation: S_LATCH state asserts LE=1, runs a small sub-FSM that
//      toggles DCLK exactly latch_edges_target times then drops LE.
//      latch_edges_target is computed at S_LATCH entry from (plane, row_idx).
//
//   3. OE_PRE eliminated
//      ICND2047 has true double buffering (reg1 SR + reg2 output latch via
//      LE command). OE-falling-edge does NOT need pre-setup. After LE
//      command word completes, go straight: S_LATCH → S_ADDR_ABCDE →
//      S_DISPLAY (drop OE). No S_OE_PRE state.
//
//   4. No FM6124-style "overlap" runtime mode
//      Chip's reg2 holds last latched data permanently while reg1 SR can be
//      shifted with new data without disturbing display. To keep this MVP
//      simple, we still do sequential: shift → latch → display → next.
//      Once fps measurement works, can refactor to shift-while-display.
//
//   5. External ABCDE row select still needed
//      Chip's internal row counter is for ITS OWN consumption (open-detect /
//      blanking). The board-level row driver (ICND3019 NMOS) needs external
//      5-bit ABCDE. S_ADDR_ABCDE updates external addr AFTER S_LATCH.
//
//   6. Registers (WR_REG1 / WR_REG2) skipped for MVP
//      Default register values are fine for first light. ADDR_SR mode dropped.
//      Open-circuit detection dropped.
//
// AXI-Lite register layout (same as hub75e_panel_seq_v2):
//   0x00 CTRL       [0]=en [3:1]=mode [5]=use_fb [12:8]=addr_bits
//                   (bits [4]=addr_sr and [6]=overlap_en from FM6124 are
//                    ignored here; reads back as 0)
//   0x04 COLOR      [23:0] top-half 24-bit RGB (byte order R[7:0] G[15:8] B[23:16])
//   0x08 PARAM      [11:0]=width-1 [23:16]=stripe_w [31:24]=walk_speed
//   0x0C STATUS     [0]=running [12:8]=cur_addr [15:13]=cur_plane [31:16]=frame_count
//   0x10 COLOR_BOT  [23:0] bot-half 24-bit RGB (0 → mirror COLOR)
//   0x14 BCM_TUNIT  [7:0]
//
// Module name: icnd2047_panel_seq_v1 (distinct from hub75e_panel_seq_v2)
//
// FSM:
//   S_IDLE       → wait for enable
//   S_SHIFT      → DDR shift 16 cols (one chip width per shift unit; PANEL_WIDTH
//                  driven externally, 16 = one ICND2047 chip; col_idx++ every aclk,
//                  DCLK toggles every aclk)
//   S_LATCH      → LE=1, run latch_edges_target CLK edges, then LE=0
//   S_ADDR_ABCDE → update external ABCDE row select (OE still HIGH)
//   S_DISPLAY    → OE=0 for (T_UNIT << plane) aclk cycles (BCM weighted)
//   S_DISPLAY_END→ OE=1, advance plane++ or row++, back to S_SHIFT
//
// fps target: ~12000+ fps @ 16 col / TUNIT=1 / aclk=50 MHz.
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

// AXI 16-bit address space (64 KB):
//   0x0000-0x001F : control regs (bit[15]=0, bits [4:2] select 6 regs)
//   0x8000-0xFFFF : framebuffer (bit[15]=1, bits [14:2] = pixel index 0..8191)
//                   each pixel 32-bit aligned, low 24-bit = RGB
// v30: ICND2047 driver wearing the hub75e_panel_seq_v2 name so BD module_ref
// resolves to this implementation without rebuilding the xci/wrapper. Unused
// FM6124 parameters (DCLK_DIV/LATCH_CYC/BLANK_CYC/OE_PRE_CYC/DISP_CYCLES) are
// accepted but ignored — DDR shift is 1 aclk = 1 bit, OE_PRE eliminated by
// chip's double buffering.
module hub75e_panel_seq_v2 #(
    parameter integer DCLK_DIV     = 2,    // unused (DDR: 1 aclk = 1 bit)
    parameter integer PANEL_WIDTH  = 16,
    parameter integer ADDR_BITS    = 5,    // 1/32 scan, ABCDE
    parameter integer BCM_PLANES   = 6,    // 6-bit per channel (64 levels)
    parameter integer T_UNIT_DEF   = 1,    // default TUNIT=1 aclk
    parameter integer DISP_CYCLES  = 1000, // unused (legacy compat)
    parameter integer LATCH_CYC    = 2,    // unused (ICND2047 LE width = N edges of DCLK)
    parameter integer BLANK_CYC    = 1,    // unused
    parameter integer LATCH_GAP_CYC = 2,   // gap after LE drop before driving ADDR
    parameter integer ADDR_SET_CYC = 1,    // ABCDE settle before OE drops
    parameter integer OE_PRE_CYC   = 8,    // unused (double buffer, no setup needed)
    parameter integer FB_DEPTH     = 8192  // 128×64 pixel (kept for AXI compat; stubbed)
)(
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [15:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg [1:0]   s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [15:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // Physical pin names kept as hub75e_* for board / BD wrapper drop-in compat
    output reg [5:0]   hub75e_rgb_out,
    output reg         hub75e_dclk_out,
    output reg         hub75e_lat_out,
    output reg         hub75e_oe_out,
    output reg [4:0]   hub75e_addr_out
);

    //==========================================================================
    // AXI-Lite slave register file (write + read paths)
    //==========================================================================
    reg [31:0] reg_ctrl;
    reg [31:0] reg_color;       // 0x04 top color
    reg [31:0] reg_param;
    reg [31:0] reg_color_bot;   // 0x10 bot color
    reg [31:0] reg_tunit;       // 0x14 T_unit

    wire        enable        = reg_ctrl[0];
    wire [2:0]  test_mode     = reg_ctrl[3:1];
    // reg_ctrl[4] (addr_sr) and reg_ctrl[6] (overlap_en) intentionally unused
    wire        use_fb        = reg_ctrl[5];
    wire [4:0]  addr_bits_cfg = (reg_ctrl[12:8] == 5'd0) ? 5'd5 : reg_ctrl[12:8];
    wire [4:0]  row_max       = (5'd1 << addr_bits_cfg) - 5'd1;
    wire [23:0] user_color_top = reg_color[23:0];
    wire [23:0] user_color_bot = (reg_color_bot[23:0] == 24'h0 && reg_color[23:0] != 24'h0)
                                  ? reg_color[23:0] : reg_color_bot[23:0];
    wire [11:0] width_max     = (reg_param[11:0] == 12'd0) ? (PANEL_WIDTH-1) : reg_param[11:0];
    wire [7:0]  stripe_w      = (reg_param[23:16] == 8'd0) ? 8'd8 : reg_param[23:16];
    wire [7:0]  walk_speed    = (reg_param[31:24] == 8'd0) ? 8'd10 : reg_param[31:24];
    wire [7:0]  t_unit        = (reg_tunit[7:0] == 8'd0) ? T_UNIT_DEF[7:0] : reg_tunit[7:0];

    reg [15:0] aw_addr_q;
    reg        aw_done, w_done;
    wire [15:0] cur_aw_addr = aw_done ? aw_addr_q : s_axi_awaddr;

    // Debug telemetry for AXI write traffic (FB stubbed but counter still wired)
    reg [15:0] fb_we_count;
    reg [23:0] last_fb_wdata;
    reg [11:0] last_fb_waddr;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            aw_done       <= 1'b0;
            w_done        <= 1'b0;
            reg_ctrl      <= 32'b0;
            reg_color     <= 32'b0;
            reg_param     <= 32'b0;
            reg_color_bot <= 32'b0;
            reg_tunit     <= 32'b0;
            fb_we_count   <= 16'h0;
            last_fb_wdata <= 24'h0;
            last_fb_waddr <= 12'h0;
        end else begin
            if (!aw_done && s_axi_awvalid) begin
                s_axi_awready <= 1'b1;
                aw_addr_q     <= s_axi_awaddr;
                aw_done       <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
            end
            if (!w_done && s_axi_wvalid) begin
                s_axi_wready <= 1'b1;
                w_done       <= 1'b1;
                if (aw_done || s_axi_awvalid) begin
                    if (cur_aw_addr[15]) begin
                        // FB region: stub (no BRAM in MVP). Count writes for debug.
                        last_fb_wdata <= s_axi_wdata[23:0];
                        last_fb_waddr <= cur_aw_addr[13:2];
                        fb_we_count   <= fb_we_count + 16'h1;
                    end else begin
                        case (cur_aw_addr[4:2])
                            3'd0: reg_ctrl      <= s_axi_wdata;
                            3'd1: reg_color     <= s_axi_wdata;
                            3'd2: reg_param     <= s_axi_wdata;
                            3'd4: reg_color_bot <= s_axi_wdata;
                            3'd5: reg_tunit     <= s_axi_wdata;
                            default: ;
                        endcase
                    end
                end
            end else begin
                s_axi_wready <= 1'b0;
            end
            if (aw_done && w_done && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                aw_done      <= 1'b0;
                w_done       <= 1'b0;
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'b0;
        end else begin
            if (!s_axi_rvalid && s_axi_arvalid && !s_axi_arready) begin
                s_axi_arready <= 1'b1;
                if (s_axi_araddr[15]) begin
                    // FB read stub: always 0
                    s_axi_rdata <= 32'h0;
                end else case (s_axi_araddr[4:2])
                    3'd0: s_axi_rdata <= reg_ctrl;
                    3'd1: s_axi_rdata <= reg_color;
                    3'd2: s_axi_rdata <= reg_param;
                    3'd3: s_axi_rdata <= status_word;
                    3'd4: s_axi_rdata <= reg_color_bot;
                    3'd5: s_axi_rdata <= reg_tunit;
                    default: s_axi_rdata <= 32'h0;
                endcase
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;
            end
        end
    end

    //==========================================================================
    // FSM state encoding
    //==========================================================================
    localparam [3:0]
        S_IDLE        = 4'd0,
        S_SHIFT       = 4'd1,
        S_LATCH       = 4'd2,
        S_LATCH_GAP   = 4'd3,
        S_ADDR_ABCDE  = 4'd4,
        S_DISPLAY     = 4'd5,
        S_DISPLAY_END = 4'd6;

    reg [3:0]  state;
    reg [11:0] col_idx;
    reg [4:0]  row_idx;
    reg [4:0]  row_displayed;
    reg [2:0]  plane;
    reg [15:0] frame_count;
    reg [7:0]  walk_pos;
    reg [7:0]  walk_div_count;
    reg [15:0] disp_count;
    reg [15:0] disp_target;
    reg [3:0]  ctrl_count;

    // LE command word generator state
    // latch_edges_target = N (3, 4, or 5) edges (CLK rising + falling combined)
    // latch_edge_count   = how many edges we've produced while LE=1 so far
    reg [3:0]  latch_edges_target;
    reg [3:0]  latch_edge_count;

    reg [4:0]  addr_abcde_lat;

    // STATUS register packing
    wire [31:0] status_word = {frame_count, plane, row_displayed, 7'b0, (state != S_IDLE)};

    //==========================================================================
    // Pattern generator (combinational LUT). use_fb path stubbed → uses LUT
    // unconditionally for MVP. Reuses test_mode encoding from FM6124 driver.
    //==========================================================================
    reg [23:0] pattern_24_top_lut;
    reg [23:0] pattern_24_bot_lut;

    // FB stub: all-zero. Real BRAM left for later.
    wire [23:0] fb_top_dout = 24'h0;
    wire [23:0] fb_bot_dout = 24'h0;

    wire [23:0] pattern_24_top = use_fb ? fb_top_dout : pattern_24_top_lut;
    wire [23:0] pattern_24_bot = use_fb ? fb_bot_dout : pattern_24_bot_lut;

    // 8 color LUT (R in low byte)
    function [23:0] color_lut;
        input [2:0] i;
        begin
            case (i)
                3'd0: color_lut = 24'h0000FF;  // R
                3'd1: color_lut = 24'h00FF00;  // G
                3'd2: color_lut = 24'hFF0000;  // B
                3'd3: color_lut = 24'hFFFFFF;  // W
                3'd4: color_lut = 24'h00FFFF;  // Y
                3'd5: color_lut = 24'hFF00FF;  // M
                3'd6: color_lut = 24'hFFFF00;  // C
                default: color_lut = 24'h000000;
            endcase
        end
    endfunction

    always @(*) begin
        case (test_mode)
            3'd0: begin
                pattern_24_top_lut = user_color_top;
                pattern_24_bot_lut = user_color_bot;
            end
            3'd1: begin
                pattern_24_top_lut = color_lut(row_idx[4:2]);
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd2: begin
                pattern_24_top_lut = color_lut(col_eff[6:4]);
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd3: begin
                pattern_24_top_lut = (col_eff[3] ^ row_idx[2]) ? 24'h0000FF : 24'h00FF00;
                pattern_24_bot_lut = (col_eff[3] ^ row_idx[2]) ? 24'h00FF00 : 24'h0000FF;
            end
            3'd4: begin
                pattern_24_top_lut = (row_idx == walk_pos[4:0]) ? 24'hFFFFFF : 24'h000000;
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd5: begin
                pattern_24_top_lut = (col_eff[7:0] == walk_pos) ? 24'hFFFFFF : 24'h000000;
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd6: begin
                pattern_24_top_lut = {col_eff[7:0], col_eff[7:0], col_eff[7:0]};
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            default: begin
                pattern_24_top_lut = 24'hFFFFFF;
                pattern_24_bot_lut = 24'hFFFFFF;
            end
        endcase
    end

    // BCM plane slice — pick the bit-`plane` from each of R/G/B for top + bot.
    // For 6-plane 6-bit per channel, plane = 0..5.
    // 色序重映射: 实测 panel 内部 IP_r→蓝/IP_g→红/IP_b→绿 (循环置换)。
    // 故 lane 喂入: rgb[0](→蓝LED)=pattern.B, rgb[1](→红LED)=pattern.R, rgb[2](→绿LED)=pattern.G
    wire [4:0] plane_ext = {2'b0, plane};
    wire r1_bit = pattern_24_top[plane_ext + 5'd16];  // R1 pin → 蓝LED : 喂 B
    wire g1_bit = pattern_24_top[plane_ext];          // G1 pin → 红LED : 喂 R
    wire b1_bit = pattern_24_top[plane_ext + 5'd8];   // B1 pin → 绿LED : 喂 G
    wire r2_bit = pattern_24_bot[plane_ext + 5'd16];
    wire g2_bit = pattern_24_bot[plane_ext];
    wire b2_bit = pattern_24_bot[plane_ext + 5'd8];
    wire [5:0] plane_rgb = {b2_bit, g2_bit, r2_bit, b1_bit, g1_bit, r1_bit};

    // 运行时可调列偏移: 补偿 LE 命令边沿造成 SR 多移 + 数据-DCLK 流水线相位 (实测左移)。
    // reg_param[15:12] = col_shift (0~15). pattern 取 (col_idx + col_shift) mod (width) 列。
    // 这样不用反复 rebuild, 用 mwr 0x40020008 调 PARAM[15:12] 即可现场对齐偏移。
    wire [3:0]  col_shift = reg_param[15:12];
    // 左移补偿: 在 col_idx 处生成 (col_idx - col_shift) 列的图案 (带 wrap)。
    wire [11:0] col_eff   = (col_idx >= {8'd0, col_shift})
                              ? (col_idx - {8'd0, col_shift})
                              : (col_idx + width_max + 12'd1 - {8'd0, col_shift});

    //==========================================================================
    // ADDR mux — always external ABCDE in this driver (SR mode dropped)
    //==========================================================================
    always @(*) begin
        hub75e_addr_out = addr_abcde_lat;
    end

    //==========================================================================
    // Main FSM
    //
    //   S_IDLE      : wait for enable=1, hold everything quiet
    //   S_SHIFT     : DDR shift PANEL_WIDTH cols.
    //                 - DCLK toggles EVERY aclk cycle (no sub-counter)
    //                 - SIN/SDI presents new bit EVERY aclk cycle
    //                 - bit rate per lane = aclk freq (chip latches both edges)
    //   S_LATCH     : LE=1 + continue toggling DCLK exactly latch_edges_target
    //                 edges (3/4/5 depending on plane+row), then LE=0
    //   S_LATCH_GAP : short idle (LE low, DCLK low) for setup
    //   S_ADDR_ABCDE: drive external ABCDE row select (OE still HIGH)
    //   S_DISPLAY   : OE=0 for (t_unit << plane) cycles
    //   S_DISPLAY_END: OE=1, advance (plane, row), next frame counter
    //==========================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            state              <= S_IDLE;
            col_idx            <= 12'd0;
            row_idx            <= 5'd0;
            row_displayed      <= 5'd0;
            plane              <= 3'd0;
            ctrl_count         <= 4'd0;
            disp_count         <= 16'd0;
            disp_target        <= 16'd0;
            frame_count        <= 16'd0;
            walk_pos           <= 8'd0;
            walk_div_count     <= 8'd0;
            latch_edges_target <= 4'd0;
            latch_edge_count   <= 4'd0;
            hub75e_rgb_out     <= 6'b0;
            hub75e_dclk_out    <= 1'b0;
            hub75e_lat_out     <= 1'b0;
            hub75e_oe_out      <= 1'b1;
            addr_abcde_lat     <= 5'b0;
        end else begin
            case (state)
                //--------------------------------------------------------------
                S_IDLE: begin
                    hub75e_oe_out   <= 1'b1;
                    hub75e_lat_out  <= 1'b0;
                    hub75e_dclk_out <= 1'b0;
                    hub75e_rgb_out  <= 6'b0;
                    col_idx         <= 12'd0;
                    row_idx         <= 5'd0;
                    plane           <= 3'd0;
                    if (enable) state <= S_SHIFT;
                end

                //--------------------------------------------------------------
                // DDR shift register: 1 aclk = 1 bit per lane.
                // DCLK toggles every cycle; rgb data presents new bit every cycle.
                // After PANEL_WIDTH columns we've shifted PANEL_WIDTH bits into
                // each lane of the chain's reg1 SR.
                //--------------------------------------------------------------
                S_SHIFT: begin
                    hub75e_oe_out  <= 1'b1;
                    hub75e_lat_out <= 1'b0;
                    hub75e_rgb_out <= plane_rgb;
                    // Toggle DCLK every aclk
                    hub75e_dclk_out <= ~hub75e_dclk_out;

                    if (col_idx == width_max) begin
                        col_idx          <= 12'd0;
                        // LE 命令边沿数: 首行5 / 换行4 / 普通3 (LE 全程在数据移完之后发,
                        // datasheet: 数据传完后才产生 latch; LE 高期间芯片不收数据)
                        if (plane == 3'd0) begin
                            if (row_idx == 5'd0)
                                latch_edges_target <= 4'd5;
                            else
                                latch_edges_target <= 4'd4;
                        end else begin
                            latch_edges_target <= 4'd3;
                        end
                        latch_edge_count <= 4'd0;
                        ctrl_count       <= 4'd0;
                        state            <= S_LATCH;
                    end else begin
                        col_idx <= col_idx + 1;
                    end
                end

                //--------------------------------------------------------------
                // LE command word: hold LE=1 while toggling DCLK exactly
                // latch_edges_target EDGES (rises + falls combined).
                //
                // Strategy: every aclk we flip hub75e_dclk_out. Each flip is
                // ONE edge — we count latch_edge_count++ each cycle, and exit
                // when we've produced latch_edges_target edges.
                //
                // SDI/SIN during LE-high can be anything (chip latches reg2
                // from SR on LE command; SR may be overwritten). We keep
                // driving plane_rgb so SR ends up with consistent content.
                //--------------------------------------------------------------
                S_LATCH: begin
                    // 纯 LE 脉冲 (普通双锁存模式): LE 高电平期间 CLK 停在低、不打边沿。
                    // 外部 ABCDE 行选 → 不用片内行计数器 → 不需要 3/4/5 边沿命令。
                    // 去掉 LE 期间的 CLK 边沿 = 不再多移数据 → 从根上消除像素偏移。
                    hub75e_oe_out   <= 1'b1;
                    hub75e_lat_out  <= 1'b1;
                    hub75e_dclk_out <= 1'b0;       // CLK 停低, LE 期间无边沿
                    hub75e_rgb_out  <= plane_rgb;
                    // LE 脉冲保持 latch_edges_target 拍 (脉宽), 然后落沿锁存
                    if (latch_edge_count == latch_edges_target - 4'd1) begin
                        hub75e_lat_out <= 1'b0;
                        ctrl_count     <= 4'd0;
                        state          <= S_LATCH_GAP;
                    end else begin
                        latch_edge_count <= latch_edge_count + 4'd1;
                    end
                end

                //--------------------------------------------------------------
                // Brief gap with LE=0, DCLK=0 to satisfy setup/hold for the
                // following ABCDE update. Length = LATCH_GAP_CYC aclks.
                //--------------------------------------------------------------
                S_LATCH_GAP: begin
                    hub75e_lat_out  <= 1'b0;
                    hub75e_dclk_out <= 1'b0;
                    hub75e_oe_out   <= 1'b1;
                    if (ctrl_count == LATCH_GAP_CYC[3:0] - 1) begin
                        ctrl_count <= 4'd0;
                        state      <= S_ADDR_ABCDE;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                //--------------------------------------------------------------
                // External ABCDE row select. Updates AFTER LE latches reg2
                // so the new row select arrives in sync with the new display
                // latch content. OE still HIGH (panel blank).
                //--------------------------------------------------------------
                S_ADDR_ABCDE: begin
                    hub75e_lat_out <= 1'b0;
                    addr_abcde_lat <= row_idx;
                    row_displayed  <= row_idx;
                    if (ctrl_count == ADDR_SET_CYC[3:0] - 1) begin
                        ctrl_count  <= 4'd0;
                        disp_count  <= 16'd0;
                        // BCM plane weight: T_UNIT × 2^plane
                        disp_target <= {8'd0, t_unit} << plane;
                        state       <= S_DISPLAY;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                //--------------------------------------------------------------
                // Display window: OE LOW for disp_target aclk cycles.
                // ICND2047's chip-internal reg2 holds latched data; SR (reg1)
                // is idle (DCLK low). Could shift NEXT plane here for higher
                // fps (built-in shift-while-display), but MVP keeps sequential.
                //--------------------------------------------------------------
                S_DISPLAY: begin
                    hub75e_oe_out   <= enable ? 1'b0 : 1'b1;
                    hub75e_lat_out  <= 1'b0;
                    hub75e_dclk_out <= 1'b0;
                    if (disp_count >= disp_target) begin
                        hub75e_oe_out <= 1'b1;
                        state         <= S_DISPLAY_END;
                    end else begin
                        disp_count <= disp_count + 1;
                    end
                end

                //--------------------------------------------------------------
                // End-of-display: OE high, advance (plane, row), back to SHIFT.
                //--------------------------------------------------------------
                S_DISPLAY_END: begin
                    hub75e_oe_out   <= 1'b1;
                    hub75e_lat_out  <= 1'b0;
                    hub75e_dclk_out <= 1'b0;
                    if (plane == BCM_PLANES[2:0] - 3'd1) begin
                        plane <= 3'd0;
                        if (row_idx == row_max) begin
                            row_idx     <= 5'd0;
                            frame_count <= frame_count + 1;
                            // Walk demo position update
                            if (walk_div_count == walk_speed - 1) begin
                                walk_div_count <= 8'd0;
                                if (test_mode == 3'd4) begin
                                    walk_pos <= (walk_pos == row_max) ? 8'd0 : walk_pos + 1;
                                end else if (test_mode == 3'd5) begin
                                    walk_pos <= (walk_pos == width_max[7:0]) ? 8'd0 : walk_pos + 1;
                                end
                            end else begin
                                walk_div_count <= walk_div_count + 1;
                            end
                        end else begin
                            row_idx <= row_idx + 1;
                        end
                    end else begin
                        plane <= plane + 1;
                    end
                    state <= enable ? S_SHIFT : S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
