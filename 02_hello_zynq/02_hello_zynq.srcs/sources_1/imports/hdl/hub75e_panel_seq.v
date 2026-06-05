//-----------------------------------------------------------------------------
// hub75e_panel_seq.v - 128x64 HUB75E FM6124 panel PL driver (BCM 8-bit)
//
// Phase 1+A: 8-bit per channel BCM (256 灰度), 24-bit true color
//            DCLK_DIV=2 @ 50 MHz aclk → 25 MHz DCLK 50% duty
//            8 plane per row × 32 row = ~75 Hz @ T_unit 1.28 µs
//
// 双模式 ADDR (运行时 reg_ctrl[4] 切换):
//   0 = 标准 ABCDE 5-bit 行解码
//   1 = multivox shift register 32-bit
//
// AXI-Lite 寄存器:
//   0x00 CTRL   [0]=en [3:1]=mode [4]=addr_sr [5]=use_fb [6]=overlap_en [12:8]=addr_bits
//   0x04 COLOR  [23:0] 顶半 24-bit RGB (R[7:0] | G[15:8] | B[23:16])
//   0x08 PARAM  [11:0]=width-1 [23:16]=stripe_w [31:24]=walk_speed
//   0x0C STATUS [0]=running [12:8]=cur_addr [15:13]=cur_plane [31:16]=frame_count
//   0x10 COLOR_BOT [23:0] 底半 24-bit RGB (mode 0 用; 0 时跟 COLOR 同色)
//   0x14 BCM_TUNIT [7:0] (默认 64 cycle ≈ 1.28 µs @ 50 MHz)
//
// FM6124 datasheet (V1.0 / S&CIC1501):
//   FCLK max 30 MHz, TWCLK ≥ 20 ns, TWLE ≥ 20 ns, TWOE ≥ 30 ns, setup/hold ≥ 5 ns
//
// BCM 原理:
//   - 24-bit RGB → 8 个 1-bit plane (bit 0..7)
//   - plane N 显示时长 = T_unit × 2^N
//   - 8 plane 总显示 = 255 × T_unit
//   - shift 时间每 plane = 128 col × DCLK_DIV aclk
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

// AXI 地址布局 (16-bit, 64 KB):
//   0x0000-0x001F : 控制寄存器区 (bit[15]=0, 用 bit[4:2] 选 6 reg)
//   0x8000-0xFFFF : framebuffer 区 (bit[15]=1, 用 bit[14:2] = pixel index 0..8191)
//   每 pixel 32-bit aligned, 低 24-bit = RGB (R[7:0] G[15:8] B[23:16])
//   total 8192 pixel × 24-bit = 196608 bit = 6 个 36Kb BRAM
// v33 Phase 2: rename to v3 for BD recreate path (memory feedback_vivado_bd_addr_width_cache.md)
// v3 = FM6124 driver + hub75e_rgb_out2 output port for panel 2 mirror (128×128 dual panel)
module hub75e_panel_seq_v3 #(
    parameter integer DCLK_DIV     = 2,    // 75 MHz / 2 = 37.5 MHz DCLK 50% duty (超 FM6124 spec 30M 25%, 实测)
    parameter integer PANEL_WIDTH  = 128,
    parameter integer ADDR_BITS    = 5,    // 1/32 scan
    parameter integer BCM_PLANES   = 6,    // 6-bit per channel (64 灰度, 帧率 ×4 vs 8-bit)
    parameter integer T_UNIT_DEF   = 8,    // 默认 TUNIT=8 cycle (用户测试)
    parameter integer DISP_CYCLES  = 1000, // (legacy compat)
    parameter integer LATCH_CYC    = 2,    // tWLE=20ns spec, 2 cyc @ 60MHz = 33ns (1.65x margin)
    parameter integer BLANK_CYC    = 1,    // tSETUP2=5ns spec (CLK→LE), 1 cyc = 17ns (3.3x margin)
    parameter integer ADDR_SET_CYC = 1,    // v29: LE-fall → OE-fall 缩到 1 cyc (~14ns), spec 无指定下限
    parameter integer OE_PRE_CYC   = 8,    // v28: OE-fall setup before shift, gives FM6124DJ time to cache SR (memory ≥100ns, 不动)
    parameter integer FB_DEPTH     = 8192  // 128×64 pixel
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

    output reg [5:0]   hub75e_rgb_out,
    output reg [5:0]   hub75e_rgb_out2,  // v33: panel 2 SDI (128×128 dual panel, MVP mirror panel 1)
    output reg         hub75e_dclk_out,
    output reg         hub75e_lat_out,
    output reg         hub75e_oe_out,
    output reg [4:0]   hub75e_addr_out
);

    //==========================================================================
    // AXI-Lite 寄存器
    //==========================================================================
    reg [31:0] reg_ctrl;
    reg [31:0] reg_color;       // 0x04 top color
    reg [31:0] reg_param;
    reg [31:0] reg_color_bot;   // 0x10 bot color
    reg [31:0] reg_tunit;       // 0x14 T_unit

    wire        enable        = reg_ctrl[0];
    wire [2:0]  test_mode     = reg_ctrl[3:1];
    wire        addr_mode_sr  = reg_ctrl[4];
    wire        use_fb        = reg_ctrl[5];   // 1=从 framebuffer 取 pixel, 0=用 pattern LUT
    wire        overlap_en    = reg_ctrl[6];   // v28: 1=enable shift-while-display overlap (ABCDE only), 0=serial
    wire [4:0]  addr_bits_cfg = (reg_ctrl[12:8] == 5'd0) ? 5'd5 : reg_ctrl[12:8];
    wire [4:0]  row_max       = (5'd1 << addr_bits_cfg) - 5'd1;
    wire [23:0] user_color_top = reg_color[23:0];
    wire [23:0] user_color_bot = (reg_color_bot[23:0] == 24'h0 && reg_color[23:0] != 24'h0)
                                  ? reg_color[23:0] : reg_color_bot[23:0];
    wire [11:0] width_max     = (reg_param[11:0] == 12'd0) ? PANEL_WIDTH-1 : reg_param[11:0];
    wire [7:0]  stripe_w      = (reg_param[23:16] == 8'd0) ? 8'd8 : reg_param[23:16];
    wire [7:0]  walk_speed    = (reg_param[31:24] == 8'd0) ? 8'd10 : reg_param[31:24];
    wire [7:0]  t_unit        = (reg_tunit[7:0] == 8'd0) ? T_UNIT_DEF[7:0] : reg_tunit[7:0];
    // v31: runtime BCM planes (1..6 bit). reg_tunit[11:8]=0 → BCM_PLANES default
    wire [3:0]  bcm_planes_cfg = (reg_tunit[11:8] == 4'd0) ? BCM_PLANES[3:0] : reg_tunit[11:8];
    wire [2:0]  plane_max_run  = bcm_planes_cfg[2:0] - 3'd1;

    // Framebuffer 用 sdp_bram helper module 实例化 (Xilinx UG901 标准 SDP 模板)
    // 之前 inferred BRAM in main module 不稳, 实例化 sub-module 强制 SDP 行为
    wire fb_top_we_main;
    wire fb_bot_we_main;
    wire [11:0] fb_waddr_main = cur_aw_addr[13:2];
    wire [23:0] fb_wdata_main = s_axi_wdata[23:0];
    assign fb_top_we_main = (s_axi_wvalid && !w_done && (aw_done || s_axi_awvalid) &&
                              cur_aw_addr[15] && !cur_aw_addr[14]);
    assign fb_bot_we_main = (s_axi_wvalid && !w_done && (aw_done || s_axi_awvalid) &&
                              cur_aw_addr[15] && cur_aw_addr[14]);

    // DEBUG: 任何 AXI W handshake 都触发 fb_top_we (用来验证 ARM 写 AXI 是否真到 IP)
    // 实际 BRAM write 在 main always block 嵌套 if 里, 这只是 debug counter
    wire fb_top_we = s_axi_wvalid && !w_done && (aw_done || s_axi_awvalid);

    reg [15:0] aw_addr_q;
    reg        aw_done, w_done;
    // Verilog 不支持 (ternary)[bit slice], 用 wire 包一层
    wire [15:0] cur_aw_addr = aw_done ? aw_addr_q : s_axi_awaddr;
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
                        // DEBUG: 把 fb wdata sample 移到 main always block, 跟 reg_color 完全同条件
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
                    // framebuffer write-only (combinational BRAM read 让 Vivado 推 LUTRAM
                    // + constant propagation 删 RAM). AXI read fb 永远返回 0.
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
    // FSM (v28: hybrid - serial + optional overlap with OE_PRE delay)
    // CTRL[6]=overlap_en chooses path at runtime (ABCDE only, SR mode always serial):
    //   overlap_en=0: SHIFT → BLANK → LATCH → ADDR → DISPLAY → SHIFT (serial, BCM safe)
    //   overlap_en=1: SHIFT (initial prime) → BLANK → LATCH → ADDR → OE_PRE → PHASE
    //                 → BLANK → LATCH → ADDR → OE_PRE → PHASE → ...
    //                 S_OE_PRE drops OE, waits OE_PRE_CYC for FM6124DJ to cache SR data
    //                 into display latch (per datasheet OE-falling-edge spec), then
    //                 S_PHASE shifts next plane while displaying current.
    //==========================================================================
    localparam [3:0]
        S_IDLE       = 4'd0,
        S_SHIFT      = 4'd1,
        S_BLANK      = 4'd2,
        S_LATCH      = 4'd3,
        S_ADDR_ABCDE = 4'd4,
        S_ADDR_SR    = 4'd5,
        S_DISPLAY    = 4'd6,
        S_OE_PRE     = 4'd7,    // v28 overlap: drop OE, wait for chip cache
        S_PHASE      = 4'd8;    // v28 overlap: shift next + display current

    reg [3:0]  state;
    reg [11:0] col_idx;
    reg [4:0]  row_idx;
    reg [4:0]  row_displayed;
    reg [2:0]  plane;
    reg [4:0]  disp_row;        // v28 overlap: snapshot at LATCH (= currently displayed row)
    reg [2:0]  disp_plane;      // v28 overlap: snapshot at LATCH (= currently displayed plane)
    reg        shift_active;    // v28 overlap: 1 = shift still pushing SR
    reg        disp_active;     // v28 overlap: 1 = OE should be low (display running)
    reg [15:0] frame_count;
    reg [7:0]  walk_pos;
    reg [7:0]  walk_div_count;
    reg [15:0] disp_count;
    reg [15:0] disp_target;
    reg [3:0]  ctrl_count;
    reg [$clog2(DCLK_DIV):0] sub_count;

    reg [5:0]  sr_bit_idx;
    reg [1:0]  sr_sub;
    reg        sr_clk;
    reg        sr_dat;
    reg        sr_en;
    reg [4:0]  addr_abcde_lat;

    // fb_we_count + last_fb_wdata + last_fb_waddr 在 main always block 内 sample
    reg [15:0] fb_we_count;
    reg [23:0] last_fb_wdata;
    reg [11:0] last_fb_waddr;
    // STATUS [31:16]=frame_count [15:13]=plane [12:8]=row_displayed [0]=running
    wire [31:0] status_word = {frame_count, plane, row_displayed, 7'b0, (state != S_IDLE)};

    //==========================================================================
    // Pattern generator: 24-bit per RGB → plane slice → 6-bit out
    // pattern_24_top/_bot 是组合, 取决于 mode + (col, row)
    // 输出 pattern_rgb = {B2[p], G2[p], R2[p], B1[p], G1[p], R1[p]}
    //==========================================================================
    reg [23:0] pattern_24_top_lut;
    reg [23:0] pattern_24_bot_lut;

    // PL 端 BRAM read addr
    wire [11:0] fb_raddr = {row_idx[4:0], col_idx[6:0]};
    wire [23:0] fb_top_dout, fb_bot_dout;

    // Xilinx XPM macro: 100% defined behavior, Vivado 不会 swap/优化掉
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(12), .ADDR_WIDTH_B(12),
        .BYTE_WRITE_WIDTH_A(24),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(98304),       // 4096 entries × 24-bit
        .READ_DATA_WIDTH_B(24),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(24),
        .USE_MEM_INIT(0)
    ) u_fb_top (
        .clka(s_axi_aclk), .ena(1'b1), .wea(fb_top_we_main),
        .addra(fb_waddr_main), .dina(fb_wdata_main),
        .clkb(s_axi_aclk), .enb(1'b1), .regceb(1'b1), .rstb(1'b0),
        .addrb(fb_raddr), .doutb(fb_top_dout),
        .injectsbiterra(1'b0), .injectdbiterra(1'b0), .sleep(1'b0),
        .sbiterrb(), .dbiterrb()
    );
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(12), .ADDR_WIDTH_B(12),
        .BYTE_WRITE_WIDTH_A(24),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(98304),
        .READ_DATA_WIDTH_B(24),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(24),
        .USE_MEM_INIT(0)
    ) u_fb_bot (
        .clka(s_axi_aclk), .ena(1'b1), .wea(fb_bot_we_main),
        .addra(fb_waddr_main), .dina(fb_wdata_main),
        .clkb(s_axi_aclk), .enb(1'b1), .regceb(1'b1), .rstb(1'b0),
        .addrb(fb_raddr), .doutb(fb_bot_dout),
        .injectsbiterra(1'b0), .injectdbiterra(1'b0), .sleep(1'b0),
        .sbiterrb(), .dbiterrb()
    );

    // pattern_24 = LUT (use_fb=0) vs framebuffer 读 (use_fb=1)
    // BRAM write 改成独立 always block 后 (UG901 SDP 标准), fb_dout 应该有 ARM 写的 data
    wire [23:0] pattern_24_top = use_fb ? fb_top_dout : pattern_24_top_lut;
    wire [23:0] pattern_24_bot = use_fb ? fb_bot_dout : pattern_24_bot_lut;

    // 8 色 LUT (R, G, B, W, Y, M, C, K) — R in low byte
    function [23:0] color_lut;
        input [2:0] i;
        begin
            case (i)
                3'd0: color_lut = 24'h0000FF;  // R
                3'd1: color_lut = 24'h00FF00;  // G
                3'd2: color_lut = 24'hFF0000;  // B
                3'd3: color_lut = 24'hFFFFFF;  // W
                3'd4: color_lut = 24'h00FFFF;  // Y (R+G)
                3'd5: color_lut = 24'hFF00FF;  // M (R+B)
                3'd6: color_lut = 24'hFFFF00;  // C (G+B)
                default: color_lut = 24'h000000; // K
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
                // 固定 4-row 一条 stripe (row / 4 & 7), 去除除法器
                pattern_24_top_lut = color_lut(row_idx[4:2]);
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd2: begin
                // 固定 16-col 一条 stripe (col / 16 & 7), 去除除法器以缩短 critical path
                pattern_24_top_lut = color_lut(col_idx[6:4]);
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd3: begin
                pattern_24_top_lut = (col_idx[3] ^ row_idx[2]) ? 24'h0000FF : 24'h00FF00;
                pattern_24_bot_lut = (col_idx[3] ^ row_idx[2]) ? 24'h00FF00 : 24'h0000FF;
            end
            3'd4: begin
                pattern_24_top_lut = (row_idx == walk_pos[4:0]) ? 24'hFFFFFF : 24'h000000;
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd5: begin
                pattern_24_top_lut = (col_idx[7:0] == walk_pos) ? 24'hFFFFFF : 24'h000000;
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd6: begin
                // 渐变: col 低 8 bit 作 R, col 中 G, col 高 B
                pattern_24_top_lut = {col_idx[7:0], col_idx[7:0], col_idx[7:0]};
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            default: begin   // mode 7 FULL WHITE
                pattern_24_top_lut = 24'hFFFFFF;
                pattern_24_bot_lut = 24'hFFFFFF;
            end
        endcase
    end

    // BCM slice: 取 plane 位的 R/G/B bit
    // BCM plane bit slice (修复: 之前 3'd0 + 3'd8 expression 不正确算 bit index)
    wire [4:0] plane_ext = {2'b0, plane};
    wire r1_bit = pattern_24_top[plane_ext];
    wire g1_bit = pattern_24_top[plane_ext + 5'd8];
    wire b1_bit = pattern_24_top[plane_ext + 5'd16];
    wire r2_bit = pattern_24_bot[plane_ext];
    wire g2_bit = pattern_24_bot[plane_ext + 5'd8];
    wire b2_bit = pattern_24_bot[plane_ext + 5'd16];
    wire [5:0] plane_rgb = {b2_bit, g2_bit, r2_bit, b1_bit, g1_bit, r1_bit};

    //==========================================================================
    // ADDR 输出 mux
    //==========================================================================
    always @(*) begin
        if (addr_mode_sr) begin
            hub75e_addr_out = {2'b00, sr_en, sr_dat, sr_clk};
        end else begin
            hub75e_addr_out = addr_abcde_lat;
        end
    end

    //==========================================================================
    // 主 FSM (BCM: 每 row 跑 8 plane)
    //==========================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            state           <= S_IDLE;
            col_idx         <= 12'd0;
            row_idx         <= 5'd0;
            row_displayed   <= 5'd0;
            plane           <= 3'd0;
            disp_row        <= 5'd0;
            disp_plane      <= 3'd0;
            shift_active    <= 1'b0;
            disp_active     <= 1'b0;
            sub_count       <= 0;
            ctrl_count      <= 4'd0;
            disp_count      <= 16'd0;
            disp_target     <= 16'd0;
            frame_count     <= 16'd0;
            walk_pos        <= 8'd0;
            walk_div_count  <= 8'd0;
            hub75e_rgb_out  <= 6'b0;
            hub75e_rgb_out2 <= 6'b0;
            hub75e_dclk_out <= 1'b0;
            hub75e_lat_out  <= 1'b0;
            hub75e_oe_out   <= 1'b1;
            addr_abcde_lat  <= 5'b0;
            sr_bit_idx      <= 6'd0;
            sr_sub          <= 2'd0;
            sr_clk          <= 1'b0;
            sr_dat          <= 1'b0;
            sr_en           <= 1'b1;
        end else begin
            case (state)
                S_IDLE: begin
                    hub75e_oe_out   <= 1'b1;
                    hub75e_lat_out  <= 1'b0;
                    hub75e_dclk_out <= 1'b0;
                    hub75e_rgb_out  <= 6'b0;
                    hub75e_rgb_out2 <= 6'b0;
                    sr_en           <= 1'b1;
                    sr_clk          <= 1'b0;
                    col_idx         <= 12'd0;
                    row_idx         <= 5'd0;
                    plane           <= 3'd0;
                    disp_row        <= 5'd0;
                    disp_plane      <= 3'd0;
                    shift_active    <= 1'b0;
                    disp_active     <= 1'b0;
                    sub_count       <= 0;
                    if (enable) state <= S_SHIFT;
                end

                S_SHIFT: begin
                    hub75e_oe_out  <= 1'b1;
                    hub75e_lat_out <= 1'b0;
                    hub75e_rgb_out <= plane_rgb;
                    hub75e_rgb_out2 <= plane_rgb;

                    if (sub_count == (DCLK_DIV/2 - 1)) begin
                        hub75e_dclk_out <= 1'b1;
                        sub_count       <= sub_count + 1;
                    end else if (sub_count == (DCLK_DIV - 1)) begin
                        hub75e_dclk_out <= 1'b0;
                        sub_count       <= 0;
                        if (col_idx == width_max) begin
                            col_idx <= 12'd0;
                            state   <= S_BLANK;
                            ctrl_count <= 4'd0;
                        end else begin
                            col_idx <= col_idx + 1;
                        end
                    end else begin
                        sub_count <= sub_count + 1;
                    end
                end

                S_BLANK: begin
                    hub75e_dclk_out <= 1'b0;
                    hub75e_oe_out   <= 1'b1;
                    sr_en           <= 1'b1;
                    if (ctrl_count == BLANK_CYC[3:0] - 1) begin
                        ctrl_count <= 4'd0;
                        state <= S_LATCH;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                S_LATCH: begin
                    hub75e_lat_out <= 1'b1;
                    if (ctrl_count == LATCH_CYC[3:0] - 1) begin
                        hub75e_lat_out <= 1'b0;
                        ctrl_count  <= 4'd0;
                        disp_count  <= 16'd0;
                        disp_target <= {8'd0, t_unit} << plane;
                        sr_bit_idx  <= 6'd0;
                        sr_sub      <= 2'd0;
                        sr_clk      <= 1'b0;
                        sr_dat      <= 1'b0;
                        // v28 OVERLAP path (ABCDE only): snapshot disp_* + advance plane/row
                        if (overlap_en && !addr_mode_sr) begin
                            disp_row    <= row_idx;
                            disp_plane  <= plane;
                            if (plane == plane_max_run) begin
                                plane <= 3'd0;
                                if (row_idx == row_max) begin
                                    row_idx <= 5'd0;
                                    frame_count <= frame_count + 1;
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
                            state <= S_ADDR_ABCDE;
                        end else begin
                            // serial path (both SR mode and overlap_en=0 ABCDE)
                            state <= addr_mode_sr ? S_ADDR_SR : S_ADDR_ABCDE;
                        end
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                S_ADDR_ABCDE: begin
                    hub75e_lat_out  <= 1'b0;
                    // overlap path uses disp_row (= row just snapshotted, what's in output latch)
                    // serial path uses row_idx (no advance yet, same value)
                    addr_abcde_lat  <= (overlap_en) ? disp_row : row_idx;
                    row_displayed   <= (overlap_en) ? disp_row : row_idx;
                    if (ctrl_count == ADDR_SET_CYC[3:0] - 1) begin
                        ctrl_count <= 4'd0;
                        state      <= overlap_en ? S_OE_PRE : S_DISPLAY;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                // v28 OVERLAP: drop OE LOW, wait OE_PRE_CYC cycles. This gives FM6124DJ
                // time to cache SR data to its internal display latch at the OE falling edge
                // (per datasheet). Only THEN start shifting next plane into SR.
                S_OE_PRE: begin
                    hub75e_lat_out  <= 1'b0;
                    hub75e_oe_out   <= enable ? 1'b0 : 1'b1;   // OE drops here
                    hub75e_dclk_out <= 1'b0;
                    if (ctrl_count == OE_PRE_CYC[3:0] - 1) begin
                        ctrl_count   <= 4'd0;
                        disp_count   <= 16'd0;
                        disp_active  <= 1'b1;
                        shift_active <= 1'b1;
                        state        <= S_PHASE;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                // v28 OVERLAP: shift NEXT plane (uses advanced `plane`) into SR while
                // displaying CURRENT plane (in chip's display latch, from OE_PRE cache).
                // Exits when both shift_active and disp_active are 0.
                S_PHASE: begin
                    hub75e_lat_out <= 1'b0;
                    // Display half
                    if (disp_active) begin
                        hub75e_oe_out <= enable ? 1'b0 : 1'b1;
                        if (disp_count >= disp_target) begin
                            disp_active   <= 1'b0;
                            hub75e_oe_out <= 1'b1;
                        end else begin
                            disp_count <= disp_count + 1;
                        end
                    end else begin
                        hub75e_oe_out <= 1'b1;
                    end
                    // Shift half (uses pattern_rgb at current `plane` = advanced NEXT plane)
                    if (shift_active) begin
                        hub75e_rgb_out <= plane_rgb;
                        hub75e_rgb_out2 <= plane_rgb;
                        if (sub_count == (DCLK_DIV/2 - 1)) begin
                            hub75e_dclk_out <= 1'b1;
                            sub_count       <= sub_count + 1;
                        end else if (sub_count == (DCLK_DIV - 1)) begin
                            hub75e_dclk_out <= 1'b0;
                            sub_count       <= 0;
                            if (col_idx == width_max) begin
                                col_idx      <= 12'd0;
                                shift_active <= 1'b0;
                            end else begin
                                col_idx <= col_idx + 1;
                            end
                        end else begin
                            sub_count <= sub_count + 1;
                        end
                    end else begin
                        hub75e_dclk_out <= 1'b0;
                    end
                    // Both done → BLANK (which will go to LATCH for next plane)
                    if (!shift_active && !disp_active) begin
                        hub75e_oe_out <= 1'b1;
                        ctrl_count    <= 4'd0;
                        // If !enable, return to IDLE; else continue
                        state <= enable ? S_LATCH : S_IDLE;  // v29: 跳过 S_BLANK 省 1 cyc (CLK→LE -14ns)
                    end
                end

                S_ADDR_SR: begin
                    sr_en <= 1'b1;
                    case (sr_sub)
                        2'd0: begin
                            sr_clk <= 1'b0;
                            sr_dat <= (sr_bit_idx[4:0] == row_idx) ? 1'b1 : 1'b0;
                            sr_sub <= 2'd1;
                        end
                        2'd1: begin sr_clk <= 1'b1; sr_sub <= 2'd2; end
                        2'd2: begin sr_clk <= 1'b0; sr_sub <= 2'd3; end
                        2'd3: begin
                            sr_sub <= 2'd0;
                            if (sr_bit_idx == 6'd31) begin
                                sr_dat        <= 1'b0;
                                row_displayed <= row_idx;
                                disp_count    <= 16'd0;
                                disp_target   <= {8'd0, t_unit} << plane;
                                state         <= S_DISPLAY;
                            end else begin
                                sr_bit_idx <= sr_bit_idx + 1;
                            end
                        end
                    endcase
                end

                S_DISPLAY: begin
                    // SR legacy 串行 display
                    hub75e_oe_out <= enable ? 1'b0 : 1'b1;
                    sr_en         <= 1'b0;
                    if (disp_count >= disp_target) begin
                        hub75e_oe_out <= 1'b1;
                        sr_en         <= 1'b1;
                        disp_count    <= 16'd0;
                        if (plane == plane_max_run) begin
                            plane <= 3'd0;
                            if (row_idx == row_max) begin
                                row_idx <= 5'd0;
                                frame_count <= frame_count + 1;
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
                    end else begin
                        disp_count <= disp_count + 1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule


//-----------------------------------------------------------------------------
// sdp_bram: 加 enable signal 防止 Vivado optimize swap we ↔ ce
// 上版本 (无 re port) Vivado 报 "Swapped enable and write-enable ... to conserve
// power" — 把 read port enable 接到 we, 让 read 只在 write 时 clock, rdata 锁 0.
// 加 explicit re=1'b1 input 显式 read enable, 防 swap.
//-----------------------------------------------------------------------------
module sdp_bram #(
    parameter integer WIDTH  = 24,
    parameter integer DEPTH  = 4096,
    parameter integer ADDR_W = 12
)(
    input  wire              clk,
    input  wire              we,
    input  wire [ADDR_W-1:0] waddr,
    input  wire [WIDTH-1:0]  wdata,
    input  wire              re,
    input  wire [ADDR_W-1:0] raddr,
    output reg  [WIDTH-1:0]  rdata
);
    (* ram_style = "block", keep = "true" *) reg [WIDTH-1:0] mem [0:DEPTH-1];

    // 拆 2 个 always block, port-A write + port-B read 完全独立
    always @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
    end
    always @(posedge clk) begin
        if (re) rdata <= mem[raddr];
    end
endmodule

