//-----------------------------------------------------------------------------
// icnd2260_seq_tb.v -- icnd2260_seq + icnd2260_tx 的自校验测试台
//-----------------------------------------------------------------------------
// 不是「看波形」型 TB: 内置一个按《编程指导 V2.8》§3.1 写的协议解码器,
// 把 isync/bit_r/bit_f 还原成指令 + 载荷, 逐字段对拍。任何一条不符直接 $fatal。
//
// 解码器按「真芯片能做到的方式」找同步, 而不是按拍数硬对齐:
//   I_SYNC 拉低后先是一段全 0 (手册只保证「不少于 16 DCLK」, 不是精确值),
//   遇到第一个 1 才开始收头 —— 命令头以 RSYNC=0x000d55 的低 12 位 0xd55 起头,
//   显示头以 0xA5A5 起头, 两者第一个 1 之后的 12 位不可能相同, 无歧义。
//   ⚠ 早先版本按「恰好 LEAD_DCLK 拍」对齐, 结果被 tx 的一拍输出延迟错开 2 bit,
//     整个头都解错 —— 别再改回去。
//
// 覆盖:
//   1. I_SYNC 帧格: 拉低 -> 至少 LEAD 拍全 0 -> 头部 -> 载荷 -> IDLE 全 0 -> 拉高 GAP 拍
//   2. RSYNC / CMD / DEVICE / OFFSET / LENGTH 字段
//   3. §12 上电顺序: 头两条整表写的 0x00[3] / 0x15[5] 必须被清掉, 之后必须恢复
//   4. 整表写的 238 个寄存器值逐个对拍 ROM
//   5. VHEAD = A5A5 / 行数 / 0x3 / 级联数 / 重复
//   6. 显示载荷逐像素对拍帧缓存, 且 lane1/lane2 在头部期间必须是 0
//   7. 空屏阶段 (§12 步骤 2) 的显示数据必须全 0
//
// 跑法: tools/run_sim.sh   (iverilog 或 xsim 均可)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_seq_tb;

    // 默认是缩短版 (跑得快); 全尺寸跑法见 tools/run_sim.sh --full
    parameter integer LINES        = 4;       // 真板 48
    parameter integer BLANK_FRAMES = 2;       // 真板 64

    localparam integer NLANE     = 3;
    localparam integer PIX       = 40;
    localparam integer CASCADE   = 1;
    localparam integer REG_COUNT = 238;
    localparam integer TOTAL_PIX    = PIX * LINES * CASCADE;
    localparam integer FB_AW        = 11;

    localparam integer LEAD_DCLK = 16;
    localparam integer IDLE_DCLK = 160;
    localparam integer GAP_DCLK  = 8;

    reg clk = 1'b0, rst_n = 1'b0;
    always #20 clk = ~clk;                    // 25 MHz

    // ---- 帧缓存模型 -------------------------------------------------------
    reg [16*NLANE-1:0] fb [0:TOTAL_PIX-1];
    wire [FB_AW-1:0]   fb_addr;
    reg  [16*NLANE-1:0] fb_q;
    always @(posedge clk) fb_q <= fb[fb_addr];

    // ---- 期望寄存器表 -----------------------------------------------------
    reg [15:0] exp_reg [0:255];

    // ---- DUT --------------------------------------------------------------
    wire                cmd_valid, cmd_ready, tx_busy;
    wire [2:0]          cmd_kind;
    wire [3:0]          cmd_device, cmd_cascade;
    wire [7:0]          cmd_offset, cmd_length, cmd_rows;
    wire                pl_next, pl_last;
    wire [16*NLANE-1:0] pl_data;
    wire                en_3v8, en_2v8, out_en, running;
    wire [31:0]         frame_cnt;
    wire [NLANE-1:0]    bit_r, bit_f;
    wire                isync;

    icnd2260_seq #(
        .NLANE (NLANE), .REG_COUNT (REG_COUNT), .PIX_PER_LINE (PIX),
        .LINES (LINES), .CASCADE (CASCADE), .BLANK_FRAMES (BLANK_FRAMES),
        .REG_REFRESH_FR (64), .READ_PROBE_FR (2),
        .RAIL_STAGGER (20), .RAIL_SETTLE (40), .FB_AW (FB_AW)
    ) u_seq (
        .clk (clk), .rst_n (rst_n),
        .en_3v8 (en_3v8), .en_2v8 (en_2v8), .out_en (out_en),
        .fb_addr (fb_addr), .fb_q (fb_q),
        .cmd_valid (cmd_valid), .cmd_ready (cmd_ready), .cmd_kind (cmd_kind),
        .cmd_device (cmd_device), .cmd_offset (cmd_offset),
        .cmd_length (cmd_length), .cmd_rows (cmd_rows), .cmd_cascade (cmd_cascade),
        .pl_next (pl_next), .pl_data (pl_data), .pl_last (pl_last),
        .tx_busy (tx_busy), .running (running), .frame_cnt (frame_cnt),
        // 调试口显式接死: 悬空的话是 z, dbg_probe_en 会把 cmd_offset 传成 x,
        // 而 TB 又不检查读指令的 offset ⇒ 悄悄放过去。别留悬空输入。
        .dbg_reg_we (1'b0), .dbg_reg_addr (8'h00), .dbg_reg_data (16'h0000),
        .dbg_probe_en (1'b0), .dbg_probe_off (8'h00),
        .dbg_ph (), .dbg_sub ()
    );

    icnd2260_tx #(
        .NLANE (NLANE), .LEAD_DCLK (LEAD_DCLK),
        .IDLE_DCLK (IDLE_DCLK), .GAP_DCLK (GAP_DCLK)
    ) u_tx (
        .clk (clk), .rst_n (rst_n),
        .cmd_valid (cmd_valid), .cmd_ready (cmd_ready), .cmd_kind (cmd_kind),
        .cmd_device (cmd_device), .cmd_offset (cmd_offset),
        .cmd_length (cmd_length), .cmd_rows (cmd_rows), .cmd_cascade (cmd_cascade),
        .pl_next (pl_next), .pl_data (pl_data), .pl_last (pl_last),
        .bit_r (bit_r), .bit_f (bit_f), .isync (isync), .busy (tx_busy)
    );

    //-------------------------------------------------------------------------
    // 协议解码器
    //-------------------------------------------------------------------------
    integer errors  = 0;
    integer n_vsync = 0;
    integer n_wreg  = 0;
    integer n_read  = 0;      // 读寄存器指令 (CMD=1010) 的条数
    integer n_disp  = 0;
    integer blank_disp_seen = 0;

    localparam integer PH_LEAD = 0, PH_HDR = 1, PH_PAY = 2, PH_TRAIL = 3;

    reg        in_cmd = 1'b0;
    integer    dph;                  // 解码阶段
    integer    lead_cyc;             // I_SYNC 低之后、第一个 1 之前的拍数
    reg [47:0] hdr;
    integer    hdr_bits;
    integer    hdr_len;
    integer    kind;                 // 0=未定 1=命令 2=VHEAD
    reg [3:0]  cmd_f;
    reg [7:0]  off_f, len_f;
    reg [15:0] pay [0:NLANE-1];
    integer    pay_bit, pay_idx, pay_len;
    integer    trail_zero;
    integer    gap_cyc = 1000;
    reg        expect_zero_disp;

    localparam integer K_UNK = 0, K_CMD = 1, K_VH = 2;

    task fail(input [255:0] tag);
        begin
            $display("[FAIL @%0t] %0s", $time, tag);
            errors = errors + 1;
            if (errors > 8) begin
                $display("too many errors, stop");
                $fatal(1);
            end
        end
    endtask

    always @(negedge isync) begin
        if (gap_cyc < GAP_DCLK) fail("gap_too_short");
        in_cmd     = 1'b1;
        dph        = PH_LEAD;
        lead_cyc   = 0;
        hdr        = 48'h0;
        hdr_bits   = 0;
        hdr_len    = 48;
        kind       = K_UNK;
        pay_bit    = 0;
        pay_idx    = 0;
        pay_len    = 0;
        trail_zero = 0;
    end

    always @(posedge isync) begin
        if (in_cmd) begin
            if (dph != PH_TRAIL)          fail("cmd_ended_before_payload_done");
            if (trail_zero < IDLE_DCLK)   fail("trailing_idle_too_short");
            if (kind == K_CMD && cmd_f == 4'b0101 && pay_idx != pay_len)
                fail("reg_payload_count_mismatch");
            if (kind == K_VH && pay_idx != TOTAL_PIX)
                fail("disp_payload_count_mismatch");
            in_cmd = 1'b0;
        end
        gap_cyc = 0;
    end

    integer i;
    integer wi;

    always @(posedge clk) begin
        if (isync === 1'b1) gap_cyc = gap_cyc + 1;

        if (in_cmd && isync === 1'b0) begin
            case (dph)
            // ---- I_SYNC 已低, 等第一个 1 -------------------------------
            PH_LEAD: begin
                if (|bit_r[NLANE-1:1] || |bit_f[NLANE-1:1])
                    fail("lane12_nonzero_in_lead");
                // 两种头的第一个 1 都落在偶数位 (RSYNC 的第 12 位 / A5A5 的第 0 位),
                // 而 tx 总是从 bit_r 开始发 ⇒ 第一个 1 必然出现在 bit_r 上。
                if (bit_r[0] === 1'b1) begin
                    dph      = PH_HDR;
                    hdr      = {47'h0, 1'b1};
                    hdr      = {hdr[46:0], bit_f[0]};
                    hdr_bits = 2;
                    if (lead_cyc < LEAD_DCLK) fail("lead_too_short");
                end else if (bit_f[0] === 1'b1) begin
                    fail("header_started_on_falling_edge");
                end else begin
                    lead_cyc = lead_cyc + 1;
                end
            end

            // ---- 头部 --------------------------------------------------
            PH_HDR: begin
                if (|bit_r[NLANE-1:1] || |bit_f[NLANE-1:1])
                    fail("lane12_nonzero_in_header");
                if (hdr_bits < hdr_len) begin
                    hdr = {hdr[45:0], bit_r[0], bit_f[0]};
                    hdr_bits = hdr_bits + 2;
                end

                // 定种类: 第一个 1 之后 12 位 = 0xd55 -> RSYNC 尾; 16 位 = 0xA5A5 -> VHEAD
                if (kind == K_UNK && hdr_bits >= 12 && hdr[11:0] == 12'hd55 && hdr_bits == 12) begin
                    kind    = K_CMD;
                    hdr_len = 12 + 8;            // 还要 CMD(4)+DEVICE(4)
                end
                if (kind == K_UNK && hdr_bits == 16 && hdr[15:0] == 16'hA5A5) begin
                    kind    = K_VH;
                    hdr_len = 48;
                end
                if (kind == K_UNK && hdr_bits >= 16) fail("no_sync_pattern_found");

                if (kind == K_CMD && hdr_bits == 20 && hdr_len == 20) begin
                    cmd_f = hdr[7:4];
                    if (hdr[3:0] != 4'hF && cmd_f == 4'b0101) fail("write_all_device_not_F");
                    if (cmd_f == 4'b0011) begin        // VSYNC: 到此为止
                        n_vsync = n_vsync + 1;
                        if (hdr[3:0] != 4'hF) fail("vsync_device_not_F");
                        dph = PH_TRAIL;
                    end else begin
                        hdr_len = 36;                  // 再收 OFFSET(8)+LENGTH(8)
                    end
                end else if (kind == K_CMD && hdr_bits == 36) begin
                    off_f   = hdr[15:8];
                    len_f   = hdr[7:0];
                    pay_len = len_f + 1;
                    if (cmd_f == 4'b0101) begin
                        n_wreg = n_wreg + 1;
                        if (off_f != 8'h00)          fail("write_all_offset_not_0");
                        if (len_f != REG_COUNT - 1)  fail("write_all_length_wrong");
                        dph = PH_PAY;
                    end else if (cmd_f == 4'b1010) begin
                        // 读寄存器: **没有数据域**, 头后面直接是 IDLE, 返回值走 ACK
                        n_read = n_read + 1;
                        dph    = PH_TRAIL;
                    end else begin
                        dph = PH_PAY;
                    end
                end else if (kind == K_VH && hdr_bits == 48) begin
                    n_disp = n_disp + 1;
                    if (hdr[47:32] != 16'hA5A5)     fail("vhead_magic");
                    if (hdr[31:24] != LINES - 1)    fail("vhead_rows");
                    if (hdr[23:20] != 4'h3)         fail("vhead_width_not_3");
                    if (hdr[19:16] != CASCADE - 1)  fail("vhead_cascade");
                    if (hdr[15:0]  != hdr[31:16])   fail("vhead_tail_not_repeat");
                    expect_zero_disp = (blank_disp_seen < BLANK_FRAMES);
                    blank_disp_seen  = blank_disp_seen + 1;
                    pay_len = TOTAL_PIX;
                    dph     = PH_PAY;
                end
            end

            // ---- 载荷 --------------------------------------------------
            PH_PAY: begin
                for (i = 0; i < NLANE; i = i + 1)
                    pay[i] = {pay[i][13:0], bit_r[i], bit_f[i]};
                pay_bit = pay_bit + 2;
                if (pay_bit == 16) begin
                    pay_bit = 0;
                    if (kind == K_CMD) begin
                        if (pay[0] !== exp_reg[off_f + pay_idx]) begin
                            $display("  reg[0x%02x] got %04x want %04x (write#%0d)",
                                     off_f + pay_idx, pay[0], exp_reg[off_f + pay_idx], n_wreg);
                            fail("reg_value_mismatch");
                        end
                        for (i = 1; i < NLANE; i = i + 1)
                            if (pay[i] !== 16'h0) fail("lane12_nonzero_in_regwrite");
                    end else begin
                        if (expect_zero_disp) begin
                            for (i = 0; i < NLANE; i = i + 1)
                                if (pay[i] !== 16'h0) fail("blank_frame_not_zero");
                        end else begin
                            for (i = 0; i < NLANE; i = i + 1)
                                if (pay[i] !== fb[pay_idx][16*i +: 16]) begin
                                    $display("  px%0d lane%0d got %04x want %04x",
                                             pay_idx, i, pay[i], fb[pay_idx][16*i +: 16]);
                                    fail("pixel_mismatch");
                                end
                        end
                    end
                    pay_idx = pay_idx + 1;
                    if (pay_idx == pay_len) dph = PH_TRAIL;
                end
            end

            // ---- 尾部 IDLE ---------------------------------------------
            PH_TRAIL: begin
                if (|bit_r || |bit_f) fail("nonzero_in_trailing_idle");
                trail_zero = trail_zero + 1;
            end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // §12 上电: 头两次整表写必须屏蔽 0x00[3] / 0x15[5], 第三次起恢复
    //-------------------------------------------------------------------------
    always @(n_wreg) begin
        if (n_wreg <= 2) begin
            exp_reg[8'h00] = u_seq.reg_rom[8'h00] & ~16'h0008;
            exp_reg[8'h15] = u_seq.reg_rom[8'h15] & ~16'h0020;
        end else begin
            exp_reg[8'h00] = u_seq.reg_rom[8'h00];
            exp_reg[8'h15] = u_seq.reg_rom[8'h15];
        end
    end

    //-------------------------------------------------------------------------
    initial begin
        for (wi = 0; wi < 256; wi = wi + 1) exp_reg[wi] = 16'h0;
        $readmemh("icnd2260_regs.mem", exp_reg);
        exp_reg[8'h00] = exp_reg[8'h00] & ~16'h0008;   // 头两遍是屏蔽版
        exp_reg[8'h15] = exp_reg[8'h15] & ~16'h0020;

        for (wi = 0; wi < TOTAL_PIX; wi = wi + 1)
            fb[wi] = {16'h1000 + wi[15:0], 16'h2000 + wi[15:0], 16'h3000 + wi[15:0]};

        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        wait (running);
        wait (frame_cnt >= BLANK_FRAMES + 2);
        repeat (200) @(posedge clk);

        if (!en_3v8 || !en_2v8) fail("rails_not_enabled");
        if (!out_en)            fail("out_en_low");
        if (n_wreg < 3)         fail("too_few_reg_writes");
        if (n_disp < BLANK_FRAMES + 2) fail("too_few_display_cmds");
        if (n_vsync < BLANK_FRAMES + 2) fail("too_few_vsync");
        if (n_read  < 1)                fail("read_probe_never_fired");

        $display("-----------------------------------------------------------");
        $display("VSYNC=%0d  WRITE_ALL=%0d  READ=%0d  DISPLAY=%0d  frame_cnt=%0d",
                 n_vsync, n_wreg, n_read, n_disp, frame_cnt);
        if (errors == 0) $display("*** PASS ***");
        else begin
            $display("*** FAIL: %0d mismatches ***", errors);
            $fatal(1);
        end
        $finish;
    end

    initial begin
        #200_000_000;
        $display("*** TIMEOUT ***");
        $fatal(1);
    end

endmodule

`default_nettype wire
