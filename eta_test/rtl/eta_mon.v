`timescale 1ns / 1ps
// eta_mon.v -- PL-side gauge for the DDR read-efficiency (eta) test.
//
// Fans out ap_start to both gauge IPs from ONE register write (same clock edge => truly
// simultaneous start) and counts, at ap_clk resolution:
//     cyc    free-running cycles            done0/1  ap_done pulses (= completed runs of n_slots slices)
//     busy0/1 cycles with ap_idle==0        both     cycles with both IPs busy (overlap proof)
//     per0/1  sum of cycles between consecutive ap_done pulses  (exact average run period = per/pcnt,
//     pcnt0/1 number of such periods                             no partial-run edge error)
// A rising edge on ctrl[0] latches every counter into a shadow bank at the same instant, so the
// slow JTAG reader sees one consistent snapshot. eta = bytes / (cycles / f_clk) / 2.133 GB/s is
// then computed on the host from two snapshots.
//
// Wiring (BD): ctrl <- axi_gpio ch1 (32 outputs), dout -> axi_gpio ch2 (32 inputs).
//   ctrl[0]   snap   (rising edge latches counters)
//   ctrl[1]   start0 -> ip0/ap_start (level; held high = IP re-runs back to back)
//   ctrl[2]   start1 -> ip1/ap_start
//   ctrl[3]   clear  (rising edge zeroes all counters)
//   ctrl[7:4] sel    (which snapshot word appears on dout, see case below)
//
// 32-bit counters at 150 MHz wrap every 28.6 s: the host must take deltas mod 2^32 and keep
// measurement windows < 20 s. ASCII only.
module eta_mon (
    input  wire        clk,
    input  wire        rstn,
    input  wire        done0,
    input  wire        idle0,
    input  wire        ready0,
    input  wire        done1,
    input  wire        idle1,
    input  wire        ready1,
    input  wire [31:0] ctrl,
    output wire        start0,
    output wire        start1,
    output reg  [31:0] dout
);
    localparam [31:0] MAGIC = 32'hE7A0_0001;   // sel=6 must read this, else the GPIO->mon path is broken

    assign start0 = ctrl[1];
    assign start1 = ctrl[2];
    wire       snap_bit = ctrl[0];
    wire       clr_bit  = ctrl[3];
    wire [3:0] sel      = ctrl[7:4];

    reg snap_d, clr_d;
    wire snap_pulse = snap_bit & ~snap_d;
    wire clr_pulse  = clr_bit  & ~clr_d;

    reg [31:0] cyc, done0_cnt, done1_cnt, busy0_cnt, busy1_cnt, both_cnt;
    reg [31:0] s_cyc, s_done0, s_done1, s_busy0, s_busy1, s_both;
    reg [31:0] per0, per1, pcnt0, pcnt1, last0, last1;      // period accumulators
    reg        seen0, seen1;                                 // first done since clear seen?
    reg [31:0] s_per0, s_per1, s_pcnt0, s_pcnt1;
    reg [31:0] snap_cnt;                       // how many snapshots taken (host sanity: increments by 1 per snap)

    wire b0 = ~idle0;
    wire b1 = ~idle1;

    always @(posedge clk) begin
        if (!rstn) begin
            snap_d <= 1'b0; clr_d <= 1'b0;
            cyc <= 0; done0_cnt <= 0; done1_cnt <= 0; busy0_cnt <= 0; busy1_cnt <= 0; both_cnt <= 0;
            s_cyc <= 0; s_done0 <= 0; s_done1 <= 0; s_busy0 <= 0; s_busy1 <= 0; s_both <= 0;
            per0 <= 0; per1 <= 0; pcnt0 <= 0; pcnt1 <= 0; last0 <= 0; last1 <= 0; seen0 <= 0; seen1 <= 0;
            s_per0 <= 0; s_per1 <= 0; s_pcnt0 <= 0; s_pcnt1 <= 0;
            snap_cnt <= 0;
        end else begin
            snap_d <= snap_bit;
            clr_d  <= clr_bit;
            if (clr_pulse) begin
                cyc <= 0; done0_cnt <= 0; done1_cnt <= 0; busy0_cnt <= 0; busy1_cnt <= 0; both_cnt <= 0;
                per0 <= 0; per1 <= 0; pcnt0 <= 0; pcnt1 <= 0; seen0 <= 0; seen1 <= 0;
            end else begin
                cyc <= cyc + 1;
                if (done0)   done0_cnt <= done0_cnt + 1;
                if (done1)   done1_cnt <= done1_cnt + 1;
                if (b0)      busy0_cnt <= busy0_cnt + 1;
                if (b1)      busy1_cnt <= busy1_cnt + 1;
                if (b0 & b1) both_cnt  <= both_cnt  + 1;
                if (done0) begin
                    last0 <= cyc; seen0 <= 1'b1;
                    if (seen0) begin per0 <= per0 + (cyc - last0); pcnt0 <= pcnt0 + 1; end
                end
                if (done1) begin
                    last1 <= cyc; seen1 <= 1'b1;
                    if (seen1) begin per1 <= per1 + (cyc - last1); pcnt1 <= pcnt1 + 1; end
                end
            end
            if (snap_pulse) begin
                s_cyc <= cyc; s_done0 <= done0_cnt; s_done1 <= done1_cnt;
                s_busy0 <= busy0_cnt; s_busy1 <= busy1_cnt; s_both <= both_cnt;
                s_per0 <= per0; s_per1 <= per1; s_pcnt0 <= pcnt0; s_pcnt1 <= pcnt1;
                snap_cnt <= snap_cnt + 1;
            end
        end
    end

    always @(*) begin
        case (sel)
            4'd0:  dout = s_cyc;
            4'd1:  dout = s_done0;
            4'd2:  dout = s_done1;
            4'd3:  dout = s_busy0;
            4'd4:  dout = s_busy1;
            4'd5:  dout = s_both;
            4'd6:  dout = MAGIC;
            4'd7:  dout = ctrl;                                   // echo: proves the write reached the PL
            4'd8:  dout = cyc;                                    // live counter: two reads must differ
            4'd9:  dout = {26'd0, ready1, ready0, idle1, idle0, start1, start0};   // live status
            4'd10: dout = snap_cnt;
            4'd11: dout = s_per0;
            4'd12: dout = s_pcnt0;
            4'd13: dout = s_per1;
            4'd14: dout = s_pcnt1;
            default: dout = 32'hDEAD_0000 | {28'd0, sel};
        endcase
    end
endmodule
