//-----------------------------------------------------------------------------
// icnd2260_seq.v
//-----------------------------------------------------------------------------
// ICND2260 上电流程 + 帧循环序列器 (TTL 模式)
//
// 依据《ICND2260 编程指导 V2.8》§12「上电配置建议」:
//   1. 发送两次完整寄存器, 其中 Reg0x00[3]=0, Reg0x15[5]=0
//   2. 发送 64 帧全 0 显示数据, 寄存器恢复为常规发送方式
//   3. 发送正常显示数据
// 以及 §3.1: 每帧由 VSYNC 指令开始, 两个 VSYNC 之间可发任意多组指令。
//
// 电源: 转接板 (zynq-lxb_2260_V0.1) 的两路 BL8032 的 EN 由 FPGA 控制,
//       各带 100k 下拉 ⇒ 复位态两路都是关的。本模块负责按序开、等稳、再开口说话。
//       ⚠ 上电顺序按「2.8V 先、3.8V 后」写, 依据是 2.8V 为 R 路、3.8V 为 G/B 路,
//       芯片 VDDD 从哪一路取还没有 LED 板图纸确认 —— 见 docs/00_board_and_protocol.md
//       的待确认项 Q1。要改顺序只动 POWER_2V8_FIRST。
//
// 载荷源三选一 (寄存器表 / 帧缓存 / 全 0), 都遵守 icnd2260_tx 的「地址提前一拍」约定。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_seq #(
    parameter integer NLANE           = 3,
    parameter integer REG_COUNT       = 238,      // 0x00..0xED, 见 tools/gen_reg_defaults.py
    parameter integer PIX_PER_LINE    = 40,       // 单颗 40 像素
    parameter integer LINES           = 48,       // 扫描行数
    parameter integer CASCADE         = 1,        // 级联颗数
    parameter integer BLANK_FRAMES    = 64,       // §12 第 2 步
    parameter integer REG_REFRESH_FR  = 64,       // 每多少帧重发一次整表 (手册建议定期刷新)
    // 每多少帧插一条「读寄存器」指令 (0 = 关)。回包走 ACK 引脚, 由 icnd2260_ack_rx 解。
    // 这是判断「芯片到底活没活」最硬的判据, 也是验证 CRC 推断对不对的唯一手段。
    parameter integer READ_PROBE_FR   = 16,
    parameter integer READ_PROBE_OFF  = 8'h00,   // 探哪个寄存器 (可被 dbg_probe_off 覆盖)
    parameter integer POWER_2V8_FIRST = 1,
    parameter integer RAIL_STAGGER    = 25_000,   // 两路 EN 之间的间隔 (clk 拍)
    parameter integer RAIL_SETTLE     = 500_000,  // 电源稳定等待 (clk 拍), 25MHz -> 20 ms
    parameter integer FB_AW           = 11,       // ceil(log2(PIX_PER_LINE*LINES*CASCADE))
    // TTL 用 icnd2260_regs.mem; mini-LVDS 用 icnd2260_regs_lvds.mem
    // (差别是 0x06[9] / 0x1a[9] 两个使能位, 见 tools/gen_reg_defaults.py)
    parameter          REG_MEM        = "icnd2260_regs.mem"
) (
    input  wire                    clk,
    input  wire                    rst_n,

    // ---- 电源与输出使能 --------------------------------------------------
    output reg                     en_3v8,
    output reg                     en_2v8,
    output reg                     out_en,       // 电源没稳之前不要往芯片脚上灌电平

    // ---- 帧缓存读口 (同步读, 一拍延迟) -----------------------------------
    output wire [FB_AW-1:0]        fb_addr,
    input  wire [16*NLANE-1:0]     fb_q,

    // ---- 接 icnd2260_tx --------------------------------------------------
    output reg                     cmd_valid,
    input  wire                    cmd_ready,
    output reg  [2:0]              cmd_kind,
    output wire [3:0]              cmd_device,
    output reg  [7:0]              cmd_offset,
    output reg  [7:0]              cmd_length,
    output wire [7:0]              cmd_rows,
    output wire [3:0]              cmd_cascade,
    input  wire                    pl_next,
    output wire [16*NLANE-1:0]     pl_data,
    output wire                    pl_last,
    input  wire                    tx_busy,

    // ---- 调试口 (不接就是 0, 行为与不带调试时完全一致) --------------------
    // 寄存器表做成可写: VIO/JTAG 把 (addr,data) poke 进来, **下一次整表刷新**
    // 就会带上新值 ⇒ 扫帧率参数 (0x00 分组数 / 0x01 Width_X / 倍率档) 不用重出 bit。
    input  wire                    dbg_reg_we,
    input  wire [7:0]              dbg_reg_addr,
    input  wire [15:0]             dbg_reg_data,
    input  wire                    dbg_probe_en,   // 1 = 用 dbg_probe_off 覆盖参数
    input  wire [7:0]              dbg_probe_off,

    // ---- 状态 -------------------------------------------------------------
    output wire                    running,      // 已进入正常显示
    output reg  [31:0]             frame_cnt,
    output wire [3:0]              dbg_ph,
    output wire [1:0]              dbg_sub
);

    localparam integer TOTAL_PIX = PIX_PER_LINE * LINES * CASCADE;

    localparam [2:0] KIND_VSYNC     = 3'd0;
    localparam [2:0] KIND_WRITE_ALL = 3'd1;
    localparam [2:0] KIND_READ_DEV  = 3'd3;
    localparam [2:0] KIND_DISPLAY   = 3'd4;

    localparam [1:0] SRC_REG = 2'd0, SRC_FB = 2'd1, SRC_ZERO = 2'd2;

    assign cmd_device  = 4'hF;
    assign cmd_rows    = LINES[7:0] - 8'd1;
    assign cmd_cascade = CASCADE[3:0] - 4'd1;

    // ---------------------------------------------------------------------
    // 寄存器默认值 ROM
    // ⚠ 同步读存储器的 q 比 addr 落后一拍。icnd2260_tx 在第 6 拍拉高 pl_next、
    //   第 7 拍就要拿到「下一个字」, 所以送进存储器的地址要用 pl_next 做一拍前瞻;
    //   reg_addr / pix_addr 本身仍在第 6 拍的沿更新, 好让 pl_last 与总线上的字对齐。
    // ---------------------------------------------------------------------
    // ⚠ 这里是 **RAM 不是 ROM**: $readmemh 给初值, dbg 口可以改。
    //   改完不会立刻生效, 要等下一条整表写 (每 REG_REFRESH_FR 帧一次) 才送进芯片。
    reg [15:0] reg_rom [0:255];
    initial $readmemh(REG_MEM, reg_rom);
    always @(posedge clk) if (dbg_reg_we) reg_rom[dbg_reg_addr] <= dbg_reg_data;

    reg [7:0]  reg_addr;
    reg [15:0] reg_q;
    reg        poweron_mask;      // §12 头两遍整表要屏蔽 0x00[3] / 0x15[5]

    wire [7:0]  reg_addr_nx = pl_next ? (reg_addr + 8'd1) : reg_addr;
    wire [15:0] reg_raw = reg_rom[reg_addr_nx];
    wire [15:0] reg_masked =
        (poweron_mask && reg_addr_nx == 8'h00) ? (reg_raw & ~16'h0008) :
        (poweron_mask && reg_addr_nx == 8'h15) ? (reg_raw & ~16'h0020) : reg_raw;

    always @(posedge clk) reg_q <= reg_masked;

    reg [FB_AW-1:0] pix_addr;
    assign fb_addr = pl_next ? (pix_addr + 1'b1) : pix_addr;

    reg [1:0] src;

    assign pl_data = (src == SRC_REG) ? {{(16*(NLANE-1)){1'b0}}, reg_q} :
                     (src == SRC_FB)  ? fb_q :
                                        {(16*NLANE){1'b0}};

    assign pl_last = (src == SRC_REG) ? (reg_addr == (REG_COUNT[7:0] - 8'd1))
                                      : (pix_addr == (TOTAL_PIX[FB_AW-1:0] - 1'b1));

    // ⚠ 地址寄存器用**同步**复位: 它们直接驱动 BRAM 的 ADDR 脚, 异步复位会被
    //   Vivado 判 [REQP-1839] "RAMB36 async control check" (复位撒手那一刻可能
    //   读出/写坏内容, 且不进静态时序分析)。跑过一次 report_drc, 20 条全是这个。
    always @(posedge clk) begin
        if (!rst_n) begin
            reg_addr <= 8'd0;
            pix_addr <= {FB_AW{1'b0}};
        end else if (pl_next) begin
            if (src == SRC_REG) reg_addr <= reg_addr + 8'd1;
            else                pix_addr <= pix_addr + 1'b1;
        end else if (!tx_busy && !cmd_valid) begin
            // 指令之间把地址归零, 保证下一条指令开头 pl_data 就位
            reg_addr <= 8'd0;
            pix_addr <= {FB_AW{1'b0}};
        end
    end

    // ---------------------------------------------------------------------
    // 主状态机
    //
    // 每条指令都走「issue -> P_WAIT -> 回到 ph_next / sub_next」这一条路径,
    // 帧内的三小步 (VSYNC / 整表写 / 显示) 由 sub 表示。
    // ⚠ 别把「命令结束后该去哪」的判断塞进 P_WAIT 里按 ph_next 猜 ——
    //   之前那版就是这么写的, 结果 §12 第一帧空屏漏掉了 VSYNC。
    // ---------------------------------------------------------------------
    localparam [3:0] P_RST    = 4'd0,
                     P_RAIL_A = 4'd1,
                     P_RAIL_B = 4'd2,
                     P_SETTLE = 4'd3,
                     P_REG_1  = 4'd4,   // §12 步骤 1, 第一遍
                     P_REG_2  = 4'd5,   // §12 步骤 1, 第二遍
                     P_BLANK  = 4'd6,   // §12 步骤 2
                     P_RUN    = 4'd7,
                     P_WAIT   = 4'd8;

    reg [3:0]  ph, ph_next;
    reg [1:0]  sub, sub_next;
    reg        frame_adv;              // 这条指令发完算走完一帧
    reg        clr_mask;               // 这条指令发完就恢复常规寄存器值
    reg [31:0] dly;
    reg [31:0] blank_cnt;
    reg [31:0] refresh_cnt;
    reg [31:0] probe_cnt;

    assign running = (ph == P_RUN) || ((ph == P_WAIT) && (ph_next == P_RUN));
    assign dbg_ph  = ph;
    assign dbg_sub = sub;

    task issue(input [2:0] k, input [1:0] s, input [3:0] nxt,
               input [1:0] nsub, input adv, input clrm);
        begin
            cmd_kind  <= k;
            src       <= s;
            cmd_valid <= 1'b1;
            ph        <= P_WAIT;
            ph_next   <= nxt;
            sub_next  <= nsub;
            frame_adv <= adv;
            clr_mask  <= clrm;
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            ph           <= P_RST;
            ph_next      <= P_RST;
            sub          <= 2'd0;
            sub_next     <= 2'd0;
            frame_adv    <= 1'b0;
            clr_mask     <= 1'b0;
            dly          <= 32'd0;
            blank_cnt    <= 32'd0;
            refresh_cnt  <= 32'd0;
            probe_cnt    <= 32'd0;
            frame_cnt    <= 32'd0;
            en_3v8       <= 1'b0;
            en_2v8       <= 1'b0;
            out_en       <= 1'b0;
            cmd_valid    <= 1'b0;
            cmd_kind     <= KIND_VSYNC;
            cmd_offset   <= 8'd0;
            cmd_length   <= 8'd0;
            src          <= SRC_ZERO;
            poweron_mask <= 1'b1;
        end else begin
            case (ph)
            // ---- 电源上电 -----------------------------------------------
            P_RST: begin
                if (POWER_2V8_FIRST != 0) en_2v8 <= 1'b1;
                else                      en_3v8 <= 1'b1;
                dly <= RAIL_STAGGER;
                ph  <= P_RAIL_A;
            end

            P_RAIL_A: begin
                if (dly == 0) begin
                    if (POWER_2V8_FIRST != 0) en_3v8 <= 1'b1;
                    else                      en_2v8 <= 1'b1;
                    dly <= RAIL_SETTLE;
                    ph  <= P_RAIL_B;
                end else dly <= dly - 32'd1;
            end

            P_RAIL_B: begin
                if (dly == 0) begin
                    out_en <= 1'b1;          // 电源稳了才开始发 DCLK / 数据
                    dly    <= RAIL_SETTLE;
                    ph     <= P_SETTLE;
                end else dly <= dly - 32'd1;
            end

            // 让 DCLK 空跑一段再发第一条指令 (芯片内部 PLL 以 DCLK 为参考)
            P_SETTLE: begin
                if (dly == 0) begin
                    cmd_offset <= 8'h00;
                    cmd_length <= REG_COUNT[7:0] - 8'd1;
                    ph         <= P_REG_1;
                end else dly <= dly - 32'd1;
            end

            // ---- §12 步骤 1: 屏蔽位的整表 ×2 -----------------------------
            P_REG_1: issue(KIND_WRITE_ALL, SRC_REG, P_REG_2, 2'd0, 1'b0, 1'b0);
            P_REG_2: issue(KIND_WRITE_ALL, SRC_REG, P_BLANK, 2'd0, 1'b0, 1'b1);

            // ---- §12 步骤 2: BLANK_FRAMES 帧全 0 -------------------------
            P_BLANK: begin
                case (sub)
                2'd0: issue(KIND_VSYNC,     SRC_ZERO, P_BLANK, 2'd1, 1'b0, 1'b0);
                2'd1: issue(KIND_WRITE_ALL, SRC_REG,  P_BLANK, 2'd2, 1'b0, 1'b0);
                default: begin
                    if (blank_cnt >= BLANK_FRAMES - 1)
                        issue(KIND_DISPLAY, SRC_ZERO, P_RUN,   2'd0, 1'b1, 1'b0);
                    else begin
                        issue(KIND_DISPLAY, SRC_ZERO, P_BLANK, 2'd0, 1'b1, 1'b0);
                        blank_cnt <= blank_cnt + 32'd1;
                    end
                end
                endcase
            end

            // ---- 正常显示: VSYNC -> [整表] -> [读探针] -> 显示 ------------
            P_RUN: begin
                case (sub)
                2'd0: begin
                    cmd_offset <= 8'h00;
                    cmd_length <= REG_COUNT[7:0] - 8'd1;
                    issue(KIND_VSYNC, SRC_ZERO, P_RUN, 2'd1, 1'b0, 1'b0);
                end
                2'd1: begin
                    if (refresh_cnt == 0)
                        issue(KIND_WRITE_ALL, SRC_REG, P_RUN, 2'd2, 1'b0, 1'b0);
                    else
                        sub <= 2'd2;              // 这帧不刷寄存器
                end
                2'd2: begin
                    if (READ_PROBE_FR != 0 && probe_cnt == 0) begin
                        // 读 1 个寄存器: OFFSET=READ_PROBE_OFF, LENGTH=0 (0 对应 1 个)
                        cmd_offset <= dbg_probe_en ? dbg_probe_off : READ_PROBE_OFF[7:0];
                        cmd_length <= 8'd0;
                        issue(KIND_READ_DEV, SRC_ZERO, P_RUN, 2'd3, 1'b0, 1'b0);
                    end else sub <= 2'd3;
                end
                default: issue(KIND_DISPLAY, SRC_FB, P_RUN, 2'd0, 1'b1, 1'b0);
                endcase
            end

            // ---- 等一条指令发完 ------------------------------------------
            P_WAIT: begin
                if (cmd_valid && cmd_ready) begin
                    cmd_valid <= 1'b0;            // 已被 tx 接走
                end else if (!cmd_valid && !tx_busy) begin
                    ph  <= ph_next;
                    sub <= sub_next;
                    if (clr_mask) poweron_mask <= 1'b0;
                    if (frame_adv) begin
                        frame_cnt   <= frame_cnt + 32'd1;
                        refresh_cnt <= (refresh_cnt >= REG_REFRESH_FR - 1)
                                       ? 32'd0 : (refresh_cnt + 32'd1);
                        if (READ_PROBE_FR != 0)
                            probe_cnt <= (probe_cnt >= READ_PROBE_FR - 1)
                                         ? 32'd0 : (probe_cnt + 32'd1);
                    end
                end
            end

            default: ph <= P_RST;
            endcase
        end
    end

endmodule

`default_nettype wire
