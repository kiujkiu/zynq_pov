//-----------------------------------------------------------------------------
// led_panel_seq.v - PL-side ICND1069 timing generator
//
// 解决 ARM bit-bang DCLK <2 MHz 跑不动 chip 4 MHz min DCLK 的问题.
// AXI-Lite slave, ARM 写一条命令 (16-bit data + LE 计数 + mode), PL 生成
// 精确时序: DCLK 在 PL 时钟域以分频跑 ~8 MHz, SDI 在 DCLK 上升前 settle,
// LE 高电平宽度严格 = N 个 DCLK 周期.
//
// 寄存器:
//   0x00 CMD (W: trigger; R: status)
//     [15:0]   data word (MSB first shifted)
//     [20:16]  le_count (0..31)
//     [25:24]  mode: 00=word (16 DCLK shift, LE 高在最后 le_count 个)
//                    01=marker_LE (仅 le_count 个 DCLK, LE 高, SDI=0, ROW=0)
//                    10=marker_ROW (仅 le_count 个 DCLK, ROW 高, LE=0, SDI=0)
//                    11=reserved
//   0x00 read: [0] = busy
//   0x04 BURST (W): repeat_count for NEXT 0x00 write (0=single fire, N=fire N+1 times back-to-back)
//
// 时钟: s_axi_aclk = 75 MHz (FCLK1), DCLK = 75/DCLK_DIV MHz
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module led_panel_seq #(
    parameter DCLK_DIV = 10    // 75 MHz / 10 = 7.5 MHz DCLK
)(
    // AXI-Lite slave
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [3:0]  s_axi_awaddr,
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
    input  wire [3:0]  s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // Panel signals
    output reg         dclk_out,
    output reg         le_out,
    output reg         row_out,   // ICND1069 ROW (=GCLK label on schematic)
    output reg [8:0]   sdi_out    // 9-way broadcast
);

    //---------- Sequencer state ----------
    reg        busy;
    reg [15:0] data_shift;     // data being shifted (MSB first)
    reg [4:0]  bits_left;      // bits remaining to shift (max 16)
    reg [4:0]  le_count_reg;   // LE counter (which last N bits get LE high)
    reg [1:0]  mode_reg;       // 00=word, 01=marker_LE, 10=marker_ROW
    reg [7:0]  div_count;      // DCLK divider counter
    reg [15:0] data_latched;   // latched data word for re-fire in burst
    reg [1:0]  mode_latched;
    reg [4:0]  le_latched;
    reg [15:0] burst_left;     // burst repeat counter (PL self-refires)

    //---------- AXI-Lite WRITE FSM ----------
    reg start_pulse;           // 1-cycle pulse to sequencer
    reg [15:0] burst_reg;      // pending burst count from 0x04 write

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            start_pulse   <= 1'b0;
            burst_reg     <= 16'b0;
        end else begin
            start_pulse <= 1'b0;
            // single-cycle awready+wready handshake when both valid
            if (!s_axi_awready && !s_axi_wready &&
                s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                // addr 0x00: trigger sequencer; addr 0x04: set burst count
                if (s_axi_awaddr[3:2] == 2'b00 && !busy) begin
                    start_pulse <= 1'b1;
                end else if (s_axi_awaddr[3:2] == 2'b01) begin
                    burst_reg <= s_axi_wdata[15:0];
                end
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                if (s_axi_bvalid && s_axi_bready)
                    s_axi_bvalid <= 1'b0;
            end
            // Clear burst_reg when sequencer consumed it (start_pulse fired)
            if (start_pulse) burst_reg <= 16'b0;
        end
    end

    //---------- AXI-Lite READ FSM ----------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'b0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
                // any address returns status
                s_axi_rdata   <= {31'b0, busy};
                s_axi_rresp   <= 2'b00;
                s_axi_rvalid  <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready)
                    s_axi_rvalid <= 1'b0;
            end
        end
    end

    //---------- Sequencer FSM ----------
    // States:
    //   IDLE: wait for start
    //   SETUP: SDI pre-write, then wait for half-cycle to rise DCLK
    //   DCLK_HIGH: DCLK is high, count down half-cycle
    //   DCLK_LOW: DCLK fell, advance shift, decide LE for next bit
    localparam S_IDLE     = 2'd0;
    localparam S_DCLK_LOW = 2'd1;   // DCLK low, prep next bit
    localparam S_DCLK_HI  = 2'd2;   // DCLK high
    reg [1:0] state;

    wire div_tick = (div_count == (DCLK_DIV/2) - 1);

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            busy         <= 1'b0;
            dclk_out     <= 1'b0;
            le_out       <= 1'b0;
            row_out      <= 1'b0;
            sdi_out      <= 9'b0;
            data_shift   <= 16'b0;
            bits_left    <= 5'b0;
            le_count_reg <= 5'b0;
            mode_reg     <= 2'b0;
            div_count    <= 8'b0;
            data_latched <= 16'b0;
            mode_latched <= 2'b0;
            le_latched   <= 5'b0;
            burst_left   <= 16'b0;
            state        <= S_IDLE;
        end else begin
            case (state)
                S_IDLE: begin
                    dclk_out <= 1'b0;
                    if (start_pulse) begin
                        // First fire from AXI write: latch params for potential burst
                        busy         <= 1'b1;
                        data_shift   <= s_axi_wdata[15:0];
                        le_count_reg <= s_axi_wdata[20:16];
                        mode_reg     <= s_axi_wdata[25:24];
                        data_latched <= s_axi_wdata[15:0];
                        mode_latched <= s_axi_wdata[25:24];
                        le_latched   <= s_axi_wdata[20:16];
                        burst_left   <= burst_reg;
                        case (s_axi_wdata[25:24])
                            2'b01: begin   // marker_LE
                                bits_left <= s_axi_wdata[20:16];
                                le_out    <= 1'b1;
                                row_out   <= 1'b0;
                                sdi_out   <= 9'b0;
                            end
                            2'b10: begin   // marker_ROW
                                bits_left <= s_axi_wdata[20:16];
                                le_out    <= 1'b0;
                                row_out   <= 1'b1;
                                sdi_out   <= 9'b0;
                            end
                            default: begin // word (00) or reserved (11) → treat as word
                                bits_left <= 5'd16;
                                sdi_out   <= {9{s_axi_wdata[15]}};
                                le_out    <= (s_axi_wdata[20:16] >= 5'd16);
                                row_out   <= 1'b0;
                            end
                        endcase
                        div_count <= 8'b0;
                        state     <= S_DCLK_LOW;
                    end else if (burst_left != 16'b0) begin
                        // PL self-refire: same params as latched, no AXI gap
                        burst_left   <= burst_left - 1;
                        busy         <= 1'b1;
                        data_shift   <= data_latched;
                        le_count_reg <= le_latched;
                        mode_reg     <= mode_latched;
                        case (mode_latched)
                            2'b01: begin
                                bits_left <= le_latched;
                                le_out    <= 1'b1;
                                row_out   <= 1'b0;
                                sdi_out   <= 9'b0;
                            end
                            2'b10: begin
                                bits_left <= le_latched;
                                le_out    <= 1'b0;
                                row_out   <= 1'b1;
                                sdi_out   <= 9'b0;
                            end
                            default: begin
                                bits_left <= 5'd16;
                                sdi_out   <= {9{data_latched[15]}};
                                le_out    <= (le_latched >= 5'd16);
                                row_out   <= 1'b0;
                            end
                        endcase
                        div_count <= 8'b0;
                        state     <= S_DCLK_LOW;
                    end
                end

                S_DCLK_LOW: begin
                    // DCLK low half, wait for div_tick, then raise DCLK
                    if (div_tick) begin
                        div_count <= 8'b0;
                        dclk_out  <= 1'b1;   // rising edge: chip samples SDI
                        state     <= S_DCLK_HI;
                    end else begin
                        div_count <= div_count + 1;
                    end
                end

                S_DCLK_HI: begin
                    // DCLK high half, wait for div_tick, then fall + advance
                    if (div_tick) begin
                        div_count <= 8'b0;
                        dclk_out  <= 1'b0;   // falling edge
                        // bit just sampled. advance state.
                        if (bits_left == 5'd1) begin
                            // done — keep busy=1 if burst pending, IDLE refires next cycle
                            busy    <= (burst_left != 16'b0);
                            le_out  <= 1'b0;
                            row_out <= 1'b0;
                            sdi_out <= 9'b0;
                            state   <= S_IDLE;
                        end else begin
                            // prep next bit
                            bits_left <= bits_left - 1;
                            if (mode_reg == 2'b00) begin
                                // word mode: shift data left, present next MSB
                                data_shift <= {data_shift[14:0], 1'b0};
                                sdi_out    <= {9{data_shift[14]}};
                                // LE high on last le_count bits
                                le_out <= ((bits_left - 1) <= le_count_reg);
                            end
                            // marker_LE / marker_ROW: keep le_out/row_out as set, SDI=0, count down
                            state <= S_DCLK_LOW;
                        end
                    end else begin
                        div_count <= div_count + 1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
