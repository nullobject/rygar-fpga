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

use work.rygar.all;

-- Generates the character tilemap.
--
-- The character tilemap is a 32x32 grid of 8x8 tiles. The CPU updates the
-- state of the tilemap by reading and writing data to the character RAM. Each
-- tile in RAM is represented by two bytes, a low and high byte, which contains
-- the tile code and color data.
--
-- The tile code is a 10-bit value, and is used to look up the actual pixel
-- data stored in the tile ROM. The pixel data for each 8x8 tile in the ROM is
-- represented by four bitplanes, and each tile takes up exactly 32 bytes (8
-- bytes per bitplane).
entity char_tilemap is
  port (
    reset : in std_logic;

    -- input clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- char RAM
    ram_cs   : in std_logic;
    ram_addr : in std_logic_vector(CHAR_RAM_ADDR_WIDTH-1 downto 0);
    ram_din  : in std_logic_vector(7 downto 0);
    ram_dout : out std_logic_vector(7 downto 0);
    ram_we   : in std_logic;

    -- horizontal and vertical counter
    hcnt : in unsigned(7 downto 0);
    vcnt : in unsigned(7 downto 0);

    -- palette index output
    data : out std_logic_vector(7 downto 0);

    -- debug output
    debug : out std_logic_vector(5 downto 0)
  );
end char_tilemap;

architecture arch of char_tilemap is
  constant COLS : natural := 32;
  constant ROWS : natural := 32;

  type state_type is (FETCH_LOW_BYTE_STATE, FETCH_HIGH_BYTE_STATE, LATCH_STATE);

  -- state
  signal state      : state_type;
  signal next_state : state_type;

  -- char RAM
  signal tile_ram_addr : std_logic_vector(CHAR_RAM_ADDR_WIDTH-1 downto 0);
  signal tile_ram_dout : std_logic_vector(7 downto 0);

  -- char ROM
  signal tile_rom_addr      : std_logic_vector(CHAR_ROM_ADDR_WIDTH-1 downto 0);
  signal next_tile_rom_addr : std_logic_vector(CHAR_ROM_ADDR_WIDTH-1 downto 0);
  signal tile_rom_dout      : std_logic_vector(7 downto 0);

  signal high_byte      : std_logic_vector(7 downto 0);
  signal next_high_byte : std_logic_vector(7 downto 0);
  signal low_byte       : std_logic_vector(7 downto 0);
  signal next_low_byte  : std_logic_vector(7 downto 0);

  -- tile column and row
  alias col : unsigned(4 downto 0) is hcnt(7 downto 3);
  alias row : unsigned(4 downto 0) is vcnt(7 downto 3);

  -- tile offset in pixels
  alias offset_x : unsigned(2 downto 0) is hcnt(2 downto 0);
  alias offset_y : unsigned(2 downto 0) is vcnt(2 downto 0);

  -- the color is represented by the 4 MSBs of the high byte
  alias color : std_logic_vector(3 downto 0) is high_byte(7 downto 4);
begin
  -- character RAM (2kB)
  tile_ram : entity work.dual_port_ram
  generic map (ADDR_WIDTH => CHAR_RAM_ADDR_WIDTH)
  port map (
    clk_a  => clk,
    cen_a  => ram_cs,
    addr_a => ram_addr,
    din_a  => ram_din,
    dout_a => ram_dout,
    we_a   => ram_we,
    clk_b  => clk,
    addr_b => tile_ram_addr,
    dout_b => tile_ram_dout
  );

  -- tile ROM (32kB)
  tile_rom : entity work.single_port_rom
  generic map (ADDR_WIDTH => CHAR_ROM_ADDR_WIDTH, INIT_FILE => "cpu_8k.mif")
  port map (
    clk  => clk,
    addr => tile_rom_addr,
    dout => tile_rom_dout
  );

  -- state machine synchronous process
  sync_proc : process(clk, reset)
  begin
    if reset = '1' then
      state <= FETCH_LOW_BYTE_STATE;
    elsif rising_edge(clk) then
      state         <= next_state;
      low_byte      <= next_low_byte;
      high_byte     <= next_high_byte;
      -- tile_rom_addr <= next_tile_rom_addr;
    end if;
  end process;

  -- state machine combinatorial process
  comb_proc : process(state, tile_ram_dout, col, row, high_byte, low_byte)
    variable index : unsigned(9 downto 0);
    variable tile_code : unsigned(9 downto 0);
  begin
    next_state         <= state;
    next_low_byte      <= low_byte;
    next_high_byte     <= high_byte;
    -- next_tile_rom_addr <= tile_rom_addr;

    -- calculate index of the current tile
    index := row*COLS + col;

    case state is
      when FETCH_LOW_BYTE_STATE =>
        next_state <= FETCH_HIGH_BYTE_STATE;

        -- fetch low byte from the tile RAM
        tile_ram_addr <= std_logic_vector('0' & index);
        next_low_byte <= tile_ram_dout;

      when FETCH_HIGH_BYTE_STATE =>
        next_state <= LATCH_STATE;

        -- fetch high byte from the tile RAM
        tile_ram_addr <= std_logic_vector('1' & index);
        next_high_byte <= tile_ram_dout;

      when LATCH_STATE =>
        next_state <= FETCH_LOW_BYTE_STATE;

        -- the tile code is a 10-bit value, represented by the low byte and the
        -- two LSBs of the high byte
        tile_code := unsigned(high_byte(1 downto 0) & low_byte);

        -- fetch pixel data from the tile ROM
        next_tile_rom_addr <= std_logic_vector(tile_code & offset_y & offset_x(2 downto 1));
    end case;
  end process;

  process(clk)
    variable pixel : std_logic_vector(3 downto 0);
  begin
    if cen = '1' then
      tile_rom_addr <= std_logic_vector(row & col & offset_y & offset_x(2 downto 1));

      -- each byte in the tile ROM contains two 4-bit pixels
      if offset_x(0) = '1' then
        pixel := tile_rom_dout(7 downto 4);
      else
        pixel := tile_rom_dout(3 downto 0);
      end if;

      data <= color & pixel;

      -- debug <= tile_code(9 downto 4);
      debug <= pixel & pixel(3 downto 2);
    end if;
  end process;
end architecture;
