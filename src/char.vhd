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

-- The character layer is a 32x32 grid of 8x8 tiles. It is used to render
-- things like the logo, score, playfield, and other static graphics.
--
-- This tile data is stored in the character RAM. Each tile is represented by
-- two bytes, a high byte and a low byte, which contain the tile code and
-- colour data. The CPU updates the tilemap by writing to the character RAM.
--
-- The tile code is a 10-bit value, which is used to look up the tile pixel
-- data stored in the tile ROM. The pixel data for each 8x8 tile in the ROM is
-- made up of four bitplanes, and each tile takes up exactly 32 bytes (8 bytes
-- per bitplane).
entity char is
  port (
    -- input clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- char RAM
    ram_cs   : in std_logic;
    ram_addr : in std_logic_vector(CHAR_RAM_ADDR_WIDTH-1 downto 0);
    ram_din  : in byte_t;
    ram_dout : out byte_t;
    ram_we   : in std_logic;

    -- current position
    pos : in position_t;

    -- palette index output
    data : out byte_t
  );
end char;

architecture arch of char is
  constant COLS : natural := 32;
  constant ROWS : natural := 32;

  -- column and row aliases
  alias col : unsigned(4 downto 0) is pos.x(7 downto 3);
  alias row : unsigned(4 downto 0) is pos.y(7 downto 3);

  -- char RAM
  signal char_ram_addr_b : std_logic_vector(CHAR_RAM_ADDR_WIDTH-1 downto 0);
  signal char_ram_dout_b : byte_t;

  -- char ROM
  signal char_rom_addr : std_logic_vector(CHAR_ROM_ADDR_WIDTH-1 downto 0);
  signal char_rom_dout : byte_t;

  -- registers
  signal hi_byte : byte_t;
  signal lo_byte : byte_t;
  signal code    : unsigned(9 downto 0);
  signal pixel   : std_logic_vector(3 downto 0);
  signal color   : std_logic_vector(3 downto 0);
begin
  -- The character RAM (2kB) contains the code and colour for each tile in the
  -- 32x32 tilemap. The tile code is used to look up the actual pixel data in
  -- the character tile ROM.
  --
  -- It has been implemented as a dual-port RAM because both the CPU and the
  -- graphics pipeline need to access the RAM concurrently.
  --
  -- This differs from the original arcade hardware, which only contains
  -- a single-port character RAM. Using a dual-port RAM means we can simplify
  -- things by doing away with all additional logic required to coordinate
  -- access to the RAM.
  char_ram : entity work.dual_port_ram
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
    addr_b => char_ram_addr_b,
    dout_b => char_ram_dout_b
  );

  -- The character tile ROM contains the pixel data for the tiles.
  --
  -- Each 8x8 tile contains four bitplanes, and each bitplane takes up eight
  -- bytes (one byte per row). This means that every tile takes up exactly 32
  -- bytes in the ROM.
  char_tile_rom : entity work.single_port_rom
  generic map (
    ADDR_WIDTH => CHAR_ROM_ADDR_WIDTH,
    INIT_FILE => "cpu_8k.mif"
  )
  port map (
    clk  => clk,
    addr => char_rom_addr,
    dout => char_rom_dout
  );

  -- Fetch the tile code and colour from the character RAM.
  --
  -- The data for each tile needs to be fetched *before* rendering it to the
  -- display. This means that as the current tile is being rendered, we need to
  -- be fetching the data for the *next* tile.
  fetch_tile_data : process(clk)
    variable offset_x : natural range 0 to 7;
  begin
    offset_x := to_integer(pos.x(2 downto 0));

    if rising_edge(clk) then
      if cen = '1' then
        case offset_x is
          -- fetch high byte
          when 3 =>
            char_ram_addr_b <= std_logic_vector('1' & row & col);

          -- latch high byte
          when 4 =>
            hi_byte <= char_ram_dout_b;

          -- fetch low byte
          when 5 =>
            char_ram_addr_b <= std_logic_vector('0' & row & col);

          -- latch low byte
          when 6 =>
            lo_byte <= char_ram_dout_b;

          -- latch tile data
          when 7 =>
            color <= hi_byte(7 downto 4);
            code <= unsigned(hi_byte(1 downto 0) & lo_byte);

          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- Fetch the pixel data from the character ROM.
  fetch_pixel_data : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        char_rom_addr <= std_logic_vector(code & pos.y(2 downto 0) & pos.x(2 downto 1));

        -- select the low/high pixel
        if pos.x(0) = '0' then
          pixel <= char_rom_dout(3 downto 0);
        else
          pixel <= char_rom_dout(7 downto 4);
        end if;
      end if;
    end if;
  end process;

  data <= color & pixel;
end architecture;
