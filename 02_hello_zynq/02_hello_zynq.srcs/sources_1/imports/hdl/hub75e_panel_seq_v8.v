//-----------------------------------------------------------------------------
// hub75e_panel_seq_v8.v - 128x64(x2) HUB75E panel PL driver (BCM)
//
// v7 (DRAFT, 2026-06-11): 1-bit compact DDR frame format, DMA 64KB -> 8KB/slice
//   1. module rename v6 -> v7 (BD module_ref 缓存坑, 必须 rename + recreate cell)
//   2. 新增 CTRL[14] = compact_en. =0 时行为与 v6 完全一致 (64KB DMA + lite 路径,
//      后向兼容). =1 时 DMA 用紧凑 1-bit 帧格式:
//        - 每 32-bit word 低 24 bit = 8 像素 x 3 bit lane.
//          lane k (k = 像素号 & 7): bit[k*3+0]=B, bit[k*3+1]=R, bit[k*3+2]=G
//          (1-bit 通道开关, plane 索引忽略 — TUNIT planes>1 时各 plane 同内容)
//        - 帧 = 16384 px / 8 = 2048 word = 8 KB. 布局:
//          word    0.. 511 -> fb_top  (panel 1 上半, 像素 0..4095)
//          word  512..1023 -> fb_bot  (panel 1 下半)
//          word 1024..1535 -> fb_top2 (panel 2 上半)
//          word 1536..2047 -> fb_bot2 (panel 2 下半)
//        - DDR slice 地址 = SLICE_BASE + slice_idx * 0x2000 (stride 8 KB;
//          非 compact 维持 * 0x10000). SLICE_BASE 仍建议 64KB 对齐 (1KB 对齐即
//          满足 burst 不跨 4KB, 但统一 64KB 省事).
//        - DMA burst 不变: 1KB INCR x N. compact 时 N=8 (2048 beat), 否则 N=64.
//   3. BRAM 存储: 紧凑 word 原样存进现有 24-bit BRAM.
//        bank 内 word 地址 = dma_word[8:0], bank 选择 = dma_word[10:9],
//        写地址 = {fetch_buf, 3'b000, dma_word[8:0]} (高位补零, 复用 13-bit
//        地址空间低段; 13 = 1 buf + 3 zero + 9 word)
//   4. 显示读侧 (compact_en=1):
//        px = {row_idx[4:0], col_idx[6:0]} (12-bit bank 内像素号)
//        fb_raddr = {disp_buf_eff, 3'b000, px[11:3]}
//        lane = px[2:0] 打 1 拍 (lane_q, 对齐 READ_LATENCY_B=1 的 BRAM dout) 后
//        从 dout 选: b=dout[lane*3], r=dout[lane*3+1], g=dout[lane*3+2].
//        ⚠ lane_q 延迟拍数必须 == READ_LATENCY_B. v6 不需要对齐是因为 plane
//        在整行 shift 期间静态; px[2:0] 每像素变, 必须随 dout 一起延迟.
//   5. 寄存器/0x24 调试寄存器/lite fb 写路径全部不动.
//
// ---- 以下继承 v6 注释 ----
// v6: AXI4 read master DMA + BRAM double buffer + fake angle
//   m_axi: AXI4 read-only master, 32-bit data, 256-beat INCR burst (1 KB),
//   单 outstanding. 64 KB slice frame = 16384 word = 64 burst.
//   非 compact 帧: word 0..4095 top / 4096..8191 bot / 8192..12287 top2 /
//   12288..16383 bot2, 每 word 低 24-bit = RGB (R[7:0] G[15:8] B[23:16]).
//   4x XPM SDPRAM 深度 8192 (ADDR 13 bit), addr[12] = buffer.
//   DMA 写 fetch buf (= ~disp_buf); 显示 FSM 读 disp_buf.
//   dma_en=0 时显示强制 buf 0, AXI-Lite 写口照旧只写 buf 0 → 行为与 v5 等价.
//   假角度计数器: 每 reg_angle_period 个 aclk slice_idx+1, 到 reg_n_slices wrap.
//   aresetn 低 DMA FSM 回 IDLE; RRESP 非 OKAY 只计数 (0x24[31:28] 饱和), 不卡死.
//
// 注意:
//   - m_axi 必须与 s_axi_aclk 同时钟 (单时钟设计, BD 里 HP 口/SMC ACLK 同 FCLK).
//   - dma_en=1 期间 AXI-Lite 仍可写 fb 区, 但只写 buf 0. lite fb 写当拍
//     m_axi_rready 拉低 1 cyc 避免 BRAM 写口冲突 (lite 优先, DMA 延后不丢 beat).
//
// AXI-Lite 寄存器:
//   0x00 CTRL   [0]=en [3:1]=mode [4]=addr_sr [5]=use_fb [6]=overlap_en
//               [7]=dma_en (v6) [12:8]=addr_bits [14]=compact_en (v7)
//   0x04 COLOR  [23:0] 顶半 24-bit RGB (R[7:0] | G[15:8] | B[23:16])
//   0x08 PARAM  [11:0]=width-1 [23:16]=stripe_w [31:24]=walk_speed
//   0x0C STATUS [0]=running [12:8]=cur_addr [15:13]=cur_plane [31:16]=frame_count
//   0x10 COLOR_BOT [23:0] 底半 24-bit RGB (0 时跟 COLOR 同色)
//   0x14 BCM_TUNIT [7:0]=T_unit [11:8]=bcm_planes
//   0x18 SLICE_BASE / 0x1C ANGLE_PERIOD / 0x20 N_SLICES / 0x24 DMA_STATUS
//
// AXI-Lite 地址布局 (17-bit, 128 KB) 不变:
//   addr[15]=0 : 寄存器区 (addr[5:2] 选 reg, 0x00-0x27)
//   addr[15]=1 : framebuffer 区, {addr[16], addr[14]} 选 4 BRAM 之一,
//                addr[13:2] = pixel index 0..4095, 永远写 buffer 0
//
// FM6124 datasheet (V1.0 / S&CIC1501):
//   FCLK max 30 MHz, TWCLK >= 20 ns, TWLE >= 20 ns, TWOE >= 30 ns, setup/hold >= 5 ns
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module hub75e_panel_seq_v8 #(
    parameter integer DCLK_DIV     = 2,    // 75 MHz / 2 = 37.5 MHz DCLK 50% duty
    parameter integer PANEL_WIDTH  = 128,
    parameter integer ADDR_BITS    = 5,    // 1/32 scan
    parameter integer BCM_PLANES   = 6,    // 6-bit per channel (64 灰度)
    parameter integer T_UNIT_DEF   = 8,    // 默认 TUNIT=8 cycle
    parameter integer DISP_CYCLES  = 1000, // (legacy compat)
    parameter integer LATCH_CYC    = 2,    // tWLE=20ns spec
    parameter integer BLANK_CYC    = 1,    // tSETUP2=5ns spec (CLK->LE)
    parameter integer ADDR_SET_CYC = 1,    // v29: LE-fall -> OE-fall 1 cyc
    parameter integer OE_PRE_CYC   = 15,   // v34k: SM16208 chain 末端 cache 时间
    parameter integer FB_DEPTH     = 8192  // (legacy compat; BRAM 深度 8192 = 2 buf x 4096)
)(
    // 单时钟设计: s_axi + m_axi + 显示 FSM 全在 s_axi_aclk 域
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi:m_axi, ASSOCIATED_RESET s_axi_aresetn" *)
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [16:0] s_axi_awaddr,  // v34g: 17-bit for 128K segment
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
    input  wire [16:0] s_axi_araddr,  // v34g: 17-bit
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg [31:0]  s_axi_rdata,
    output reg [1:0]   s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    //--- v6: AXI4 read-only master (slice frame DMA), 接 PS7 S_AXI_HP2 ---
    output reg  [31:0] m_axi_araddr,
    output wire [7:0]  m_axi_arlen,    // 固定 255 = 256 beat
    output wire [2:0]  m_axi_arsize,   // 固定 2 = 4 byte/beat
    output wire [1:0]  m_axi_arburst,  // 固定 INCR
    output wire        m_axi_arlock,
    output wire [3:0]  m_axi_arcache,  // 4'b0011 (normal non-cacheable bufferable)
    output wire [2:0]  m_axi_arprot,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,

    //--- v6: ANGLE SOURCE 预留 angle_tracker 接口 (暂不用, BD 里接 1'b0) ---
    (* dont_touch = "true" *) input  wire        sensor_pulse,

    output reg [5:0]   hub75e_rgb_out,
    (* dont_touch = "true" *) output reg [5:0]   hub75e_rgb_out2,  // panel 2 SDI
    output reg         hub75e_dclk_out,
    output reg         hub75e_lat_out,
    output reg         hub75e_oe_out,
    output reg [4:0]   hub75e_addr_out,
    // v34L: panel 2 独立 8 pin (减 dual panel SI)
    (* dont_touch = "true" *) output wire         hub75e_dclk_out2,
    (* dont_touch = "true" *) output wire         hub75e_lat_out2,
    (* dont_touch = "true" *) output wire         hub75e_oe_out2,
    (* dont_touch = "true" *) output wire [4:0]   hub75e_addr_out2
);

    // AXI4 master 常量通道
    assign m_axi_arlen   = 8'd255;
    assign m_axi_arsize  = 3'b010;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;

    // v34L: panel 2 控制信号直复 panel 1 (同步), 独立 IO pin → SI 隔离
    assign hub75e_dclk_out2 = hub75e_dclk_out;
    assign hub75e_lat_out2  = hub75e_lat_out;
    assign hub75e_oe_out2   = hub75e_oe_out;
    assign hub75e_addr_out2 = hub75e_addr_out;

    //==========================================================================
    // AXI-Lite 寄存器
    //==========================================================================
    reg [31:0] reg_ctrl;
    reg [31:0] reg_color;        // 0x04 top color
    reg [31:0] reg_param;
    reg [31:0] reg_color_bot;    // 0x10 bot color
    reg [31:0] reg_tunit;        // 0x14 T_unit
    reg [31:0] reg_slice_base;   // 0x18 v6: DDR slice frame 基址 (64 KB 对齐)
    reg [31:0] reg_angle_period; // 0x1C v6: aclk cycles per slice
    reg [31:0] reg_n_slices;     // 0x20 v6: slice 总数 (低 16-bit 有效)

    wire        enable        = reg_ctrl[0];
    wire [2:0]  test_mode     = reg_ctrl[3:1];
    wire        addr_mode_sr  = reg_ctrl[4];
    wire        use_fb        = reg_ctrl[5];   // 1=从 framebuffer 取 pixel
    wire        overlap_en    = reg_ctrl[6];   // v28: shift-while-display overlap
    wire        dma_en        = reg_ctrl[7];   // v6: AXI4 master slice DMA enable
    wire [4:0]  addr_bits_cfg = (reg_ctrl[12:8] == 5'd0) ? 5'd5 : reg_ctrl[12:8];
    wire        compact_en    = reg_ctrl[14];  // v7: 1-bit compact frame format
    wire [4:0]  row_max       = (5'd1 << addr_bits_cfg) - 5'd1;
    wire [23:0] user_color_top = reg_color[23:0];
    wire [23:0] user_color_bot = (reg_color_bot[23:0] == 24'h0 && reg_color[23:0] != 24'h0)
                                  ? reg_color[23:0] : reg_color_bot[23:0];
    wire [11:0] width_max     = (reg_param[11:0] == 12'd0) ? PANEL_WIDTH-1 : reg_param[11:0];
    wire [7:0]  stripe_w      = (reg_param[23:16] == 8'd0) ? 8'd8 : reg_param[23:16];
    wire [7:0]  walk_speed    = (reg_param[31:24] == 8'd0) ? 8'd10 : reg_param[31:24];
    wire [7:0]  t_unit        = (reg_tunit[7:0] == 8'd0) ? T_UNIT_DEF[7:0] : reg_tunit[7:0];
    // v31: runtime BCM planes (1..6 bit). reg_tunit[11:8]=0 -> BCM_PLANES default
    wire [3:0]  bcm_planes_cfg = (reg_tunit[11:8] == 4'd0) ? BCM_PLANES[3:0] : reg_tunit[11:8];
    wire [2:0]  plane_max_run  = bcm_planes_cfg[2:0] - 3'd1;
    wire [15:0] n_slices_eff   = (reg_n_slices[15:0] == 16'd0) ? 16'd1 : reg_n_slices[15:0];

    // Framebuffer write decode (AXI-Lite path, 不变):
    //   panel 1 fb_top  @ 0x0_8000 (addr[16]=0, addr[15]=1, addr[14]=0)
    //   panel 1 fb_bot  @ 0x0_C000 (addr[16]=0, addr[15]=1, addr[14]=1)
    //   panel 2 fb_top  @ 0x1_8000 (addr[16]=1, addr[15]=1, addr[14]=0)
    //   panel 2 fb_bot  @ 0x1_C000 (addr[16]=1, addr[15]=1, addr[14]=1)
    wire fb_top_we_main;
    wire fb_bot_we_main;
    wire fb_top2_we_main;
    wire fb_bot2_we_main;
    wire [11:0] fb_waddr_main = cur_aw_addr[13:2];
    wire [23:0] fb_wdata_main = s_axi_wdata[23:0];
    assign fb_top_we_main  = (s_axi_wvalid && !w_done && (aw_done || s_axi_awvalid) &&
                              !cur_aw_addr[16] && cur_aw_addr[15] && !cur_aw_addr[14]);
    assign fb_bot_we_main  = (s_axi_wvalid && !w_done && (aw_done || s_axi_awvalid) &&
                              !cur_aw_addr[16] && cur_aw_addr[15] &&  cur_aw_addr[14]);
    assign fb_top2_we_main = (s_axi_wvalid && !w_done && (aw_done || s_axi_awvalid) &&
                               cur_aw_addr[16] && cur_aw_addr[15] && !cur_aw_addr[14]);
    assign fb_bot2_we_main = (s_axi_wvalid && !w_done && (aw_done || s_axi_awvalid) &&
                               cur_aw_addr[16] && cur_aw_addr[15] &&  cur_aw_addr[14]);
    wire lite_fb_we_any = fb_top_we_main | fb_bot_we_main | fb_top2_we_main | fb_bot2_we_main;

    // DEBUG: 任何 AXI W handshake 都触发 fb_top_we (验证 ARM 写 AXI 是否真到 IP)
    wire fb_top_we = s_axi_wvalid && !w_done && (aw_done || s_axi_awvalid);

    reg [16:0] aw_addr_q;  // 17-bit
    reg        aw_done, w_done;
    // Verilog 不支持 (ternary)[bit slice], 用 wire 包一层
    wire [16:0] cur_aw_addr = aw_done ? aw_addr_q : s_axi_awaddr;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready    <= 1'b0;
            s_axi_wready     <= 1'b0;
            s_axi_bvalid     <= 1'b0;
            s_axi_bresp      <= 2'b00;
            aw_done          <= 1'b0;
            w_done           <= 1'b0;
            reg_ctrl         <= 32'b0;
            reg_color        <= 32'b0;
            reg_param        <= 32'b0;
            reg_color_bot    <= 32'b0;
            reg_tunit        <= 32'b0;
            reg_slice_base   <= 32'b0;   // v6
            reg_angle_period <= 32'b0;   // v6
            reg_n_slices     <= 32'b0;   // v6
            fb_we_count      <= 16'h0;
            last_fb_wdata    <= 24'h0;
            last_fb_waddr    <= 12'h0;
        end else begin
            if (!aw_done && s_axi_awvalid) begin
                s_axi_awready <= 1'b1;
                aw_addr_q     <= s_axi_awaddr;
                aw_done       <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
            end
            if (!w_done && s_axi_wvalid) begin
                s_axi_wready <= 1'b1;
                w_done       <= 1'b1;
                if (aw_done || s_axi_awvalid) begin
                    if (cur_aw_addr[15]) begin
                        // DEBUG sample, 跟 reg_color 完全同条件
                        last_fb_wdata <= s_axi_wdata[23:0];
                        last_fb_waddr <= cur_aw_addr[13:2];
                        fb_we_count   <= fb_we_count + 16'h1;
                    end else begin
                        // v6: decode [4:2] 3-bit 扩成 [5:2] 4-bit
                        case (cur_aw_addr[5:2])
                            4'd0: reg_ctrl         <= s_axi_wdata;
                            4'd1: reg_color        <= s_axi_wdata;
                            4'd2: reg_param        <= s_axi_wdata;
                            // 4'd3 = STATUS, read-only
                            4'd4: reg_color_bot    <= s_axi_wdata;
                            4'd5: reg_tunit        <= s_axi_wdata;
                            4'd6: reg_slice_base   <= s_axi_wdata;   // 0x18
                            4'd7: reg_angle_period <= s_axi_wdata;   // 0x1C
                            4'd8: reg_n_slices     <= s_axi_wdata;   // 0x20
                            // 4'd9 = DMA_STATUS, read-only
                            default: ;
                        endcase
                    end
                end
            end else begin
                s_axi_wready <= 1'b0;
            end
            if (aw_done && w_done && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                aw_done      <= 1'b0;
                w_done       <= 1'b0;
            end
        end
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'b0;
        end else begin
            if (!s_axi_rvalid && s_axi_arvalid && !s_axi_arready) begin
                s_axi_arready <= 1'b1;
                if (s_axi_araddr[15]) begin
                    // framebuffer write-only, AXI read fb 永远返回 0
                    s_axi_rdata <= 32'h0;
                end else case (s_axi_araddr[5:2])   // v6: 4-bit decode
                    4'd0: s_axi_rdata <= reg_ctrl;
                    4'd1: s_axi_rdata <= reg_color;
                    4'd2: s_axi_rdata <= reg_param;
                    4'd3: s_axi_rdata <= status_word;
                    4'd4: s_axi_rdata <= reg_color_bot;
                    4'd5: s_axi_rdata <= reg_tunit;
                    4'd6: s_axi_rdata <= reg_slice_base;     // v6
                    4'd7: s_axi_rdata <= reg_angle_period;   // v6
                    4'd8: s_axi_rdata <= reg_n_slices;       // v6
                    4'd9: s_axi_rdata <= dma_status_word;    // v6 0x24 RO (v8: bit23=locked)
                    4'd10: s_axi_rdata <= trk_rev_period;    // v8 0x28 RO 实测每转周期
                    4'd11: s_axi_rdata <= sens_dbg_word;     // v8 0x2C RO {raw_lvl[31],pulse_cnt[15:0]} 保命计数器
                    default: s_axi_rdata <= 32'h0;
                endcase
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
            end else begin
                s_axi_arready <= 1'b0;
                if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;
            end
        end
    end

    //==========================================================================
    // v6: 假角度计数器 (ANGLE SOURCE)
    // 每 reg_angle_period 个 aclk slice_idx_live+1, 到 n_slices_eff wrap 0.
    // period=0 → 停在 slice 0 (静态调试).
    //
    // *** 后续接 angle_tracker 时: 删掉这个 always block, 实例化 angle_tracker
    // *** (input sensor_pulse, output [15:0] slice_idx), 把它的 slice_idx 接到
    // *** slice_idx_live (改成 wire). DMA FSM / 0x24 读口都只认 slice_idx_live.
    //==========================================================================

    // v8b: angle_tracker 做唯一角度源 (去掉外部 mux + 独立假计数器, 防综合判 slice 链无用).
    //   CTRL[15]=sensor_en: 0=angle_tracker 内部 fake 自由跑(同旧假计数器行为) 1=光电开关.
    //   fake_en = ~sensor_en, fake_period = reg_angle_period (复用 0x1C).
    //   slice_idx_live = trk_slice 直接, 无条件在 slice→araddr 链上 → sensor_pulse 不会被 trim.
    wire        sensor_en = reg_ctrl[15];
    wire [15:0] trk_slice;
    wire [31:0] trk_rev_period;
    wire        trk_locked;
    angle_tracker #(.CLK_HZ(75000000)) u_angle_trk (
        .clk(s_axi_aclk), .rst_n(s_axi_aresetn),
        .sensor_in(sensor_pulse),
        .fake_en(~sensor_en), .fake_period(reg_angle_period),
        .n_slices(n_slices_eff),
        .slice_idx(trk_slice), .rev_period(trk_rev_period), .locked(trk_locked)
    );
    wire [15:0] slice_idx_live = trk_slice;

    // v8 保命: sensor_pulse 直接驱动可读计数器 (绕开 angle_tracker, 综合不敢删被读出的寄存器)
    // 0x2C 读: {raw_lvl[31], pulse_cnt[15:0]}. 验电路通断 + 脉冲数, 不依赖 angle_tracker
    (* dont_touch = "true" *) reg [1:0]  sens_sync;
    reg [15:0] sens_pulse_cnt;
    reg        sens_lvl;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            sens_sync <= 2'b0; sens_pulse_cnt <= 16'd0; sens_lvl <= 1'b0;
        end else begin
            sens_sync <= {sens_sync[0], sensor_pulse};
            sens_lvl  <= sens_sync[1];
            if (sens_sync[1] & ~sens_lvl) sens_pulse_cnt <= sens_pulse_cnt + 16'd1;  // 上升沿计数
        end
    end
    wire [31:0] sens_dbg_word = {sens_sync[1], 15'b0, sens_pulse_cnt};

    //==========================================================================
    // v6: DMA FSM (AXI4 read master, 单 outstanding)
    //
    //   D_IDLE  : dma_en=0 停 (disp_buf 归 0). dma_en=1 → latch slice_idx_live,
    //             发第一个 AR → D_AR
    //   D_AR    : arvalid hold 到 arready → D_R (dma_en 已掉 → D_DRAIN)
    //   D_R     : 收 256 beat 写 fetch buf BRAM. rlast:
    //               最后 burst (compact: 7, 否则 63) → D_WAIT_FR;
    //               否则 araddr+=1024 再发 AR → D_AR
    //             中途 dma_en 掉 → D_DRAIN (剩余 beat 丢弃, 不写 BRAM)
    //   D_WAIT_FR: 等 frame_count 自增 (帧边界) 或显示 FSM 在 S_IDLE (没人产帧,
    //             避免死等) → 翻 disp_buf, latch 新 slice_idx_live 再取.
    //   D_DRAIN : 把 outstanding burst 的 R beat 收完 (AXI 不允许弃 txn) → D_IDLE
    //
    // v7: fetch_compact 在每次 fetch 启动时 latch compact_en, 保证单次 fetch 的
    //     地址步进/burst 数/bank 解码/写地址全程一致 (中途翻 CTRL[14] 不撕裂).
    //
    // BRAM 写口仲裁: lite fb 写优先, 当拍 m_axi_rready 拉低 (DMA beat 延后不丢).
    // RRESP[1] (SLVERR/DECERR) → dma_err_count 饱和 +1, 流程照走.
    //==========================================================================
    localparam [3:0]
        D_IDLE    = 4'd0,
        D_AR      = 4'd1,
        D_R       = 4'd2,
        D_WAIT_FR = 4'd3,
        D_DRAIN   = 4'd4;

    reg [3:0]  dstate;
    reg [15:0] fetch_slice;     // 本轮 fetch 的 slice (latch 自 slice_idx_live)
    reg [5:0]  burst_cnt;       // 0..63 (64KB 模式) / 0..7 (compact 8KB 模式)
    reg [13:0] dma_word;        // 0..16383 整帧 word index (compact: 0..2047)
    reg        disp_buf;        // 显示 FSM 用的 buffer; fetch buf = ~disp_buf
    reg        fetch_compact;   // v7: 本轮 fetch 是否 compact (latch 自 compact_en)
    reg [3:0]  dma_err_count;   // RRESP 非 OKAY 饱和计数
    reg [15:0] frame_count_q;   // 帧边界检测 (frame_count 在显示 FSM 自增)

    wire frame_tick = (frame_count != frame_count_q);
    wire fetch_buf  = ~disp_buf;

    // v7: 末 burst 序号 (compact 帧 8KB = 8 burst; 64KB = 64 burst)
    wire [5:0] burst_last = fetch_compact ? 6'd7 : 6'd63;

    // R 通道握手: D_R 收数 (lite fb 写当拍让位), D_DRAIN 只收不写
    assign m_axi_rready = (dstate == D_DRAIN) ||
                          ((dstate == D_R) && !lite_fb_we_any);
    wire dma_beat = m_axi_rvalid && m_axi_rready;
    wire dma_we   = (dstate == D_R) && dma_beat;

    // bank 选择: compact 用 word[10:9] (512 word/bank), 否则 word[13:12] (4096/bank)
    wire [1:0] dma_bank  = fetch_compact ? dma_word[10:9] : dma_word[13:12];
    wire dma_we_top  = dma_we && (dma_bank == 2'b00);
    wire dma_we_bot  = dma_we && (dma_bank == 2'b01);
    wire dma_we_top2 = dma_we && (dma_bank == 2'b10);
    wire dma_we_bot2 = dma_we && (dma_bank == 2'b11);

    // v7: bank 内写地址 12-bit. compact = {3'b000, word[8:0]} (低段), 否则 word[11:0]
    wire [11:0] dma_waddr12 = fetch_compact ? {3'b000, dma_word[8:0]} : dma_word[11:0];

    // 0x24 RO: {err[31:28], dma_state[27:24], 8'b0, cur_slice_idx[15:0]}
    wire [31:0] dma_status_word = {dma_err_count, dstate, 7'b0, trk_locked, slice_idx_live};

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            dstate        <= D_IDLE;
            m_axi_arvalid <= 1'b0;
            m_axi_araddr  <= 32'd0;
            fetch_slice   <= 16'd0;
            burst_cnt     <= 6'd0;
            dma_word      <= 14'd0;
            disp_buf      <= 1'b0;
            fetch_compact <= 1'b0;
            dma_err_count <= 4'd0;
            frame_count_q <= 16'd0;
        end else begin
            frame_count_q <= frame_count;

            // RRESP 错误饱和计数 (D_R + D_DRAIN 都计), 不影响流程
            if (m_axi_rvalid && m_axi_rready && m_axi_rresp[1]
                && dma_err_count != 4'hF)
                dma_err_count <= dma_err_count + 4'd1;

            case (dstate)
                D_IDLE: begin
                    m_axi_arvalid <= 1'b0;
                    if (!dma_en) begin
                        disp_buf <= 1'b0;   // 后向兼容: 关 DMA 显示回 buf 0
                    end else begin
                        fetch_slice   <= slice_idx_live;
                        fetch_compact <= compact_en;
                        burst_cnt     <= 6'd0;
                        dma_word      <= 14'd0;
                        // v7: compact slice stride 0x2000 (<<13), 否则 0x10000 (<<16)
                        m_axi_araddr  <= reg_slice_base +
                                         (compact_en ? {3'b0, slice_idx_live, 13'b0}
                                                     : {slice_idx_live, 16'b0});
                        m_axi_arvalid <= 1'b1;
                        dstate        <= D_AR;
                    end
                end

                D_AR: begin
                    // arvalid 已置位, hold 到 arready (AXI 规定不能撤)
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        dstate        <= dma_en ? D_R : D_DRAIN;
                    end
                end

                D_R: begin
                    if (dma_beat) begin
                        dma_word <= dma_word + 14'd1;
                        if (m_axi_rlast) begin
                            if (!dma_en) begin
                                dstate <= D_IDLE;       // burst 刚好收完, 直接停
                            end else if (burst_cnt == burst_last) begin
                                burst_cnt <= 6'd0;
                                dstate    <= D_WAIT_FR; // 整帧收完, 等帧边界
                            end else begin
                                burst_cnt     <= burst_cnt + 6'd1;
                                m_axi_araddr  <= m_axi_araddr + 32'd1024;
                                m_axi_arvalid <= 1'b1;
                                dstate        <= D_AR;
                            end
                        end
                    end else if (!dma_en) begin
                        // burst 中途掉 dma_en: 剩余 beat 进 D_DRAIN 丢弃
                        dstate <= D_DRAIN;
                    end
                end

                D_WAIT_FR: begin
                    if (!dma_en) begin
                        dstate <= D_IDLE;   // 无 outstanding txn, 可直接停
                    end else if (frame_tick || state == S_IDLE) begin
                        // 帧边界 (或显示 FSM 根本没跑, 避免死等) → 翻 buffer
                        disp_buf      <= fetch_buf;          // = ~disp_buf
                        fetch_slice   <= slice_idx_live;     // 取最新角度
                        fetch_compact <= compact_en;
                        burst_cnt     <= 6'd0;
                        dma_word      <= 14'd0;
                        m_axi_araddr  <= reg_slice_base +
                                         (compact_en ? {3'b0, slice_idx_live, 13'b0}
                                                     : {slice_idx_live, 16'b0});
                        m_axi_arvalid <= 1'b1;
                        dstate        <= D_AR;
                    end
                end

                D_DRAIN: begin
                    // 收完 outstanding burst 剩余 beat (不写 BRAM) 再回 IDLE
                    if (m_axi_rvalid && m_axi_rready && m_axi_rlast)
                        dstate <= D_IDLE;
                end

                default: dstate <= D_IDLE;
            endcase
        end
    end

    //==========================================================================
    // 显示 FSM (v28 hybrid: serial + optional overlap with OE_PRE delay)
    // CTRL[6]=overlap_en (ABCDE only, SR mode always serial)
    //==========================================================================
    localparam [3:0]
        S_IDLE       = 4'd0,
        S_SHIFT      = 4'd1,
        S_BLANK      = 4'd2,
        S_LATCH      = 4'd3,
        S_ADDR_ABCDE = 4'd4,
        S_ADDR_SR    = 4'd5,
        S_DISPLAY    = 4'd6,
        S_OE_PRE     = 4'd7,    // v28 overlap: drop OE, wait for chip cache
        S_PHASE      = 4'd8;    // v28 overlap: shift next + display current

    reg [3:0]  state;
    reg [11:0] col_idx;
    reg [4:0]  row_idx;
    reg [4:0]  row_displayed;
    reg [2:0]  plane;
    reg [4:0]  disp_row;        // v28 overlap: snapshot at LATCH
    reg [2:0]  disp_plane;      // v28 overlap: snapshot at LATCH
    reg        shift_active;    // v28 overlap: 1 = shift still pushing SR
    reg        disp_active;     // v28 overlap: 1 = OE should be low
    reg [15:0] frame_count;
    reg [7:0]  walk_pos;
    reg [7:0]  walk_div_count;
    reg [15:0] disp_count;
    reg [15:0] disp_target;
    reg [3:0]  ctrl_count;
    reg [$clog2(DCLK_DIV):0] sub_count;

    reg [5:0]  sr_bit_idx;
    reg [1:0]  sr_sub;
    reg        sr_clk;
    reg        sr_dat;
    reg        sr_en;
    reg [4:0]  addr_abcde_lat;

    // fb_we_count + last_fb_wdata + last_fb_waddr 在 main always block 内 sample
    reg [15:0] fb_we_count;
    reg [23:0] last_fb_wdata;
    reg [11:0] last_fb_waddr;
    // STATUS [31:16]=frame_count [15:13]=plane [12:8]=row_displayed [0]=running
    wire [31:0] status_word = {frame_count, plane, row_displayed, 7'b0, (state != S_IDLE)};

    //==========================================================================
    // Pattern generator: 24-bit per RGB -> plane slice -> 6-bit out
    //==========================================================================
    reg [23:0] pattern_24_top_lut;
    reg [23:0] pattern_24_bot_lut;

    // v6: 显示读地址加 buffer 高位. dma_en=0 强制 buf 0 (= v5 行为)
    wire        disp_buf_eff = dma_en ? disp_buf : 1'b0;
    // v7: px_idx = bank 内像素号 (= v6 的 {row,col} 地址低 12 bit)
    wire [11:0] px_idx = {row_idx[4:0], col_idx[6:0]};
    // v7: compact 时 8 像素共享 1 word, 读地址 = word 号 px[11:3] (高位补 0,
    //     与 DMA 写地址 {fetch_buf, 3'b000, word[8:0]} 同段); 否则 = v6 原样
    wire [12:0] fb_raddr = compact_en ? {disp_buf_eff, 3'b000, px_idx[11:3]}
                                      : {disp_buf_eff, px_idx};
    wire [23:0] fb_top_dout, fb_bot_dout;
    wire [23:0] fb_top2_dout, fb_bot2_dout;

    //==========================================================================
    // v6: BRAM 写口仲裁 (port A)
    //   - DMA beat (D_R) 写 fetch buf {~disp_buf, dma_waddr12}
    //   - AXI-Lite 写 buf 0 {1'b0, addr[13:2]} (优先; 当拍 rready 已拉低,
    //     所以 dma_we_* 和 fb_*_we_main 不可能同拍同 BRAM 都为 1)
    //==========================================================================
    wire        fbw_top_we    = dma_we_top  | fb_top_we_main;
    wire [12:0] fbw_top_addr  = dma_we_top  ? {fetch_buf, dma_waddr12} : {1'b0, fb_waddr_main};
    wire [23:0] fbw_top_data  = dma_we_top  ? m_axi_rdata[23:0] : fb_wdata_main;
    wire        fbw_bot_we    = dma_we_bot  | fb_bot_we_main;
    wire [12:0] fbw_bot_addr  = dma_we_bot  ? {fetch_buf, dma_waddr12} : {1'b0, fb_waddr_main};
    wire [23:0] fbw_bot_data  = dma_we_bot  ? m_axi_rdata[23:0] : fb_wdata_main;
    wire        fbw_top2_we   = dma_we_top2 | fb_top2_we_main;
    wire [12:0] fbw_top2_addr = dma_we_top2 ? {fetch_buf, dma_waddr12} : {1'b0, fb_waddr_main};
    wire [23:0] fbw_top2_data = dma_we_top2 ? m_axi_rdata[23:0] : fb_wdata_main;
    wire        fbw_bot2_we   = dma_we_bot2 | fb_bot2_we_main;
    wire [12:0] fbw_bot2_addr = dma_we_bot2 ? {fetch_buf, dma_waddr12} : {1'b0, fb_waddr_main};
    wire [23:0] fbw_bot2_data = dma_we_bot2 ? m_axi_rdata[23:0] : fb_wdata_main;

    // Xilinx XPM macro: 100% defined behavior, Vivado 不会 swap/优化掉
    // v6: ADDR 13 bit, MEMORY_SIZE 196608 (8192 entries x 24-bit, 双 buffer)
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(13), .ADDR_WIDTH_B(13),
        .BYTE_WRITE_WIDTH_A(24),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(196608),      // 8192 entries x 24-bit (v6 double buffer)
        .READ_DATA_WIDTH_B(24),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(24),
        .USE_MEM_INIT(0)
    ) u_fb_top (
        .clka(s_axi_aclk), .ena(1'b1), .wea(fbw_top_we),
        .addra(fbw_top_addr), .dina(fbw_top_data),
        .clkb(s_axi_aclk), .enb(1'b1), .regceb(1'b1), .rstb(1'b0),
        .addrb(fb_raddr), .doutb(fb_top_dout),
        .injectsbiterra(1'b0), .injectdbiterra(1'b0), .sleep(1'b0),
        .sbiterrb(), .dbiterrb()
    );
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(13), .ADDR_WIDTH_B(13),
        .BYTE_WRITE_WIDTH_A(24),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(196608),
        .READ_DATA_WIDTH_B(24),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(24),
        .USE_MEM_INIT(0)
    ) u_fb_bot (
        .clka(s_axi_aclk), .ena(1'b1), .wea(fbw_bot_we),
        .addra(fbw_bot_addr), .dina(fbw_bot_data),
        .clkb(s_axi_aclk), .enb(1'b1), .regceb(1'b1), .rstb(1'b0),
        .addrb(fb_raddr), .doutb(fb_bot_dout),
        .injectsbiterra(1'b0), .injectdbiterra(1'b0), .sleep(1'b0),
        .sbiterrb(), .dbiterrb()
    );
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(13), .ADDR_WIDTH_B(13),
        .BYTE_WRITE_WIDTH_A(24),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(196608),
        .READ_DATA_WIDTH_B(24),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(24),
        .USE_MEM_INIT(0)
    ) u_fb_top2 (
        .clka(s_axi_aclk), .ena(1'b1), .wea(fbw_top2_we),
        .addra(fbw_top2_addr), .dina(fbw_top2_data),
        .clkb(s_axi_aclk), .enb(1'b1), .regceb(1'b1), .rstb(1'b0),
        .addrb(fb_raddr), .doutb(fb_top2_dout),
        .injectsbiterra(1'b0), .injectdbiterra(1'b0), .sleep(1'b0),
        .sbiterrb(), .dbiterrb()
    );
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(13), .ADDR_WIDTH_B(13),
        .BYTE_WRITE_WIDTH_A(24),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_PRIMITIVE("block"),
        .MEMORY_SIZE(196608),
        .READ_DATA_WIDTH_B(24),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(24),
        .USE_MEM_INIT(0)
    ) u_fb_bot2 (
        .clka(s_axi_aclk), .ena(1'b1), .wea(fbw_bot2_we),
        .addra(fbw_bot2_addr), .dina(fbw_bot2_data),
        .clkb(s_axi_aclk), .enb(1'b1), .regceb(1'b1), .rstb(1'b0),
        .addrb(fb_raddr), .doutb(fb_bot2_dout),
        .injectsbiterra(1'b0), .injectdbiterra(1'b0), .sleep(1'b0),
        .sbiterrb(), .dbiterrb()
    );

    // pattern_24 = LUT (use_fb=0) vs framebuffer 读 (use_fb=1)
    wire [23:0] pattern_24_top = use_fb ? fb_top_dout : pattern_24_top_lut;
    wire [23:0] pattern_24_bot = use_fb ? fb_bot_dout : pattern_24_bot_lut;
    // v34g: panel 2 独立 pattern, use_fb=0 时 fallback 到 panel 1
    wire [23:0] pattern_24_top2 = use_fb ? fb_top2_dout : pattern_24_top_lut;
    wire [23:0] pattern_24_bot2 = use_fb ? fb_bot2_dout : pattern_24_bot_lut;

    // 8 色 LUT (R, G, B, W, Y, M, C, K) — R in low byte
    function [23:0] color_lut;
        input [2:0] i;
        begin
            case (i)
                3'd0: color_lut = 24'h0000FF;  // R
                3'd1: color_lut = 24'h00FF00;  // G
                3'd2: color_lut = 24'hFF0000;  // B
                3'd3: color_lut = 24'hFFFFFF;  // W
                3'd4: color_lut = 24'h00FFFF;  // Y (R+G)
                3'd5: color_lut = 24'hFF00FF;  // M (R+B)
                3'd6: color_lut = 24'hFFFF00;  // C (G+B)
                default: color_lut = 24'h000000; // K
            endcase
        end
    endfunction

    always @(*) begin
        case (test_mode)
            3'd0: begin
                pattern_24_top_lut = user_color_top;
                pattern_24_bot_lut = user_color_bot;
            end
            3'd1: begin
                // 固定 4-row 一条 stripe
                pattern_24_top_lut = color_lut(row_idx[4:2]);
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd2: begin
                // 固定 16-col 一条 stripe
                pattern_24_top_lut = color_lut(col_idx[6:4]);
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd3: begin
                pattern_24_top_lut = (col_idx[3] ^ row_idx[2]) ? 24'h0000FF : 24'h00FF00;
                pattern_24_bot_lut = (col_idx[3] ^ row_idx[2]) ? 24'h00FF00 : 24'h0000FF;
            end
            3'd4: begin
                pattern_24_top_lut = (row_idx == walk_pos[4:0]) ? 24'hFFFFFF : 24'h000000;
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd5: begin
                pattern_24_top_lut = (col_idx[7:0] == walk_pos) ? 24'hFFFFFF : 24'h000000;
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            3'd6: begin
                pattern_24_top_lut = {col_idx[7:0], col_idx[7:0], col_idx[7:0]};
                pattern_24_bot_lut = pattern_24_top_lut;
            end
            default: begin   // mode 7 FULL WHITE
                pattern_24_top_lut = 24'hFFFFFF;
                pattern_24_bot_lut = 24'hFFFFFF;
            end
        endcase
    end

    //==========================================================================
    // v7: compact lane 选择, 关键时序对齐
    //   fb_raddr 是 col_idx/row_idx 的组合函数, BRAM READ_LATENCY_B=1 →
    //   dout(t) 对应 px_idx(t-1). v6 的选择器 plane 整行静态所以不用对齐;
    //   compact 的 lane = px_idx[2:0] 每像素变, 必须同样打 1 拍 (lane_q),
    //   使 lane_q(t) 与 dout(t) 同属一个像素. 拍数 == READ_LATENCY_B, 改
    //   READ_LATENCY_B 时这里必须跟着改.
    //==========================================================================
    reg [2:0] lane_q;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) lane_q <= 3'd0;
        else                lane_q <= px_idx[2:0];
    end

    // lane*3 (0,3,..,21). v34h 教训: 必须 5-bit wire + 常量偏移动态索引写法,
    // byte-slice 写法会被 Vivado 优化掉 (勿改)
    wire [4:0] lane3 = {1'b0, lane_q, 1'b0} + {2'b00, lane_q};

    // compact 1-bit lane: bit[lane*3+0]=B, +1=R, +2=G
    wire c_b1  = pattern_24_top [lane3];
    wire c_r1  = pattern_24_top [lane3 + 5'd1];
    wire c_g1  = pattern_24_top [lane3 + 5'd2];
    wire c_b2  = pattern_24_bot [lane3];
    wire c_r2  = pattern_24_bot [lane3 + 5'd1];
    wire c_g2  = pattern_24_bot [lane3 + 5'd2];
    wire c_b1p2 = pattern_24_top2[lane3];
    wire c_r1p2 = pattern_24_top2[lane3 + 5'd1];
    wire c_g1p2 = pattern_24_top2[lane3 + 5'd2];
    wire c_b2p2 = pattern_24_bot2[lane3];
    wire c_r2p2 = pattern_24_bot2[lane3 + 5'd1];
    wire c_g2p2 = pattern_24_bot2[lane3 + 5'd2];

    // v34h plane_ext + 5'd16 写法 (勿改, v34i byte-slice 写法会被 Vivado 优化掉)
    // v7: compact_en=1 时换 lane 1-bit 通道, plane 忽略 (planes>1 各 plane 同内容)
    wire [4:0] plane_ext = {2'b0, plane};
    wire r1_bit = compact_en ? c_r1 : pattern_24_top[plane_ext];
    wire g1_bit = compact_en ? c_g1 : pattern_24_top[plane_ext + 5'd8];
    wire b1_bit = compact_en ? c_b1 : pattern_24_top[plane_ext + 5'd16];
    wire r2_bit = compact_en ? c_r2 : pattern_24_bot[plane_ext];
    wire g2_bit = compact_en ? c_g2 : pattern_24_bot[plane_ext + 5'd8];
    wire b2_bit = compact_en ? c_b2 : pattern_24_bot[plane_ext + 5'd16];
    wire [5:0] plane_rgb = {b2_bit, g2_bit, r2_bit, b1_bit, g1_bit, r1_bit};
    wire r1_bit2 = compact_en ? c_r1p2 : pattern_24_top2[plane_ext];
    wire g1_bit2 = compact_en ? c_g1p2 : pattern_24_top2[plane_ext + 5'd8];
    wire b1_bit2 = compact_en ? c_b1p2 : pattern_24_top2[plane_ext + 5'd16];
    wire r2_bit2 = compact_en ? c_r2p2 : pattern_24_bot2[plane_ext];
    wire g2_bit2 = compact_en ? c_g2p2 : pattern_24_bot2[plane_ext + 5'd8];
    wire b2_bit2 = compact_en ? c_b2p2 : pattern_24_bot2[plane_ext + 5'd16];
    wire [5:0] plane_rgb2 = {b2_bit2, g2_bit2, r2_bit2, b1_bit2, g1_bit2, r1_bit2};

    //==========================================================================
    // ADDR 输出 mux
    //==========================================================================
    always @(*) begin
        if (addr_mode_sr) begin
            hub75e_addr_out = {2'b00, sr_en, sr_dat, sr_clk};
        end else begin
            hub75e_addr_out = addr_abcde_lat;
        end
    end

    //==========================================================================
    // 主显示 FSM (BCM: 每 row 跑 N plane) — v7 未改动 (只有 fb_raddr/lane 在外面变)
    //==========================================================================
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            state           <= S_IDLE;
            col_idx         <= 12'd0;
            row_idx         <= 5'd0;
            row_displayed   <= 5'd0;
            plane           <= 3'd0;
            disp_row        <= 5'd0;
            disp_plane      <= 3'd0;
            shift_active    <= 1'b0;
            disp_active     <= 1'b0;
            sub_count       <= 0;
            ctrl_count      <= 4'd0;
            disp_count      <= 16'd0;
            disp_target     <= 16'd0;
            frame_count     <= 16'd0;
            walk_pos        <= 8'd0;
            walk_div_count  <= 8'd0;
            hub75e_rgb_out  <= 6'b0;
            hub75e_rgb_out2 <= 6'b0;
            hub75e_dclk_out <= 1'b0;
            hub75e_lat_out  <= 1'b0;
            hub75e_oe_out   <= 1'b1;
            addr_abcde_lat  <= 5'b0;
            sr_bit_idx      <= 6'd0;
            sr_sub          <= 2'd0;
            sr_clk          <= 1'b0;
            sr_dat          <= 1'b0;
            sr_en            <= 1'b1;
        end else begin
            case (state)
                S_IDLE: begin
                    hub75e_oe_out   <= 1'b1;
                    hub75e_lat_out  <= 1'b0;
                    hub75e_dclk_out <= 1'b0;
                    hub75e_rgb_out  <= 6'b0;
                    hub75e_rgb_out2 <= 6'b0;
                    sr_en           <= 1'b1;
                    sr_clk          <= 1'b0;
                    col_idx         <= 12'd0;
                    row_idx         <= 5'd0;
                    plane           <= 3'd0;
                    disp_row        <= 5'd0;
                    disp_plane      <= 3'd0;
                    shift_active    <= 1'b0;
                    disp_active     <= 1'b0;
                    sub_count       <= 0;
                    if (enable) state <= S_SHIFT;
                end

                S_SHIFT: begin
                    hub75e_oe_out  <= 1'b1;
                    hub75e_lat_out <= 1'b0;
                    hub75e_rgb_out <= plane_rgb;
                    hub75e_rgb_out2 <= plane_rgb2;

                    if (sub_count == (DCLK_DIV/2 - 1)) begin
                        hub75e_dclk_out <= 1'b1;
                        sub_count       <= sub_count + 1;
                    end else if (sub_count == (DCLK_DIV - 1)) begin
                        hub75e_dclk_out <= 1'b0;
                        sub_count       <= 0;
                        if (col_idx == width_max) begin
                            col_idx <= 12'd0;
                            state   <= S_BLANK;
                            ctrl_count <= 4'd0;
                        end else begin
                            col_idx <= col_idx + 1;
                        end
                    end else begin
                        sub_count <= sub_count + 1;
                    end
                end

                S_BLANK: begin
                    hub75e_dclk_out <= 1'b0;
                    hub75e_oe_out   <= 1'b1;
                    sr_en           <= 1'b1;
                    if (ctrl_count == BLANK_CYC[3:0] - 1) begin
                        ctrl_count <= 4'd0;
                        state <= S_LATCH;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                S_LATCH: begin
                    hub75e_lat_out <= 1'b1;
                    if (ctrl_count == LATCH_CYC[3:0] - 1) begin
                        hub75e_lat_out <= 1'b0;
                        ctrl_count  <= 4'd0;
                        disp_count  <= 16'd0;
                        disp_target <= {8'd0, t_unit} << plane;
                        sr_bit_idx  <= 6'd0;
                        sr_sub      <= 2'd0;
                        sr_clk      <= 1'b0;
                        sr_dat      <= 1'b0;
                        // v28 OVERLAP path (ABCDE only): snapshot disp_* + advance
                        if (overlap_en && !addr_mode_sr) begin
                            disp_row    <= row_idx;
                            disp_plane  <= plane;
                            if (plane == plane_max_run) begin
                                plane <= 3'd0;
                                if (row_idx == row_max) begin
                                    row_idx <= 5'd0;
                                    frame_count <= frame_count + 1;  // ← 帧边界 (overlap path)
                                    if (walk_div_count == walk_speed - 1) begin
                                        walk_div_count <= 8'd0;
                                        if (test_mode == 3'd4) begin
                                            walk_pos <= (walk_pos == row_max) ? 8'd0 : walk_pos + 1;
                                        end else if (test_mode == 3'd5) begin
                                            walk_pos <= (walk_pos == width_max[7:0]) ? 8'd0 : walk_pos + 1;
                                        end
                                    end else begin
                                        walk_div_count <= walk_div_count + 1;
                                    end
                                end else begin
                                    row_idx <= row_idx + 1;
                                end
                            end else begin
                                plane <= plane + 1;
                            end
                            state <= S_ADDR_ABCDE;
                        end else begin
                            // serial path (both SR mode and overlap_en=0 ABCDE)
                            state <= addr_mode_sr ? S_ADDR_SR : S_ADDR_ABCDE;
                        end
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                S_ADDR_ABCDE: begin
                    hub75e_lat_out  <= 1'b0;
                    addr_abcde_lat  <= (overlap_en) ? disp_row : row_idx;
                    row_displayed   <= (overlap_en) ? disp_row : row_idx;
                    if (ctrl_count == ADDR_SET_CYC[3:0] - 1) begin
                        ctrl_count <= 4'd0;
                        state      <= overlap_en ? S_OE_PRE : S_DISPLAY;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                // v28 OVERLAP: drop OE LOW, wait OE_PRE_CYC cycles (chip cache)
                S_OE_PRE: begin
                    hub75e_lat_out  <= 1'b0;
                    hub75e_oe_out   <= enable ? 1'b0 : 1'b1;
                    hub75e_dclk_out <= 1'b0;
                    if (ctrl_count == OE_PRE_CYC[3:0] - 1) begin
                        ctrl_count   <= 4'd0;
                        disp_count   <= 16'd0;
                        disp_active  <= 1'b1;
                        shift_active <= 1'b1;
                        state        <= S_PHASE;
                    end else begin
                        ctrl_count <= ctrl_count + 1;
                    end
                end

                // v28 OVERLAP: shift NEXT plane while displaying CURRENT plane
                S_PHASE: begin
                    hub75e_lat_out <= 1'b0;
                    // Display half
                    if (disp_active) begin
                        hub75e_oe_out <= enable ? 1'b0 : 1'b1;
                        if (disp_count >= disp_target) begin
                            disp_active   <= 1'b0;
                            hub75e_oe_out <= 1'b1;
                        end else begin
                            disp_count <= disp_count + 1;
                        end
                    end else begin
                        hub75e_oe_out <= 1'b1;
                    end
                    // Shift half
                    if (shift_active) begin
                        hub75e_rgb_out <= plane_rgb;
                        hub75e_rgb_out2 <= plane_rgb2;
                        if (sub_count == (DCLK_DIV/2 - 1)) begin
                            hub75e_dclk_out <= 1'b1;
                            sub_count       <= sub_count + 1;
                        end else if (sub_count == (DCLK_DIV - 1)) begin
                            hub75e_dclk_out <= 1'b0;
                            sub_count       <= 0;
                            if (col_idx == width_max) begin
                                col_idx      <= 12'd0;
                                shift_active <= 1'b0;
                            end else begin
                                col_idx <= col_idx + 1;
                            end
                        end else begin
                            sub_count <= sub_count + 1;
                        end
                    end else begin
                        hub75e_dclk_out <= 1'b0;
                    end
                    // Both done -> LATCH (v29: 跳过 S_BLANK 省 1 cyc)
                    if (!shift_active && !disp_active) begin
                        hub75e_oe_out <= 1'b1;
                        ctrl_count    <= 4'd0;
                        state <= enable ? S_LATCH : S_IDLE;
                    end
                end

                S_ADDR_SR: begin
                    sr_en <= 1'b1;
                    case (sr_sub)
                        2'd0: begin
                            sr_clk <= 1'b0;
                            sr_dat <= (sr_bit_idx[4:0] == row_idx) ? 1'b1 : 1'b0;
                            sr_sub <= 2'd1;
                        end
                        2'd1: begin sr_clk <= 1'b1; sr_sub <= 2'd2; end
                        2'd2: begin sr_clk <= 1'b0; sr_sub <= 2'd3; end
                        2'd3: begin
                            sr_sub <= 2'd0;
                            if (sr_bit_idx == 6'd31) begin
                                sr_dat        <= 1'b0;
                                row_displayed <= row_idx;
                                disp_count    <= 16'd0;
                                disp_target   <= {8'd0, t_unit} << plane;
                                state         <= S_DISPLAY;
                            end else begin
                                sr_bit_idx <= sr_bit_idx + 1;
                            end
                        end
                    endcase
                end

                S_DISPLAY: begin
                    // SR legacy 串行 display
                    hub75e_oe_out <= enable ? 1'b0 : 1'b1;
                    sr_en         <= 1'b0;
                    if (disp_count >= disp_target) begin
                        hub75e_oe_out <= 1'b1;
                        sr_en         <= 1'b1;
                        disp_count    <= 16'd0;
                        if (plane == plane_max_run) begin
                            plane <= 3'd0;
                            if (row_idx == row_max) begin
                                row_idx <= 5'd0;
                                frame_count <= frame_count + 1;  // ← 帧边界 (serial path)
                                if (walk_div_count == walk_speed - 1) begin
                                    walk_div_count <= 8'd0;
                                    if (test_mode == 3'd4) begin
                                        walk_pos <= (walk_pos == row_max) ? 8'd0 : walk_pos + 1;
                                    end else if (test_mode == 3'd5) begin
                                        walk_pos <= (walk_pos == width_max[7:0]) ? 8'd0 : walk_pos + 1;
                                    end
                                end else begin
                                    walk_div_count <= walk_div_count + 1;
                                end
                            end else begin
                                row_idx <= row_idx + 1;
                            end
                        end else begin
                            plane <= plane + 1;
                        end
                        state <= enable ? S_SHIFT : S_IDLE;
                    end else begin
                        disp_count <= disp_count + 1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule

// ===== inline angle_tracker (避免 module_ref 依赖捕获不到独立文件) =====
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
