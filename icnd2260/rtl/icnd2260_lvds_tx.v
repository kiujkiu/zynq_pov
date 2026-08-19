//-----------------------------------------------------------------------------
// icnd2260_lvds_tx.v
//-----------------------------------------------------------------------------
// ICND2260 mini-LVDS 模式发送器 (协议层 + 位串行化, 不含 IOB)
//
// 依据《ICND2260 编程指导 CN 2025 V2.8》§3.2。⚠ 与 TTL 模式**不是同一套帧格**:
//
//   TTL:   每条指令用 I_SYNC 拉低做分隔; 时钟可停; 头 RSYNC=0x000d55; 无 CRC
//   LVDS:  双线协议(只有时钟和数据); **时钟不停**; **I_SYNC 每帧只翻转一次**
//          (VSYNC = I_SYNC 的上升沿或下降沿); 段间靠 IDLE(数据恒 0) 分隔;
//          RSYNC = 0xFFFF0F0F0F0F0F (56 bit); **每包尾部带 CHKSUM[15:0]**
//
//   一帧: IDLE(64) → RSYNC → Configuration → … → IDLE → VHEAD → Video Data
//                  → CHEAD → Correction Data → IDLE(64)
//
//   ⚠ 采样率分两档:
//     * RSYNC 段与 Configuration 段: **每 4 个时钟沿一位**(一位占 2 个时钟周期)
//     * VHEAD 段与 Video Data 段:     **每个时钟沿一位**
//   ⚠ Configuration 只走第一组差分对; 第一对还兼发 VHEAD 与 Video Data,
//     其余差分对只发 Video Data(不含 VHEAD)。
//
// CHKSUM: 手册第 13 页给的是一张 LFSR 图, 抄下来是
//         多项式 x^16 + x^12 + x^5 + 1 (=0x1021), 初值 0xFFFF, 高位先入,
//         不反射、末尾不取反 —— 即 CRC-16/CCITT-FALSE。
//   🔴 这是**从图形反推的**, 没有厂家书面确认。上板第一件事就是拿读寄存器的
//      ACK 回包对一次 CRC; 对不上先怀疑这里(反射? 末尾取反? 覆盖范围?)。
//      覆盖范围按手册原文: 配置包从 CMD[3:0] 算到 D_last; VHEAD[15:0] 算 VHEAD[31:16];
//      图像数据每颗芯片末尾一个 CHKSUM(VID_CRC 参数可关掉以便二分排查)。
//
// 本模块工作在**位时钟**域: 一拍 = 一个 mini-LVDS 时钟周期 = 2 个沿。
// 输出 bit_r/bit_f 交给外部 ODDR + OBUFDS。
//
// 指令口与 icnd2260_tx 保持一致 ⇒ icnd2260_seq 不用改就能驱动这个 PHY。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_lvds_tx #(
    parameter integer NLANE    = 3,     // mini-LVDS 数据对数: 1 / 2 / 3
    parameter integer IDLE_CLK = 64,    // 段间 IDLE 长度 (手册标注 64 mLVDS_CLOCK)
    parameter integer VID_CRC  = 1      // 1 = 每颗芯片图像数据后追加 CHKSUM
) (
    input  wire                    clk,          // = mini-LVDS 位时钟
    input  wire                    rst_n,

    // ---- 指令口 (与 icnd2260_tx 同形) -----------------------------------
    input  wire                    cmd_valid,
    output wire                    cmd_ready,
    input  wire [2:0]              cmd_kind,
    input  wire [3:0]              cmd_device,
    input  wire [7:0]              cmd_offset,
    input  wire [7:0]              cmd_length,
    input  wire [7:0]              cmd_rows,
    input  wire [3:0]              cmd_cascade,

    // ---- 载荷口 ----------------------------------------------------------
    output wire                    pl_next,
    input  wire [16*NLANE-1:0]     pl_data,
    input  wire                    pl_last,

    // ---- 位输出 -----------------------------------------------------------
    output reg  [NLANE-1:0]        bit_r,
    output reg  [NLANE-1:0]        bit_f,
    output reg                     isync,        // 每帧翻转一次
    output wire                    busy
);

    localparam [2:0] KIND_VSYNC     = 3'd0;
    localparam [2:0] KIND_WRITE_ALL = 3'd1;
    localparam [2:0] KIND_WRITE_DEV = 3'd2;
    localparam [2:0] KIND_READ_DEV  = 3'd3;
    localparam [2:0] KIND_DISPLAY   = 3'd4;
    localparam [2:0] KIND_CORRECT   = 3'd5;

    localparam [55:0] RSYNC_LVDS = 56'hFFFF0F0F0F0F0F;

    localparam [3:0] CMD_WRITE_ALL = 4'b0101;
    localparam [3:0] CMD_WRITE_DEV = 4'b0110;
    localparam [3:0] CMD_READ_DEV  = 4'b1010;

    // ---- CRC-16/CCITT (x^16+x^12+x^5+1), 高位先入 ------------------------
    function [15:0] crc_step(input [15:0] c, input b);
        reg fb;
        begin
            fb       = c[15] ^ b;
            crc_step = {c[14:0], 1'b0};
            if (fb) crc_step = crc_step ^ 16'h1021;
        end
    endfunction

    function [15:0] crc_of16(input [15:0] d);
        integer k;
        reg [15:0] c;
        begin
            c = 16'hFFFF;
            for (k = 15; k >= 0; k = k - 1) c = crc_step(c, d[k]);
            crc_of16 = c;
        end
    endfunction

    // ---- FSM -------------------------------------------------------------
    localparam [3:0] S_IDLE  = 4'd0,   // 等指令 (数据恒 0, 时钟照跑)
                     S_PRE   = 4'd1,   // 段前 IDLE
                     S_RSYNC = 4'd2,   // 56 bit, 4 沿/位
                     S_HDR4  = 4'd3,   // 配置包头 24 bit, 4 沿/位
                     S_PAY4  = 4'd4,   // 配置数据, 4 沿/位
                     S_CRC4  = 4'd5,   // 配置 CHKSUM 16 bit, 4 沿/位
                     S_VHEAD = 4'd6,   // 48 bit, 1 沿/位, 仅 lane0
                     S_VID   = 4'd7,   // 图像数据, 1 沿/位, 各 lane 并行
                     S_VCRC  = 4'd8,   // 每 lane 的图像 CHKSUM
                     S_POST  = 4'd9;   // 段后 IDLE

    reg [3:0]  st;
    reg [2:0]  kind_r;
    reg [55:0] sr;            // RSYNC / 配置包头 / VHEAD 的移位器 (lane0)
    reg [6:0]  nbits;
    reg        os_phase;      // 4 沿/位时的半拍相位
    reg [8:0]  gcnt;
    reg [15:0] crc;           // 配置包 CRC
    reg [15:0] crc_sr;        // 正在发的 CRC 移位器
    // ⚠ bitcnt 要 4 位: S_PAY4 是 **4 边/位**, 一个 16 位字要数满 16 个 bit;
    //   而 S_VID 是 1 边/位、一拍出 2 位, 8 拍就够。两处终值不同, 别共用 3 位计数器
    //   (踩过: 3 位计数器在 S_PAY4 里数到 8 就翻回去, 每个寄存器只发了一半)。
    reg [3:0]  bitcnt;
    reg        pay_last_r;
    reg [16*NLANE-1:0] pay_sr;

    reg [15:0] vcrc [0:NLANE-1];

    assign busy      = (st != S_IDLE);
    assign cmd_ready = (st == S_IDLE);

    // 载荷推进: 组合输出, 提前一拍 (与 icnd2260_tx 同约定)
    assign pl_next = (!pl_last) &&
                     (((st == S_VID)  && (bitcnt == 4'd6)) ||
                      ((st == S_PAY4) && (bitcnt == 4'd14) && os_phase));

    function [3:0] cmd_code(input [2:0] k);
        cmd_code = (k == KIND_WRITE_ALL) ? CMD_WRITE_ALL :
                   (k == KIND_WRITE_DEV) ? CMD_WRITE_DEV : CMD_READ_DEV;
    endfunction

    wire [15:0] vh_hi  = {cmd_rows, 4'h3, cmd_cascade};
    wire [15:0] vh_magic = (cmd_kind == KIND_CORRECT) ? 16'hC3C3 : 16'hA5A5;

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            st         <= S_IDLE;
            isync      <= 1'b0;
            bit_r      <= {NLANE{1'b0}};
            bit_f      <= {NLANE{1'b0}};
            sr         <= 56'h0;
            nbits      <= 7'd0;
            os_phase   <= 1'b0;
            gcnt       <= 9'd0;
            crc        <= 16'hFFFF;
            crc_sr     <= 16'hFFFF;
            bitcnt     <= 4'd0;
            pay_last_r <= 1'b0;
            pay_sr     <= {16*NLANE{1'b0}};
            kind_r     <= 3'd0;
            for (i = 0; i < NLANE; i = i + 1) vcrc[i] <= 16'hFFFF;
        end else begin
            bit_r <= {NLANE{1'b0}};
            bit_f <= {NLANE{1'b0}};

            case (st)
            // ---------------------------------------------------------
            S_IDLE: begin
                if (cmd_valid) begin
                    kind_r     <= cmd_kind;
                    gcnt       <= IDLE_CLK[8:0];
                    crc        <= 16'hFFFF;
                    os_phase   <= 1'b0;
                    bitcnt     <= 4'd0;
                    pay_last_r <= 1'b0;
                    for (i = 0; i < NLANE; i = i + 1) vcrc[i] <= 16'hFFFF;
                    if (cmd_kind == KIND_VSYNC) begin
                        isync <= ~isync;          // VSYNC = I_SYNC 翻转一次
                        st    <= S_POST;
                    end else if (cmd_kind == KIND_DISPLAY || cmd_kind == KIND_CORRECT) begin
                        // VHEAD 48 bit = 幻数 + [31:16] + 其 CRC, 左对齐进 sr
                        sr    <= {vh_magic, vh_hi, crc_of16(vh_hi), 8'h0};
                        nbits <= 7'd48;
                        st    <= S_PRE;
                    end else begin
                        sr    <= RSYNC_LVDS;
                        nbits <= 7'd56;
                        st    <= S_PRE;
                    end
                end
            end

            // ---- 段前 IDLE ------------------------------------------
            S_PRE: begin
                if (gcnt <= 9'd1) begin
                    st <= (kind_r == KIND_DISPLAY || kind_r == KIND_CORRECT)
                          ? S_VHEAD : S_RSYNC;
                end else gcnt <= gcnt - 9'd1;
            end

            // ---- RSYNC: 4 沿/位, 不进 CRC ---------------------------
            S_RSYNC: begin
                bit_r[0] <= sr[55];
                bit_f[0] <= sr[55];
                if (os_phase) begin
                    os_phase <= 1'b0;
                    sr       <= {sr[54:0], 1'b0};
                    if (nbits <= 7'd1) begin
                        sr     <= {cmd_code(kind_r), cmd_device, cmd_offset, cmd_length, 32'h0};
                        nbits  <= 7'd24;
                        st     <= S_HDR4;
                    end else nbits <= nbits - 7'd1;
                end else os_phase <= 1'b1;
            end

            // ---- 配置包头 CMD/DEVICE/OFFSET/LENGTH: 4 沿/位, 进 CRC --
            S_HDR4: begin
                bit_r[0] <= sr[55];
                bit_f[0] <= sr[55];
                if (os_phase) begin
                    os_phase <= 1'b0;
                    crc      <= crc_step(crc, sr[55]);
                    sr       <= {sr[54:0], 1'b0};
                    if (nbits <= 7'd1) begin
                        if (kind_r == KIND_READ_DEV) begin
                            crc_sr <= crc_step(crc, sr[55]);   // 读指令没有数据域
                            nbits  <= 7'd16;
                            st     <= S_CRC4;
                        end else begin
                            pay_sr     <= pl_data;
                            bitcnt     <= 4'd0;
                            pay_last_r <= 1'b0;
                            st         <= S_PAY4;
                        end
                    end else nbits <= nbits - 7'd1;
                end else os_phase <= 1'b1;
            end

            // ---- 配置数据: 4 沿/位, 仅 lane0, 进 CRC -----------------
            S_PAY4: begin
                bit_r[0] <= pay_sr[15];
                bit_f[0] <= pay_sr[15];
                if (os_phase) begin
                    os_phase <= 1'b0;
                    crc      <= crc_step(crc, pay_sr[15]);
                    pay_sr[15:0] <= {pay_sr[14:0], 1'b0};

                    if (bitcnt == 4'd14 && pl_last) pay_last_r <= 1'b1;

                    if (bitcnt == 4'd15) begin
                        if (pay_last_r) begin
                            crc_sr <= crc_step(crc, pay_sr[15]);
                            nbits  <= 7'd16;
                            st     <= S_CRC4;
                        end else begin
                            pay_sr <= pl_data;
                        end
                    end
                    bitcnt <= bitcnt + 4'd1;
                end else os_phase <= 1'b1;
            end

            // ---- 配置包 CHKSUM: 4 沿/位 ------------------------------
            S_CRC4: begin
                bit_r[0] <= crc_sr[15];
                bit_f[0] <= crc_sr[15];
                if (os_phase) begin
                    os_phase <= 1'b0;
                    crc_sr   <= {crc_sr[14:0], 1'b0};
                    if (nbits <= 7'd1) begin
                        gcnt <= IDLE_CLK[8:0];
                        st   <= S_POST;
                    end else nbits <= nbits - 7'd1;
                end else os_phase <= 1'b1;
            end

            // ---- VHEAD: 1 沿/位, 仅 lane0 ---------------------------
            S_VHEAD: begin
                bit_r[0] <= sr[55];
                bit_f[0] <= sr[54];
                sr       <= {sr[53:0], 2'b00};
                if (nbits <= 7'd2) begin
                    pay_sr     <= pl_data;
                    bitcnt     <= 4'd0;
                    pay_last_r <= 1'b0;
                    st         <= S_VID;
                end else nbits <= nbits - 7'd2;
            end

            // ---- 图像数据: 1 沿/位, 各 lane 并行 ---------------------
            S_VID: begin
                for (i = 0; i < NLANE; i = i + 1) begin
                    bit_r[i] <= pay_sr[16*i + 15];
                    bit_f[i] <= pay_sr[16*i + 14];
                    vcrc[i]  <= crc_step(crc_step(vcrc[i], pay_sr[16*i+15]),
                                                          pay_sr[16*i+14]);
                    pay_sr[16*i +: 16] <= {pay_sr[16*i +: 14], 2'b00};
                end

                if (bitcnt == 4'd6 && pl_last) pay_last_r <= 1'b1;
                if (bitcnt == 4'd7) begin
                    if (pay_last_r) begin
                        nbits <= 7'd16;
                        gcnt  <= IDLE_CLK[8:0];
                        st    <= (VID_CRC != 0) ? S_VCRC : S_POST;
                    end else pay_sr <= pl_data;
                end
                bitcnt <= (bitcnt == 4'd7) ? 4'd0 : (bitcnt + 4'd1);
            end

            // ---- 每 lane 的图像 CHKSUM: 1 沿/位 ----------------------
            S_VCRC: begin
                for (i = 0; i < NLANE; i = i + 1) begin
                    bit_r[i] <= vcrc[i][15];
                    bit_f[i] <= vcrc[i][14];
                    vcrc[i]  <= {vcrc[i][13:0], 2'b00};
                end
                if (nbits <= 7'd2) begin
                    gcnt <= IDLE_CLK[8:0];
                    st   <= S_POST;
                end else nbits <= nbits - 7'd2;
            end

            // ---- 段后 IDLE ------------------------------------------
            S_POST: begin
                if (gcnt <= 9'd1) st <= S_IDLE;
                else              gcnt <= gcnt - 9'd1;
            end

            default: st <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
