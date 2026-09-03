// -----------------------------------------------------------------------------
// angle_tracker.v  -- POV rotor angle / slice-index tracker
//
// Method modeled on multivox src/driver/rotation.c:
//   * one sync pulse per revolution (photo interrupter / hall)
//   * measure revolution period in clock cycles
//   * between pulses, interpolate the current slice index by accumulating
//     time and stepping every (rev_period / n_slices) cycles
//   * lost-pulse / stall protection drops `locked`
//
// Differences vs multivox (per spec for this IP):
//   * slice_idx is hard-resynchronized to 0 on every accepted sensor pulse
//     (multivox instead servo-trims the rate; hard resync is simpler and the
//     panel pipeline tolerates a <=1-slice jump once per rev)
//   * the per-rev divide ROTATION_FULL/period is replaced by a 32-cycle
//     serial divider computing rev_period / n_slices once per revolution
//
// Verilog-2001, synchronous to single clk (aclk = 75 MHz typical).
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
`default_nettype none

module angle_tracker #(
    parameter integer CLK_HZ = 75000000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sensor_in,       // photo interrupter, 1 pulse / rev, async
    input  wire        fake_en,         // 1 = no sensor, free-run on fake_period
    input  wire [31:0] fake_period,     // fake mode: aclk cycles per slice
    input  wire [15:0] n_slices,        // slices per revolution (e.g. 122)
    output reg  [15:0] slice_idx,       // current slice 0 .. n_slices-1
    output reg  [31:0] rev_period,      // measured cycles per revolution (debug)
    output reg         locked           // 1 = two consecutive stable periods
);

    // ------------------------------------------------------------------
    // derived constants
    // ------------------------------------------------------------------
    // debounce: input must be stable for >= 1 us before it is believed
    localparam integer DEBOUNCE_CYC = CLK_HZ / 1000000;          // 75 @ 75 MHz
    // reject "revolutions" shorter than 1 ms (= 60000 RPM) as bounce/glitch,
    // same idea as multivox rotation.c:66 (elapsed > 10000 us gate)
    localparam [31:0]  MIN_REV_CYC  = CLK_HZ / 1000;

    // ------------------------------------------------------------------
    // 1) two-flop synchronizer + 1 us debounce + rising-edge detect
    // ------------------------------------------------------------------
    reg  [1:0] sync_ff;
    reg        sens_clean;          // debounced level
    reg  [7:0] db_cnt;
    reg        sens_clean_d;
    wire       sens_rise;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff    <= 2'b00;
            sens_clean <= 1'b0;
            db_cnt     <= 8'd0;
        end else begin
            sync_ff <= {sync_ff[0], sensor_in};
            if (sync_ff[1] == sens_clean) begin
                db_cnt <= 8'd0;                       // input agrees, re-arm
            end else if (db_cnt == DEBOUNCE_CYC[7:0]) begin
                sens_clean <= sync_ff[1];             // stable >= 1 us: accept
                db_cnt     <= 8'd0;
            end else begin
                db_cnt <= db_cnt + 8'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) sens_clean_d <= 1'b0;
        else        sens_clean_d <= sens_clean;
    end
    assign sens_rise = sens_clean & ~sens_clean_d;

    // ------------------------------------------------------------------
    // 2) revolution period measurement + stability / stall detection
    // ------------------------------------------------------------------
    reg  [31:0] rev_cnt;            // cycles since last accepted pulse
    reg  [31:0] prev_period;        // previous measurement, for stability check
    reg         have_pulse;         // at least one pulse seen since reset
    reg         div_start;          // kick the serial divider

    wire        pulse_ok = sens_rise && (rev_cnt >= MIN_REV_CYC);

    // stability: |new - old| < old/8  (multivox uses an 8-deep median filter,
    // rotation.c:45-51; a relative window on consecutive periods is the
    // cheap hardware equivalent)
    wire [31:0] diff_ab  = (rev_cnt > prev_period) ? (rev_cnt - prev_period)
                                                   : (prev_period - rev_cnt);
    wire        stable   = have_pulse && (diff_ab < (prev_period >> 3));

    // lost-pulse / stall: no pulse for > 2x last good period -> unlock
    // (multivox rotation.c:83 uses a fixed 1 s for rotation_stopped)
    wire        stalled  = have_pulse && (rev_cnt > {rev_period[30:0], 1'b0});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rev_cnt     <= 32'd0;
            rev_period  <= 32'hFFFF_FFFF;
            prev_period <= 32'd0;
            have_pulse  <= 1'b0;
            div_start   <= 1'b0;
        end else begin
            div_start <= 1'b0;
            if (pulse_ok) begin
                rev_cnt     <= 32'd1;            // this cycle belongs to new rev
                prev_period <= rev_cnt;
                have_pulse  <= 1'b1;
                if (!have_pulse || stable) begin
                    rev_period <= rev_cnt;       // accept measurement
                    div_start  <= 1'b1;          // recompute slice step
                end
            end else if (rev_cnt != 32'hFFFF_FFFF) begin
                rev_cnt <= rev_cnt + 32'd1;      // saturate, never wrap
            end
        end
    end

    // ------------------------------------------------------------------
    // 3) serial divider: slice_period = rev_period / n_slices
    //    one shift-subtract step per clock, 32 clocks per revolution --
    //    no combinational 32/16 divide anywhere
    // ------------------------------------------------------------------
    reg  [31:0] div_quot;
    reg  [47:0] div_rem;            // partial remainder, holds up to 16-bit divisor
    reg  [31:0] div_dividend;
    reg  [5:0]  div_bit;
    reg         div_busy;
    reg  [31:0] slice_period;       // current accepted cycles-per-slice
    reg         slice_period_valid;

    wire [47:0] div_try = {div_rem[46:0], div_dividend[31]};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_busy           <= 1'b0;
            div_quot           <= 32'd0;
            div_rem            <= 48'd0;
            div_dividend       <= 32'd0;
            div_bit            <= 6'd0;
            slice_period       <= 32'hFFFF_FFFF;
            slice_period_valid <= 1'b0;
        end else if (div_start && (n_slices != 16'd0)) begin
            div_busy     <= 1'b1;
            div_dividend <= rev_cnt;             // period just measured
            div_rem      <= 48'd0;
            div_quot     <= 32'd0;
            div_bit      <= 6'd0;
        end else if (div_busy) begin
            div_dividend <= {div_dividend[30:0], 1'b0};
            if (div_try >= {32'd0, n_slices}) begin
                div_rem  <= div_try - {32'd0, n_slices};
                div_quot <= {div_quot[30:0], 1'b1};
            end else begin
                div_rem  <= div_try;
                div_quot <= {div_quot[30:0], 1'b0};
            end
            if (div_bit == 6'd31) begin
                div_busy <= 1'b0;
            end
            div_bit <= div_bit + 6'd1;
        end else if (div_bit == 6'd32) begin
            // latch result one cycle after the last divider step
            div_bit <= 6'd0;
            if (div_quot >= 32'd2) begin         // guard absurd step of 0/1
                slice_period       <= div_quot;
                slice_period_valid <= 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------
    // 4) slice interpolation: accumulate cycles, step slice_idx every
    //    slice_period (real mode) / fake_period (fake mode) cycles.
    //    Remainder is carried (acc -= period, not acc <= 0) so boundary
    //    error never accumulates beyond +/-1 cycle per slice.
    // ------------------------------------------------------------------
    reg  [31:0] acc;
    wire [31:0] cur_step = fake_en ? fake_period : slice_period;
    wire        track_en = fake_en | (slice_period_valid & ~stalled);
    wire [15:0] last_idx = n_slices - 16'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slice_idx <= 16'd0;
            acc       <= 32'd0;
            locked    <= 1'b0;
        end else if (fake_en) begin
            // free-run: no sensor involved at all
            locked <= 1'b1;
            if (acc + 32'd1 >= cur_step) begin
                acc       <= acc + 32'd1 - cur_step;
                slice_idx <= (slice_idx >= last_idx) ? 16'd0 : slice_idx + 16'd1;
            end else begin
                acc <= acc + 32'd1;
            end
        end else begin
            // real-sensor mode
            if (pulse_ok) begin
                // resynchronize: every accepted pulse restarts the revolution
                slice_idx <= 16'd0;
                acc       <= 32'd0;
                // locked = two consecutive pulse periods agree
                locked    <= stable & slice_period_valid;
            end else begin
                if (stalled) locked <= 1'b0;     // 2x period with no pulse
                if (track_en) begin
                    if (acc + 32'd1 >= cur_step) begin
                        acc       <= acc + 32'd1 - cur_step;
                        slice_idx <= (slice_idx >= last_idx) ? 16'd0
                                                             : slice_idx + 16'd1;
                    end else begin
                        acc <= acc + 32'd1;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
