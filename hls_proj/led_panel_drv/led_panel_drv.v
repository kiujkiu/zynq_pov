//-----------------------------------------------------------------------------
// led_panel_drv.v
//-----------------------------------------------------------------------------
// POV-3D LED panel driver IP (top module, Verilog FSM)
//
// Target panel:
//   * 160 x 180 RGB pixels
//   * Row driver : ICND3019 x 24 cascade (16ch x 24 = 384 row signals)
//   * Col driver : ICND1069 x 108 = 4 chain x 27 cascade, 4 parallel SDI
//   * DCLK <= 25 MHz (panel limit)
//
// Slice budget: 720 angles x 30 Hz = 21600 slice/s -> 46.30 us/slice
//
// Strategy:
//   * AXI clock = 100 MHz (s_axi_aclk). Internal /4 -> 25 MHz DCLK domain.
//   * 1/(scan_ratio) row multiplex (default 1/90, configurable).
//   * 16-bit PWM payload per channel per slice (panel internal PWM PLL @ 96
//     MHz does sub-frame refresh autonomously; FPGA only ships intensity).
//   * 4 SDI chains each push 27 chips * 16 channels * 16 bits per row =
//     27*16*16 = 6912 DCLK per row (per ICND1069 编程指导 V1.2).
//
// LE-encoded commands (ICND1069 编程指导 CN 2024 V1.2 深圳映己鸿鹄科技):
//   N = 1  : DATA_LATCH   (latch 16-bit RGB payload, MSB first)
//   N = 3  : VSYNC        (vertical sync per displayed frame)
//   N = 5  : WR_CFG       (SDI = {8-bit addr, 8-bit value})
//   N = 7  : RD_CFG       (read register, not used here)
//   N = 11 : EN_OP        (enable display output)
//   N = 12 : DIS_OP       (disable display output)
//   N = 14 : PRE_ACT      (pre-activate before config writes)
//
// Init pipeline (run once on POR / soft_reset):
//   PRE_ACT (LE=14)
//     -> WR_CFG 0x00=0xAA          (password byte 0)
//     -> WR_CFG 0x01=0xAA          (password byte 1, unlock complete)
//     -> WR_CFG 0x04=0x02          PLL_PRE_DIV
//     -> WR_CFG 0x05=0x04          PLL_LOOP_DIV
//     -> WR_CFG 0x06=0x01          PLL_POST_DIV
//     -> WR_CFG 0x07=0x20          GCLK/4 default
//     -> WR_CFG 0x1C=0xC0          current gain 100%
//     -> WR_CFG 0x02=scan_ratio-1  (tune on real panel)
//     -> WR_CFG 0x03=refresh_div-1 (tune on real panel)
//     -> WR_CFG 0x00=0x55          (password byte 0, lock)
//     -> WR_CFG 0x01=0x55          (password byte 1, lock complete)
//     -> EN_OP  (LE=11)
//     -> cfg_done sticky bit set, FSM falls through to IDLE
//
// Display pipeline:
//   VSYNC (LE=3) -> 16 DCLK gap -> ROW high 12 DCLK -> shift one row data
//   -> DATA_LATCH (LE=1) -> ROW high 4 DCLK -> next row ... -> DONE
//
// Resource estimate (lint-level, before P&R):
//   * frame_buffer BRAM: 160 * 180 * 3 byte = 86400 byte -> ~24 BRAM18.
//   * FSM logic LUT/FF: ~ 900 LUT, ~ 700 FF (init seq + register ROM adds
//     ~ 100 LUT / ~ 100 FF over the v0 implementation).
//   * Init register ROM is combinational case() -> ~ 50 LUT, 0 BRAM.
//
// This file is pure RTL with no Xilinx primitives so it is portable to
// xsim / iverilog / verilator. AXI-Lite is implemented as a minimal slave
// (subset: WRITE/READ to 8 dword registers, no burst).
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps
`default_nettype none

module led_panel_drv #(
    // panel geometry
    parameter integer PANEL_W           = 160,
    parameter integer PANEL_H           = 180,
    parameter integer N_CHAIN           = 4,
    parameter integer CHIPS_PER_CHAIN   = 27,
    parameter integer CH_PER_CHIP       = 16,
    parameter integer DEFAULT_PWM_BITS  = 8,
    parameter integer DEFAULT_SCAN_RATIO= 90,   // 1/90 row multiplex
    // timing
    parameter integer CLK_DIV           = 4,    // 100 MHz / 4 = 25 MHz DCLK
    parameter integer ROW_HIGH_LONG     = 12,   // ROW high for first row pulse
    parameter integer ROW_HIGH_SHORT    = 4,    // ROW high between rows
    parameter integer VSYNC_GAP_TICKS   = 16,   // 16 DCLK blanking after VSYNC
    parameter integer INIT_REG_COUNT    = 7     // default register table size
)(
    // ---- clk / rst ----
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    // ---- AXI-Lite slave (control regs) ----
    input  wire [7:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [7:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // ---- AXI-Stream slave (frame buffer ingress) ----
    input  wire [31:0] s_axis_fb_tdata,
    input  wire        s_axis_fb_tvalid,
    output wire        s_axis_fb_tready,
    input  wire        s_axis_fb_tlast,

    // ---- panel signals ----
    output wire                 dclk,        // shared col DCLK (25 MHz)
    output wire                 le,          // ICND1069 latch / cmd
    output wire [N_CHAIN-1:0]   sdi,         // 4 parallel data lanes
    output wire                 row,         // ICND1069 ROW pulse
    // 3019 row driver
    output wire                 dclk_row,    // 3019 row DCLK
    output wire                 rclk,        // 3019 RCLK (cfg)
    output wire                 sdi_row,     // 3019 row scan SDI

    // status
    output wire                 frame_done,
    output wire                 busy
);

    //-------------------------------------------------------------------------
    // 0. LE-command length constants  (per ICND1069 编程指导 V1.2)
    //-------------------------------------------------------------------------
    localparam [3:0] LE_DATA_LATCH = 4'd1;
    localparam [3:0] LE_VSYNC      = 4'd3;
    localparam [3:0] LE_WR_CFG     = 4'd5;
    localparam [3:0] LE_RD_CFG     = 4'd7;
    localparam [3:0] LE_EN_OP      = 4'd11;
    localparam [3:0] LE_DIS_OP     = 4'd12;
    localparam [3:0] LE_PRE_ACT    = 4'd14;

    //-------------------------------------------------------------------------
    // 1. AXI-Lite slave  (8 dword regs)
    //-------------------------------------------------------------------------
    // 0x00 CTRL    : [0]=enable, [1]=soft_reset, [2]=loop_mode
    // 0x04 STATUS  : [0]=busy, [1]=frame_done(W1C), [2]=cfg_done
    // 0x10 FRAME_ADDR : reserved (DMA addr if external)
    // 0x14 TRIGGER : write 1 -> kick one slice
    // 0x18 STATUS2 : alias of STATUS (RO)
    // 0x20 CFG     : [7:0]=scan_ratio, [15:8]=pwm_bits, [31:16]=brightness gain
    // 0x24 LE_CMD0 : [3:0]=DATA_LATCH (=1), [7:4]=VSYNC (=3),
    //                [11:8]=WR_CFG (=5), [15:12]=PRE_ACT (=14),
    //                [19:16]=EN_OP (=11), [23:20]=DIS_OP (=12)
    // 0x28 LE_CMD1 : [3:0]=RD_CFG (=7), rest reserved
    reg [31:0] reg_ctrl;
    reg [31:0] reg_status;
    reg [31:0] reg_frame_addr;
    reg [31:0] reg_trigger;
    reg [31:0] reg_cfg;
    reg [31:0] reg_le_cmd0;
    reg [31:0] reg_le_cmd1;

    reg        awready_r, wready_r, bvalid_r;
    reg        arready_r, rvalid_r;
    reg [31:0] rdata_r;
    reg [7:0]  awaddr_r;
    reg        awaddr_valid;     // 1 once awaddr_r holds a fresh address

    assign s_axi_awready = awready_r;
    assign s_axi_wready  = wready_r;
    assign s_axi_bvalid  = bvalid_r;
    assign s_axi_bresp   = 2'b00;
    assign s_axi_arready = arready_r;
    assign s_axi_rvalid  = rvalid_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = 2'b00;

    // trigger : sticky request bit, cleared once FSM consumes it
    reg  trig_pulse_r;       // 1-cycle pulse on AXI write to 0x14
    reg  trig_request;       // sticky flag held until FSM consumes
    reg  trig_consume;       // FSM-side strobe to clear trig_request
    wire trig_pulse;
    assign trig_pulse = trig_request;

    // default LE_CMD0 packing  (datasheet V1.2 lengths)
    localparam [31:0] LE_CMD0_DEFAULT =
        {8'h00,                  // [31:24] reserved
         LE_DIS_OP,               // [23:20] = 12
         LE_EN_OP,                // [19:16] = 11
         LE_PRE_ACT,              // [15:12] = 14
         LE_WR_CFG,               // [11:8]  = 5
         LE_VSYNC,                // [7:4]   = 3
         LE_DATA_LATCH};          // [3:0]   = 1

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            awready_r      <= 1'b0;
            wready_r       <= 1'b0;
            bvalid_r       <= 1'b0;
            arready_r      <= 1'b0;
            rvalid_r       <= 1'b0;
            rdata_r        <= 32'h0;
            awaddr_r       <= 8'h0;
            awaddr_valid   <= 1'b0;
            reg_ctrl       <= 32'h0;
            reg_frame_addr <= 32'h0;
            reg_trigger    <= 32'h0;
            reg_cfg        <= {16'd1,                              // gain = 1
                               DEFAULT_PWM_BITS[7:0],              // pwm bits
                               DEFAULT_SCAN_RATIO[7:0]};           // scan ratio
            reg_le_cmd0    <= LE_CMD0_DEFAULT;
            reg_le_cmd1    <= {28'h0, LE_RD_CFG};
            trig_pulse_r   <= 1'b0;
            trig_request   <= 1'b0;
        end else begin
            // ---- write address : capture awaddr first, then awready ----
            if (!awaddr_valid && s_axi_awvalid && !awready_r) begin
                awaddr_r     <= s_axi_awaddr;
                awaddr_valid <= 1'b1;
                awready_r    <= 1'b1;
            end else begin
                awready_r <= 1'b0;
            end
            // ---- write data : only consume once awaddr_r is valid ----
            trig_pulse_r <= 1'b0;
            if (trig_pulse_r)        trig_request <= 1'b1;
            else if (trig_consume)   trig_request <= 1'b0;
            if (!wready_r && s_axi_wvalid && awaddr_valid) begin
                wready_r <= 1'b1;
                case (awaddr_r[7:0])
                    8'h00: reg_ctrl       <= s_axi_wdata;
                    8'h04: reg_status     <= reg_status & ~s_axi_wdata; // W1C
                    8'h10: reg_frame_addr <= s_axi_wdata;
                    8'h14: begin
                        reg_trigger  <= s_axi_wdata;
                        if (s_axi_wdata[0]) trig_pulse_r <= 1'b1;
                    end
                    8'h20: reg_cfg        <= s_axi_wdata;
                    8'h24: reg_le_cmd0    <= s_axi_wdata;
                    8'h28: reg_le_cmd1    <= s_axi_wdata;
                    default: ;
                endcase
            end else begin
                wready_r <= 1'b0;
            end
            // ---- write resp ----
            if (wready_r && !bvalid_r) begin
                bvalid_r     <= 1'b1;
                awaddr_valid <= 1'b0;       // release for next transaction
            end else if (bvalid_r && s_axi_bready) begin
                bvalid_r <= 1'b0;
            end
            // ---- read addr ----
            if (!arready_r && s_axi_arvalid) begin
                arready_r <= 1'b1;
                rvalid_r  <= 1'b1;
                case (s_axi_araddr[7:0])
                    8'h00: rdata_r <= reg_ctrl;
                    8'h04: rdata_r <= reg_status;
                    8'h10: rdata_r <= reg_frame_addr;
                    8'h14: rdata_r <= reg_trigger;
                    8'h18: rdata_r <= reg_status;
                    8'h20: rdata_r <= reg_cfg;
                    8'h24: rdata_r <= reg_le_cmd0;
                    8'h28: rdata_r <= reg_le_cmd1;
                    default: rdata_r <= 32'hDEAD_BEEF;
                endcase
            end else if (rvalid_r && s_axi_rready) begin
                rvalid_r  <= 1'b0;
                arready_r <= 1'b0;
            end
        end
    end

    wire [7:0]  cfg_scan_ratio = reg_cfg[7:0];
    wire [7:0]  cfg_pwm_bits   = reg_cfg[15:8];
    wire [15:0] cfg_gain       = reg_cfg[31:16];
    wire        soft_rst       = reg_ctrl[1];
    wire        en_loop        = reg_ctrl[2];

    // shorthand : LE lengths from runtime-programmable register
    wire [7:0] LEN_DATA   = {4'h0, reg_le_cmd0[3:0]};
    wire [7:0] LEN_VSYNC  = {4'h0, reg_le_cmd0[7:4]};
    wire [7:0] LEN_WR_CFG = {4'h0, reg_le_cmd0[11:8]};
    wire [7:0] LEN_PRE    = {4'h0, reg_le_cmd0[15:12]};
    wire [7:0] LEN_EN_OP  = {4'h0, reg_le_cmd0[19:16]};
    wire [7:0] LEN_DIS_OP = {4'h0, reg_le_cmd0[23:20]};

    //-------------------------------------------------------------------------
    // 2. DCLK divider  (s_axi_aclk / CLK_DIV -> ~25 MHz toggle pair)
    //-------------------------------------------------------------------------
    reg [3:0] clk_cnt;
    reg       dclk_r;
    reg       dclk_tick;       // 1-cycle pulse @ rising DCLK edge in fast domain

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn || soft_rst) begin
            clk_cnt   <= 4'd0;
            dclk_r    <= 1'b0;
            dclk_tick <= 1'b0;
        end else begin
            dclk_tick <= 1'b0;
            if (clk_cnt == (CLK_DIV/2 - 1)) begin
                clk_cnt <= 4'd0;
                dclk_r  <= ~dclk_r;
                if (~dclk_r)
                    dclk_tick <= 1'b1;   // pulse on rising edge of DCLK
            end else begin
                clk_cnt <= clk_cnt + 4'd1;
            end
        end
    end

    assign dclk     = dclk_r;
    assign dclk_row = dclk_r;            // share clock to 3019; can split if needed

    //-------------------------------------------------------------------------
    // 3. Frame buffer (simple BRAM-inferred RAM, ping-pong omitted for v0)
    //-------------------------------------------------------------------------
    localparam integer FB_DEPTH = PANEL_W * PANEL_H;   // 160*180 = 28800 words
    localparam integer FB_AW    = 15;                  // ceil(log2 28800) = 15

    reg [23:0] frame_buf [0:FB_DEPTH-1];

    // ---- AXIS write port ----
    reg [FB_AW-1:0] axis_waddr;
    reg             axis_busy;
    assign s_axis_fb_tready = axis_busy ? 1'b1 : 1'b0;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            axis_waddr <= {FB_AW{1'b0}};
            axis_busy  <= 1'b1;          // accept frames eagerly
        end else if (s_axis_fb_tvalid && s_axis_fb_tready) begin
            frame_buf[axis_waddr] <= s_axis_fb_tdata[23:0];
            if (s_axis_fb_tlast)
                axis_waddr <= {FB_AW{1'b0}};
            else
                axis_waddr <= axis_waddr + 1'b1;
        end
    end

    //-------------------------------------------------------------------------
    // 4. Quadrant -> chain mapping
    //-------------------------------------------------------------------------
    function automatic [23:0] fb_pixel(input integer chain_id,
                                       input integer col,
                                       input integer sub_row);
        integer x, y;
        begin
            case (chain_id)
                0: begin x =        col;             y =          sub_row; end
                1: begin x = (PANEL_W/2) + col;      y =          sub_row; end
                2: begin x =        col;             y = (PANEL_H/2) + sub_row; end
                3: begin x = (PANEL_W/2) + col;      y = (PANEL_H/2) + sub_row; end
                default: begin x = 0; y = 0; end
            endcase
            if (x < PANEL_W && y < PANEL_H)
                fb_pixel = frame_buf[y*PANEL_W + x];
            else
                fb_pixel = 24'h0;
        end
    endfunction

    //-------------------------------------------------------------------------
    // 5. Init register table ROM  ({addr[7:0], value[7:0]})
    //-------------------------------------------------------------------------
    function automatic [15:0] init_reg_entry(input integer idx);
        begin
            case (idx)
                0: init_reg_entry = {8'h04, 8'h02};   // PLL_PRE_DIV
                1: init_reg_entry = {8'h05, 8'h04};   // PLL_LOOP_DIV
                2: init_reg_entry = {8'h06, 8'h01};   // PLL_POST_DIV
                3: init_reg_entry = {8'h07, 8'h20};   // GCLK/4 per row
                4: init_reg_entry = {8'h1C, 8'hC0};   // current gain 100%
                5: init_reg_entry = {8'h02, 8'h59};   // scan_ratio-1 (90-1)
                6: init_reg_entry = {8'h03, 8'h0F};   // refresh_div-1 (tune)
                default: init_reg_entry = 16'h0000;
            endcase
        end
    endfunction

    //-------------------------------------------------------------------------
    // 6. Main FSM (DCLK domain via dclk_tick)
    //-------------------------------------------------------------------------
    localparam [4:0] S_INIT_PRE     = 5'd0,    // boot directly into init
                     S_INIT_PWD_OP  = 5'd1,    // WR_CFG 0x00=0xAA / 0x01=0xAA
                     S_INIT_REGS    = 5'd2,    // WR_CFG default table
                     S_INIT_PWD_CL  = 5'd3,    // WR_CFG 0x00=0x55 / 0x01=0x55
                     S_INIT_EN      = 5'd4,    // EN_OP (LE=11)
                     S_IDLE         = 5'd5,
                     S_VSYNC        = 5'd6,    // LE=3
                     S_VSYNC_GAP    = 5'd7,    // 16 DCLK blanking
                     S_ROW_FIRST    = 5'd8,    // ROW high 12 DCLK
                     S_LOAD         = 5'd9,
                     S_SHIFT        = 5'd10,
                     S_LE_LATCH     = 5'd11,   // LE=1
                     S_ROW_NEXT     = 5'd12,   // ROW high 4 DCLK
                     S_DONE         = 5'd13;

    reg [4:0]  st;
    reg        cfg_done_r;
    reg [3:0]  init_pwd_step;     // 0 or 1 within each password phase
    reg [3:0]  init_reg_idx;      // current entry of init_reg_table
    reg [7:0]  le_cnt;            // unified LE high-tick counter
    reg [7:0]  le_target;
    reg [15:0] cur_cfg_payload;   // {addr, value} being shifted
    reg [4:0]  cfg_bit_idx;       // 0..15
    reg [4:0]  cfg_chip_idx;      // 0..CHIPS_PER_CHAIN-1
    reg [7:0]  gap_cnt;           // VSYNC gap counter
    reg [7:0]  row_hi_cnt;
    reg [7:0]  row_hi_target;

    // shifter regs : 4 chains
    reg [N_CHAIN-1:0] sdi_r;
    reg               le_r;
    reg               row_r;
    reg               rclk_r;
    reg               sdi_row_r;

    assign sdi     = sdi_r;
    assign le      = le_r;
    assign row     = row_r;
    assign rclk    = rclk_r;
    assign sdi_row = sdi_row_r;

    // bit / chip / row counters (display path)
    reg [4:0]  bit_idx;            // 0..15
    reg [4:0]  ch_idx;             // 0..15
    reg [4:0]  chip_idx;           // 0..26
    reg [7:0]  sub_row;            // 0..(PANEL_H/2 - 1)
    reg [7:0]  rows_in_slice;

    // staged channel intensity for each chain
    reg [15:0] pwm_word [0:N_CHAIN-1];

    integer ci;

    reg busy_r;
    reg frame_done_r;
    assign busy        = busy_r;
    assign frame_done  = frame_done_r;

    // helper : map (chip,ch) within a chain to a quadrant pixel column / colour
    task automatic load_pwm_for_lane;
        input  integer chain_id;
        input  integer chip_i;
        input  integer ch_i;
        input  integer sub_r;
        integer lane, col, comp;
        reg [23:0] px;
        reg [7:0]  intensity;
        begin
            lane = chip_i * CH_PER_CHIP + ch_i;
            if (lane < (PANEL_W/2) * 3) begin
                col  = lane / 3;
                comp = lane - col*3;
                px   = fb_pixel(chain_id, col, sub_r);
                case (comp)
                    0: intensity = px[23:16]; // R
                    1: intensity = px[15:8];  // G
                    2: intensity = px[7:0];   // B
                    default: intensity = 8'h0;
                endcase
                pwm_word[chain_id] <= {intensity, 8'h00};
            end else begin
                pwm_word[chain_id] <= 16'h0;
            end
        end
    endtask

    task automatic prime_cfg_write;
        input [7:0] addr;
        input [7:0] value;
        begin
            cur_cfg_payload <= {addr, value};
            cfg_bit_idx     <= 5'd0;
            cfg_chip_idx    <= 5'd0;
        end
    endtask

    task automatic prime_cfg_write_packed;
        input [15:0] av;
        begin
            cur_cfg_payload <= av;
            cfg_bit_idx     <= 5'd0;
            cfg_chip_idx    <= 5'd0;
        end
    endtask

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn || soft_rst) begin
            st              <= S_INIT_PRE;       // run init seq automatically
            cfg_done_r      <= 1'b0;
            init_pwd_step   <= 4'd0;
            init_reg_idx    <= 4'd0;
            le_cnt          <= 8'd0;
            le_target       <= 8'd0;
            cur_cfg_payload <= 16'h0;
            cfg_bit_idx     <= 5'd0;
            cfg_chip_idx    <= 5'd0;
            gap_cnt         <= 8'd0;
            row_hi_cnt      <= 8'd0;
            row_hi_target   <= 8'd0;
            sdi_r           <= {N_CHAIN{1'b0}};
            le_r            <= 1'b0;
            row_r           <= 1'b0;
            rclk_r          <= 1'b0;
            sdi_row_r       <= 1'b0;
            bit_idx         <= 5'd0;
            ch_idx          <= 5'd0;
            chip_idx        <= 5'd0;
            sub_row         <= 8'd0;
            rows_in_slice   <= 8'd0;
            busy_r          <= 1'b1;             // busy during init
            frame_done_r    <= 1'b0;
            trig_consume    <= 1'b0;
            reg_status      <= 32'h0;
            for (ci = 0; ci < N_CHAIN; ci = ci + 1)
                pwm_word[ci] <= 16'h0;
        end else if (dclk_tick) begin
            // default trig_consume strobe deasserts each tick
            trig_consume <= 1'b0;
            // default deassertions
            le_r  <= 1'b0;
            row_r <= 1'b0;

            case (st)
            //================================================================
            // INIT : PRE_ACT -> WR_CFG password open -> default reg table ->
            //        WR_CFG password close -> EN_OP -> IDLE
            //================================================================
            S_INIT_PRE: begin
                le_r       <= 1'b1;
                sdi_r      <= {N_CHAIN{1'b0}};
                le_cnt     <= le_cnt + 8'd1;
                if (le_cnt >= LEN_PRE) begin
                    le_r            <= 1'b0;
                    le_cnt          <= 8'd0;
                    init_pwd_step   <= 4'd0;
                    prime_cfg_write(8'h00, 8'hAA);
                    st              <= S_INIT_PWD_OP;
                end
            end
            //----------------------------------------------------------------
            // WR_CFG send phase : 16 DCLK shift {addr,value} per chip per
            // chain (mirrored across chains), then LE high for LEN_WR_CFG.
            S_INIT_PWD_OP: begin
                if (cfg_chip_idx < CHIPS_PER_CHAIN[4:0]) begin
                    for (ci = 0; ci < N_CHAIN; ci = ci + 1)
                        sdi_r[ci] <= cur_cfg_payload[15 - cfg_bit_idx];
                    if (cfg_bit_idx + 1 >= 5'd16) begin
                        cfg_bit_idx  <= 5'd0;
                        cfg_chip_idx <= cfg_chip_idx + 5'd1;
                    end else begin
                        cfg_bit_idx <= cfg_bit_idx + 5'd1;
                    end
                end else begin
                    le_r   <= 1'b1;
                    sdi_r  <= {N_CHAIN{1'b0}};
                    le_cnt <= le_cnt + 8'd1;
                    if (le_cnt >= LEN_WR_CFG) begin
                        le_r       <= 1'b0;
                        le_cnt     <= 8'd0;
                        case (init_pwd_step)
                            4'd0: begin
                                init_pwd_step <= 4'd1;
                                prime_cfg_write(8'h01, 8'hAA);
                            end
                            4'd1: begin
                                // password open done -> register table
                                init_pwd_step <= 4'd0;
                                init_reg_idx  <= 4'd0;
                                prime_cfg_write_packed(init_reg_entry(0));
                                st <= S_INIT_REGS;
                            end
                            default: ;
                        endcase
                    end
                end
            end
            //----------------------------------------------------------------
            S_INIT_REGS: begin
                if (cfg_chip_idx < CHIPS_PER_CHAIN[4:0]) begin
                    for (ci = 0; ci < N_CHAIN; ci = ci + 1)
                        sdi_r[ci] <= cur_cfg_payload[15 - cfg_bit_idx];
                    if (cfg_bit_idx + 1 >= 5'd16) begin
                        cfg_bit_idx  <= 5'd0;
                        cfg_chip_idx <= cfg_chip_idx + 5'd1;
                    end else begin
                        cfg_bit_idx <= cfg_bit_idx + 5'd1;
                    end
                end else begin
                    le_r   <= 1'b1;
                    sdi_r  <= {N_CHAIN{1'b0}};
                    le_cnt <= le_cnt + 8'd1;
                    if (le_cnt >= LEN_WR_CFG) begin
                        le_r   <= 1'b0;
                        le_cnt <= 8'd0;
                        if (init_reg_idx + 1 >= INIT_REG_COUNT[3:0]) begin
                            // table done -> password close
                            init_pwd_step <= 4'd0;
                            prime_cfg_write(8'h00, 8'h55);
                            st <= S_INIT_PWD_CL;
                        end else begin
                            init_reg_idx <= init_reg_idx + 4'd1;
                            prime_cfg_write_packed(
                                init_reg_entry(init_reg_idx + 1));
                        end
                    end
                end
            end
            //----------------------------------------------------------------
            S_INIT_PWD_CL: begin
                if (cfg_chip_idx < CHIPS_PER_CHAIN[4:0]) begin
                    for (ci = 0; ci < N_CHAIN; ci = ci + 1)
                        sdi_r[ci] <= cur_cfg_payload[15 - cfg_bit_idx];
                    if (cfg_bit_idx + 1 >= 5'd16) begin
                        cfg_bit_idx  <= 5'd0;
                        cfg_chip_idx <= cfg_chip_idx + 5'd1;
                    end else begin
                        cfg_bit_idx <= cfg_bit_idx + 5'd1;
                    end
                end else begin
                    le_r   <= 1'b1;
                    sdi_r  <= {N_CHAIN{1'b0}};
                    le_cnt <= le_cnt + 8'd1;
                    if (le_cnt >= LEN_WR_CFG) begin
                        le_r   <= 1'b0;
                        le_cnt <= 8'd0;
                        case (init_pwd_step)
                            4'd0: begin
                                init_pwd_step <= 4'd1;
                                prime_cfg_write(8'h01, 8'h55);
                            end
                            4'd1: begin
                                init_pwd_step <= 4'd0;
                                st            <= S_INIT_EN;
                            end
                            default: ;
                        endcase
                    end
                end
            end
            //----------------------------------------------------------------
            // EN_OP : LE high for LEN_EN_OP DCLK ticks, SDI = 0
            S_INIT_EN: begin
                le_r   <= 1'b1;
                sdi_r  <= {N_CHAIN{1'b0}};
                le_cnt <= le_cnt + 8'd1;
                if (le_cnt >= LEN_EN_OP) begin
                    le_r          <= 1'b0;
                    le_cnt        <= 8'd0;
                    cfg_done_r    <= 1'b1;
                    reg_status[2] <= 1'b1;
                    busy_r        <= 1'b0;
                    st            <= S_IDLE;
                end
            end
            //================================================================
            // IDLE
            //================================================================
            S_IDLE: begin
                busy_r <= 1'b0;
                if (trig_pulse || en_loop) begin
                    st            <= S_VSYNC;
                    sub_row       <= 8'd0;
                    rows_in_slice <= 8'd0;
                    le_cnt        <= 8'd0;
                    le_target     <= LEN_VSYNC;
                    busy_r        <= 1'b1;
                    frame_done_r  <= 1'b0;
                    trig_consume  <= 1'b1;
                end
            end
            //================================================================
            // DISPLAY  : VSYNC -> 16 DCLK gap -> ROW(12) -> shift -> LE(1)
            //            -> ROW(4) -> next row ... -> DONE
            //================================================================
            S_VSYNC: begin
                le_r   <= 1'b1;
                sdi_r  <= {N_CHAIN{1'b0}};
                le_cnt <= le_cnt + 8'd1;
                if (le_cnt >= LEN_VSYNC) begin
                    le_r    <= 1'b0;
                    le_cnt  <= 8'd0;
                    gap_cnt <= 8'd0;
                    st      <= S_VSYNC_GAP;
                end
            end
            //----------------------------------------------------------------
            S_VSYNC_GAP: begin
                sdi_r   <= {N_CHAIN{1'b0}};
                gap_cnt <= gap_cnt + 8'd1;
                if (gap_cnt >= VSYNC_GAP_TICKS[7:0]) begin
                    gap_cnt        <= 8'd0;
                    row_hi_cnt     <= 8'd0;
                    row_hi_target  <= ROW_HIGH_LONG[7:0];
                    st             <= S_ROW_FIRST;
                end
            end
            //----------------------------------------------------------------
            S_ROW_FIRST: begin
                row_r      <= 1'b1;
                row_hi_cnt <= row_hi_cnt + 8'd1;
                if (row_hi_cnt >= row_hi_target) begin
                    row_r <= 1'b0;
                    st    <= S_LOAD;
                end
            end
            //----------------------------------------------------------------
            S_LOAD: begin
                chip_idx <= 5'd0;
                ch_idx   <= 5'd0;
                bit_idx  <= 5'd0;
                load_pwm_for_lane(0, 0, 0, sub_row);
                load_pwm_for_lane(1, 0, 0, sub_row);
                load_pwm_for_lane(2, 0, 0, sub_row);
                load_pwm_for_lane(3, 0, 0, sub_row);
                st <= S_SHIFT;
            end
            //----------------------------------------------------------------
            // SHIFT one bit / dclk_tick per chain. 16 bit/ch * 16 ch/chip *
            // CHIPS_PER_CHAIN chips = full row.
            S_SHIFT: begin
                for (ci = 0; ci < N_CHAIN; ci = ci + 1) begin
                    sdi_r[ci] <= pwm_word[ci][15 - bit_idx];
                end
                if (bit_idx + 1 >= 5'd16) begin
                    bit_idx <= 5'd0;
                    if (ch_idx + 1 >= CH_PER_CHIP[4:0]) begin
                        ch_idx <= 5'd0;
                        if (chip_idx + 1 >= CHIPS_PER_CHAIN[4:0]) begin
                            chip_idx   <= 5'd0;
                            le_cnt     <= 8'd0;
                            le_target  <= LEN_DATA;
                            st         <= S_LE_LATCH;
                        end else begin
                            chip_idx <= chip_idx + 5'd1;
                            load_pwm_for_lane(0, chip_idx + 1, 0, sub_row);
                            load_pwm_for_lane(1, chip_idx + 1, 0, sub_row);
                            load_pwm_for_lane(2, chip_idx + 1, 0, sub_row);
                            load_pwm_for_lane(3, chip_idx + 1, 0, sub_row);
                        end
                    end else begin
                        ch_idx <= ch_idx + 5'd1;
                        load_pwm_for_lane(0, chip_idx, ch_idx + 1, sub_row);
                        load_pwm_for_lane(1, chip_idx, ch_idx + 1, sub_row);
                        load_pwm_for_lane(2, chip_idx, ch_idx + 1, sub_row);
                        load_pwm_for_lane(3, chip_idx, ch_idx + 1, sub_row);
                    end
                end else begin
                    bit_idx <= bit_idx + 5'd1;
                end
            end
            //----------------------------------------------------------------
            // DATA_LATCH : LE high LEN_DATA DCLK ticks (=1)
            S_LE_LATCH: begin
                le_r   <= 1'b1;
                le_cnt <= le_cnt + 8'd1;
                if (le_cnt >= le_target) begin
                    le_r          <= 1'b0;
                    le_cnt        <= 8'd0;
                    row_hi_cnt    <= 8'd0;
                    row_hi_target <= ROW_HIGH_SHORT[7:0];
                    st            <= S_ROW_NEXT;
                end
            end
            //----------------------------------------------------------------
            // ROW pulse between rows : 4 DCLK high
            S_ROW_NEXT: begin
                row_r      <= 1'b1;
                row_hi_cnt <= row_hi_cnt + 8'd1;
                if (row_hi_cnt >= row_hi_target) begin
                    row_r        <= 1'b0;
                    rows_in_slice <= rows_in_slice + 8'd1;
                    if (sub_row + 1 >= (PANEL_H/2)) sub_row <= 8'd0;
                    else                            sub_row <= sub_row + 8'd1;
                    sdi_row_r    <= ~sdi_row_r;
                    if (rows_in_slice + 1 >= cfg_scan_ratio[7:0]) st <= S_DONE;
                    else                                          st <= S_LOAD;
                end
            end
            //----------------------------------------------------------------
            S_DONE: begin
                frame_done_r  <= 1'b1;
                reg_status[1] <= 1'b1;
                reg_status[0] <= 1'b0;
                busy_r        <= 1'b0;
                st            <= S_IDLE;
            end
            default: st <= S_IDLE;
            endcase
        end

        // status[0] busy mirror
        if (busy_r) reg_status[0] <= 1'b1;
    end

endmodule

`default_nettype wire
