//-----------------------------------------------------------------------------
// icnd2260_lvds_tb.v -- icnd2260_seq + icnd2260_lvds_tx 的自校验测试台
//-----------------------------------------------------------------------------
// 内置一个按《编程指导 V2.8》§3.2 写的 mini-LVDS 解码器, 独立重算 CRC 后对拍。
//
// 解码器按「边」工作: 每个时钟周期有 2 个边 (bit_r 在前, bit_f 在后)。
// 靠数据本身找同步, 不按拍数硬对齐:
//   IDLE 段数据恒 0 ⇒ lane0 第一个 1 就是段首。
//   段首后的第 2 个边可以区分两种段:
//     RSYNC (0xFFFF0F0F0F0F0F, 4 边/位) 首位是 1 ⇒ 前 4 个边都是 1 ⇒ 第 2 边 = 1
//     VHEAD (0xA5A5,          1 边/位) 首两位是 1,0            ⇒ 第 2 边 = 0
//
// 覆盖:
//   1. RSYNC 值正确, 且**每 4 个边确实是同一位**(4 倍过采样没做错)
//   2. 配置包 CMD/DEVICE/OFFSET/LENGTH 字段 + 238 个寄存器值 (对拍 LVDS 版 ROM)
//   3. 配置包 CHKSUM: TB 独立重算 CRC-16/CCITT(init FFFF, 覆盖 CMD..D_last) 后比对
//   4. VHEAD = A5A5 / 行数 / 0x3 / 级联数 / **CRC(VHEAD[31:16])**
//   5. 图像数据逐像素对拍帧缓存, 且**头部期间 lane1/lane2 必须为 0**
//   6. 每 lane 的图像 CHKSUM
//   7. §12 上电: 头两条整表写要屏蔽 0x00[3] / 0x15[5]
//   8. I_SYNC 每帧只翻转一次 (VSYNC), 不是每条指令翻
//
// 🔴 CRC 多项式/初值/覆盖范围是从手册第 13 页那张 LFSR 图反推的。TB 通过只说明
//    RTL 与这份推断一致, **不代表芯片认**。上板拿 ACK 回包对一次才算数。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_lvds_tb;

    parameter integer LINES        = 4;       // 真板 48
    parameter integer BLANK_FRAMES = 2;       // 真板 64

    localparam integer NLANE     = 3;
    localparam integer PIX       = 40;
    localparam integer CASCADE   = 1;
    localparam integer REG_COUNT = 238;
    localparam integer TOTAL_PIX = PIX * LINES * CASCADE;
    localparam integer FB_AW     = 11;
    localparam integer IDLE_CLK  = 64;

    reg clk = 1'b0, rst_n = 1'b0;
    always #6 clk = ~clk;                     // ~83 MHz, 数值不影响协议

    // ---- 帧缓存模型 (LVDS 字序: 低 16 位 = B = lane0) --------------------
    reg [16*NLANE-1:0] fb [0:TOTAL_PIX-1];
    wire [FB_AW-1:0]   fb_addr;
    reg  [16*NLANE-1:0] fb_q;
    always @(posedge clk) fb_q <= fb[fb_addr];

    reg [15:0] exp_reg [0:255];

    // ---- DUT -------------------------------------------------------------
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
        .REG_REFRESH_FR (64), .RAIL_STAGGER (20), .RAIL_SETTLE (40),
        .FB_AW (FB_AW), .REG_MEM ("icnd2260_regs_lvds.mem")
    ) u_seq (
        .clk (clk), .rst_n (rst_n),
        .en_3v8 (en_3v8), .en_2v8 (en_2v8), .out_en (out_en),
        .fb_addr (fb_addr), .fb_q (fb_q),
        .cmd_valid (cmd_valid), .cmd_ready (cmd_ready), .cmd_kind (cmd_kind),
        .cmd_device (cmd_device), .cmd_offset (cmd_offset),
        .cmd_length (cmd_length), .cmd_rows (cmd_rows), .cmd_cascade (cmd_cascade),
        .pl_next (pl_next), .pl_data (pl_data), .pl_last (pl_last),
        .tx_busy (tx_busy), .running (running), .frame_cnt (frame_cnt)
    );

    icnd2260_lvds_tx #(.NLANE (NLANE), .IDLE_CLK (IDLE_CLK), .VID_CRC (1)) u_tx (
        .clk (clk), .rst_n (rst_n),
        .cmd_valid (cmd_valid), .cmd_ready (cmd_ready), .cmd_kind (cmd_kind),
        .cmd_device (cmd_device), .cmd_offset (cmd_offset),
        .cmd_length (cmd_length), .cmd_rows (cmd_rows), .cmd_cascade (cmd_cascade),
        .pl_next (pl_next), .pl_data (pl_data), .pl_last (pl_last),
        .bit_r (bit_r), .bit_f (bit_f), .isync (isync), .busy (tx_busy)
    );

    //-------------------------------------------------------------------------
    // TB 侧独立实现的 CRC-16/CCITT
    //-------------------------------------------------------------------------
    function [15:0] crc_step(input [15:0] c, input b);
        reg fb_;
        begin
            fb_      = c[15] ^ b;
            crc_step = {c[14:0], 1'b0};
            if (fb_) crc_step = crc_step ^ 16'h1021;
        end
    endfunction

    //-------------------------------------------------------------------------
    // 解码器
    //-------------------------------------------------------------------------
    localparam integer D_IDLE  = 0, D_START = 1, D_RSYNC = 2, D_CHDR = 3,
                       D_CDATA = 4, D_CCRC  = 5, D_VHEAD = 6, D_VDATA = 7,
                       D_VCRC  = 8;

    integer errors  = 0;
    integer n_cfg   = 0;      // 配置包条数
    integer n_disp  = 0;      // 显示包条数
    integer n_sync  = 0;      // I_SYNC 翻转次数
    integer blank_seen = 0;

    integer dst = D_IDLE;
    integer os;               // 当前段的过采样倍数: 4 或 1
    integer osc;              // 段内边计数 (用于 4 倍过采样的组内校验)
    reg     osbit;            // 4 倍组里的第一个边, 后 3 个必须与它相同
    integer nb;               // 已收多少位
    reg [55:0] acc;           // 位累加器 (lane0)
    reg [15:0] wacc [0:NLANE-1];
    integer widx;
    integer zeros;

    reg [3:0] f_cmd, f_dev;
    reg [7:0] f_off, f_len;
    reg [15:0] crc_calc;
    reg expect_zero_disp;
    integer i;
    integer ci, cj;          // D_VCRC 里重算 CRC 的循环变量 (别复用 widx/nb!)

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

    // 处理一个「边」: e = 各 lane 在这个边上的值
    task push_edge(input [NLANE-1:0] e);
        reg b0;
        begin
            b0 = e[0];
            case (dst)
            //-----------------------------------------------------------
            D_IDLE: begin
                if (b0) begin
                    if (zeros < IDLE_CLK) fail("idle_gap_too_short");
                    dst = D_START;
                    acc = 56'h1;
                    nb  = 1;
                end else begin
                    zeros = zeros + 1;
                    if (|e[NLANE-1:1]) fail("lane12_nonzero_in_idle");
                end
            end

            //---- 第 2 个边定段类型 --------------------------------------
            D_START: begin
                if (b0) begin                       // 1,1 -> RSYNC (4 边/位)
                    dst   = D_RSYNC;
                    os    = 4;  osc = 2;  osbit = 1'b1;
                    acc   = 56'h1;  nb = 0;         // 第 1 位在组末才计入
                end else begin                      // 1,0 -> VHEAD (1 边/位)
                    dst   = D_VHEAD;
                    os    = 1;
                    acc   = 56'h2;                  // 已收 1,0
                    nb    = 2;
                    n_disp = n_disp + 1;
                end
                if (|e[NLANE-1:1]) fail("lane12_nonzero_in_header");
            end

            //---- RSYNC: 56 位, 4 边/位 ---------------------------------
            D_RSYNC: begin
                if (|e[NLANE-1:1]) fail("lane12_nonzero_in_rsync");
                if (osc == 0) osbit = b0;
                else if (b0 !== osbit) fail("oversample4_bits_differ");
                osc = osc + 1;
                if (osc == 4) begin
                    osc = 0;
                    acc = {acc[54:0], osbit};
                    nb  = nb + 1;
                    if (nb == 56) begin
                        if (acc !== 56'hFFFF0F0F0F0F0F) fail("rsync_pattern_wrong");
                        dst = D_CHDR;  acc = 56'h0;  nb = 0;  crc_calc = 16'hFFFF;
                    end
                end
            end

            //---- 配置包头 24 位, 4 边/位 -------------------------------
            D_CHDR: begin
                if (|e[NLANE-1:1]) fail("lane12_nonzero_in_cfghdr");
                if (osc == 0) osbit = b0;
                else if (b0 !== osbit) fail("oversample4_bits_differ");
                osc = osc + 1;
                if (osc == 4) begin
                    osc      = 0;
                    acc      = {acc[54:0], osbit};
                    crc_calc = crc_step(crc_calc, osbit);
                    nb       = nb + 1;
                    if (nb == 24) begin
                        f_cmd = acc[23:20];  f_dev = acc[19:16];
                        f_off = acc[15:8];   f_len = acc[7:0];
                        n_cfg = n_cfg + 1;
                        if (f_cmd !== 4'b0101)        fail("cfg_cmd_not_write_all");
                        if (f_off !== 8'h00)          fail("cfg_offset_not_0");
                        if (f_len !== REG_COUNT - 1)  fail("cfg_length_wrong");
                        dst = D_CDATA;  nb = 0;  widx = 0;  wacc[0] = 16'h0;
                    end
                end
            end

            //---- 配置数据: (LENGTH+1) x 16 位, 4 边/位 -----------------
            D_CDATA: begin
                if (|e[NLANE-1:1]) fail("lane12_nonzero_in_cfgdata");
                if (osc == 0) osbit = b0;
                else if (b0 !== osbit) fail("oversample4_bits_differ");
                osc = osc + 1;
                if (osc == 4) begin
                    osc      = 0;
                    wacc[0]  = {wacc[0][14:0], osbit};
                    crc_calc = crc_step(crc_calc, osbit);
                    nb       = nb + 1;
                    if (nb == 16) begin
                        if (wacc[0] !== exp_reg[f_off + widx]) begin
                            $display("  reg[0x%02x] got %04x want %04x (cfg#%0d)",
                                     f_off + widx, wacc[0], exp_reg[f_off + widx], n_cfg);
                            fail("reg_value_mismatch");
                        end
                        nb   = 0;
                        widx = widx + 1;
                        if (widx == f_len + 1) begin dst = D_CCRC; acc = 56'h0; end
                    end
                end
            end

            //---- 配置包 CHKSUM: 16 位, 4 边/位 -------------------------
            D_CCRC: begin
                if (osc == 0) osbit = b0;
                else if (b0 !== osbit) fail("oversample4_bits_differ");
                osc = osc + 1;
                if (osc == 4) begin
                    osc = 0;
                    acc = {acc[54:0], osbit};
                    nb  = nb + 1;
                    if (nb == 16) begin
                        if (acc[15:0] !== crc_calc) begin
                            $display("  cfg CRC got %04x want %04x", acc[15:0], crc_calc);
                            fail("cfg_crc_mismatch");
                        end
                        dst = D_IDLE;  zeros = 0;
                    end
                end
            end

            //---- VHEAD: 48 位, 1 边/位 --------------------------------
            D_VHEAD: begin
                if (|e[NLANE-1:1]) fail("lane12_nonzero_in_vhead");
                acc = {acc[54:0], b0};
                nb  = nb + 1;
                if (nb == 48) begin
                    crc_calc = 16'hFFFF;
                    for (i = 15; i >= 0; i = i - 1)
                        crc_calc = crc_step(crc_calc, acc[16 + i]);
                    if (acc[47:32] !== 16'hA5A5)      fail("vhead_magic");
                    if (acc[31:24] !== LINES - 1)     fail("vhead_rows");
                    if (acc[23:20] !== 4'h3)          fail("vhead_width_not_3");
                    if (acc[19:16] !== CASCADE - 1)   fail("vhead_cascade");
                    if (acc[15:0]  !== crc_calc) begin
                        $display("  VHEAD CRC got %04x want %04x", acc[15:0], crc_calc);
                        fail("vhead_crc_mismatch");
                    end
                    expect_zero_disp = (blank_seen < BLANK_FRAMES);
                    blank_seen = blank_seen + 1;
                    dst = D_VDATA;  nb = 0;  widx = 0;
                    for (i = 0; i < NLANE; i = i + 1) wacc[i] = 16'h0;
                end
            end

            //---- 图像数据: 每 lane 每像素 16 位, 1 边/位 ---------------
            D_VDATA: begin
                for (i = 0; i < NLANE; i = i + 1)
                    wacc[i] = {wacc[i][14:0], e[i]};
                nb = nb + 1;
                if (nb == 16) begin
                    for (i = 0; i < NLANE; i = i + 1) begin
                        if (expect_zero_disp) begin
                            if (wacc[i] !== 16'h0) fail("blank_frame_not_zero");
                        end else if (wacc[i] !== fb[widx][16*i +: 16]) begin
                            $display("  px%0d lane%0d got %04x want %04x",
                                     widx, i, wacc[i], fb[widx][16*i +: 16]);
                            fail("pixel_mismatch");
                        end
                    end
                    nb   = 0;
                    widx = widx + 1;
                    if (widx == TOTAL_PIX) begin
                        dst = D_VCRC;
                        for (i = 0; i < NLANE; i = i + 1) wacc[i] = 16'h0;
                    end
                end
            end

            //---- 每 lane 的图像 CHKSUM: 16 位, 1 边/位 -----------------
            D_VCRC: begin
                for (i = 0; i < NLANE; i = i + 1)
                    wacc[i] = {wacc[i][14:0], e[i]};
                nb = nb + 1;
                if (nb == 16) begin
                    for (i = 0; i < NLANE; i = i + 1) begin
                        crc_calc = 16'hFFFF;
                        for (ci = 0; ci < TOTAL_PIX; ci = ci + 1) begin
                            for (cj = 15; cj >= 0; cj = cj - 1)
                                crc_calc = crc_step(crc_calc,
                                    expect_zero_disp ? 1'b0 : fb[ci][16*i + cj]);
                        end
                        if (wacc[i] !== crc_calc) begin
                            $display("  lane%0d video CRC got %04x want %04x",
                                     i, wacc[i], crc_calc);
                            fail("video_crc_mismatch");
                        end
                    end
                    dst = D_IDLE;  zeros = 0;  nb = 0;
                end
            end
            endcase
        end
    endtask

    // 每个时钟周期送两个边: 先 bit_r 后 bit_f
    always @(posedge clk) begin
        if (rst_n) begin
            push_edge(bit_r);
            push_edge(bit_f);
        end
    end

    // I_SYNC 每帧只翻一次
    always @(isync) if (rst_n) n_sync = n_sync + 1;

    //-------------------------------------------------------------------------
    // §12 上电: 头两条整表写要屏蔽 0x00[3] / 0x15[5]
    //-------------------------------------------------------------------------
    always @(n_cfg) begin
        if (n_cfg <= 2) begin
            exp_reg[8'h00] = u_seq.reg_rom[8'h00] & ~16'h0008;
            exp_reg[8'h15] = u_seq.reg_rom[8'h15] & ~16'h0020;
        end else begin
            exp_reg[8'h00] = u_seq.reg_rom[8'h00];
            exp_reg[8'h15] = u_seq.reg_rom[8'h15];
        end
    end

    integer wi;
    initial begin
        for (wi = 0; wi < 256; wi = wi + 1) exp_reg[wi] = 16'h0;
        $readmemh("icnd2260_regs_lvds.mem", exp_reg);
        exp_reg[8'h00] = exp_reg[8'h00] & ~16'h0008;
        exp_reg[8'h15] = exp_reg[8'h15] & ~16'h0020;

        // LVDS 版必须是 LVDS 表 (0x06[9]=1, 0x1a[9]=1)
        if (exp_reg[8'h06][9] !== 1'b1) fail("reg06_bit9_not_set_lvds");
        if (exp_reg[8'h1a][9] !== 1'b1) fail("reg1a_bit9_not_set_lvds");

        for (wi = 0; wi < TOTAL_PIX; wi = wi + 1)
            fb[wi] = {16'h1000 + wi[15:0], 16'h2000 + wi[15:0], 16'h3000 + wi[15:0]};

        zeros = IDLE_CLK;      // 复位后先当作已经空闲够久
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        wait (running);
        wait (frame_cnt >= BLANK_FRAMES + 2);
        repeat (400) @(posedge clk);

        if (!en_3v8 || !en_2v8)         fail("rails_not_enabled");
        if (n_cfg  < 3)                 fail("too_few_cfg_packets");
        if (n_disp < BLANK_FRAMES + 2)  fail("too_few_display_packets");
        if (n_sync < BLANK_FRAMES + 2)  fail("too_few_isync_toggles");

        $display("-----------------------------------------------------------");
        $display("CFG=%0d  DISPLAY=%0d  ISYNC_TOGGLE=%0d  frame_cnt=%0d",
                 n_cfg, n_disp, n_sync, frame_cnt);
        if (errors == 0) $display("*** PASS ***");
        else begin
            $display("*** FAIL: %0d mismatches ***", errors);
            $fatal(1);
        end
        $finish;
    end

    initial begin
        #500_000_000;
        $display("*** TIMEOUT ***");
        $fatal(1);
    end

endmodule

`default_nettype wire
