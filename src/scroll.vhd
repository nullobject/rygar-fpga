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
-- visible on the screen at once. The scroll position is used to offset the
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

    -- horizontal scroll position
    scroll_pos : in unsigned(8 downto 0);

    -- palette index output
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

  -- The register that contains the colour and code of the next tile to be
  -- rendered.
  --
  -- The 16-bit tile data words aren't stored contiguously in RAM, instead they
  -- are split into high and low bytes. The high bytes are stored in the
  -- upper-half of the RAM, while the low bytes are stored in the lower-half.
  signal tile_data : std_logic_vector(15 downto 0);

  -- The register that contains next two 4-bit pixels to be rendered.
  signal gfx_data : byte_t;

  -- tile code
  signal code : unsigned(9 downto 0);

  -- tile colour
  signal color : nibble_t;

  -- pixel data
  signal pixel : nibble_t;

  signal pos_x : unsigned(2 downto 0);

  signal hpos : unsigned(8 downto 0);

  -- extract the components of the video position vectors
  alias col      : unsigned(4 downto 0) is hpos(8 downto 4);
  alias row      : unsigned(3 downto 0) is video_pos.y(7 downto 4);
  alias offset_x : unsigned(3 downto 0) is hpos(3 downto 0);
  alias offset_y : unsigned(3 downto 0) is video_pos.y(3 downto 0);
begin
  hpos <= video_pos.x(7 downto 0) + scroll_pos + 48;

  -- The tile RAM (1kB) contains the code and colour of each tile in the
  -- tilemap.
  --
  -- It has been implemented as a dual-port RAM because both the CPU and the
  -- graphics pipeline need to access the RAM concurrently. Ports A and B are
  -- identical.
  --
  -- This differs from the original arcade hardware, which only contains
  -- a single-port character RAM. Using a dual-port RAM instead simplifies
  -- things, because we don't need all additional logic required to coordinate
  -- RAM access.
  scroll_ram : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH_A => RAM_ADDR_WIDTH,
    ADDR_WIDTH_B => RAM_ADDR_WIDTH
  )
  port map (
    -- port A
    clk_a  => clk,
    cs_a   => ram_cs,
    addr_a => ram_addr,
    din_a  => ram_din,
    dout_a => ram_dout,
    we_a   => ram_we,

    -- port B
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

  -- Load the tile data from the scroll RAM.
  --
  -- The tile data needs to be fetched *before* rendering it to the screen.
  -- This means that we need to be fetching the data for the next tile, while
  -- the current tile is being rendered.
  tile_data_pipeline : process (clk)
  begin
    if rising_edge(clk) then
      case to_integer(offset_x) is
        when 10 =>
          -- load high byte from the scroll RAM
          scroll_ram_addr_b <= std_logic_vector('1' & row & col);

        when 11 =>
          -- latch high byte
          tile_data(15 downto 8) <= scroll_ram_dout_b;

          -- load low byte from the scroll RAM
          scroll_ram_addr_b <= std_logic_vector('0' & row & col);

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

  pos_x <= offset_x(3 downto 1)+1;

  -- load graphics data from the tile ROM
  tile_rom_addr <= std_logic_vector(code & video_pos.y(3) & pos_x(2) & video_pos.y(2 downto 0) & pos_x(1 downto 0));

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
  pixel <= gfx_data(7 downto 4) when hpos(0) = '1' else gfx_data(3 downto 0);

  -- output data
  data <= color & pixel;
end architecture;
