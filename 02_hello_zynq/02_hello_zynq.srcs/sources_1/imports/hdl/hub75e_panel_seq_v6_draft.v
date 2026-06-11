//-----------------------------------------------------------------------------
// hub75e_panel_seq_v6_draft.v - 128x64(x2) HUB75E panel PL driver (BCM)
//
// v6 (DRAFT, 2026-06-11): AXI4 read master DMA + BRAM double buffer + fake angle
//   1. module rename v5 -> v6 (BD module_ref 缓存坑, 必须 rename + recreate cell)
//   2. m_axi: AXI4 read-only master, 32-bit data, 256-beat INCR burst (1 KB),
//      单 outstanding. 64 KB slice frame = 16384 word = 64 burst, 1 KB 对齐
//      (SLICE_BASE 64 KB 对齐时) 永不跨 4 KB 边界. 从 DDR 自取 slice 帧:
//      word     0.. 4095 -> fb_top  (panel 1 上半)
//      word  4096.. 8191 -> fb_bot  (panel 1 下半)
//      word  8192..12287 -> fb_top2 (panel 2 上半)
//      word 12288..16383 -> fb_bot2 (panel 2 下半)
//      每 word 低 24-bit = RGB (R[7:0] G[15:8] B[23:16]), 高 8-bit 丢弃 (同 lite 写)
//   3. 4x XPM SDPRAM 深度 4096 -> 8192 (ADDR 12 -> 13 bit), addr[12] = buffer.
//      DMA 写 fetch buf (= ~disp_buf); 显示 FSM 读 disp_buf.
//      dma_en=0 时显示强制 buf 0, AXI-Lite 写口照旧只写 buf 0 → 行为与 v5 等价.
//   4. 假角度计数器: 每 reg_angle_period 个 aclk slice_idx+1, 到 reg_n_slices wrap 0.
//      sensor_pulse input 预留 (angle_tracker 后续接入, 见 "ANGLE SOURCE" 标记).
//   5. DMA 控制流 (dma_en=1 循环):
//      latch slice_idx → 64 burst 读 base + slice*65536 共 64KB 进 fetch buf
//      → 等显示帧边界 (frame_count 自增) → 翻 disp_buf → latch 新 slice_idx 再取.
//   6. 新寄存器 (写 decode awaddr[4:2] 3-bit 扩成 [5:2] 4-bit, 读同步扩):
//      0x18 SLICE_BASE   DDR 字节基址 (要求 64 KB 对齐)
//      0x1C ANGLE_PERIOD aclk cycles per slice (0 = 角度计数器停在 slice 0)
//      0x20 N_SLICES     slice 总数 (0 当 1)
//      0x24 RO: {err_cnt[3:0], dma_state[3:0], 8'b0, cur_slice_idx[15:0]}
//      CTRL bit7 = dma_en
//   7. aresetn 低 DMA FSM 回 IDLE (假设 interconnect 同复位); RRESP 非 OKAY 只
//      计数 (0x24[31:28] 饱和 4-bit), 不卡死, 继续下一 burst.
//
// 注意:
//   - m_axi 必须与 s_axi_aclk 同时钟 (单时钟设计, BD 里 HP 口/SMC ACLK 接同一 FCLK).
//   - dma_en=1 期间 AXI-Lite 仍可写 fb 区, 但只写 buf 0 (会撞 disp 或 fetch buf,
//     DMA 模式下 ARM 不应再走 lite 写 fb). lite fb 写当拍 m_axi_rready 拉低 1 cyc
//     避免 BRAM 写口冲突 (lite 优先, DMA 只延后不丢 beat).
//   - 本文件是整体替换 hub75e_panel_seq.v 用的完整模块, **不要**与原文件同时加入
//     工程编译. 原文件尾部 legacy sdp_bram (无人实例化) 已删, 替换时一并消失.
//
// AXI-Lite 寄存器:
//   0x00 CTRL   [0]=en [3:1]=mode [4]=addr_sr [5]=use_fb [6]=overlap_en
//               [7]=dma_en (v6) [12:8]=addr_bits
//   0x04 COLOR  [23:0] 顶半 24-bit RGB (R[7:0] | G[15:8] | B[23:16])
//   0x08 PARAM  [11:0]=width-1 [23:16]=stripe_w [31:24]=walk_speed
//   0x0C STATUS [0]=running [12:8]=cur_addr [15:13]=cur_plane [31:16]=frame_count
//   0x10 COLOR_BOT [23:0] 底半 24-bit RGB (0 时跟 COLOR 同色)
//   0x14 BCM_TUNIT [7:0]=T_unit [11:8]=bcm_planes
//   0x18 SLICE_BASE / 0x1C ANGLE_PERIOD / 0x20 N_SLICES / 0x24 DMA_STATUS (v6 新增)
//
// AXI-Lite 地址布局 (17-bit, 128 KB) 不变:
//   addr[15]=0 : 寄存器区 (v6: addr[5:2] 选 reg, 0x00-0x27)
//   addr[15]=1 : framebuffer 区, {addr[16], addr[14]} 选 4 BRAM 之一,
//                addr[13:2] = pixel index 0..4095, 永远写 buffer 0
//
// FM6124 datasheet (V1.0 / S&CIC1501):
//   FCLK max 30 MHz, TWCLK >= 20 ns, TWLE >= 20 ns, TWOE >= 30 ns, setup/hold >= 5 ns
//-----------------------------------------------------------------------------

`timescale 1ns / 1ps

module hub75e_panel_seq_v6 #(
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
    parameter integer FB_DEPTH     = 8192  // (legacy compat; v6 BRAM 深度 8192 = 2 buf x 4096)
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
    input  wire        sensor_pulse,

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
                    4'd9: s_axi_rdata <= dma_status_word;    // v6 0x24 RO
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
    reg [31:0] angle_div;
    reg [15:0] slice_idx_live;
    // 防 sensor_pulse 现在没人用被 port 优化告警 (综合会剪掉, 无副作用)
    wire       sensor_pulse_unused = sensor_pulse;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            angle_div      <= 32'd0;
            slice_idx_live <= 16'd0;
        end else begin
            if (reg_angle_period == 32'd0) begin
                angle_div      <= 32'd0;
                slice_idx_live <= 16'd0;
            end else if (angle_div >= reg_angle_period - 32'd1) begin
                angle_div      <= 32'd0;
                slice_idx_live <= (slice_idx_live >= n_slices_eff - 16'd1)
                                  ? 16'd0 : slice_idx_live + 16'd1;
            end else begin
                angle_div <= angle_div + 32'd1;
            end
        end
    end

    //==========================================================================
    // v6: DMA FSM (AXI4 read master, 单 outstanding)
    //
    //   D_IDLE  : dma_en=0 停 (disp_buf 归 0). dma_en=1 → latch slice_idx_live,
    //             发第一个 AR → D_AR
    //   D_AR    : arvalid hold 到 arready → D_R (dma_en 已掉 → D_DRAIN)
    //   D_R     : 收 256 beat 写 fetch buf BRAM. rlast:
    //               burst 63 → D_WAIT_FR; 否则 araddr+=1024 再发 AR → D_AR
    //             中途 dma_en 掉 → D_DRAIN (剩余 beat 丢弃, 不写 BRAM)
    //   D_WAIT_FR: 等 frame_count 自增 (帧边界) 或显示 FSM 在 S_IDLE (没人产帧,
    //             避免死等) → 翻 disp_buf, latch 新 slice_idx_live → D_AR
    //   D_DRAIN : 把 outstanding burst 的 R beat 收完 (AXI 不允许弃 txn) → D_IDLE
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
    reg [5:0]  burst_cnt;       // 0..63 (64 x 1KB burst = 64KB)
    reg [13:0] dma_word;        // 0..16383 整帧 word index
    reg        disp_buf;        // 显示 FSM 用的 buffer; fetch buf = ~disp_buf
    reg [3:0]  dma_err_count;   // RRESP 非 OKAY 饱和计数
    reg [15:0] frame_count_q;   // 帧边界检测 (frame_count 在显示 FSM 自增)

    wire frame_tick = (frame_count != frame_count_q);
    wire fetch_buf  = ~disp_buf;

    // R 通道握手: D_R 收数 (lite fb 写当拍让位), D_DRAIN 只收不写
    assign m_axi_rready = (dstate == D_DRAIN) ||
                          ((dstate == D_R) && !lite_fb_we_any);
    wire dma_beat = m_axi_rvalid && m_axi_rready;
    wire dma_we   = (dstate == D_R) && dma_beat;

    // word[13:12] 选 4 BRAM 之一 (帧布局: top, bot, top2, bot2 各 4096 word)
    wire dma_we_top  = dma_we && (dma_word[13:12] == 2'b00);
    wire dma_we_bot  = dma_we && (dma_word[13:12] == 2'b01);
    wire dma_we_top2 = dma_we && (dma_word[13:12] == 2'b10);
    wire dma_we_bot2 = dma_we && (dma_word[13:12] == 2'b11);

    // 0x24 RO: {err[31:28], dma_state[27:24], 8'b0, cur_slice_idx[15:0]}
    wire [31:0] dma_status_word = {dma_err_count, dstate, 8'b0, slice_idx_live};

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            dstate        <= D_IDLE;
            m_axi_arvalid <= 1'b0;
            m_axi_araddr  <= 32'd0;
            fetch_slice   <= 16'd0;
            burst_cnt     <= 6'd0;
            dma_word      <= 14'd0;
            disp_buf      <= 1'b0;
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
                        burst_cnt     <= 6'd0;
                        dma_word      <= 14'd0;
                        m_axi_araddr  <= reg_slice_base + {slice_idx_live, 16'b0};
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
                            end else if (burst_cnt == 6'd63) begin
                                burst_cnt <= 6'd0;
                                dstate    <= D_WAIT_FR; // 64KB 收完, 等帧边界
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
                        burst_cnt     <= 6'd0;
                        dma_word      <= 14'd0;
                        m_axi_araddr  <= reg_slice_base + {slice_idx_live, 16'b0};
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
    wire [12:0] fb_raddr = {disp_buf_eff, row_idx[4:0], col_idx[6:0]};
    wire [23:0] fb_top_dout, fb_bot_dout;
    wire [23:0] fb_top2_dout, fb_bot2_dout;

    //==========================================================================
    // v6: BRAM 写口仲裁 (port A)
    //   - DMA beat (D_R) 写 fetch buf {~disp_buf, word[11:0]}
    //   - AXI-Lite 写 buf 0 {1'b0, addr[13:2]} (优先; 当拍 rready 已拉低,
    //     所以 dma_we_* 和 fb_*_we_main 不可能同拍同 BRAM 都为 1)
    //==========================================================================
    wire        fbw_top_we    = dma_we_top  | fb_top_we_main;
    wire [12:0] fbw_top_addr  = dma_we_top  ? {fetch_buf, dma_word[11:0]} : {1'b0, fb_waddr_main};
    wire [23:0] fbw_top_data  = dma_we_top  ? m_axi_rdata[23:0] : fb_wdata_main;
    wire        fbw_bot_we    = dma_we_bot  | fb_bot_we_main;
    wire [12:0] fbw_bot_addr  = dma_we_bot  ? {fetch_buf, dma_word[11:0]} : {1'b0, fb_waddr_main};
    wire [23:0] fbw_bot_data  = dma_we_bot  ? m_axi_rdata[23:0] : fb_wdata_main;
    wire        fbw_top2_we   = dma_we_top2 | fb_top2_we_main;
    wire [12:0] fbw_top2_addr = dma_we_top2 ? {fetch_buf, dma_word[11:0]} : {1'b0, fb_waddr_main};
    wire [23:0] fbw_top2_data = dma_we_top2 ? m_axi_rdata[23:0] : fb_wdata_main;
    wire        fbw_bot2_we   = dma_we_bot2 | fb_bot2_we_main;
    wire [12:0] fbw_bot2_addr = dma_we_bot2 ? {fetch_buf, dma_word[11:0]} : {1'b0, fb_waddr_main};
    wire [23:0] fbw_bot2_data = dma_we_bot2 ? m_axi_rdata[23:0] : fb_wdata_main;

    // Xilinx XPM macro: 100% defined behavior, Vivado 不会 swap/优化掉
    // v6: ADDR 12->13 bit, MEMORY_SIZE 98304 -> 196608 (8192 entries x 24-bit,
    //     双 buffer, 每 BRAM 多用 ~3 个 RAMB36; 4 BRAM 共 ~24 RAMB36, 7020 有 140)
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

    // v34h plane_ext + 5'd16 写法 (勿改, v34i byte-slice 写法会被 Vivado 优化掉)
    wire [4:0] plane_ext = {2'b0, plane};
    wire r1_bit = pattern_24_top[plane_ext];
    wire g1_bit = pattern_24_top[plane_ext + 5'd8];
    wire b1_bit = pattern_24_top[plane_ext + 5'd16];
    wire r2_bit = pattern_24_bot[plane_ext];
    wire g2_bit = pattern_24_bot[plane_ext + 5'd8];
    wire b2_bit = pattern_24_bot[plane_ext + 5'd16];
    wire [5:0] plane_rgb = {b2_bit, g2_bit, r2_bit, b1_bit, g1_bit, r1_bit};
    wire r1_bit2 = pattern_24_top2[plane_ext];
    wire g1_bit2 = pattern_24_top2[plane_ext + 5'd8];
    wire b1_bit2 = pattern_24_top2[plane_ext + 5'd16];
    wire r2_bit2 = pattern_24_bot2[plane_ext];
    wire g2_bit2 = pattern_24_bot2[plane_ext + 5'd8];
    wire b2_bit2 = pattern_24_bot2[plane_ext + 5'd16];
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
    // 主显示 FSM (BCM: 每 row 跑 N plane) — v6 未改动 (只有 fb_raddr 宽度在外面变)
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
