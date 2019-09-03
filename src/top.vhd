-- Copyright (c) 2019 Josh Bassett
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;

use work.rygar.all;

entity top is
  port (
    -- 50MHz reference clock
    clk : in std_logic;

    -- VGA signals
    vga_r     : out std_logic_vector(5 downto 0);
    vga_g     : out std_logic_vector(5 downto 0);
    vga_b     : out std_logic_vector(5 downto 0);
    vga_csync : out std_logic;

    -- buttons
    key : in std_logic_vector(1 downto 0);

    -- SDRAM interface
    SDRAM_A    : out unsigned(SDRAM_ADDR_WIDTH-1 downto 0);
    SDRAM_BA   : out unsigned(SDRAM_BANK_WIDTH-1 downto 0);
    SDRAM_DQ   : inout std_logic_vector(SDRAM_DATA_WIDTH-1 downto 0);
    SDRAM_CLK  : out std_logic;
    SDRAM_CKE  : out std_logic;
    SDRAM_nCS  : out std_logic;
    SDRAM_nRAS : out std_logic;
    SDRAM_nCAS : out std_logic;
    SDRAM_nWE  : out std_logic;
    SDRAM_DQML : out std_logic;
    SDRAM_DQMH : out std_logic
  );
end top;

architecture arch of top is
  constant TILE_ROM_SIZE : natural := 163840;

  type state_t is (INIT, PRELOAD, LOAD, IDLE);

  signal reset : std_logic;

  -- clock signals
  signal sys_clk : std_logic;
  signal cen_4   : std_logic;

  -- state signals
  signal state, next_state : state_t;

  -- counters
  signal data_counter : natural range 0 to TILE_ROM_SIZE-1;

  -- SDRAM signals
  signal sdram_addr  : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal sdram_din   : std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
  signal sdram_dout  : std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
  signal sdram_we    : std_logic;
  signal sdram_ack   : std_logic;
  signal sdram_ready : std_logic;
  signal sdram_valid : std_logic;

  -- IOCTL signals
  signal ioctl_addr     : unsigned(IOCTL_ADDR_WIDTH-1 downto 0);
  signal ioctl_data     : byte_t;
  signal ioctl_wr       : std_logic;
  signal ioctl_download : std_logic;

  -- tile ROM signals
  signal tile_rom_addr : unsigned(ilog2(TILE_ROM_SIZE)-1 downto 0);
  signal tile_rom_data : byte_t;

  -- sync signals
  signal hsync : std_logic;
  signal vsync : std_logic;
  signal csync : std_logic;

  -- RGB signals
  signal r : std_logic_vector(COLOR_DEPTH_R-1 downto 0);
  signal g : std_logic_vector(COLOR_DEPTH_G-1 downto 0);
  signal b : std_logic_vector(COLOR_DEPTH_B-1 downto 0);
begin
  -- generate the clock signals
  my_pll : entity pll.pll
  port map (
    refclk   => clk,
    rst      => '0',
    outclk_0 => sys_clk,
    outclk_1 => SDRAM_CLK,
    locked   => open
  );

  -- generate a 4MHz clock enable signal
  clock_divider_4 : entity work.clock_divider
  generic map (DIVISOR => 12)
  port map (clk => sys_clk, cen => cen_4);

  -- Generate a reset pulse after powering on, or when KEY0 is pressed.
  --
  -- The Z80 needs to be reset after powering on, otherwise it may load garbage
  -- data from the address and data buses.
  reset_gen : entity work.reset_gen
  port map (
    clk  => sys_clk,
    rin  => not key(0),
    rout => reset
  );

  -- SDRAM controller
  sdram : entity work.sdram
  generic map (CLK_FREQ => 48.0)
  port map (
    reset => reset,
    clk   => sys_clk,

    -- IO interface
    addr  => sdram_addr,
    din   => sdram_din,
    dout  => sdram_dout,
    we    => sdram_we,
    ack   => sdram_ack,
    ready => sdram_ready,
    valid => sdram_valid,

    -- SDRAM interface
    sdram_a     => SDRAM_A,
    sdram_ba    => SDRAM_BA,
    sdram_dq    => SDRAM_DQ,
    sdram_cke   => SDRAM_CKE,
    sdram_cs_n  => SDRAM_nCS,
    sdram_ras_n => SDRAM_nRAS,
    sdram_cas_n => SDRAM_nCAS,
    sdram_we_n  => SDRAM_nWE,
    sdram_dqml  => SDRAM_DQML,
    sdram_dqmh  => SDRAM_DQMH
  );

  -- the actual game
  game : entity work.game
  port map (
    reset => reset,
    clk   => sys_clk,

    -- SDRAM interface
    sdram_addr  => sdram_addr,
    sdram_din   => sdram_din,
    sdram_dout  => sdram_dout,
    sdram_we    => sdram_we,
    sdram_ack   => sdram_ack,
    sdram_valid => sdram_valid,
    sdram_ready => sdram_ready,

    -- IOCTL interface
    ioctl_addr     => ioctl_addr,
    ioctl_data     => ioctl_data,
    ioctl_wr       => ioctl_wr,
    ioctl_download => ioctl_download,

    -- video signals
    hsync  => hsync,
    vsync  => vsync,
    hblank => open,
    vblank => open,

    -- RGB signals
    r => r,
    g => g,
    b => b
  );

  -- tile ROM
  tile_rom : entity work.single_port_rom
  generic map (
    ADDR_WIDTH => ilog2(TILE_ROM_SIZE),
    INIT_FILE  => "rom/tiles.mif"
  )
  port map (
    clk  => sys_clk,
    addr => tile_rom_addr,
    dout => tile_rom_data
  );

  -- state machine
  fsm : process (state, data_counter)
  begin
    next_state <= state;

    case state is
      when INIT =>
        if data_counter = TILE_ROM_SIZE-1 then
          next_state <= PRELOAD;
        end if;

      -- preload the byte from the tile ROM
      when PRELOAD =>
        next_state <= LOAD;

      when LOAD =>
        if data_counter = TILE_ROM_SIZE-1 then
          next_state <= IDLE;
        end if;

      when IDLE =>
        -- do nothing
    end case;
  end process;

  -- latch the next state
  latch_next_state : process (sys_clk, reset)
  begin
    if reset = '1' then
      state <= INIT;
    elsif rising_edge(sys_clk) then
      if cen_4 = '1' then
        state <= next_state;
      end if;
    end if;
  end process;

  -- update the data counter
  update_data_counter : process (sys_clk, reset)
  begin
    if reset = '1' then
      data_counter <= 0;
    elsif rising_edge(sys_clk) then
      if cen_4 = '1' then
        if state /= next_state then -- state changing
          data_counter <= 0;
        else
          data_counter <= data_counter + 1;
        end if;
      end if;
    end if;
  end process;

  -- write ROM data
  write_rom_data : process (sys_clk)
  begin
    if rising_edge(sys_clk) then
      ioctl_wr <= '0';

      if cen_4 = '1' and state = LOAD then
        ioctl_addr <= resize(tile_rom_addr, ioctl_addr'length);
        ioctl_data <= tile_rom_data;
        ioctl_wr   <= '1';
      end if;
    end if;
  end process;

  tile_rom_addr <= to_unsigned(data_counter, tile_rom_addr'length);

  ioctl_download <= '1' when state = LOAD else '0';

  -- set composite sync
  vga_csync <= not (hsync xor vsync);

  -- set RGB signals
  vga_r <= r & r(3 downto 2);
  vga_g <= g & g(3 downto 2);
  vga_b <= b & b(3 downto 2);
end architecture arch;
