//-----------------------------------------------------------------------------
// icnd2260_lxb_lvds_top.v
//-----------------------------------------------------------------------------
// 鹿小班 (XC7Z020-CLG484) + 转接板 zynq-lxb_2260_V0.1 —— **mini-LVDS** 首次点亮顶层
//
// 与 TTL 版 (icnd2260_lxb_top.v) 的四个实质差别, 每条都能单独把屏搞黑:
//
//  1. 🔴 **BANK 33 的 VCCO 必须是 2.5V**, 否则 7 系列 HR bank 出不了 LVDS_25。
//     鹿小班上 BANK 33 是唯一挂在 VCCIO_ADJ 上的 bank (34/35/13/0 都固定 3V3),
//     改法见 docs/02_lvds_bringup.md: U6 反馈电阻 R13 33K → 22.6K (1%)。
//     ⇒ 同 bank 的 DCLK/SYNC/ACK/EN 也一并变成 LVCMOS25 (XDC 里已经改好)。
//
//  2. 🔴 **转发时钟要 90° 移相**。mini-LVDS 的 tSTU/tHLD = 1/4 tLVCP ⇒ 数据必须在
//     时钟沿前后各留 1/4 周期 ⇒ 时钟沿落在**位中间**。而 TTL 那版是边沿对齐
//     (位横跨上升沿→下降沿)。两者要求相反, 别照抄。
//     打不出来的备选: 芯片自己有采样相位调整 (1/8, 1/4, 3/8 tLVCP, ±0.7ns)。
//
//  3. 🔴 **第一通道不是 R 是 B**。手册 §3 传输模式表「寄存器配置」列:
//     TTL 走 SDI_R1, mini-LVDS 一律走 D0IP/N —— 而 D0 = SDI_B1 (球 F1/F2) = B 对。
//     第一通道除了发配置还独家发 VHEAD ⇒ 它必须是 tx 的 lane0。
//     ⇒ 帧缓存字序换成 {R,G,B} (低 16 位 = B), 用 gen_test_pattern.py --iface lvds 生成。
//     搞反了不报错, 只是红蓝对调。
//
//  4. 🔴 **寄存器表用供应商那份** icnd2260_regs_vendor.mem (由 2260lvds.xlsx 导入,
//     是他们实测点亮本样板的配置)。它证实了我们对 0x06[9]=1/0x1a[9]=1 的推断,
//     但另有 46 处差异是我们从手册推不出来的。参数 REG_MEM 可切回自推的对照版。
//
// 转接板上四对差分在连接器处各跨接了 100Ω (R7~R10)。⚠ 若 LED 板在 BGA 附近**也**有
// 100Ω 端接, 就是双重端接, Vod 减半 —— 上板前要确认, 见 docs/02_lvds_bringup.md。
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module icnd2260_lxb_lvds_top #(
    parameter integer NLANE   = 3,
    parameter integer PIX     = 40,
    // 供应商样板实测: 9 颗级联, 每颗 40 像素 x 45 扫描行 (2026-08-20 用户确认)
    parameter integer LINES   = 45,
    parameter integer CASCADE = 9,
    // 位时钟 = 1000 MHz / CLK_DIV。24→41.7MHz  12→83.3MHz  6→166.7MHz(手册上限)
    // 首光建议从 24 起步, 通了再往上推。每对速率 = 位时钟 × 2 (双沿)。
    parameter integer CLK_DIV = 24,
    // 转发时钟相对数据的相移。90 = 时钟沿落在位中间 (mini-LVDS tSTU/tHLD=1/4 tLVCP 的要求)。
    // 打不出来时的第一个备选是 270 (等效反相), 见 docs/03_branches.md 的 phase270 变体。
    // 🔴 转发时钟相对数据的相移(度)。90 = 位中间(我们从 tSTU/tHLD=1/4tLVCP 推的);
    //    但 2026-09-01 从供应商抓包实测他们用的是 **~28°**(基本边沿对齐), 差 62°。
    //    手册 DS P.09 注1 明写驱动端延时可设 1/8 / 1/4 / 3/8 tLVCP ⇒ 这是自由度不是唯一解。
    //    用整数 generic 是因为 Vivado 的 -generic 对 real 不保证。
    //    单位是 **1/8 度**: MMCM 的相位分辨率是 45/CLKOUT_DIVIDE 度,
    //    DIVIDE=32 时 = 1.40625 度, 整数度数里只有 45 的倍数在格点上。
    parameter integer CLK_PHASE_X8 = 720,   // 720/8 = 90 度
    parameter integer BLANK_FRAMES = 64,
    parameter integer FRAME_GAP    = 0,   // 帧间空闲(位时钟拍数), 见 seq.v
    parameter integer VID_CRC = 1,
    // 1 = 例化 VIO 调试核 (JTAG 直连, 不需要 PS/Linux)。DEBUG=0 时下面的 generate
    // 完全不展开 ⇒ 与不带调试的已验证版本逐门相同。用 synth_design -generic DEBUG=1 打开。
    // 🔴 寄存器表。默认用**供应商实测能点亮本样板**的那份 (2260lvds.xlsx 导入)。
    //    icnd2260_regs_lvds.mem 是我们从手册 §11(TTL 默认值) + §3 传输模式表反推的,
    //    只对了 0x06[9]/0x1a[9] 两位, 另有 46 处电流/时序/扫描参数无从推断 —— 留作对照。
    parameter          REG_MEM = "icnd2260_regs_vendor.mem",
    parameter integer DEBUG = 0
) (
    input  wire clk50,        // M19  PL_CLK_50M

    // mini-LVDS: 时钟对 + 3 数据对
    output wire clk_p, clk_n, // AA21/AB21  L_CKIP/L_CKIN
    output wire b_p,   b_n,   // AA22/AB22  D0 = SDI_B1  <-- lane0, 兼发配置与 VHEAD
    output wire g_p,   g_n,   // Y20 /Y21   D1 = SDI_G1
    output wire r_p,   r_n,   // V22 /W22   D2 = SDI_R1

    // 单端控制
    output wire sync,         // AA18 I_SYNC, LVDS 模式下每帧翻转一次
    input  wire ack,          // AB15 ACK_O
    output wire dclk,         // AA13 TTL 时钟, LVDS 模式不用 -> 恒 0

    output wire en_3v8,       // V14
    output wire en_2v8,       // V15

    output wire [1:0] led     // P20 / P21
                              //   LED1: 常亮=没进正常显示, 闪=帧循环在跑
                              //   LED2: 亮=收到过 CRC 正确的 ACK 回包 (芯片确认活着)
);

    localparam integer TOTAL_PIX = PIX * LINES * CASCADE;
    localparam integer BITCLK_HZ = 1_000_000_000 / CLK_DIV;
    // ⚠ 旧版这里写死成 (TOTAL_PIX<=2048)?11:12, 只够 1 颗 40x48(1920 字);
    //   换成 9 颗 40x45(16200 字) 时 12 位根本不够 ⇒ 地址回绕、图像乱。用 clog2 算。
    function integer clog2(input integer v);
        integer i;
        begin
            clog2 = 0;
            for (i = v - 1; i > 0; i = i >> 1) clog2 = clog2 + 1;
        end
    endfunction
    localparam integer FB_AW     = clog2(TOTAL_PIX);
    localparam real    CLK_PHASE = CLK_PHASE_X8 / 8.0;

    // ---------------------------------------------------------------------
    // 时钟: 50 MHz -> VCO 1000 MHz -> 位时钟 (0° 给数据, 90° 给转发时钟)
    // ---------------------------------------------------------------------
    wire clkfb, clkfb_buf;
    wire clkbit_raw, clkbit90_raw;
    wire clkbit, clkbit90;
    wire mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH        ("OPTIMIZED"),
        .CLKIN1_PERIOD    (20.000),        // 50 MHz
        .CLKFBOUT_MULT_F  (20.000),        // VCO = 1000 MHz
        .DIVCLK_DIVIDE    (1),
        .CLKOUT0_DIVIDE_F (CLK_DIV),       // 数据用, 0°
        .CLKOUT1_DIVIDE   (CLK_DIV),       // 转发时钟用, 90°
        .CLKOUT1_PHASE    (CLK_PHASE),
        .STARTUP_WAIT     ("FALSE")
    ) u_mmcm (
        .CLKIN1   (clk50),
        .CLKFBIN  (clkfb_buf),
        .CLKFBOUT (clkfb),
        .CLKOUT0  (clkbit_raw),
        .CLKOUT1  (clkbit90_raw),
        .CLKOUT2  (), .CLKOUT3 (), .CLKOUT4 (), .CLKOUT5 (), .CLKOUT6 (),
        .CLKOUT0B (), .CLKOUT1B (), .CLKOUT2B (), .CLKOUT3B (), .CLKFBOUTB (),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    BUFG u_bufg_fb (.I(clkfb),        .O(clkfb_buf));
    BUFG u_bufg_0  (.I(clkbit_raw),   .O(clkbit));
    BUFG u_bufg_90 (.I(clkbit90_raw), .O(clkbit90));

    reg [7:0] por_cnt = 8'd0;
    reg       rst_n   = 1'b0;
    always @(posedge clkbit) begin
        if (!mmcm_locked) begin
            por_cnt <= 8'd0;
            rst_n   <= 1'b0;
        end else if (!por_cnt[7]) por_cnt <= por_cnt + 8'd1;
        else                      rst_n   <= 1'b1;
    end

    // ---------------------------------------------------------------------
    // 帧缓存: 字序 {R,G,B}, 低 16 位 = B = lane0 = D0
    // ---------------------------------------------------------------------
    wire [FB_AW-1:0]     fb_addr;
    reg  [16*NLANE-1:0]  fb_rom_q;
    (* ram_style = "block" *) reg [16*NLANE-1:0] fb [0:TOTAL_PIX-1];

    initial $readmemh("icnd2260_fb_lvds.mem", fb);
    always @(posedge clkbit) fb_rom_q <= fb[fb_addr];

    // ---- 运行时图案发生器 (点屏流程用, 切图案不用重编) --------------------
    //   dbg_pat_mode: 0=ROM(.mem 里的图)  1=三色循环  2=纯红 3=纯绿 4=纯蓝
    //                 5=全白  6=全灭
    //   dbg_pat_lvl : 亮度 (16 bit 线上灰度)。⚠ 首光阶段别拉满, 整屏全亮很费电也很烫。
    //   字序 {R,G,B}, 低 16 位 = B = lane0 = D0。
    reg [1:0]  pat_cix = 2'd0;      // 三色循环的当前颜色
    reg        fdiv_d  = 1'b0;
    always @(posedge clkbit) begin
        fdiv_d <= frame_cnt[7];                       // 160fps 下约 0.8 s 换一次
        if (frame_cnt[7] & ~fdiv_d)
            pat_cix <= (pat_cix == 2'd2) ? 2'd0 : pat_cix + 2'd1;
    end
    wire [2:0]  cyc_rgb = (pat_cix == 2'd0) ? 3'b100 :   // R
                          (pat_cix == 2'd1) ? 3'b010 :   // G
                                              3'b001;    // B
    wire [2:0] sel_rgb = (dbg_pat_mode == 3'd1) ? cyc_rgb :
                         (dbg_pat_mode == 3'd2) ? 3'b100 :
                         (dbg_pat_mode == 3'd3) ? 3'b010 :
                         (dbg_pat_mode == 3'd4) ? 3'b001 :
                         (dbg_pat_mode == 3'd5) ? 3'b111 : 3'b000;
    // ⚠ 字序 {B,G,R}: 低 16 位 = R = lane0 (2026-09-01 首光实测, 不是引脚名推的 B)
    wire [16*NLANE-1:0] pat_q = {sel_rgb[0] ? dbg_pat_lvl : 16'h0,   // B
                                 sel_rgb[1] ? dbg_pat_lvl : 16'h0,   // G
                                 sel_rgb[2] ? dbg_pat_lvl : 16'h0};  // R
    wire [16*NLANE-1:0] fb_q = (dbg_pat_mode == 3'd0) ? fb_rom_q : pat_q;

    // ---------------------------------------------------------------------
    // 序列器 (与 TTL 版共用) + LVDS 发送器
    // ---------------------------------------------------------------------
    wire                 cmd_valid, cmd_ready, tx_busy;
    wire [2:0]           cmd_kind;
    wire [3:0]           cmd_device, cmd_cascade;
    wire [7:0]           cmd_offset, cmd_length, cmd_rows;
    wire                 pl_next, pl_last;
    wire [16*NLANE-1:0]  pl_data;
    wire                 out_en, running;
    wire [31:0]          frame_cnt;
    wire [NLANE-1:0]     bit_r, bit_f;
    wire                 isync;

    // ---- 调试口 ---------------------------------------------------------
    wire        dbg_reg_we;
    wire [7:0]  dbg_reg_addr;
    wire [15:0] dbg_reg_data;
    wire        dbg_probe_en;
    wire [7:0]  dbg_probe_off;
    wire [3:0]  dbg_probe_dev;
    wire        dbg_minimal;
    wire        dbg_dclk_lvl;
    wire [3:0]  dbg_pn_inv;    // [2:0]=三条数据 lane, [3]=转发时钟
    wire        dbg_crc_refl;  // CHKSUM: 1=手册 LFSR(0x8408 反射)  0=旧的 CCITT-FALSE
    wire        dbg_crc_lsb;   // CHKSUM 域: 1=LSB 先发  0=MSB 先发
    wire        dbg_vhead_copy;// VHEAD[15:0]: 1=填 VHEAD[31:16] 拷贝(p.12)  0=填校验和(p.14)
    wire [2:0]  dbg_pat_mode;  // 图案: 0=ROM 1=三色循环 2=R 3=G 4=B 5=白 6=灭
    wire [15:0] dbg_pat_lvl;   // 图案亮度
    wire [23:0] dbg_frame_gap; // 帧间空闲(拍), 在线调帧率
    wire        dbg_ck_free;   // 1=转发时钟从电源使能就自由跑(手册 3.2「时钟不停」)
                               // 0=等 out_en(现状, 中间有 25.2ms 完全无时钟)
    wire        seq_quiet;
    wire        dbg_soft_rst;
    wire [3:0]  dbg_ph;
    wire [1:0]  dbg_sub;

    wire rst_n_eff = rst_n & ~dbg_soft_rst;   // VIO 可以重跑整个上电流程(含电源 EN)

    icnd2260_seq #(
        .NLANE        (NLANE),
        .PIX_PER_LINE (PIX),
        .LINES        (LINES),
        .CASCADE      (CASCADE),
        .BLANK_FRAMES (BLANK_FRAMES),
        .FRAME_GAP    (FRAME_GAP),
        .FB_AW        (FB_AW),
        .REG_MEM      (REG_MEM)
    ) u_seq (
        .clk (clkbit), .rst_n (rst_n_eff),
        .en_3v8 (en_3v8), .en_2v8 (en_2v8), .out_en (out_en),
        .fb_addr (fb_addr), .fb_q (fb_q),
        .cmd_valid (cmd_valid), .cmd_ready (cmd_ready), .cmd_kind (cmd_kind),
        .cmd_device (cmd_device), .cmd_offset (cmd_offset),
        .cmd_length (cmd_length), .cmd_rows (cmd_rows), .cmd_cascade (cmd_cascade),
        .pl_next (pl_next), .pl_data (pl_data), .pl_last (pl_last),
        .tx_busy (tx_busy), .running (running), .frame_cnt (frame_cnt),
        .dbg_reg_we (dbg_reg_we), .dbg_reg_addr (dbg_reg_addr),
        .dbg_reg_data (dbg_reg_data),
        .dbg_probe_en (dbg_probe_en), .dbg_probe_off (dbg_probe_off),
        .dbg_probe_dev (dbg_probe_dev), .dbg_minimal (dbg_minimal),
        .dbg_frame_gap (dbg_frame_gap),
        .quiet (seq_quiet),
        .dbg_ph (dbg_ph), .dbg_sub (dbg_sub)
    );

    icnd2260_lvds_tx #(.NLANE (NLANE), .VID_CRC (VID_CRC),
                      .WORDS_PER_CHIP (PIX * LINES)) u_tx (
        .clk (clkbit), .rst_n (rst_n_eff),
        .cmd_valid (cmd_valid), .cmd_ready (cmd_ready), .cmd_kind (cmd_kind),
        .cmd_device (cmd_device), .cmd_offset (cmd_offset),
        .cmd_length (cmd_length), .cmd_rows (cmd_rows), .cmd_cascade (cmd_cascade),
        .pl_next (pl_next), .pl_data (pl_data), .pl_last (pl_last),
        .crc_refl (dbg_crc_refl), .crc_lsb_tx (dbg_crc_lsb), .vhead_copy (dbg_vhead_copy),
        .bit_r (bit_r), .bit_f (bit_f), .isync (isync), .busy (tx_busy)
    );

    // ---------------------------------------------------------------------
    // IOB: 每对 = 一个 ODDR + 一个 OBUFDS
    // (OBUFDS 本身就是差分缓冲, 一个 ODDR 驱动它是合法的 —— TTL 版那个
    //  "一个 ODDR 扇出两个 port" 的 OLOGIC 限制在这里不存在)
    // ---------------------------------------------------------------------
    // 🔴 差分对 P/N 对调 == 数据取反: 接收端看的是 (P-N), 屏侧若把两根接反
    //    就是 -(P-N)。所以极性能做成**运行时**开关(dbg_pn_inv), 不必每种组合编一次 bit。
    //    取反放在 out_en 掩码**之后** —— 物理上接反的那一对, 连静默电平也是反的。
    //    ⚠ 改极性后必须 soft_rst 重跑上电流程, 否则芯片没机会用新极性重收一遍配置。
    wire [NLANE-1:0] d_r = (bit_r & {NLANE{out_en}}) ^ dbg_pn_inv[NLANE-1:0];
    wire [NLANE-1:0] d_f = (bit_f & {NLANE{out_en}}) ^ dbg_pn_inv[NLANE-1:0];
    wire [NLANE-1:0] lane_q;

    genvar gi;
    generate
        for (gi = 0; gi < NLANE; gi = gi + 1) begin : g_lane
            ODDR #(.DDR_CLK_EDGE ("SAME_EDGE"), .INIT (1'b0), .SRTYPE ("SYNC"))
            u_oddr (.Q (lane_q[gi]), .C (clkbit), .CE (1'b1),
                    .D1 (d_r[gi]), .D2 (d_f[gi]), .R (1'b0), .S (1'b0));
        end
    endgenerate

    OBUFDS u_obuf_d0 (.I (lane_q[0]), .O (b_p), .OB (b_n));   // lane0 = D0 = B
    OBUFDS u_obuf_d1 (.I (lane_q[1]), .O (g_p), .OB (g_n));   // lane1 = D1 = G
    OBUFDS u_obuf_d2 (.I (lane_q[2]), .O (r_p), .OB (r_n));   // lane2 = D2 = R

    // 转发时钟: 90° 相移 (见文件头第 2 条)
    wire clkfwd;
    // 🔴 u_oddr_ck 用 clkbit90 打, 而 out_en / en_2v8 / en_3v8 / dbg_pn_inv 都是
    //    clkbit 域(或 VIO 异步)。90° 相位差只给 T/4 的时间 —— 100MHz 下只剩 2.5ns,
    //    2026-09-01 实测就是这条路径把 div10 卡在 WNS -0.598, **不是源同步接口的问题**。
    //    这几个都是准静态信号(上电时变一次), 在 clkbit90 域再打一拍即可。
    reg ck_rst_q  = 1'b1;
    reg ck_inv_q  = 1'b0;
    always @(posedge clkbit90) begin
        ck_rst_q <= dbg_ck_free ? ~(en_2v8 | en_3v8) : ~out_en;
        ck_inv_q <= dbg_pn_inv[3];
    end

    ODDR #(.DDR_CLK_EDGE ("SAME_EDGE"), .INIT (1'b0), .SRTYPE ("SYNC"))
    u_oddr_ck (.Q (clkfwd), .C (clkbit90), .CE (1'b1),
               // dbg_pn_inv[3]=1 ⇒ 时钟对 P/N 对调(= 180° 相移)。
               // ⚠ xdc:68 的 create_generated_clock 没有 -invert ⇒ 这一位置 1 时
               //    时序报告描述的不再是硅上的真实关系, 只作首光实验用。
               .D1 (~ck_inv_q), .D2 (ck_inv_q),
               .R (ck_rst_q), .S (1'b0));
    OBUFDS u_obuf_ck (.I (clkfwd), .O (clk_p), .OB (clk_n));

    // 单端: I_SYNC 落 IOB 寄存器; DCLK 在 LVDS 模式不用, 恒 0
    (* IOB = "TRUE" *) reg sync_q;
    always @(posedge clkbit) sync_q <= out_en ? isync : 1'b0;
    assign sync = sync_q;
    // DCLK 在 mini-LVDS 模式下手册说用不到, 但**不能排除它是模式/使能 strap**:
    // 这块供应商样板把它引到了连接器(而我们自己那块面板是直接接地的) ⇒ 接地并非唯一选择。
    // ⇒ 电平做成 VIO 可调, 且**从电源刚使能那一刻就驱动到位** ——
    //    若芯片是在自己上电时锁存这个脚, 等 out_en 才驱动就太晚了。
    assign dclk = (en_2v8 | en_3v8) ? dbg_dclk_lvl : 1'b0;

    // ---------------------------------------------------------------------
    reg [26:0] hb = 27'd0;
    always @(posedge clkbit) hb <= hb + 27'd1;

    // ---- ACK 回传解调 ---------------------------------------------------
    // 序列器每 READ_PROBE_FR 帧发一条读寄存器指令, 回包从这里解出来。
    // crc_ok 一旦为真, 就同时坐实了三件事: 芯片活着 / 收到了我们的指令 /
    // CRC 那套推断是对的。这是首光阶段最硬的判据 —— 比"屏亮没亮"硬得多,
    // 因为屏不亮还可能是电流、灰度、LED 板的问题。
    wire        ack_frame_valid, ack_frame_ok, ack_crc_ok, ack_frame_err;
    wire        ack_crc_pulse, ack_crc_bad;
    wire [3:0]  ack_f_ack, ack_f_dev;
    wire [7:0]  ack_f_off, ack_f_len;
    wire [15:0] ack_f_data0, ack_f_crc_rx, ack_f_crc_calc;
    wire [8:0]  ack_f_nbits;

    icnd2260_ack_rx #(.CLK_HZ (BITCLK_HZ), .MAX_WORDS (4)) u_ack (
        .clk (clkbit), .rst_n (rst_n_eff), .ack_pin (ack), .crc_refl (dbg_crc_refl),
        .frame_valid (ack_frame_valid), .frame_ok (ack_frame_ok), .crc_ok (ack_crc_ok), .crc_ok_pulse (ack_crc_pulse),
        .crc_bad_pulse (ack_crc_bad),
        .frame_err (ack_frame_err),
        .f_ack (ack_f_ack), .f_dev (ack_f_dev), .f_off (ack_f_off),
        .f_len (ack_f_len), .f_data0 (ack_f_data0),
        .f_crc_rx (ack_f_crc_rx), .f_crc_calc (ack_f_crc_calc),
        .f_nbits (ack_f_nbits), .busy ()
    );

    // ---- 硬件测帧率: 1 秒窗口锁存 -------------------------------------
    // 位时钟频率是精确已知的 (MMCM 从 50MHz 晶振分出来), 所以直接在片内数
    // 「一秒内发了多少帧」比在 GUI 里拿秒表读两次 frame_cnt 相减靠谱得多。
    // 读 probe_in7 就是 fps, 不用换算。
    reg [31:0] sec_cnt     = 32'd0;
    reg [31:0] frame_mark  = 32'd0;
    reg [31:0] fps_latched = 32'd0;
    always @(posedge clkbit) begin
        if (!rst_n_eff) begin
            sec_cnt     <= 32'd0;
            frame_mark  <= 32'd0;
            fps_latched <= 32'd0;
        end else if (sec_cnt >= BITCLK_HZ - 1) begin
            sec_cnt     <= 32'd0;
            fps_latched <= frame_cnt - frame_mark;
            frame_mark  <= frame_cnt;
        end else begin
            sec_cnt <= sec_cnt + 32'd1;
        end
    end

    reg ack_ok_sticky = 1'b0;
    reg [15:0] ack_frame_cnt = 16'd0;
    reg [15:0] ack_err_cnt   = 16'd0;
    reg        ack_err_d     = 1'b0;
    always @(posedge clkbit) begin
        if (!rst_n_eff) begin
            ack_ok_sticky <= 1'b0;
            ack_frame_cnt <= 16'd0;
            ack_err_cnt   <= 16'd0;
            ack_err_d     <= 1'b0;
        end else begin
            if (ack_crc_ok)      ack_ok_sticky <= 1'b1;
            // 🔴 只数 **CRC 通过** 的帧。原来数的是"头部码合理"(ACK[3:0]==0b0010),
            //    实测挡不住周期性噪声 —— TTL 模式下 DCLK(J1.21) 串到相邻的 ACK(J1.22),
            //    解出来的垃圾帧能稳定凑出那 4 位, 每秒 5 万帧全部"合格"。
            //    CRC 那道闸是可靠的: 同一批数据里 crc_ok 从未置位过。
            if (ack_crc_pulse)   ack_frame_cnt <= ack_frame_cnt + 16'd1;
            // ⚠ frame_err 是**电平**不是脉冲(它在解调器的 A_IDLE 才清),
            //   直接 if(level) 会在电平持续期间每拍加一次, 数出来的值没有意义。
            //   这里取上升沿, 一次错误只记一次。
            ack_err_d <= ack_frame_err;
            if (ack_crc_bad || (ack_frame_err && !ack_err_d)) ack_err_cnt <= ack_err_cnt + 16'd1;
        end
    end

    // ---------------------------------------------------------------------
    // 调试核 (DEBUG=1 才展开)
    //
    // 为什么是 VIO 而不是别的: 这块板上 PL 侧没有 UART/以太网 (都在 PS 上),
    // 纯 PL 设计对外只有 JTAG 一条路。VIO 走 BSCANE2, 不碰 PS, 不用 Linux,
    // 在 Vivado Hardware Manager 里就能实时读写。
    //
    // 能干的事:
    //   * 读: frame_cnt(实际跑了多少帧) / ACK 回包的全部字段 / 状态机在哪一步
    //   * 写: 任意 poke 一个 2260 寄存器 —— **扫帧率参数不用重出 bit**
    //         (0x00[14:8] 分组数, 0x01[12:0] Width_X, 0x00[5:4] 倍率档)
    //         poke 完等下一次整表刷新 (REG_REFRESH_FR 帧) 才生效
    //   * 改读探针地址; 软复位重跑整个上电流程 (含电源 EN 关再开)
    // ---------------------------------------------------------------------
    generate
    if (DEBUG != 0) begin : g_dbg
        wire [7:0]  o_addr;
        wire [15:0] o_data;
        wire [0:0]  o_we_tog, o_probe_en, o_soft_rst, o_minimal, o_dclk_lvl;
        wire [3:0]  o_pn_inv;
        wire [3:0]  o_crc_mode;   // [0]refl [1]lsb_tx [2]vhead_copy [3]ck_free
        wire [2:0]  o_pat_mode;
        wire [15:0] o_pat_lvl;
        wire [23:0] o_frame_gap;
        wire [7:0]  o_probe_off;
        wire [3:0]  o_probe_dev;

        // VIO 的输出是电平, 用「变化沿」当写脉冲: 在 GUI 里把这一位一翻就写一次
        reg we_tog_d = 1'b0;
        always @(posedge clkbit) we_tog_d <= o_we_tog[0];
        assign dbg_reg_we    = (o_we_tog[0] != we_tog_d);
        assign dbg_reg_addr  = o_addr;
        assign dbg_reg_data  = o_data;
        assign dbg_probe_en  = o_probe_en[0];
        assign dbg_probe_off = o_probe_off;
        assign dbg_probe_dev = o_probe_dev;
        assign dbg_soft_rst  = o_soft_rst[0];
        assign dbg_minimal   = o_minimal[0];
        assign dbg_dclk_lvl  = o_dclk_lvl[0];
        assign dbg_pn_inv    = o_pn_inv;
        assign dbg_crc_refl  = o_crc_mode[0];
        assign dbg_crc_lsb   = o_crc_mode[1];
        assign dbg_vhead_copy= o_crc_mode[2];
        assign dbg_ck_free   = o_crc_mode[3];
        assign dbg_pat_mode  = o_pat_mode;
        assign dbg_pat_lvl   = o_pat_lvl;
        assign dbg_frame_gap = o_frame_gap;

        wire [15:0] status = {mmcm_locked, running, out_en, en_3v8,
                              en_2v8, ack_ok_sticky, ack_crc_ok, ack_frame_err,
                              dbg_ph, dbg_sub, 2'b00};

        vio_dbg u_vio (
            .clk        (clkbit),
            .probe_in0  (frame_cnt),                 // 32
            .probe_in1  (status),                    // 16
            .probe_in2  (ack_f_data0),               // 16
            .probe_in3  ({ack_f_ack, ack_f_dev, ack_f_off, ack_f_len}), // 24
            .probe_in4  (ack_frame_cnt),             // 16
            .probe_in5  (ack_err_cnt),               // 16
            .probe_in6  (ack_f_nbits),               // 9
            .probe_in7  (fps_latched),               // 32  <-- 直接就是 fps
            .probe_out0 (o_addr),                    // 8
            .probe_out1 (o_data),                    // 16
            .probe_out2 (o_we_tog),                  // 1
            .probe_out3 (o_probe_off),               // 8
            .probe_out4 (o_probe_en),                // 1
            .probe_out5 (o_soft_rst),                // 1
            .probe_out6 (o_probe_dev),               // 4  <-- 扫设备号找级联芯片
            .probe_out7 (o_minimal),                 // 1  <-- 最小配置模式
            .probe_out8 (o_dclk_lvl),                // 1  <-- DCLK 电平 (0/1 实时切)
            .probe_out9 (o_pn_inv),                  // 4  <-- 差分极性 {ck,r,g,b}
            .probe_out10(o_crc_mode),                // 4  <-- {ck_free,vhead_copy,lsb_tx,refl}
            .probe_out11(o_pat_mode),                // 3  <-- 图案选择
            .probe_out12(o_pat_lvl),                 // 16 <-- 图案亮度, INIT=0x0FFF
            .probe_out13(o_frame_gap)                // 24 <-- 帧间空闲(拍), 0=用参数
        );
    end else begin : g_nodbg
        assign dbg_reg_we    = 1'b0;
        assign dbg_reg_addr  = 8'h00;
        assign dbg_reg_data  = 16'h0000;
        assign dbg_probe_en  = 1'b0;
        assign dbg_probe_off = 8'h00;
        assign dbg_probe_dev = 4'h0;
        assign dbg_soft_rst  = 1'b0;
        assign dbg_minimal   = 1'b0;
        assign dbg_dclk_lvl  = 1'b0;
        assign dbg_pn_inv    = 4'h0;
        assign dbg_crc_refl  = 1'b1;
        assign dbg_crc_lsb   = 1'b0;
        assign dbg_vhead_copy= 1'b0;
        assign dbg_ck_free   = 1'b0;
        assign dbg_pat_mode  = 3'd0;
        assign dbg_pat_lvl   = 16'h0FFF;
        assign dbg_frame_gap = 24'd0;
    end
    endgenerate

    assign led[0] = running ? frame_cnt[7] : 1'b1;  // 没跑起来=常亮; 🔴 原来接 hb
                                                   // (自由计数器) ⇒ tx 挂死也照闪, 是假判据
    assign led[1] = ack_ok_sticky;             // 亮 = 收到过一条 CRC 正确的 ACK 回包

endmodule

`default_nettype wire
