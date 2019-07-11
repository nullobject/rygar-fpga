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
-- tilemap by writing data the character RAM. Each tile in the character RAM is
-- represented by two bytes, low byte and a high byte, which contain the tile
-- code and color data.
--
-- The tile code is a 10-bit value, which is used to look up the tile pixel
-- data stored in the tile ROM. The pixel data for each 8x8 tile in the ROM is
-- made up of four bitplanes, and each tile takes up exactly 32 bytes (8 bytes
-- per bitplane).
entity char_tilemap is
  port (
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
    data : out std_logic_vector(7 downto 0)
  );
end char_tilemap;

architecture arch of char_tilemap is
  constant COLS : natural := 32;
  constant ROWS : natural := 32;

  -- char RAM
  signal tile_ram_addr : std_logic_vector(CHAR_RAM_ADDR_WIDTH-1 downto 0);
  signal tile_ram_dout : std_logic_vector(7 downto 0);

  -- char ROM
  signal tile_rom_addr : std_logic_vector(CHAR_ROM_ADDR_WIDTH-1 downto 0);
  signal tile_rom_dout : std_logic_vector(7 downto 0);

  signal hi_byte, lo_byte : std_logic_vector(7 downto 0);

  signal code  : unsigned(9 downto 0);
  signal pixel : std_logic_vector(3 downto 0);
  signal color : std_logic_vector(3 downto 0);

  -- tile column and row aliases
  alias col : unsigned(4 downto 0) is hcnt(7 downto 3);
  alias row : unsigned(4 downto 0) is vcnt(7 downto 3);
begin
  -- character tile RAM
  tile_ram : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH_A => CHAR_RAM_ADDR_WIDTH,
    ADDR_WIDTH_B => CHAR_RAM_ADDR_WIDTH
  )
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

  -- character tile ROM
  tile_rom : entity work.single_port_rom
  generic map (ADDR_WIDTH => CHAR_ROM_ADDR_WIDTH, INIT_FILE => "cpu_8k.mif")
  port map (
    clk  => clk,
    addr => tile_rom_addr,
    dout => tile_rom_dout
  );

  -- Fetch tile data from the character RAM.
  --
  -- The data for each tile needs to be fetched *before* rendering it to the
  -- display. This means that we need to be reading the next tile, as the
  -- current one is being rendered.
  fetch_tile : process(clk)
    variable offset_x : natural range 0 to 7;
  begin
    offset_x := to_integer(hcnt(2 downto 0));

    if rising_edge(clk) then
      if cen = '1' then
        case offset_x is
          -- fetch high byte
          when 3 =>
            tile_ram_addr <= std_logic_vector('1' & row & col);

          -- latch high byte
          when 4 =>
            hi_byte <= tile_ram_dout;

          -- fetch low byte
          when 5 =>
            tile_ram_addr <= std_logic_vector('0' & row & col);

          -- latch low byte
          when 6 =>
            lo_byte <= tile_ram_dout;

          -- latch tile data
          when 7 =>
            color <= hi_byte(7 downto 4);
            code <= unsigned(hi_byte(1 downto 0) & lo_byte);

          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- Fetch pixel data from the character ROM.
  --
  -- Every byte in the character ROM represents two pixels, each with four
  -- bitplanes.
  fetch_bitplane : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        tile_rom_addr <= std_logic_vector(code & vcnt(2 downto 0) & hcnt(2 downto 1));

        -- select the low/high pixel
        if hcnt(0) = '0' then
          pixel <= tile_rom_dout(3 downto 0);
        else
          pixel <= tile_rom_dout(7 downto 4);
        end if;
      end if;
    end if;
  end process;

  data <= color & pixel;
end architecture;
