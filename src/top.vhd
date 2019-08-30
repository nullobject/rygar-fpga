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
  -- clock signals
  signal rom_clk : std_logic;
  signal sys_clk : std_logic;
  signal reset   : std_logic;

  -- SDRAM signals
  signal sdram_addr  : unsigned(SDRAM_INPUT_ADDR_WIDTH-1 downto 0);
  signal sdram_din   : std_logic_vector(SDRAM_INPUT_DATA_WIDTH-1 downto 0) := (others => '0');
  signal sdram_dout  : std_logic_vector(SDRAM_OUTPUT_DATA_WIDTH-1 downto 0);
  signal sdram_we    : std_logic;
  signal sdram_ready : std_logic;
  signal sdram_valid : std_logic;

  -- IOCTL signals
  signal ioctl_addr : unsigned(IOCTL_ADDR_WIDTH-1 downto 0);
  signal ioctl_data : std_logic_vector(IOCTL_DATA_WIDTH-1 downto 0);
  signal ioctl_we   : std_logic;

  -- sync signals
  signal hsync : std_logic;
  signal vsync : std_logic;
  signal csync : std_logic;
begin
  -- generate the clock signals
  my_pll : entity pll.pll
  port map (
    refclk   => clk,
    rst      => '0',
    outclk_0 => SDRAM_CLK,
    outclk_1 => rom_clk,
    outclk_2 => sys_clk,
    locked   => open
  );

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
    -- clock signals
    clk   => rom_clk,
    reset => reset,

    -- IO interface
    addr  => sdram_addr,
    din   => sdram_din,
    dout  => sdram_dout,
    ready => sdram_ready,
    valid => sdram_valid,
    we    => sdram_we,

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
    -- clock signals
    rom_clk => rom_clk,
    sys_clk => sys_clk,
    reset   => reset,

    -- SDRAM interface
    sdram_addr  => sdram_addr,
    sdram_din   => sdram_din,
    sdram_dout  => sdram_dout,
    sdram_we    => sdram_we,
    sdram_valid => sdram_valid,
    sdram_ready => sdram_ready,

    -- IOCTL interface
    ioctl_addr => ioctl_addr,
    ioctl_data => ioctl_data,
    ioctl_we   => ioctl_we,

    -- video signals
    hsync => hsync,
    vsync => vsync,
    r     => vga_r,
    g     => vga_g,
    b     => vga_b
  );

  -- set composite sync
  vga_csync <= not (hsync xor vsync);
end architecture arch;
