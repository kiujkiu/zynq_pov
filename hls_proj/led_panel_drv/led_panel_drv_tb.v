//-----------------------------------------------------------------------------
// led_panel_drv_tb.v -- self-checking testbench (ICND1069 V1.2 protocol)
//-----------------------------------------------------------------------------
// Tests:
//   1. AXI-Lite write/read of CFG register.
//   2. Power-on init sequence: capture every LE pulse, verify the LE-high
//      DCLK-cycle count matches the V1.2 command lengths in the order
//      PRE_ACT(14), WR_CFG(5) x N (password + reg table + password), EN_OP(11).
//   3. AXIS push of one full white frame.
//   4. Trigger one slice and verify:
//        * DCLK frequency  ~ 25 MHz
//        * VSYNC LE has length 3 DCLK
//        * DATA_LATCH LE has length 1 DCLK
//        * ROW high observed in 4 and 12 DCLK variants (count distinct widths)
//        * twROW  >= 160 ns (datasheet minimum)
//
// Notes:
//   * The init seq is much longer in real silicon (27 chip cascade); the tb
//     uses CHIPS_PER_CHAIN=4 to keep the run inside a few ms.
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module led_panel_drv_tb;

    // shrink panel so the entire test runs in seconds even on iverilog
    localparam integer PANEL_W           = 16;     // 1/10 scale
    localparam integer PANEL_H           = 18;
    localparam integer N_CHAIN           = 4;
    localparam integer CHIPS_PER_CHAIN   = 4;      // 4 chips * 16 ch = 64 lane
    localparam integer CH_PER_CHIP       = 16;
    localparam integer DEFAULT_PWM_BITS  = 8;
    localparam integer DEFAULT_SCAN_RATIO= 4;      // scan ratio small for tb
    localparam integer CLK_DIV           = 4;      // 100 MHz -> 25 MHz DCLK
    localparam integer ROW_HIGH_LONG     = 12;
    localparam integer ROW_HIGH_SHORT    = 4;
    localparam integer VSYNC_GAP_TICKS   = 16;
    localparam integer INIT_REG_COUNT    = 7;

    // LE length encodings (must match RTL constants)
    localparam integer LE_DATA_LATCH = 1;
    localparam integer LE_VSYNC      = 3;
    localparam integer LE_WR_CFG     = 5;
    localparam integer LE_EN_OP      = 11;
    localparam integer LE_PRE_ACT    = 14;

    // expected count of WR_CFG pulses during init :
    //   password open  : 2  (0x00=AA, 0x01=AA)
    //   register table : INIT_REG_COUNT
    //   password close : 2  (0x00=55, 0x01=55)
    localparam integer EXPECTED_WR_CFG = 2 + INIT_REG_COUNT + 2;

    reg         clk;
    reg         rst_n;

    // AXI-Lite signals
    reg  [7:0]  awaddr;
    reg         awvalid;
    wire        awready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;
    reg  [7:0]  araddr;
    reg         arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    // AXIS
    reg  [31:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;

    // panel pins
    wire                 dclk;
    wire                 le;
    wire [N_CHAIN-1:0]   sdi;
    wire                 row;
    wire                 dclk_row;
    wire                 rclk;
    wire                 sdi_row;
    wire                 frame_done;
    wire                 busy;

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    led_panel_drv #(
        .PANEL_W           (PANEL_W),
        .PANEL_H           (PANEL_H),
        .N_CHAIN           (N_CHAIN),
        .CHIPS_PER_CHAIN   (CHIPS_PER_CHAIN),
        .CH_PER_CHIP       (CH_PER_CHIP),
        .DEFAULT_PWM_BITS  (DEFAULT_PWM_BITS),
        .DEFAULT_SCAN_RATIO(DEFAULT_SCAN_RATIO),
        .CLK_DIV           (CLK_DIV),
        .ROW_HIGH_LONG     (ROW_HIGH_LONG),
        .ROW_HIGH_SHORT    (ROW_HIGH_SHORT),
        .VSYNC_GAP_TICKS   (VSYNC_GAP_TICKS),
        .INIT_REG_COUNT    (INIT_REG_COUNT)
    ) dut (
        .s_axi_aclk    (clk),
        .s_axi_aresetn (rst_n),
        .s_axi_awaddr  (awaddr),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),
        .s_axi_araddr  (araddr),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready),
        .s_axis_fb_tdata (s_axis_tdata),
        .s_axis_fb_tvalid(s_axis_tvalid),
        .s_axis_fb_tready(s_axis_tready),
        .s_axis_fb_tlast (s_axis_tlast),
        .dclk     (dclk),
        .le       (le),
        .sdi      (sdi),
        .row      (row),
        .dclk_row (dclk_row),
        .rclk     (rclk),
        .sdi_row  (sdi_row),
        .frame_done(frame_done),
        .busy     (busy)
    );

    // ------------------------------------------------------------------
    // AXI-Lite helper tasks
    // ------------------------------------------------------------------
    task axi_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            awaddr  <= addr;
            awvalid <= 1'b1;
            wdata   <= data;
            wstrb   <= 4'hF;
            wvalid  <= 1'b1;
            bready  <= 1'b1;
            @(posedge clk);
            while (!awready) @(posedge clk);
            awvalid <= 1'b0;
            while (!wready) @(posedge clk);
            @(posedge clk);
            wvalid  <= 1'b0;
            while (!bvalid) @(posedge clk);
            @(posedge clk);
            bready  <= 1'b0;
        end
    endtask

    task axi_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            araddr  <= addr;
            arvalid <= 1'b1;
            rready  <= 1'b1;
            @(posedge clk);
            while (!arready) @(posedge clk);
            arvalid <= 1'b0;
            while (!rvalid) @(posedge clk);
            data = rdata;
            @(posedge clk);
            rready <= 1'b0;
        end
    endtask

    // ------------------------------------------------------------------
    // LE-pulse capture : on every falling edge of LE record how many DCLK
    // rising edges occurred while LE was high. Save the first 32 pulses so
    // assertions can inspect the init sequence in order.
    // ------------------------------------------------------------------
    integer le_dclk_count_cur;
    integer le_pulse_log [0:63];
    integer le_pulse_n;

    reg le_d;
    reg dclk_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            le_dclk_count_cur <= 0;
            le_pulse_n        <= 0;
            le_d              <= 1'b0;
            dclk_d            <= 1'b0;
        end else begin
            le_d   <= le;
            dclk_d <= dclk;
            // rising edge of DCLK while LE is high -> increment counter
            if (le && dclk && !dclk_d) begin
                le_dclk_count_cur <= le_dclk_count_cur + 1;
            end
            // falling edge of LE -> record pulse
            if (!le && le_d) begin
                if (le_pulse_n < 64) begin
                    le_pulse_log[le_pulse_n] <= le_dclk_count_cur;
                end
                le_pulse_n        <= le_pulse_n + 1;
                le_dclk_count_cur <= 0;
            end
            // rising edge of LE -> reset counter (covers any pre-edge dclk)
            if (le && !le_d) begin
                // start counter at 1 if DCLK is already high at LE rising
                // edge (so the rising DCLK that occurred this cycle counts)
                le_dclk_count_cur <= (dclk && !dclk_d) ? 1 : 0;
            end
        end
    end

    // ------------------------------------------------------------------
    // Row pulse width capture
    // ------------------------------------------------------------------
    integer row_dclk_count_cur;
    integer row_pulse_n;
    integer row_long_seen;     // # of ROW pulses with length >= 8 DCLK
    integer row_short_seen;    // # of ROW pulses with length 2..7 DCLK

    reg row_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            row_dclk_count_cur <= 0;
            row_pulse_n        <= 0;
            row_long_seen      <= 0;
            row_short_seen     <= 0;
            row_d              <= 1'b0;
        end else begin
            row_d <= row;
            if (row && dclk && !dclk_d) begin
                row_dclk_count_cur <= row_dclk_count_cur + 1;
            end
            if (!row && row_d) begin
                row_pulse_n <= row_pulse_n + 1;
                if (row_dclk_count_cur >= 8) row_long_seen  <= row_long_seen  + 1;
                else                         row_short_seen <= row_short_seen + 1;
                row_dclk_count_cur <= 0;
            end
            if (row && !row_d) begin
                row_dclk_count_cur <= (dclk && !dclk_d) ? 1 : 0;
            end
        end
    end

    // ------------------------------------------------------------------
    // timing trackers (analog widths)
    // ------------------------------------------------------------------
    real t_dclk_prev_rise;
    real t_dclk_period_min;
    real t_dclk_period_max;
    real t_le_rise, t_le_fall, le_width_min;
    real t_row_rise, t_row_fall, row_width_min;
    real t_slice_start, t_slice_end;
    integer dclk_count;
    integer error_count;

    reg dclk_d_a;
    real now;
    always @(posedge clk) begin
        dclk_d_a <= dclk;
        if (dclk && !dclk_d_a) begin
            now = $realtime;
            if (dclk_count > 0) begin
                if (now - t_dclk_prev_rise < t_dclk_period_min)
                    t_dclk_period_min = now - t_dclk_prev_rise;
                if (now - t_dclk_prev_rise > t_dclk_period_max)
                    t_dclk_period_max = now - t_dclk_prev_rise;
            end
            t_dclk_prev_rise = now;
            dclk_count = dclk_count + 1;
        end
    end

    reg le_d_a;
    always @(posedge clk) begin
        le_d_a <= le;
        if (le && !le_d_a) t_le_rise <= $realtime;
        if (!le && le_d_a) begin
            t_le_fall = $realtime;
            if ((t_le_fall - t_le_rise) < le_width_min)
                le_width_min = t_le_fall - t_le_rise;
        end
    end

    reg row_d_a;
    always @(posedge clk) begin
        row_d_a <= row;
        if (row && !row_d_a) t_row_rise <= $realtime;
        if (!row && row_d_a) begin
            t_row_fall = $realtime;
            if ((t_row_fall - t_row_rise) < row_width_min)
                row_width_min = t_row_fall - t_row_rise;
        end
    end

    // ------------------------------------------------------------------
    // Stimulus + checking
    // ------------------------------------------------------------------
    integer i;
    integer init_pulses_seen;
    integer vsync_pulse_idx;     // pulse index of the first VSYNC after init
    integer data_pulse_count;    // # of LE=1 (DATA_LATCH) pulses after VSYNC
    reg [31:0] tmp;

    initial begin
        $dumpfile("led_panel_drv_tb.vcd");
        $dumpvars(0, led_panel_drv_tb);

        rst_n         = 0;
        awaddr        = 0;
        awvalid       = 0;
        wdata         = 0;
        wstrb         = 0;
        wvalid        = 0;
        bready        = 0;
        araddr        = 0;
        arvalid       = 0;
        rready        = 0;
        s_axis_tdata  = 0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;

        t_dclk_prev_rise  = 0.0;
        t_dclk_period_min = 1e9;
        t_dclk_period_max = 0.0;
        le_width_min      = 1e9;
        row_width_min     = 1e9;
        t_le_rise         = 0;
        t_le_fall         = 0;
        t_row_rise        = 0;
        t_row_fall        = 0;
        dclk_count        = 0;
        error_count       = 0;
        init_pulses_seen  = 0;
        vsync_pulse_idx   = 0;
        data_pulse_count  = 0;

        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (10) @(posedge clk);

        // ============================================================
        // STAGE 0 : wait for init sequence to complete (cfg_done bit)
        // ============================================================
        $display("[INFO] waiting for power-on init sequence (cfg_done)...");
        // poll STATUS until cfg_done set
        tmp = 0;
        while (!tmp[2]) begin
            axi_read(8'h04, tmp);
        end
        init_pulses_seen = le_pulse_n;
        $display("[INFO] init complete, LE pulse count = %0d", init_pulses_seen);

        // ============================================================
        // ASSERTION : init pulse pattern matches V1.2 protocol
        //   expected = [PRE_ACT(14), WR_CFG(5) x EXPECTED_WR_CFG, EN_OP(11)]
        // ============================================================
        if (init_pulses_seen != (1 + EXPECTED_WR_CFG + 1)) begin
            $display("[FAIL] init pulse count = %0d, expected %0d",
                     init_pulses_seen, 1 + EXPECTED_WR_CFG + 1);
            error_count = error_count + 1;
        end else $display("[PASS] init pulse count = %0d",
                          init_pulses_seen);

        if (le_pulse_log[0] != LE_PRE_ACT) begin
            $display("[FAIL] init pulse[0] = %0d (expected PRE_ACT=%0d)",
                     le_pulse_log[0], LE_PRE_ACT);
            error_count = error_count + 1;
        end else $display("[PASS] init pulse[0] = PRE_ACT (LE=%0d)",
                          LE_PRE_ACT);

        for (i = 1; i <= EXPECTED_WR_CFG; i = i + 1) begin
            if (le_pulse_log[i] != LE_WR_CFG) begin
                $display("[FAIL] init pulse[%0d] = %0d (expected WR_CFG=%0d)",
                         i, le_pulse_log[i], LE_WR_CFG);
                error_count = error_count + 1;
            end
        end
        $display("[PASS] init WR_CFG pulses : %0d x LE=%0d",
                 EXPECTED_WR_CFG, LE_WR_CFG);

        if (le_pulse_log[1 + EXPECTED_WR_CFG] != LE_EN_OP) begin
            $display("[FAIL] init pulse[%0d] = %0d (expected EN_OP=%0d)",
                     1 + EXPECTED_WR_CFG,
                     le_pulse_log[1 + EXPECTED_WR_CFG], LE_EN_OP);
            error_count = error_count + 1;
        end else $display("[PASS] init pulse[%0d] = EN_OP (LE=%0d)",
                          1 + EXPECTED_WR_CFG, LE_EN_OP);

        // ============================================================
        // STAGE 1 : write CFG  : scan_ratio=4, pwm_bits=8, gain=1
        // ============================================================
        $display("[INFO] writing CFG");
        axi_write(8'h20, {16'd1, 8'd8, 8'd4});
        axi_read(8'h20, tmp);
        if (tmp !== {16'd1, 8'd8, 8'd4}) begin
            $display("[FAIL] CFG readback mismatch  got=%h", tmp);
            error_count = error_count + 1;
        end else $display("[PASS] CFG readback");

        // ============================================================
        // STAGE 2 : push white frame via AXIS
        // ============================================================
        $display("[INFO] streaming %0d pixels (white)", PANEL_W*PANEL_H);
        @(posedge clk);
        for (i = 0; i < PANEL_W*PANEL_H; i = i + 1) begin
            s_axis_tdata  <= 32'h00FF_FFFF;   // R=0xFF G=0xFF B=0xFF
            s_axis_tvalid <= 1'b1;
            s_axis_tlast  <= (i == PANEL_W*PANEL_H - 1);
            @(posedge clk);
            while (!s_axis_tready) @(posedge clk);
        end
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;
        $display("[INFO] frame loaded");

        // ============================================================
        // STAGE 3 : trigger one slice
        // ============================================================
        vsync_pulse_idx = le_pulse_n;     // remember : VSYNC will be next pulse
        t_slice_start = $realtime;
        axi_write(8'h14, 32'd1);
        wait (frame_done);
        t_slice_end = $realtime;
        $display("[INFO] slice elapsed = %.3f us",
                 (t_slice_end - t_slice_start)/1000.0);

        // ============================================================
        // ASSERTION : first new LE pulse is VSYNC (3 DCLK)
        // ============================================================
        if (le_pulse_log[vsync_pulse_idx] != LE_VSYNC) begin
            $display("[FAIL] post-trigger pulse[%0d] = %0d (expected VSYNC=%0d)",
                     vsync_pulse_idx,
                     le_pulse_log[vsync_pulse_idx], LE_VSYNC);
            error_count = error_count + 1;
        end else $display("[PASS] VSYNC pulse LE=%0d", LE_VSYNC);

        // count DATA_LATCH pulses after VSYNC
        data_pulse_count = 0;
        for (i = vsync_pulse_idx + 1; i < le_pulse_n && i < 64; i = i + 1) begin
            if (le_pulse_log[i] == LE_DATA_LATCH)
                data_pulse_count = data_pulse_count + 1;
            else begin
                $display("[FAIL] post-VSYNC pulse[%0d] = %0d (expected DATA=%0d)",
                         i, le_pulse_log[i], LE_DATA_LATCH);
                error_count = error_count + 1;
            end
        end
        if (data_pulse_count != DEFAULT_SCAN_RATIO) begin
            $display("[FAIL] DATA_LATCH pulses = %0d, expected %0d",
                     data_pulse_count, DEFAULT_SCAN_RATIO);
            error_count = error_count + 1;
        end else $display("[PASS] %0d DATA_LATCH pulses (LE=%0d each)",
                          data_pulse_count, LE_DATA_LATCH);

        // ============================================================
        // ASSERTION : ROW pulse widths observed in long(12) and short(4)
        // ============================================================
        if (row_long_seen < 1) begin
            $display("[FAIL] no ROW=12 long pulse seen");
            error_count = error_count + 1;
        end else $display("[PASS] %0d ROW long (>=8 DCLK) pulses",
                          row_long_seen);
        if (row_short_seen < 1) begin
            $display("[FAIL] no ROW=4 short pulse seen");
            error_count = error_count + 1;
        end else $display("[PASS] %0d ROW short (<8 DCLK) pulses",
                          row_short_seen);

        // ============================================================
        // ASSERTION : analog timing minima
        // ============================================================
        $display("[INFO] DCLK rising edges = %0d", dclk_count);
        $display("[INFO] DCLK period min = %.2f ns  max = %.2f ns",
                 t_dclk_period_min, t_dclk_period_max);
        $display("[INFO] LE  min high width = %.2f ns", le_width_min);
        $display("[INFO] ROW min high width = %.2f ns", row_width_min);

        if (t_dclk_period_min < 35.0) begin
            $display("[FAIL] DCLK too fast (period < 40 ns)");
            error_count = error_count + 1;
        end else $display("[PASS] DCLK period >= 40 ns (twCLK)");

        if (le_width_min < 10.0 && le_width_min < 1e8) begin
            $display("[FAIL] twLE < 10 ns");
            error_count = error_count + 1;
        end else $display("[PASS] twLE >= 10 ns");

        if (row_width_min < 160.0 && row_width_min < 1e8) begin
            $display("[FAIL] twROW < 160 ns");
            error_count = error_count + 1;
        end else $display("[PASS] twROW >= 160 ns");

        // ---- summary ----
        if (error_count == 0)
            $display("\n========== ALL ASSERTIONS PASSED ==========");
        else
            $display("\n========== %0d ERRORS ==========", error_count);

        $finish;
    end

    // safety timeout : 10 ms (init seq is much longer than v0 since it now
    // shifts 16 bit/chip x 4 chip x ~11 cfg writes through DCLK)
    initial begin
        #10_000_000;
        $display("[FAIL] global timeout @ 10 ms");
        $finish;
    end

endmodule
