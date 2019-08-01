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

use work.types.all;

-- The scroll layer is a 32x16 grid of 16x16 tiles. It is used to render the
-- foreground and background scrolling graphics layers.
--
-- Because the scroll layer is twice the width of the screen, not all it is
-- visible on the screen at once. The scroll offset is used to offset the
-- visible area on the horizontal axis.
entity scroll is
  generic (
    RAM_ADDR_WIDTH : natural;
    ROM_ADDR_WIDTH : natural;
    ROM_INIT_FILE  : string
  );
  port (
    -- input clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- scroll RAM
    ram_cs   : in std_logic;
    ram_addr : in std_logic_vector(RAM_ADDR_WIDTH-1 downto 0);
    ram_din  : in byte_t;
    ram_dout : out byte_t;
    ram_we   : in std_logic;

    -- video position
    video_pos : in pos_t;

    -- horizontal offset (in pixels)
    offset : in unsigned(8 downto 0);

    -- palette index output
    data : out byte_t
  );
end scroll;

architecture arch of scroll is
  -- column and row aliases
  alias col : unsigned(4 downto 0) is video_pos.x(8 downto 4);
  alias row : unsigned(3 downto 0) is video_pos.y(7 downto 4);

  -- tile RAM (port B)
  signal scroll_ram_addr_b : std_logic_vector(RAM_ADDR_WIDTH-1 downto 0);
  signal scroll_ram_dout_b : byte_t;

  -- tile ROM
  signal tile_rom_addr : std_logic_vector(ROM_ADDR_WIDTH-1 downto 0);
  signal tile_rom_dout : byte_t;

  -- registers
  signal hi_byte    : byte_t;
  signal pixel_pair : byte_t;
  signal code       : unsigned(9 downto 0);
  signal pixel      : std_logic_vector(3 downto 0);
  signal color      : std_logic_vector(3 downto 0);
begin
  -- The tile RAM (1kB) contains the code and colour for each tile in the 32x16
  -- tilemap. The tile code is used to look up the actual pixel data in the
  -- tile ROM.
  --
  -- It has been implemented as a dual-port RAM because both the CPU and the
  -- graphics pipeline need to access the RAM concurrently.
  --
  -- This differs from the original arcade hardware, which only contains
  -- a single-port RAM. Using a dual-port RAM means we can simplify things by
  -- doing away with all additional logic required to coordinate access to the
  -- RAM.
  scroll_ram : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH_A => RAM_ADDR_WIDTH,
    ADDR_WIDTH_B => RAM_ADDR_WIDTH
  )
  port map (
    clk_a  => clk,
    cs_a   => ram_cs,
    addr_a => ram_addr,
    din_a  => ram_din,
    dout_a => ram_dout,
    we_a   => ram_we,
    clk_b  => clk,
    addr_b => scroll_ram_addr_b,
    dout_b => scroll_ram_dout_b
  );

  -- The tile ROM contains the pixel data for the tiles.
  --
  -- Each 16x16 tile contains four bitplanes, and each bitplane takes up 32
  -- bytes (one byte per row). This means that every tile takes up exactly 128
  -- bytes in the ROM.
  tile_rom : entity work.single_port_rom
  generic map (
    ADDR_WIDTH => ROM_ADDR_WIDTH,
    INIT_FILE  => ROM_INIT_FILE
  )
  port map (
    clk  => clk,
    addr => tile_rom_addr,
    dout => tile_rom_dout
  );

  -- Fetch the tile code and colour from the scroll RAM.
  --
  -- The tile data needs to be fetched *before* rendering it to the display.
  -- This means that as the current tile is being rendered, we need to be
  -- fetching the data for the *next* tile.
  fetch_tile_data : process (clk)
    variable offset_x : natural range 0 to 15;
  begin
    offset_x := to_integer(video_pos.x(3 downto 0));

    if rising_edge(clk) then
      if cen = '1' then
        case offset_x is
          when 10 => -- fetch high byte
            scroll_ram_addr_b <= std_logic_vector('1' & row & col);
          when 11 => -- latch high byte
            hi_byte <= scroll_ram_dout_b;
          when 12 => -- fetch low byte
            scroll_ram_addr_b <= std_logic_vector('0' & row & col);
          when 13 => -- latch code
            code <= unsigned(hi_byte(1 downto 0) & scroll_ram_dout_b);
          when 15 => -- latch colour
            color <= hi_byte(7 downto 4);
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- Latch the pixel pair from the tile ROM when rendering odd pixels (i.e. the
  -- second pixel in every pair of pixels).
  latch_pixel_pair : process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if video_pos.x(0) = '1' then
          pixel_pair <= tile_rom_dout;
        end if;
      end if;
    end if;
  end process;

  -- fetch the next pixel pair from the tile ROM
  tile_rom_addr <= std_logic_vector(code & video_pos.y(3) & video_pos.x(3) & video_pos.y(2 downto 0) & video_pos.x(2 downto 1));

  -- multiplex the high/low pixel from the pixel pair
  pixel <= pixel_pair(7 downto 4) when video_pos.x(0) = '1' else pixel_pair(3 downto 0);

  -- output data
  data <= color & pixel;
end architecture;
