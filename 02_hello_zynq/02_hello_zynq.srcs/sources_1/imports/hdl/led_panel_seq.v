//-----------------------------------------------------------------------------
// led_panel_seq.v - PL-side ICND1069 timing generator
//
// V2: free-running DCLK 12.5 MHz 50% duty (75 MHz / DCLK_DIV=6, 3 high + 3 low).
//     DCLK 永远跑, 命令间隙不停 (eliminate 断断续续). Sequencer 是 event-driven,
//     在 DCLK 下降沿那一拍 register 新 SDI/LE/ROW, 信号稳定半个 DCLK 周期后
//     chip 在下一个上升沿采样.
//
// 寄存器 (与 V1 相同):
//   0x00 CMD (W: trigger; R: status)
//     [15:0]   data word (MSB first shifted)
//     [22:16]  count (0..127)  — word 用 16 (固定), marker 用 N (LE/ROW 高 N 拍)
//     [25:24]  mode: 00=word (16 DCLK shift, LE 高在最后 count 个)
//                    01=marker_LE  (count 个 DCLK, LE 高, SDI=0, ROW=0)
//                    10=marker_ROW (count 个 DCLK, ROW 高, LE=0, SDI=0)
//                    11=reserved (treat as word)
//   0x00 read: [0] = busy
//   0x04 BURST (W): repeat_count for NEXT 0x00 write (PL self-refires N+1 次)
//
// 时钟: s_axi_aclk = 75 MHz (FCLK1, IO_PLL 1800/24 exact), DCLK = 75/DCLK_DIV MHz
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module led_panel_seq #(
    parameter DCLK_DIV = 6    // 75 MHz / 6 = 12.5 MHz DCLK, 3/3 = 50% 占空比
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

    // ICND1069 panel signals
    output reg         dclk_out,
    output reg         le_out,
    output reg         row_out,   // ICND1069 ROW (= 手册"换行信号", 在 schematic 上标 GCLK)
    output reg [8:0]   sdi_out,   // 9-way broadcast

    // ICND3019 row driver signals
    // 2026-05-27 用户确认: W18 (AIN 标) = DCLK, W17 (BIN 标) = RCLK, W16 (CIN 标) = SDI/DIN
    output reg         icnd_sdi_out,   // ICND3019 SDI (DIN) → W16
    output reg         icnd_dclk_out,  // ICND3019 DCLK → W18
    output reg         icnd_rclk_out   // ICND3019 RCLK → W17
);

    localparam [7:0] HALF = (DCLK_DIV/2) - 1;

    //---------- Free-running DCLK divider ----------
    // 始终跑, 不受 sequencer 状态影响. 50% duty (HALF+1 拍高, HALF+1 拍低).
    reg [7:0] div_count;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            div_count <= 8'b0;
            dclk_out  <= 1'b0;
        end else begin
            if (div_count == HALF) begin
                div_count <= 8'b0;
                dclk_out  <= ~dclk_out;
            end else begin
                div_count <= div_count + 1;
            end
        end
    end

    // 在 dclk_out 即将从 1 翻 0 的那一拍 s_axi_aclk 触发. 当拍 write SDI/LE/ROW
    // 跟 dclk_out 翻 0 同步 → 半个 DCLK 周期 stable → chip 下个上升沿 sample ✓.
    wire dclk_will_fall = (div_count == HALF) && dclk_out;

    //---------- Sequencer state ----------
    reg        busy;
    reg [15:0] data_shift;
    reg [6:0]  bits_left;
    reg [6:0]  le_count_reg;
    reg [1:0]  mode_reg;
    reg [15:0] data_latched;
    reg [1:0]  mode_latched;
    reg [6:0]  le_latched;
    reg [15:0] burst_left;

    reg        cmd_pending;
    reg [15:0] pending_data;
    reg [1:0]  pending_mode;
    reg [6:0]  pending_le;
    reg [15:0] pending_burst;

    //---------- ICND3019 sub-FSM state (declarations) ----------
    // AXI addr 0x08 写: bit[31]=cmd_type (0=advance, 1=config),
    //                   bit[0]=SDI (for advance), bit[3:0]=reg<3:0> (for config)
    reg        icnd_busy;
    reg [2:0]  icnd_state;
    reg [6:0]  icnd_div;
    reg [4:0]  icnd_pulse_count;
    reg [4:0]  icnd_pulse_target;
    reg        icnd_start_pulse;       // 1-cycle pulse from AXI write
    reg        icnd_pending_type;      // latched: 0=advance, 1=config
    reg        icnd_pending_sdi;       // latched SDI bit
    reg [3:0]  icnd_pending_reg;       // latched reg<3:0>

    //---------- AXI-Lite WRITE FSM ----------
    reg start_pulse;
    reg [15:0] burst_reg;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready    <= 1'b0;
            s_axi_wready     <= 1'b0;
            s_axi_bvalid     <= 1'b0;
            s_axi_bresp      <= 2'b00;
            start_pulse      <= 1'b0;
            burst_reg        <= 16'b0;
            icnd_start_pulse <= 1'b0;
            icnd_pending_type <= 1'b0;
            icnd_pending_sdi  <= 1'b0;
            icnd_pending_reg  <= 4'b0;
        end else begin
            start_pulse      <= 1'b0;
            icnd_start_pulse <= 1'b0;
            if (!s_axi_awready && !s_axi_wready &&
                s_axi_awvalid && s_axi_wvalid && !s_axi_bvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                if (s_axi_awaddr[3:2] == 2'b00 && !cmd_pending) begin
                    // 0x00 = ICND1069 cmd. queue 槽空就接受, 不再判 busy.
                    start_pulse <= 1'b1;
                end else if (s_axi_awaddr[3:2] == 2'b01) begin
                    // 0x04 = burst count for NEXT 0x00 write
                    burst_reg <= s_axi_wdata[15:0];
                end else if (s_axi_awaddr[3:2] == 2'b10 && !icnd_busy) begin
                    // 0x08 = ICND3019 cmd. 同步取 wdata 字段, 让 FSM 在下一拍接.
                    icnd_start_pulse  <= 1'b1;
                    icnd_pending_type <= s_axi_wdata[31];
                    icnd_pending_sdi  <= s_axi_wdata[0];
                    icnd_pending_reg  <= s_axi_wdata[3:0];
                end
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                if (s_axi_bvalid && s_axi_bready)
                    s_axi_bvalid <= 1'b0;
            end
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
                // bit[0] busy (1069 processing or queued), bit[1] cmd_pending (1069 queue full),
                // bit[2] icnd_busy (3019 FSM running)
                s_axi_rdata   <= {29'b0, icnd_busy, cmd_pending, busy};
                s_axi_rresp   <= 2'b00;
                s_axi_rvalid  <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready)
                    s_axi_rvalid <= 1'b0;
            end
        end
    end

    //---------- Sequencer (event-driven on dclk_will_fall) ----------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            busy          <= 1'b0;
            le_out        <= 1'b0;
            row_out       <= 1'b0;
            sdi_out       <= 9'b0;
            data_shift    <= 16'b0;
            bits_left     <= 7'b0;
            le_count_reg  <= 7'b0;
            mode_reg      <= 2'b0;
            data_latched  <= 16'b0;
            mode_latched  <= 2'b0;
            le_latched    <= 7'b0;
            burst_left    <= 16'b0;
            cmd_pending   <= 1'b0;
            pending_data  <= 16'b0;
            pending_mode  <= 2'b0;
            pending_le    <= 7'b0;
            pending_burst <= 16'b0;
        end else begin
            if (dclk_will_fall) begin
                if (bits_left == 7'd0) begin
                    // 空闲: 如果 cmd_pending 则启动新命令; 否则保持 0
                    if (cmd_pending) begin
                        cmd_pending   <= 1'b0;
                        burst_left    <= pending_burst;
                        data_latched  <= pending_data;
                        mode_latched  <= pending_mode;
                        le_latched    <= pending_le;
                        mode_reg      <= pending_mode;
                        le_count_reg  <= pending_le;
                        data_shift    <= pending_data;
                        case (pending_mode)
                            2'b01: begin   // marker_LE
                                bits_left <= pending_le;
                                le_out    <= 1'b1;
                                row_out   <= 1'b0;
                                sdi_out   <= 9'b0;
                            end
                            2'b10: begin   // marker_ROW
                                bits_left <= pending_le;
                                le_out    <= 1'b0;
                                row_out   <= 1'b1;
                                sdi_out   <= 9'b0;
                            end
                            default: begin // word
                                bits_left <= 7'd16;
                                sdi_out   <= {9{pending_data[15]}};
                                le_out    <= (pending_le >= 7'd16);
                                row_out   <= 1'b0;
                            end
                        endcase
                    end else begin
                        le_out  <= 1'b0;
                        row_out <= 1'b0;
                        sdi_out <= 9'b0;
                    end
                end else if (bits_left == 7'd1) begin
                    // 最后一拍: 当前 SDI/LE 在上个上升沿已被 sample, 这拍切到下个命令或 idle
                    if (burst_left != 16'b0) begin
                        burst_left   <= burst_left - 1;
                        data_shift   <= data_latched;
                        mode_reg     <= mode_latched;
                        le_count_reg <= le_latched;
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
                                bits_left <= 7'd16;
                                sdi_out   <= {9{data_latched[15]}};
                                le_out    <= (le_latched >= 7'd16);
                                row_out   <= 1'b0;
                            end
                        endcase
                    end else if (cmd_pending) begin
                        // 链入下一个 AXI 命令, 无 DCLK gap
                        cmd_pending   <= 1'b0;
                        burst_left    <= pending_burst;
                        data_latched  <= pending_data;
                        mode_latched  <= pending_mode;
                        le_latched    <= pending_le;
                        mode_reg      <= pending_mode;
                        le_count_reg  <= pending_le;
                        data_shift    <= pending_data;
                        case (pending_mode)
                            2'b01: begin
                                bits_left <= pending_le;
                                le_out    <= 1'b1;
                                row_out   <= 1'b0;
                                sdi_out   <= 9'b0;
                            end
                            2'b10: begin
                                bits_left <= pending_le;
                                le_out    <= 1'b0;
                                row_out   <= 1'b1;
                                sdi_out   <= 9'b0;
                            end
                            default: begin
                                bits_left <= 7'd16;
                                sdi_out   <= {9{pending_data[15]}};
                                le_out    <= (pending_le >= 7'd16);
                                row_out   <= 1'b0;
                            end
                        endcase
                    end else begin
                        bits_left <= 7'd0;
                        le_out    <= 1'b0;
                        row_out   <= 1'b0;
                        sdi_out   <= 9'b0;
                        busy      <= 1'b0;
                    end
                end else begin
                    // 中段: 推下一 bit
                    bits_left <= bits_left - 1;
                    if (mode_reg == 2'b00) begin
                        data_shift <= {data_shift[14:0], 1'b0};
                        sdi_out    <= {9{data_shift[14]}};
                        le_out     <= ((bits_left - 1) <= le_count_reg);
                    end
                    // marker_LE / marker_ROW: 保持 le_out/row_out, sdi=0
                end
            end

            // 接受新命令 (放在最后, busy<=1 win 任何 race)
            if (start_pulse) begin
                pending_data  <= s_axi_wdata[15:0];
                pending_mode  <= s_axi_wdata[25:24];
                pending_le    <= s_axi_wdata[22:16];
                pending_burst <= burst_reg;
                cmd_pending   <= 1'b1;
                busy          <= 1'b1;
            end
        end
    end

    //---------- ICND3019 FSM (advance row + register config) ----------
    // 时序参数 @ 75 MHz s_axi_aclk (13.33 ns/cycle):
    //   ADV: SDI setup ≥20ns → 8 cycles (107ns) ✓
    //        DCLK HIGH ≥500ns → 64 cycles (853ns) ✓ (建议 1µs)
    //        SDI hold ≥20ns → 8 cycles
    //   CFG: 前置空白 ≥100ns → 16 cycles (213ns) ✓
    //        RCLK HIGH/LOW each ~100ns → 8/8 cycles
    //        后置空白 ≥100ns → 16 cycles
    localparam ICND_S_IDLE     = 3'd0;
    localparam ICND_S_ADV_PRE  = 3'd1;
    localparam ICND_S_ADV_HIGH = 3'd2;
    localparam ICND_S_ADV_HOLD = 3'd3;
    localparam ICND_S_CFG_PRE  = 3'd4;
    localparam ICND_S_CFG_HIGH = 3'd5;
    localparam ICND_S_CFG_LOW  = 3'd6;
    localparam ICND_S_CFG_POST = 3'd7;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            icnd_state        <= ICND_S_IDLE;
            icnd_busy         <= 1'b0;
            icnd_div          <= 7'b0;
            icnd_pulse_count  <= 5'b0;
            icnd_pulse_target <= 5'b0;
            icnd_sdi_out      <= 1'b0;
            icnd_dclk_out     <= 1'b0;
            icnd_rclk_out     <= 1'b0;
        end else begin
            case (icnd_state)
                ICND_S_IDLE: begin
                    icnd_dclk_out <= 1'b0;
                    icnd_rclk_out <= 1'b0;
                    if (icnd_start_pulse) begin
                        icnd_busy <= 1'b1;
                        icnd_div  <= 7'b0;
                        if (icnd_pending_type == 1'b0) begin
                            // advance row: 先驱 SDI, 等 setup, 再升 DCLK
                            icnd_sdi_out <= icnd_pending_sdi;
                            icnd_state   <= ICND_S_ADV_PRE;
                        end else begin
                            // config: 等前置空白, 再开始 RCLK 脉冲串
                            icnd_pulse_target <= icnd_pending_reg + 5'd8;
                            icnd_pulse_count  <= 5'b0;
                            icnd_state        <= ICND_S_CFG_PRE;
                        end
                    end
                end

                ICND_S_ADV_PRE: begin
                    // SDI setup time, then raise DCLK
                    if (icnd_div == 7'd7) begin
                        icnd_div      <= 7'b0;
                        icnd_dclk_out <= 1'b1;
                        icnd_state    <= ICND_S_ADV_HIGH;
                    end else begin
                        icnd_div <= icnd_div + 1;
                    end
                end

                ICND_S_ADV_HIGH: begin
                    // DCLK HIGH 64 cycles (~850ns, > 500ns 消影建议)
                    if (icnd_div == 7'd63) begin
                        icnd_div      <= 7'b0;
                        icnd_dclk_out <= 1'b0;
                        icnd_state    <= ICND_S_ADV_HOLD;
                    end else begin
                        icnd_div <= icnd_div + 1;
                    end
                end

                ICND_S_ADV_HOLD: begin
                    // hold time after DCLK fall
                    if (icnd_div == 7'd7) begin
                        icnd_busy  <= 1'b0;
                        icnd_state <= ICND_S_IDLE;
                    end else begin
                        icnd_div <= icnd_div + 1;
                    end
                end

                ICND_S_CFG_PRE: begin
                    // 前置空白 ≥100ns
                    if (icnd_div == 7'd15) begin
                        icnd_div      <= 7'b0;
                        icnd_rclk_out <= 1'b1;
                        icnd_state    <= ICND_S_CFG_HIGH;
                    end else begin
                        icnd_div <= icnd_div + 1;
                    end
                end

                ICND_S_CFG_HIGH: begin
                    // RCLK HIGH ~100ns
                    if (icnd_div == 7'd7) begin
                        icnd_div      <= 7'b0;
                        icnd_rclk_out <= 1'b0;
                        icnd_state    <= ICND_S_CFG_LOW;
                    end else begin
                        icnd_div <= icnd_div + 1;
                    end
                end

                ICND_S_CFG_LOW: begin
                    // RCLK LOW ~100ns, 再决定下个脉冲还是结束
                    if (icnd_div == 7'd7) begin
                        icnd_div <= 7'b0;
                        if (icnd_pulse_count == icnd_pulse_target - 1) begin
                            // 完成所有脉冲, 进入后置空白
                            icnd_state <= ICND_S_CFG_POST;
                        end else begin
                            icnd_pulse_count <= icnd_pulse_count + 1;
                            icnd_rclk_out    <= 1'b1;
                            icnd_state       <= ICND_S_CFG_HIGH;
                        end
                    end else begin
                        icnd_div <= icnd_div + 1;
                    end
                end

                ICND_S_CFG_POST: begin
                    // 后置空白 ≥100ns
                    if (icnd_div == 7'd15) begin
                        icnd_busy  <= 1'b0;
                        icnd_state <= ICND_S_IDLE;
                    end else begin
                        icnd_div <= icnd_div + 1;
                    end
                end

                default: icnd_state <= ICND_S_IDLE;
            endcase
        end
    end

endmodule
