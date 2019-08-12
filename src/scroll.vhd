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

-- This module handles the scrolling foreground and background layers in the
-- graphics pipeline. It consists of of a 32x16 grid of 16x16 tiles.
--
-- Because a scrolling layer is twice the width of the screen, it can never be
-- entirely visible on the screen at once. The horizontal and vertical scroll
-- positions are used to set the position of the visible area.
entity scroll is
  generic (
    RAM_ADDR_WIDTH : natural;
    ROM_ADDR_WIDTH : natural;
    ROM_INIT_FILE  : string
  );
  port (
    -- clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- scroll RAM
    ram_cs   : in std_logic;
    ram_addr : in std_logic_vector(RAM_ADDR_WIDTH-1 downto 0);
    ram_din  : in byte_t;
    ram_dout : out byte_t;
    ram_we   : in std_logic;

    -- video signals
    video : in video_t;

    -- horizontal and vertical scroll positions
    scroll_hpos : in unsigned(8 downto 0);
    scroll_vpos : in unsigned(7 downto 0);

    -- layer data
    data : out byte_t
  );
end scroll;

architecture arch of scroll is
  -- tile RAM (port B)
  signal scroll_ram_addr_b : std_logic_vector(RAM_ADDR_WIDTH-1 downto 0);
  signal scroll_ram_dout_b : byte_t;

  -- tile ROM
  signal tile_rom_addr : std_logic_vector(ROM_ADDR_WIDTH-1 downto 0);
  signal tile_rom_dout : byte_t;

  -- tile colour and code
  signal tile_data : std_logic_vector(15 downto 0);

  -- graphics data
  signal gfx_data : byte_t;

  -- tile code
  signal code : unsigned(9 downto 0);

  -- tile colour
  signal color : nibble_t;

  -- pixel data
  signal pixel : nibble_t;

  -- horizontal and vertical position
  signal hpos : unsigned(8 downto 0);
  signal vpos : unsigned(7 downto 0);

  -- aliases to extract the components of the horizontal and vertical position
  alias col      : unsigned(4 downto 0) is hpos(8 downto 4);
  alias row      : unsigned(3 downto 0) is vpos(7 downto 4);
  alias offset_x : unsigned(3 downto 0) is hpos(3 downto 0);
  alias offset_y : unsigned(3 downto 0) is vpos(3 downto 0);
begin
  -- The tile RAM (1kB) contains the code and colour of each tile in the
  -- tilemap.
  --
  -- Each tile in the tilemap is represented by two bytes in the character RAM,
  -- a high byte and a low byte, which contains the tile colour and code.
  --
  -- It has been implemented as a dual-port RAM because both the CPU and the
  -- graphics pipeline need to access the RAM concurrently. Ports A and B are
  -- identical.
  --
  -- This differs from the original arcade hardware, which only contains
  -- a single-port character RAM. Using a dual-port RAM instead simplifies
  -- things, because we don't need all the additional logic required to
  -- coordinate RAM access.
  scroll_ram : entity work.true_dual_port_ram
  generic map (
    ADDR_WIDTH_A => RAM_ADDR_WIDTH,
    ADDR_WIDTH_B => RAM_ADDR_WIDTH
  )
  port map (
    -- port A (CPU)
    clk_a  => clk,
    cs_a   => ram_cs,
    addr_a => ram_addr,
    din_a  => ram_din,
    dout_a => ram_dout,
    we_a   => ram_we,

    -- port B (GPU)
    clk_b  => clk,
    addr_b => scroll_ram_addr_b,
    dout_b => scroll_ram_dout_b
  );

  -- The tile ROM contains the actual pixel data for the tiles.
  --
  -- Each 16x16 tile is made up of four separate 8x8 tiles, stored in
  -- a left-to-right, top-to-bottom order.
  --
  -- Each 8x8 tile is composed of four layers of pixel data (bitplanes). This
  -- means that each row in a 8x8 tile takes up exactly four bytes, for a total
  -- of 32 bytes per tile.
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

  -- Update horizontal position.
  --
  -- During a HSYNC, the horizontal position is reset to the current horizontal
  -- scroll position. Otherwise, we just increment it at every clock tick.
  hpos_counter : process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if video.hsync = '1' then
          hpos <= scroll_hpos;
        else
          hpos <= hpos + 1;
        end if;
      end if;
    end if;
  end process;

  -- Update vertical position.
  --
  -- This is just the sum of the vertical screen and scroll positions.
  vpos <= video.pos.y(7 downto 0) + scroll_vpos;

  -- Load tile data from the scroll RAM.
  --
  -- While the current tile is being rendered, we need to fetch data for the
  -- next tile ahead, so that it is loaded in time to render it on the screen.
  --
  -- The 16-bit tile data words aren't stored contiguously in RAM, instead they
  -- are split into high and low bytes. The high bytes are stored in the
  -- upper-half of the RAM, while the low bytes are stored in the lower-half.
  tile_data_pipeline : process (clk)
  begin
    if rising_edge(clk) then
      case to_integer(offset_x) is
        when 10 =>
          -- load high byte for the next tile
          scroll_ram_addr_b <= std_logic_vector('1' & row & (col+1));

        when 11 =>
          -- latch high byte
          tile_data(15 downto 8) <= scroll_ram_dout_b;

          -- load low byte for the next tile
          scroll_ram_addr_b <= std_logic_vector('0' & row & (col+1));

        when 12 =>
          -- latch low byte
          tile_data(7 downto 0) <= scroll_ram_dout_b;

        when 13 =>
          -- latch code
          code <= unsigned(tile_data(9 downto 0));

        when 15 =>
          -- latch colour
          color <= tile_data(15 downto 12);

        when others => null;
      end case;
    end if;
  end process;

  -- Load graphics data from the tile ROM.
  --
  -- While the current two pixels are being rendered, we need to fetch data for
  -- the next two pixels, so they are loaded in time to render them on the
  -- screen.
  load_gfx_data : block
    signal x : unsigned(2 downto 0);
    signal y : unsigned(3 downto 0);
  begin
    x <= offset_x(3 downto 1)+1;
    y <= offset_y(3 downto 0);

    tile_rom_addr <= std_logic_vector(code & y(3) & x(2) & y(2 downto 0) & x(1 downto 0));
  end block;

  -- Latch the graphics data from the tile ROM when rendering odd pixels (i.e.
  -- the second pixel in every pair of pixels).
  latch_gfx_data : process (clk)
  begin
    if rising_edge(clk) then
      if hpos(0) = '1' then
        gfx_data <= tile_rom_dout;
      end if;
    end if;
  end process;

  -- decode high/low pixels from the graphics data
  pixel <= gfx_data(7 downto 4) when hpos(0) = '0' else gfx_data(3 downto 0);

  -- set layer data
  data <= color & pixel;
end architecture arch;
