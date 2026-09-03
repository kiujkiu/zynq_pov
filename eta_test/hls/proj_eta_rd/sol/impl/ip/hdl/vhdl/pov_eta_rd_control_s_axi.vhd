-- ==============================================================
-- Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2024.2 (64-bit)
-- Tool Version Limit: 2024.11
-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
-- 
-- ==============================================================
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity pov_eta_rd_control_s_axi is
generic (
    C_S_AXI_ADDR_WIDTH    : INTEGER := 7;
    C_S_AXI_DATA_WIDTH    : INTEGER := 32);
port (
    ACLK                  :in   STD_LOGIC;
    ARESET                :in   STD_LOGIC;
    ACLK_EN               :in   STD_LOGIC;
    AWADDR                :in   STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
    AWVALID               :in   STD_LOGIC;
    AWREADY               :out  STD_LOGIC;
    WDATA                 :in   STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
    WSTRB                 :in   STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH/8-1 downto 0);
    WVALID                :in   STD_LOGIC;
    WREADY                :out  STD_LOGIC;
    BRESP                 :out  STD_LOGIC_VECTOR(1 downto 0);
    BVALID                :out  STD_LOGIC;
    BREADY                :in   STD_LOGIC;
    ARADDR                :in   STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
    ARVALID               :in   STD_LOGIC;
    ARREADY               :out  STD_LOGIC;
    RDATA                 :out  STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
    RRESP                 :out  STD_LOGIC_VECTOR(1 downto 0);
    RVALID                :out  STD_LOGIC;
    RREADY                :in   STD_LOGIC;
    voxel                 :out  STD_LOGIC_VECTOR(63 downto 0);
    phase                 :out  STD_LOGIC_VECTOR(31 downto 0);
    n_slots               :out  STD_LOGIC_VECTOR(31 downto 0);
    axis_off_q8           :out  STD_LOGIC_VECTOR(31 downto 0);
    mirror_u              :out  STD_LOGIC_VECTOR(31 downto 0);
    pf_cols               :out  STD_LOGIC_VECTOR(31 downto 0);
    xor_out               :in   STD_LOGIC_VECTOR(63 downto 0);
    xor_out_ap_vld        :in   STD_LOGIC
);
end entity pov_eta_rd_control_s_axi;

-- ------------------------Address Info-------------------
-- Protocol Used: ap_ctrl_none
--
-- 0x00 : reserved
-- 0x04 : reserved
-- 0x08 : reserved
-- 0x0c : reserved
-- 0x10 : Data signal of voxel
--        bit 31~0 - voxel[31:0] (Read/Write)
-- 0x14 : Data signal of voxel
--        bit 31~0 - voxel[63:32] (Read/Write)
-- 0x18 : reserved
-- 0x1c : Data signal of phase
--        bit 31~0 - phase[31:0] (Read/Write)
-- 0x20 : reserved
-- 0x24 : Data signal of n_slots
--        bit 31~0 - n_slots[31:0] (Read/Write)
-- 0x28 : reserved
-- 0x2c : Data signal of axis_off_q8
--        bit 31~0 - axis_off_q8[31:0] (Read/Write)
-- 0x30 : reserved
-- 0x34 : Data signal of mirror_u
--        bit 31~0 - mirror_u[31:0] (Read/Write)
-- 0x38 : reserved
-- 0x3c : Data signal of pf_cols
--        bit 31~0 - pf_cols[31:0] (Read/Write)
-- 0x40 : reserved
-- 0x44 : Data signal of xor_out
--        bit 31~0 - xor_out[31:0] (Read)
-- 0x48 : Data signal of xor_out
--        bit 31~0 - xor_out[63:32] (Read)
-- 0x4c : Control signal of xor_out
--        bit 0  - xor_out_ap_vld (Read/COR)
--        others - reserved
-- (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)

architecture behave of pov_eta_rd_control_s_axi is
    type states is (wridle, wrdata, wrresp, wrreset, rdidle, rddata, rdreset);  -- read and write fsm states
    signal wstate  : states := wrreset;
    signal rstate  : states := rdreset;
    signal wnext, rnext: states;
    constant ADDR_VOXEL_DATA_0       : INTEGER := 16#10#;
    constant ADDR_VOXEL_DATA_1       : INTEGER := 16#14#;
    constant ADDR_VOXEL_CTRL         : INTEGER := 16#18#;
    constant ADDR_PHASE_DATA_0       : INTEGER := 16#1c#;
    constant ADDR_PHASE_CTRL         : INTEGER := 16#20#;
    constant ADDR_N_SLOTS_DATA_0     : INTEGER := 16#24#;
    constant ADDR_N_SLOTS_CTRL       : INTEGER := 16#28#;
    constant ADDR_AXIS_OFF_Q8_DATA_0 : INTEGER := 16#2c#;
    constant ADDR_AXIS_OFF_Q8_CTRL   : INTEGER := 16#30#;
    constant ADDR_MIRROR_U_DATA_0    : INTEGER := 16#34#;
    constant ADDR_MIRROR_U_CTRL      : INTEGER := 16#38#;
    constant ADDR_PF_COLS_DATA_0     : INTEGER := 16#3c#;
    constant ADDR_PF_COLS_CTRL       : INTEGER := 16#40#;
    constant ADDR_XOR_OUT_DATA_0     : INTEGER := 16#44#;
    constant ADDR_XOR_OUT_DATA_1     : INTEGER := 16#48#;
    constant ADDR_XOR_OUT_CTRL       : INTEGER := 16#4c#;
    constant ADDR_BITS         : INTEGER := 7;

    signal waddr               : UNSIGNED(ADDR_BITS-1 downto 0);
    signal wmask               : UNSIGNED(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal aw_hs               : STD_LOGIC;
    signal w_hs                : STD_LOGIC;
    signal rdata_data          : UNSIGNED(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal ar_hs               : STD_LOGIC;
    signal raddr               : UNSIGNED(ADDR_BITS-1 downto 0);
    signal AWREADY_t           : STD_LOGIC;
    signal WREADY_t            : STD_LOGIC;
    signal ARREADY_t           : STD_LOGIC;
    signal RVALID_t            : STD_LOGIC;
    -- internal registers
    signal int_voxel           : UNSIGNED(63 downto 0) := (others => '0');
    signal int_phase           : UNSIGNED(31 downto 0) := (others => '0');
    signal int_n_slots         : UNSIGNED(31 downto 0) := (others => '0');
    signal int_axis_off_q8     : UNSIGNED(31 downto 0) := (others => '0');
    signal int_mirror_u        : UNSIGNED(31 downto 0) := (others => '0');
    signal int_pf_cols         : UNSIGNED(31 downto 0) := (others => '0');
    signal int_xor_out_ap_vld  : STD_LOGIC;
    signal int_xor_out         : UNSIGNED(63 downto 0) := (others => '0');


begin
-- ----------------------- Instantiation------------------


-- ----------------------- AXI WRITE ---------------------
    AWREADY_t <=  '1' when wstate = wridle else '0';
    AWREADY   <=  AWREADY_t;
    WREADY_t  <=  '1' when wstate = wrdata else '0';
    WREADY    <=  WREADY_t;
    BRESP     <=  "00";  -- OKAY
    BVALID    <=  '1' when wstate = wrresp else '0';
    wmask     <=  (31 downto 24 => WSTRB(3), 23 downto 16 => WSTRB(2), 15 downto 8 => WSTRB(1), 7 downto 0 => WSTRB(0));
    aw_hs     <=  AWVALID and AWREADY_t;
    w_hs      <=  WVALID and WREADY_t;

    -- write FSM
    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                wstate <= wrreset;
            elsif (ACLK_EN = '1') then
                wstate <= wnext;
            end if;
        end if;
    end process;

    process (wstate, AWVALID, WVALID, BREADY)
    begin
        case (wstate) is
        when wridle =>
            if (AWVALID = '1') then
                wnext <= wrdata;
            else
                wnext <= wridle;
            end if;
        when wrdata =>
            if (WVALID = '1') then
                wnext <= wrresp;
            else
                wnext <= wrdata;
            end if;
        when wrresp =>
            if (BREADY = '1') then
                wnext <= wridle;
            else
                wnext <= wrresp;
            end if;
        when others =>
            wnext <= wridle;
        end case;
    end process;

    waddr_proc : process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ACLK_EN = '1') then
                if (aw_hs = '1') then
                    waddr <= UNSIGNED(AWADDR(ADDR_BITS-1 downto 2) & (1 downto 0 => '0'));
                end if;
            end if;
        end if;
    end process;

-- ----------------------- AXI READ ----------------------
    ARREADY_t <= '1' when (rstate = rdidle) else '0';
    ARREADY <= ARREADY_t;
    RDATA   <= STD_LOGIC_VECTOR(rdata_data);
    RRESP   <= "00";  -- OKAY
    RVALID_t  <= '1' when (rstate = rddata) else '0';
    RVALID    <= RVALID_t;
    ar_hs   <= ARVALID and ARREADY_t;
    raddr   <= UNSIGNED(ARADDR(ADDR_BITS-1 downto 0));

    -- read FSM
    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                rstate <= rdreset;
            elsif (ACLK_EN = '1') then
                rstate <= rnext;
            end if;
        end if;
    end process;

    process (rstate, ARVALID, RREADY, RVALID_t)
    begin
        case (rstate) is
        when rdidle =>
            if (ARVALID = '1') then
                rnext <= rddata;
            else
                rnext <= rdidle;
            end if;
        when rddata =>
            if (RREADY = '1' and RVALID_t = '1') then
                rnext <= rdidle;
            else
                rnext <= rddata;
            end if;
        when others =>
            rnext <= rdidle;
        end case;
    end process;

    rdata_proc : process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ACLK_EN = '1') then
                if (ar_hs = '1') then
                    rdata_data <= (others => '0');
                    case (TO_INTEGER(raddr)) is
                    when ADDR_VOXEL_DATA_0 =>
                        rdata_data <= RESIZE(int_voxel(31 downto 0), 32);
                    when ADDR_VOXEL_DATA_1 =>
                        rdata_data <= RESIZE(int_voxel(63 downto 32), 32);
                    when ADDR_PHASE_DATA_0 =>
                        rdata_data <= RESIZE(int_phase(31 downto 0), 32);
                    when ADDR_N_SLOTS_DATA_0 =>
                        rdata_data <= RESIZE(int_n_slots(31 downto 0), 32);
                    when ADDR_AXIS_OFF_Q8_DATA_0 =>
                        rdata_data <= RESIZE(int_axis_off_q8(31 downto 0), 32);
                    when ADDR_MIRROR_U_DATA_0 =>
                        rdata_data <= RESIZE(int_mirror_u(31 downto 0), 32);
                    when ADDR_PF_COLS_DATA_0 =>
                        rdata_data <= RESIZE(int_pf_cols(31 downto 0), 32);
                    when ADDR_XOR_OUT_DATA_0 =>
                        rdata_data <= RESIZE(int_xor_out(31 downto 0), 32);
                    when ADDR_XOR_OUT_DATA_1 =>
                        rdata_data <= RESIZE(int_xor_out(63 downto 32), 32);
                    when ADDR_XOR_OUT_CTRL =>
                        rdata_data(0) <= int_xor_out_ap_vld;
                    when others =>
                        NULL;
                    end case;
                end if;
            end if;
        end if;
    end process;

-- ----------------------- Register logic ----------------
    voxel                <= STD_LOGIC_VECTOR(int_voxel);
    phase                <= STD_LOGIC_VECTOR(int_phase);
    n_slots              <= STD_LOGIC_VECTOR(int_n_slots);
    axis_off_q8          <= STD_LOGIC_VECTOR(int_axis_off_q8);
    mirror_u             <= STD_LOGIC_VECTOR(int_mirror_u);
    pf_cols              <= STD_LOGIC_VECTOR(int_pf_cols);

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_voxel(31 downto 0) <= (others => '0');
            elsif (ACLK_EN = '1') then
                if (w_hs = '1' and waddr = ADDR_VOXEL_DATA_0) then
                    int_voxel(31 downto 0) <= (UNSIGNED(WDATA(31 downto 0)) and wmask(31 downto 0)) or ((not wmask(31 downto 0)) and int_voxel(31 downto 0));
                end if;
            end if;
        end if;
    end process;

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_voxel(63 downto 32) <= (others => '0');
            elsif (ACLK_EN = '1') then
                if (w_hs = '1' and waddr = ADDR_VOXEL_DATA_1) then
                    int_voxel(63 downto 32) <= (UNSIGNED(WDATA(31 downto 0)) and wmask(31 downto 0)) or ((not wmask(31 downto 0)) and int_voxel(63 downto 32));
                end if;
            end if;
        end if;
    end process;

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_phase(31 downto 0) <= (others => '0');
            elsif (ACLK_EN = '1') then
                if (w_hs = '1' and waddr = ADDR_PHASE_DATA_0) then
                    int_phase(31 downto 0) <= (UNSIGNED(WDATA(31 downto 0)) and wmask(31 downto 0)) or ((not wmask(31 downto 0)) and int_phase(31 downto 0));
                end if;
            end if;
        end if;
    end process;

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_n_slots(31 downto 0) <= (others => '0');
            elsif (ACLK_EN = '1') then
                if (w_hs = '1' and waddr = ADDR_N_SLOTS_DATA_0) then
                    int_n_slots(31 downto 0) <= (UNSIGNED(WDATA(31 downto 0)) and wmask(31 downto 0)) or ((not wmask(31 downto 0)) and int_n_slots(31 downto 0));
                end if;
            end if;
        end if;
    end process;

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_axis_off_q8(31 downto 0) <= (others => '0');
            elsif (ACLK_EN = '1') then
                if (w_hs = '1' and waddr = ADDR_AXIS_OFF_Q8_DATA_0) then
                    int_axis_off_q8(31 downto 0) <= (UNSIGNED(WDATA(31 downto 0)) and wmask(31 downto 0)) or ((not wmask(31 downto 0)) and int_axis_off_q8(31 downto 0));
                end if;
            end if;
        end if;
    end process;

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_mirror_u(31 downto 0) <= (others => '0');
            elsif (ACLK_EN = '1') then
                if (w_hs = '1' and waddr = ADDR_MIRROR_U_DATA_0) then
                    int_mirror_u(31 downto 0) <= (UNSIGNED(WDATA(31 downto 0)) and wmask(31 downto 0)) or ((not wmask(31 downto 0)) and int_mirror_u(31 downto 0));
                end if;
            end if;
        end if;
    end process;

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_pf_cols(31 downto 0) <= (others => '0');
            elsif (ACLK_EN = '1') then
                if (w_hs = '1' and waddr = ADDR_PF_COLS_DATA_0) then
                    int_pf_cols(31 downto 0) <= (UNSIGNED(WDATA(31 downto 0)) and wmask(31 downto 0)) or ((not wmask(31 downto 0)) and int_pf_cols(31 downto 0));
                end if;
            end if;
        end if;
    end process;

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_xor_out <= (others => '0');
            elsif (ACLK_EN = '1') then
                if (xor_out_ap_vld = '1') then
                    int_xor_out <= UNSIGNED(xor_out);
                end if;
            end if;
        end if;
    end process;

    process (ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESET = '1') then
                int_xor_out_ap_vld <= '0';
            elsif (ACLK_EN = '1') then
                if (xor_out_ap_vld = '1') then
                    int_xor_out_ap_vld <= '1';
                elsif (ar_hs = '1' and raddr = ADDR_XOR_OUT_CTRL) then
                    int_xor_out_ap_vld <= '0'; -- clear on read
                end if;
            end if;
        end if;
    end process;


-- ----------------------- Memory logic ------------------

end architecture behave;
