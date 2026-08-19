//-----------------------------------------------------------------------------
// icnd2260_tx.v
//-----------------------------------------------------------------------------
// ICND2260 TTL 模式指令发送器 (协议层 + 位串行化, 不含 IOB)
//
// 依据《ICND2260 编程指导 CN 2025 V2.8》§3.1 / §5:
//   * TTL 类 SPI: I_SYNC 拉低一次 = 一条指令, 拉高分隔相邻指令
//   * DCLK 双沿传输, 1 个沿 = 1 bit; 最小传输单位 16 bit, 先发第 16 位 (MSB)
//   * SDI_R1 走命令/寄存器/图像; SDI_G1/B1 只走图像
//   * 每条指令尾部 IDLE[127:0] 固定为 0, 期间时钟正常且 I_SYNC 保持低
//
// 本模块工作在 DCLK 频率的时钟域 (clk 一拍 = 一个 DCLK 周期 = 2 bit),
// 输出 bit_r / bit_f 分别是该周期上升沿、下降沿要送的位, 由外部 ODDR 拼成波形。
//
// 时序参数默认值取手册时序图的下限 (16 / 160 / 8 DCLK), 都可以调大不能调小。
//
// 复位一律用**同步**复位: 本模块的状态寄存器经 pl_next 扇进帧缓存 BRAM 的地址脚,
// 异步复位会被 Vivado 判 [REQP-1839] "RAMB36 async control check"。rst_n 本身是
// 顶层用 MMCM locked 在 clk 域里同步生成的, 同步复位安全。
//
// 载荷握手 (pl_*):
//   源端把「当前字」组合有效地摆在 pl_data 上, 同时用 pl_last 标注它是不是最后一个;
//   本模块在每 8 拍组的第 6 拍拉高 pl_next (⚠ 组合输出, 不是寄存器 —— 寄存一拍
//   就晚了, 同步读 RAM 来不及在第 7 拍把下一个字摆出来), 源端在该拍的时钟沿推进地址
//   ⇒ 第 7 拍 pl_data 已是下一个字, 第 7 拍末沿装载。
//   ⇒ 源端可以是「地址寄存器 + 同步读 RAM」这种一拍延迟的结构, 不用额外缓冲,
//      但送进 RAM 的地址要用 pl_next 做一拍前瞻 (见 icnd2260_seq 的 reg_addr_nx)。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_tx #(
    parameter integer NLANE     = 3,    // TTL 数据通道数: 1 / 3 / 6
    parameter integer LEAD_DCLK = 16,   // I_SYNC 拉低 -> 第一个数据位, 手册「不少于 16 DCLK」
    parameter integer IDLE_DCLK = 160,  // 尾部 IDLE (全 0, I_SYNC 仍低), 手册「不少于 160 DCLK」
    parameter integer GAP_DCLK  = 8     // 指令之间 I_SYNC 拉高, 手册「不少于 8 DCLK」
) (
    input  wire                    clk,        // = DCLK 频率
    input  wire                    rst_n,

    // ---- 指令口 ----------------------------------------------------------
    input  wire                    cmd_valid,
    output wire                    cmd_ready,
    input  wire [2:0]              cmd_kind,
    input  wire [3:0]              cmd_device,  // WRITE_DEV / READ_DEV 用
    input  wire [7:0]              cmd_offset,  // 寄存器起始地址
    input  wire [7:0]              cmd_length,  // 寄存器个数 - 1
    input  wire [7:0]              cmd_rows,    // VHEAD/CHEAD[31:24] 扫描行数 - 1
    input  wire [3:0]              cmd_cascade, // VHEAD/CHEAD[19:16] 级联芯片数 - 1

    // ---- 载荷口 ----------------------------------------------------------
    output wire                    pl_next,
    input  wire [16*NLANE-1:0]     pl_data,     // lane0 在低 16 位
    input  wire                    pl_last,

    // ---- 位输出 (交给 ODDR) ----------------------------------------------
    output reg  [NLANE-1:0]        bit_r,       // 上升沿这一位
    output reg  [NLANE-1:0]        bit_f,       // 下降沿这一位
    output reg                     isync,
    output wire                    busy
);

    // ---- 指令种类 --------------------------------------------------------
    localparam [2:0] KIND_VSYNC     = 3'd0;
    localparam [2:0] KIND_WRITE_ALL = 3'd1;
    localparam [2:0] KIND_WRITE_DEV = 3'd2;
    localparam [2:0] KIND_READ_DEV  = 3'd3;
    localparam [2:0] KIND_DISPLAY   = 3'd4;
    localparam [2:0] KIND_CORRECT   = 3'd5;

    localparam [23:0] RSYNC = 24'h000d55;
    localparam [3:0]  CMD_VSYNC     = 4'b0011;
    localparam [3:0]  CMD_WRITE_ALL = 4'b0101;
    localparam [3:0]  CMD_WRITE_DEV = 4'b0110;
    localparam [3:0]  CMD_READ_DEV  = 4'b1010;

    // ---- FSM -------------------------------------------------------------
    localparam [2:0] S_IDLE  = 3'd0,
                     S_LEAD  = 3'd1,
                     S_HDR   = 3'd2,
                     S_PAY   = 3'd3,
                     S_TRAIL = 3'd4,
                     S_GAP   = 3'd5;

    reg [2:0]  st;
    reg [47:0] hdr_sr;
    reg [5:0]  hdr_cnt;      // 剩余多少拍 (每拍 2 bit)
    reg [2:0]  bitcnt;       // 8 拍 = 一个 16 位字
    reg        pay_last_r;
    reg [2:0]  kind_r;

    reg [16*NLANE-1:0] pay_sr;

    reg [8:0] gcnt;          // LEAD / IDLE / GAP 通用计数器

    // 组合输出: 第 6 拍拉高一拍, 让源端在该沿推进地址 (同步读 RAM 正好赶上第 7 拍)
    assign pl_next = (st == S_PAY) && (bitcnt == 3'd6) && !pl_last;

    assign busy      = (st != S_IDLE);
    assign cmd_ready = (st == S_IDLE);

    // 头部长度: VSYNC 只有 32 bit, 其余都是 48 bit
    function [5:0] hdr_beats(input [2:0] k);
        hdr_beats = (k == KIND_VSYNC) ? 6'd16 : 6'd24;
    endfunction

    // 是否带载荷
    function has_payload(input [2:0] k);
        has_payload = (k == KIND_WRITE_ALL) || (k == KIND_WRITE_DEV) ||
                      (k == KIND_DISPLAY)   || (k == KIND_CORRECT);
    endfunction

    // 组头部 (左对齐到 bit47, VSYNC 低 16 位补 0 且不会被移出)
    function [47:0] make_hdr(input [2:0]  k,
                             input [3:0]  dev,
                             input [7:0]  off,
                             input [7:0]  len,
                             input [7:0]  rows,
                             input [3:0]  casc);
        reg [15:0] vh_hi;
        begin
            vh_hi = {rows, 4'h3, casc};   // VHEAD[31:16], [15:0] 与之相同
            case (k)
                KIND_VSYNC:     make_hdr = {RSYNC, CMD_VSYNC,     4'hF, 16'h0000};
                KIND_WRITE_ALL: make_hdr = {RSYNC, CMD_WRITE_ALL, 4'hF, off, len};
                KIND_WRITE_DEV: make_hdr = {RSYNC, CMD_WRITE_DEV, dev,  off, len};
                KIND_READ_DEV:  make_hdr = {RSYNC, CMD_READ_DEV,  dev,  off, len};
                KIND_DISPLAY:   make_hdr = {16'hA5A5, vh_hi, vh_hi};
                KIND_CORRECT:   make_hdr = {16'hC3C3, vh_hi, vh_hi};
                default:        make_hdr = 48'h0;
            endcase
        end
    endfunction

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            st         <= S_IDLE;
            isync      <= 1'b1;
            bit_r      <= {NLANE{1'b0}};
            bit_f      <= {NLANE{1'b0}};
            hdr_sr     <= 48'h0;
            hdr_cnt    <= 6'd0;
            bitcnt     <= 3'd0;
            gcnt       <= 9'd0;
            pay_sr     <= {16*NLANE{1'b0}};
            pay_last_r <= 1'b0;
            kind_r     <= 3'd0;
        end else begin
            bit_r   <= {NLANE{1'b0}};
            bit_f   <= {NLANE{1'b0}};

            case (st)
            // -----------------------------------------------------------
            S_IDLE: begin
                isync <= 1'b1;
                if (cmd_valid) begin
                    kind_r     <= cmd_kind;
                    hdr_sr     <= make_hdr(cmd_kind, cmd_device, cmd_offset,
                                           cmd_length, cmd_rows, cmd_cascade);
                    hdr_cnt    <= hdr_beats(cmd_kind);
                    pay_last_r <= 1'b0;
                    gcnt       <= LEAD_DCLK[8:0];
                    isync      <= 1'b0;          // 指令开始: I_SYNC 拉低
                    st         <= S_LEAD;
                end
            end

            // ---- I_SYNC 已低, 先空 LEAD_DCLK 拍 (Don't Care, 送 0) -------
            S_LEAD: begin
                if (gcnt <= 9'd1) begin
                    st <= S_HDR;
                end else begin
                    gcnt <= gcnt - 9'd1;
                end
            end

            // ---- 头部: 只走 lane0, 每拍 2 bit, MSB 先 --------------------
            S_HDR: begin
                bit_r[0] <= hdr_sr[47];
                bit_f[0] <= hdr_sr[46];
                hdr_sr   <= {hdr_sr[45:0], 2'b00};
                if (hdr_cnt <= 6'd1) begin
                    if (has_payload(kind_r)) begin
                        pay_sr <= pl_data;       // 源端已把第 0 个字摆好
                        bitcnt <= 3'd0;
                        st     <= S_PAY;
                    end else begin
                        gcnt <= IDLE_DCLK[8:0] + 9'd1;   // +1: 输出比状态晚一拍
                        st   <= S_TRAIL;
                    end
                end else begin
                    hdr_cnt <= hdr_cnt - 6'd1;
                end
            end

            // ---- 载荷: 每 8 拍 = 一个 16 位字 (每通道) --------------------
            S_PAY: begin
                for (i = 0; i < NLANE; i = i + 1) begin
                    bit_r[i] <= pay_sr[16*i + 15];
                    bit_f[i] <= pay_sr[16*i + 14];
                end
                for (i = 0; i < NLANE; i = i + 1) begin
                    pay_sr[16*i +: 16] <= {pay_sr[16*i +: 14], 2'b00};
                end

                // 第 6 拍: 记住「当前字是最后一个」; 不是的话 pl_next (组合) 已经在推地址
                if (bitcnt == 3'd6 && pl_last) pay_last_r <= 1'b1;

                if (bitcnt == 3'd7) begin
                    if (pay_last_r) begin
                        gcnt <= IDLE_DCLK[8:0] + 9'd1;   // +1: 输出比状态晚一拍
                        st   <= S_TRAIL;
                    end else begin
                        pay_sr <= pl_data;       // 此刻 pl_data 已是下一个字
                    end
                end

                bitcnt <= bitcnt + 3'd1;
            end

            // ---- 尾部 IDLE: 全 0, I_SYNC 仍低 ---------------------------
            S_TRAIL: begin
                if (gcnt <= 9'd1) begin
                    isync <= 1'b1;
                    gcnt  <= GAP_DCLK[8:0];
                    st    <= S_GAP;
                end else begin
                    gcnt <= gcnt - 9'd1;
                end
            end

            // ---- 指令间隔: I_SYNC 高 -----------------------------------
            S_GAP: begin
                if (gcnt <= 9'd1) st <= S_IDLE;
                else              gcnt <= gcnt - 9'd1;
            end

            default: st <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
