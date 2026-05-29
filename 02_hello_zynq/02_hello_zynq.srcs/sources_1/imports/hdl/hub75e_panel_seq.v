//-----------------------------------------------------------------------------
// hub75e_panel_seq.v - 128x64 HUB75E FM6124 panel PL driver
//
// 目标 panel: 128×64 HUB75E, FM6124 cascade 8 颗/chain × 6 RGB chain
//             1/32 scan (PANEL_FIELD_HEIGHT = 32)
//
// 双模式 ADDR (运行时 reg_ctrl[5:4] 切换, 引脚位置不变):
//   ADDR_MODE = 0: 标准 HUB75E ABCDE 5-bit 行解码 (74HC138 + MOSFET 等)
//                  addr_out[4:0] = {E, D, C, B, A} = row 0..31 二进制
//   ADDR_MODE = 1: multivox vortex 风格 32-bit shift register row driver
//                  addr_out[0] = ADDR_CLK
//                  addr_out[1] = ADDR_DAT
//                  addr_out[2] = ADDR_EN (低有效 → 行 driver 使能)
//                  addr_out[4:3] = 0 (留空, panel 那边接 GND)
//                  推 32 个 bit, "1" 在第 row 位 → 点亮第 row 行
//
// FM6124 datasheet (V1.0 / S&CIC1501) 关键时序 (page 5):
//   ┌─────────────────────────────────────────────────────────────┐
//   │ 符号       描述              min  typ  max  unit            │
//   ├─────────────────────────────────────────────────────────────┤
//   │ FCLK      数据传输频率              30  MHz   ← 用户目标     │
//   │ TWCLK     CLK H/L 半宽       20            ns  ⚠ 30M=16.7ns │
//   │ TWLE      LE 高脉冲宽        20            ns                │
//   │ TWOE      OE 脉冲宽          30            ns (REXT=890Ω)   │
//   │ THOLD1/2  保持时间            5            ns                │
//   │ TSETUP1/2 建立时间            5            ns                │
//   │ TR / TF   CLK 最大上升/下降       500     ns                 │
//   └─────────────────────────────────────────────────────────────┘
//   chip 行为 (pin description + timing diag 2):
//     - CLK 上升沿 shift SIN 进 16-bit shift register (MSB first)
//     - LE 高电平 → shift register → output latch
//     - OE 低 → output 显示 latched data; OE 高 → output OFF
//     - 双缓存: OE 下降沿时 latch1→latch2, 显示期间可 shift 下一帧
//
// 参考: multivox/src/driver/vortex.c 主循环 + set_matrix_row()
//       128×64 1/32 scan, R1/G1/B1 推顶半 32 行, R2/G2/B2 推底半 32 行
//
// AXI-Lite 寄存器 (offset, R/W):
//   0x00 CTRL
//     [0]      enable          (0=blank panel/IP idle, 1=run)
//     [3:1]    test_mode (0-7)
//     [5:4]    addr_mode       (0=ABCDE, 1=shift_register)
//     [7:6]    reserved
//     [12:8]   addr_bits_use   (0→默认 5=1/32; 4=1/16; 3=1/8)
//   0x04 COLOR  [5:0] = {B2,G2,R2,B1,G1,R1} (mode 0/1 主色, 1-bit per channel)
//   0x08 PARAM
//     [11:0]   panel_width-1   (默认 127 = 128 cols)
//     [23:16]  stripe_width    (mode 1/2 条纹宽, 默认 8)
//     [31:24]  walk_speed      (mode 4/5 walk 速度, 默认 10)
//   0x0C STATUS (R/O)
//     [0]      running
//     [12:8]   cur_addr
//     [31:16]  frame_count
//
// 时钟: s_axi_aclk = 120 MHz (FCLK1 from PS PLL, IO_PLL/9 = 1080/9)
//       DCLK_DIV = 4 → DCLK = 30 MHz, 占空比 50% (2 high + 2 low aclk cycle)
//       Setup: SDI 在 sub=0 settle, DCLK↑ 在 sub=2 → 16.67 ns setup ✓
//       Hold:  DCLK↑→ SDI next change = 2 aclk cycle = 16.67 ns ✓
//
// 性能 (1/32 scan, 128 col, ABCDE 模式):
//   S_SHIFT=4.27 µs + S_BLANK/LATCH/ADDR ≈ 100 ns + S_DISPLAY 10 µs = ~14.4 µs/row
//   32 row/frame ≈ 460 µs;  refresh ≈ 2.2 kHz (1-bit 色深)
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module hub75e_panel_seq #(
    parameter integer DCLK_DIV     = 4,    // ACLK/DCLK_DIV = DCLK 周期; 120M/4=30M
    parameter integer PANEL_WIDTH  = 128,
    parameter integer ADDR_BITS    = 5,    // 1/2^N scan (default 1/32)
    parameter integer DISP_CYCLES  = 1200, // OE-low 持续 aclk 拍数 (120M*10us=1200)
    parameter integer LATCH_CYC    = 4,    // LE 高 cycle 数 (33 ns @ 120M, ≥20 ns spec)
    parameter integer BLANK_CYC    = 5,    // OE 高 blank cycle (42 ns ≥30 ns spec)
    parameter integer ADDR_SET_CYC = 3     // ABCDE 设值后稳定 cycle
)(
    // AXI-Lite slave
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [4:0]  s_axi_awaddr,
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
    input  wire [4:0]  s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // HUB75E panel
    output reg [5:0]   hub75e_rgb_out,    // {B2,G2,R2,B1,G1,R1}
    output reg         hub75e_dclk_out,   // FM6124 CLK 30 MHz
    output reg         hub75e_lat_out,    // FM6124 LE (高 latch)
    output reg         hub75e_oe_out,     // FM6124 OE (低=亮, 高=灭)
    output reg [4:0]   hub75e_addr_out    // ABCDE / {x,x,EN,DAT,CLK}
);

    //==========================================================================
    // AXI-Lite write/read 状态机
    //==========================================================================
    reg [31:0] reg_ctrl;
    reg [31:0] reg_color;
    reg [31:0] reg_param;

    wire        enable        = reg_ctrl[0];
    wire [2:0]  test_mode     = reg_ctrl[3:1];
    wire        addr_mode_sr  = reg_ctrl[4];    // 0=ABCDE, 1=shift register
    wire [4:0]  addr_bits_cfg = (reg_ctrl[12:8] == 5'd0) ? 5'd5 : reg_ctrl[12:8];
    wire [4:0]  row_max       = (5'd1 << addr_bits_cfg) - 5'd1;
    wire [5:0]  user_color    = reg_color[5:0];
    wire [11:0] width_max     = (reg_param[11:0] == 12'd0) ? PANEL_WIDTH-1 : reg_param[11:0];
    wire [7:0]  stripe_w      = (reg_param[23:16] == 8'd0) ? 8'd8 : reg_param[23:16];
    wire [7:0]  walk_speed    = (reg_param[31:24] == 8'd0) ? 8'd10 : reg_param[31:24];

    reg [4:0] aw_addr_q;
    reg       aw_done, w_done;
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
                    case ((aw_done ? aw_addr_q : s_axi_awaddr) >> 2)
                        3'd0: reg_ctrl  <= s_axi_wdata;
                        3'd1: reg_color <= s_axi_wdata;
                        3'd2: reg_param <= s_axi_wdata;
                        default: ;
                    endcase
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
                case (s_axi_araddr >> 2)
                    3'd0: s_axi_rdata <= reg_ctrl;
                    3'd1: s_axi_rdata <= reg_color;
                    3'd2: s_axi_rdata <= reg_param;
                    3'd3: s_axi_rdata <= status_word;
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
    // FSM
    //==========================================================================
    localparam [3:0]
        S_IDLE       = 4'd0,
        S_SHIFT      = 4'd1,
        S_BLANK      = 4'd2,
        S_LATCH      = 4'd3,
        S_ADDR_ABCDE = 4'd4,   // ABCDE mode: 设 5-bit row index
        S_ADDR_SR    = 4'd5,   // shift-reg mode: 推 32 个 ADDR_CLK
        S_DISPLAY    = 4'd6;

    reg [3:0]  state;
    reg [11:0] col_idx;
    reg [4:0]  row_idx;
    reg [4:0]  row_displayed;
    reg [15:0] frame_count;
    reg [7:0]  walk_pos;
    reg [7:0]  walk_div_count;
    reg [13:0] disp_count;
    reg [3:0]  ctrl_count;
    reg [$clog2(DCLK_DIV):0] sub_count;

    // Shift-register ADDR state
    reg [5:0]  sr_bit_idx;       // 0..31 推 32 个 bit
    reg [1:0]  sr_sub;           // ADDR_CLK 半周期计数
    reg        sr_clk;
    reg        sr_dat;

    wire [31:0] status_word = {frame_count, 3'b0, row_displayed, 7'b0, (state != S_IDLE)};

    //==========================================================================
    // Pattern generator (组合)
    // RGB bit order: [0]=R1 [1]=G1 [2]=B1 [3]=R2 [4]=G2 [5]=B2
    //==========================================================================
    reg [5:0] pattern_rgb;
    always @(*) begin
        case (test_mode)
            3'd0: pattern_rgb = user_color;
            3'd1: begin
                case ((row_idx / stripe_w[4:0]) & 3'h7)
                    3'd0:    pattern_rgb = 6'b001_001;
                    3'd1:    pattern_rgb = 6'b010_010;
                    3'd2:    pattern_rgb = 6'b100_100;
                    3'd3:    pattern_rgb = 6'b111_111;
                    3'd4:    pattern_rgb = 6'b011_011;
                    3'd5:    pattern_rgb = 6'b101_101;
                    3'd6:    pattern_rgb = 6'b110_110;
                    default: pattern_rgb = 6'b000_000;
                endcase
            end
            3'd2: begin
                case ((col_idx[10:0] / stripe_w) & 3'h7)
                    3'd0:    pattern_rgb = 6'b001_001;
                    3'd1:    pattern_rgb = 6'b010_010;
                    3'd2:    pattern_rgb = 6'b100_100;
                    3'd3:    pattern_rgb = 6'b111_111;
                    3'd4:    pattern_rgb = 6'b011_011;
                    3'd5:    pattern_rgb = 6'b101_101;
                    3'd6:    pattern_rgb = 6'b110_110;
                    default: pattern_rgb = 6'b000_000;
                endcase
            end
            3'd3: pattern_rgb = (col_idx[3] ^ row_idx[2]) ? 6'b001_100 : 6'b100_001;
            3'd4: pattern_rgb = (row_idx == walk_pos[4:0]) ? 6'b000_111 : 6'b000_000;
            3'd5: pattern_rgb = (col_idx[7:0] == walk_pos) ? 6'b111_111 : 6'b000_000;
            3'd6: pattern_rgb = {col_idx[2:0], col_idx[2:0]};
            default: pattern_rgb = 6'b111_111;
        endcase
    end

    //==========================================================================
    // ADDR 输出 mux (组合): mode 决定 addr_out[4:0] 来源
    //   ABCDE mode:  addr_out[4:0] = row_displayed (在 S_DISPLAY 时)
    //   shift mode:  addr_out = {2'b00, EN, DAT, CLK}
    //   非 S_DISPLAY 时, EN 拉高灭, ABCDE 保持上次值
    //==========================================================================
    reg        sr_en;             // shift register ADDR_EN (低=显示)
    reg [4:0]  addr_abcde_lat;    // ABCDE 模式锁存值

    always @(*) begin
        if (addr_mode_sr) begin
            hub75e_addr_out = {2'b00, sr_en, sr_dat, sr_clk};
        end else begin
            hub75e_addr_out = addr_abcde_lat;
        end
    end

    //==========================================================================
    // 主 FSM
    //==========================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            state           <= S_IDLE;
            col_idx         <= 12'd0;
            row_idx         <= 5'd0;
            row_displayed   <= 5'd0;
            sub_count       <= 0;
            ctrl_count      <= 4'd0;
            disp_count      <= 14'd0;
            frame_count     <= 16'd0;
            walk_pos        <= 8'd0;
            walk_div_count  <= 8'd0;
            hub75e_rgb_out  <= 6'b0;
            hub75e_dclk_out <= 1'b0;
            hub75e_lat_out  <= 1'b0;
            hub75e_oe_out   <= 1'b1;
            addr_abcde_lat  <= 5'b0;
            sr_bit_idx      <= 6'd0;
            sr_sub          <= 2'd0;
            sr_clk          <= 1'b0;
            sr_dat          <= 1'b0;
            sr_en           <= 1'b1;       // 上电默认禁用 row driver
        end else begin
            case (state)
                //--------------------------------------------------------------
                S_IDLE: begin
                    hub75e_oe_out   <= 1'b1;
                    hub75e_lat_out  <= 1'b0;
                    hub75e_dclk_out <= 1'b0;
                    hub75e_rgb_out  <= 6'b0;
                    sr_en           <= 1'b1;
                    sr_clk          <= 1'b0;
                    col_idx         <= 12'd0;
                    row_idx         <= 5'd0;
                    sub_count       <= 0;
                    if (enable) state <= S_SHIFT;
                end

                //--------------------------------------------------------------
                // S_SHIFT: DCLK 30 MHz, sub=0..1 DCLK 低 (RGB setup),
                //          sub=2..3 DCLK 高 (chip 上升沿采样).
                //--------------------------------------------------------------
                S_SHIFT: begin
                    hub75e_oe_out  <= 1'b1;
                    hub75e_lat_out <= 1'b0;
                    hub75e_rgb_out <= pattern_rgb;

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

                //--------------------------------------------------------------
                // S_BLANK: OE 拉高 BLANK_CYC 拍 (≥30 ns spec) 准备 LATCH
                //--------------------------------------------------------------
                S_BLANK: begin
                    hub75e_dclk_out <= 1'b0;
                    hub75e_oe_out   <= 1'b1;
                    sr_en           <= 1'b1;       // shift mode 同时禁 row driver
                    if (ctrl_count == BLANK_CYC[3:0] - 1) begin
                        ctrl_count <= 4'd0;
                        state <= S_LATCH;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                //--------------------------------------------------------------
                // S_LATCH: LE 高 LATCH_CYC 拍 (≥20 ns spec)
                //--------------------------------------------------------------
                S_LATCH: begin
                    hub75e_lat_out <= 1'b1;
                    if (ctrl_count == LATCH_CYC[3:0] - 1) begin
                        hub75e_lat_out <= 1'b0;
                        ctrl_count <= 4'd0;
                        // 跳到对应 ADDR mode
                        state <= addr_mode_sr ? S_ADDR_SR : S_ADDR_ABCDE;
                        // shift mode: 初始化推 32 bit
                        sr_bit_idx <= 6'd0;
                        sr_sub     <= 2'd0;
                        sr_clk     <= 1'b0;
                        sr_dat     <= 1'b0;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                //--------------------------------------------------------------
                // S_ADDR_ABCDE: 设 5-bit row, ADDR_SET_CYC 稳定
                //--------------------------------------------------------------
                S_ADDR_ABCDE: begin
                    hub75e_lat_out  <= 1'b0;
                    addr_abcde_lat  <= row_idx;
                    row_displayed   <= row_idx;
                    if (ctrl_count == ADDR_SET_CYC[3:0] - 1) begin
                        ctrl_count <= 4'd0;
                        disp_count <= 14'd0;
                        state <= S_DISPLAY;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                //--------------------------------------------------------------
                // S_ADDR_SR: multivox-style. 推 32 个 bit 进 ADDR shift register.
                //   "1" 位 在 row 那一拍 推入, 其他都推 0.
                //   sr_sub: 0=DAT setup + CLK low, 1=CLK high, 2=CLK low, 3=advance
                //--------------------------------------------------------------
                S_ADDR_SR: begin
                    sr_en <= 1'b1;     // shift 期间禁 row driver
                    case (sr_sub)
                        2'd0: begin
                            sr_clk <= 1'b0;
                            sr_dat <= (sr_bit_idx[4:0] == row_idx) ? 1'b1 : 1'b0;
                            sr_sub <= 2'd1;
                        end
                        2'd1: begin
                            sr_clk <= 1'b1;       // rising edge
                            sr_sub <= 2'd2;
                        end
                        2'd2: begin
                            sr_clk <= 1'b0;
                            sr_sub <= 2'd3;
                        end
                        2'd3: begin
                            sr_sub <= 2'd0;
                            if (sr_bit_idx == 6'd31) begin
                                // 完成 32 bit shift
                                sr_dat        <= 1'b0;
                                row_displayed <= row_idx;
                                disp_count    <= 14'd0;
                                state         <= S_DISPLAY;
                            end else begin
                                sr_bit_idx <= sr_bit_idx + 1;
                            end
                        end
                    endcase
                end

                //--------------------------------------------------------------
                // S_DISPLAY: OE 低 (亮) DISP_CYCLES 拍
                //--------------------------------------------------------------
                S_DISPLAY: begin
                    hub75e_oe_out <= enable ? 1'b0 : 1'b1;
                    sr_en         <= 1'b0;     // shift mode: 使能 row driver
                    if (disp_count == DISP_CYCLES[13:0]) begin
                        hub75e_oe_out <= 1'b1;
                        sr_en         <= 1'b1;
                        disp_count    <= 14'd0;
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
