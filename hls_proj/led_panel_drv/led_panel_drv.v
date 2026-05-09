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
//   * 8-bit PWM payload per channel per slice (panel internal PWM PLL @ 96 MHz
//     does sub-frame refresh autonomously; FPGA only ships intensity codes).
//   * 4 SDI chains each push 27 chips * 16 channels * pwm_bits bits per row.
//     @ 25 MHz, 27*16*8 = 3456 bits / 25e6 = 138.24 us / row -> too slow for
//     single-row-per-slice at full PWM depth. So with scan_ratio=90 we send
//     only 2 rows / slice in 8-bit mode (panel cycles the rest internally),
//     or run 4-bit mode and ship 4 rows / slice. cfg.pwm_bits selects.
//
// Pipeline:
//   IDLE -> CFG_INIT -> CFG_LE_W (issue 1069 LE-encoded register writes once)
//        -> LOAD_FB  (DMA frame data via AXIS into BRAM, or trigger reuse)
//        -> SHIFT_ROW (clock 4 chains in parallel, MSB first)
//        -> LE_LATCH  (assert LE for 1 DCLK -> data write command)
//        -> ROW_ADV   (pulse ROW high >= 160 ns -> 3019 row scan advance)
//        -> SHIFT_ROW (next sub-row) ... until rows_per_slice done
//        -> DONE      (status.frame_done=1, wait for next trigger)
//
// LE-encoded commands (per ICND1069 datasheet):
//   LE held high for N DCLK cycles while data is shifted, where:
//      N=1  : DATA_WRITE         (latch RGB PWM data, normal payload op)
//      N=2  : RESET (soft)
//      N=3  : WRITE_CFG1  (gain / scan ratio)
//      N=4  : WRITE_CFG2  (pwm depth / blanking)
//      N=5  : WRITE_CFG3  (vendor specific)
//   The exact mapping is panel/lot dependent -> kept as a parametric LUT
//   (LE_CMD_LEN table) so the operator can tune without re-synthesis.
//
// Resource estimate (lint-level, before P&R):
//   * frame_buffer BRAM: 160 * 180 * 3 byte = 86400 byte. Stored as a
//     ping-pong 2 x 43200 byte block -> ~24 x BRAM18 (ZU+ ~12 BRAM36).
//   * FSM logic LUT/FF: < 800 LUT, < 600 FF.
//   * 4 parallel shifters x 32 byte staging FIFO each: ~ 4 x BRAM18.
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
    parameter integer ROW_HIGH_TICKS    = 5,    // >= 160 ns @ 25 MHz -> 5 DCLK = 200 ns
    parameter integer LE_MIN_TICKS      = 1,    // >= 10 ns -> 1 DCLK = 40 ns
    // CFG init sequence : up-to-8 LE commands fired once after reset
    parameter integer CFG_SEQ_LEN       = 3
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
    // 1. AXI-Lite slave  (8 dword regs)
    //-------------------------------------------------------------------------
    // 0x00 CTRL    : [0]=enable, [1]=soft_reset, [2]=loop_mode
    // 0x04 STATUS  : [0]=busy, [1]=frame_done(W1C), [2]=cfg_done
    // 0x10 FRAME_ADDR : reserved (DMA addr if external)
    // 0x14 TRIGGER : write 1 -> kick one slice
    // 0x18 STATUS2 : alias of STATUS (RO)
    // 0x20 CFG     : [7:0]=scan_ratio, [15:8]=pwm_bits, [31:16]=brightness gain
    // 0x24 LE_CMD0 : LE table entry 0 length
    // 0x28 LE_CMD1 : LE table entry 1 length
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
            reg_le_cmd0    <= 32'd1;   // DATA_WRITE
            reg_le_cmd1    <= 32'd3;   // CFG1
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

    wire [7:0] cfg_scan_ratio = reg_cfg[7:0];
    wire [7:0] cfg_pwm_bits   = reg_cfg[15:8];
    wire [15:0] cfg_gain      = reg_cfg[31:16];
    wire        soft_rst      = reg_ctrl[1];
    wire        en_loop       = reg_ctrl[2];

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
    // Layout: addr = (y*PANEL_W + x), each word = {R[7:0], G[7:0], B[7:0], 8'h0}
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
    // Panel split: 4 quadrants, each 80 x 90, fed by chain[0..3].
    // Chip cascade: 27 chips/chain * 16 ch/chip = 432 ch, but 80 col * 3 RGB
    // = 240 ch only -> upper chips unused (fed zeros) for v0.
    function automatic [23:0] fb_pixel(input integer chain_id,
                                       input integer col,
                                       input integer sub_row);
        integer x, y;
        begin
            // quadrant origin
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
    // 5. Main FSM (DCLK domain via dclk_tick)
    //-------------------------------------------------------------------------
    localparam [3:0] S_IDLE    = 4'd0,
                     S_CFG_GO  = 4'd1,
                     S_CFG_LE  = 4'd2,
                     S_LOAD    = 4'd3,
                     S_SHIFT   = 4'd4,
                     S_LE_HI   = 4'd5,
                     S_ROW_HI  = 4'd6,
                     S_NEXT_R  = 4'd7,
                     S_DONE    = 4'd8;

    reg [3:0]  st;
    reg        cfg_done_r;
    reg [3:0]  cfg_idx;
    reg [7:0]  cfg_le_cnt;        // current LE held tick count
    reg [7:0]  cfg_le_target;     // current LE target length

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

    // bit / chip / row counters
    localparam integer BITS_PER_CH_MAX = 16;
    reg [4:0]  bit_idx;            // 0..pwm_bits-1
    reg [4:0]  ch_idx;             // 0..15  (channel within chip)
    reg [4:0]  chip_idx;           // 0..26  (chip in chain cascade)
    reg [7:0]  col_idx;            // helper: col in quadrant
    reg [7:0]  sub_row;            // 0..(PANEL_H/2 - 1)
    reg [15:0] le_high_cnt;
    reg [15:0] row_high_cnt;
    reg [7:0]  rows_in_slice;

    // staged channel intensity for each chain
    reg [15:0] pwm_word [0:N_CHAIN-1];

    integer ci;

    reg busy_r;
    reg frame_done_r;
    assign busy        = busy_r;
    assign frame_done  = frame_done_r;

    // helper : map (chip,ch) within a chain to a quadrant pixel column / colour
    // 27 chip * 16 ch = 432 lines but only 80 cols * 3 RGB = 240 used.
    // Mapping: lane = chip*16 + ch ; if lane < 240 -> col=lane/3, comp=lane%3.
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
                // expand 8-bit to pwm_bits  (LSB-extend or zero-pad)
                pwm_word[chain_id] <= {intensity, 8'h00};
            end else begin
                pwm_word[chain_id] <= 16'h0;
            end
        end
    endtask

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn || soft_rst) begin
            st            <= S_IDLE;
            cfg_done_r    <= 1'b0;
            cfg_idx       <= 4'd0;
            cfg_le_cnt    <= 8'd0;
            cfg_le_target <= 8'd0;
            sdi_r         <= {N_CHAIN{1'b0}};
            le_r          <= 1'b0;
            row_r         <= 1'b0;
            rclk_r        <= 1'b0;
            sdi_row_r     <= 1'b0;
            bit_idx       <= 5'd0;
            ch_idx        <= 5'd0;
            chip_idx      <= 5'd0;
            col_idx       <= 8'd0;
            sub_row       <= 8'd0;
            le_high_cnt   <= 16'd0;
            row_high_cnt  <= 16'd0;
            rows_in_slice <= 8'd0;
            busy_r        <= 1'b0;
            frame_done_r  <= 1'b0;
            trig_consume  <= 1'b0;
            reg_status    <= 32'h0;
            for (ci = 0; ci < N_CHAIN; ci = ci + 1)
                pwm_word[ci] <= 16'h0;
        end else if (dclk_tick) begin
            // default trig_consume strobe deasserts each tick
            trig_consume <= 1'b0;
            // default deassertions
            le_r  <= 1'b0;
            row_r <= 1'b0;

            case (st)
            //----------------------------------------------------------------
            S_IDLE: begin
                busy_r <= 1'b0;
                if (!cfg_done_r) begin
                    st            <= S_CFG_GO;
                    cfg_idx       <= 4'd0;
                    busy_r        <= 1'b1;
                end else if (trig_pulse || en_loop) begin
                    st            <= S_LOAD;
                    sub_row       <= 8'd0;
                    rows_in_slice <= 8'd0;
                    busy_r        <= 1'b1;
                    frame_done_r  <= 1'b0;
                    trig_consume  <= 1'b1;       // consume request next cycle
                end
            end
            //----------------------------------------------------------------
            // CFG_GO : pick LE_CMD length for this cfg index, then go LE_HI
            S_CFG_GO: begin
                case (cfg_idx)
                    4'd0: cfg_le_target <= reg_le_cmd1[7:0];   // CFG1 length
                    4'd1: cfg_le_target <= reg_le_cmd1[15:8];  // CFG2 length
                    default: cfg_le_target <= 8'd0;
                endcase
                cfg_le_cnt <= 8'd0;
                // shift one dummy zero word during LE high (datasheet allows)
                bit_idx    <= 5'd0;
                st         <= S_CFG_LE;
            end
            S_CFG_LE: begin
                le_r       <= 1'b1;
                cfg_le_cnt <= cfg_le_cnt + 8'd1;
                // shift zeros while LE held
                sdi_r      <= {N_CHAIN{1'b0}};
                if (cfg_le_cnt + 1 >= cfg_le_target) begin
                    le_r <= 1'b0;
                    if (cfg_idx + 1 >= CFG_SEQ_LEN) begin
                        cfg_done_r <= 1'b1;
                        reg_status[2] <= 1'b1;
                        st <= S_IDLE;
                    end else begin
                        cfg_idx <= cfg_idx + 4'd1;
                        st <= S_CFG_GO;
                    end
                end
            end
            //----------------------------------------------------------------
            S_LOAD: begin
                // load PWM word for first lane (chip 0, ch 0) of every chain
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
            // SHIFT one bit per dclk_tick on each of 4 chains.
            // After 'pwm_bits' bits -> next channel ; after 16 ch -> next chip.
            // After CHIPS_PER_CHAIN chips, latch via LE.
            S_SHIFT: begin
                for (ci = 0; ci < N_CHAIN; ci = ci + 1) begin
                    sdi_r[ci] <= pwm_word[ci][cfg_pwm_bits - 1 - bit_idx];
                end
                if (bit_idx + 1 >= cfg_pwm_bits) begin
                    bit_idx <= 5'd0;
                    if (ch_idx + 1 >= CH_PER_CHIP) begin
                        ch_idx <= 5'd0;
                        if (chip_idx + 1 >= CHIPS_PER_CHAIN) begin
                            // whole row shifted -> latch
                            chip_idx     <= 5'd0;
                            le_high_cnt  <= 16'd0;
                            st           <= S_LE_HI;
                        end else begin
                            chip_idx <= chip_idx + 5'd1;
                            // pre-load next lane
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
            S_LE_HI: begin
                le_r        <= 1'b1;
                le_high_cnt <= le_high_cnt + 16'd1;
                // LE length 1 = DATA_WRITE
                if (le_high_cnt + 1 >= reg_le_cmd0[7:0]) begin
                    le_r         <= 1'b0;
                    row_high_cnt <= 16'd0;
                    st           <= S_ROW_HI;
                end
            end
            S_ROW_HI: begin
                row_r        <= 1'b1;
                row_high_cnt <= row_high_cnt + 16'd1;
                if (row_high_cnt + 1 >= ROW_HIGH_TICKS) begin
                    row_r <= 1'b0;
                    st    <= S_NEXT_R;
                end
            end
            S_NEXT_R: begin
                rows_in_slice <= rows_in_slice + 8'd1;
                if (sub_row + 1 >= (PANEL_H/2)) begin
                    sub_row <= 8'd0;
                end else begin
                    sub_row <= sub_row + 8'd1;
                end
                // pulse 3019 dclk_row by toggling sdi_row strobe; one row scan
                sdi_row_r <= ~sdi_row_r;

                if (rows_in_slice + 1 >= cfg_scan_ratio[7:0]) begin
                    st <= S_DONE;
                end else begin
                    st <= S_LOAD;
                end
            end
            //----------------------------------------------------------------
            S_DONE: begin
                frame_done_r <= 1'b1;
                reg_status[1] <= 1'b1;
                reg_status[0] <= 1'b0;
                busy_r       <= 1'b0;
                st           <= S_IDLE;
            end
            default: st <= S_IDLE;
            endcase
        end

        // status[0] busy mirror (combinationally-ish in clk domain)
        if (busy_r) reg_status[0] <= 1'b1;
    end

endmodule

`default_nettype wire
