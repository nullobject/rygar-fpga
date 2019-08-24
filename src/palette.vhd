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

-- The palette combines data from the different graphics layers to produce an
-- actual RGB value, that can be rendered on the screen.
entity palette is
  port (
    -- clock signals
    clk   : in std_logic;
    cen_6 : in std_logic;

    -- palette RAM
    ram_cs   : in std_logic;
    ram_addr : in std_logic_vector(PALETTE_RAM_ADDR_WIDTH-1 downto 0);
    ram_din  : in byte_t;
    ram_dout : out byte_t;
    ram_we   : in std_logic;

    -- video signals
    video : in video_t;

    -- sprite priority data
    sprite_priority : in priority_t;

    -- graphics layer data
    sprite_data : in byte_t;
    char_data   : in byte_t;
    fg_data     : in byte_t;
    bg_data     : in byte_t;

    -- RGB data
    rgb : out rgb_t
  );
end palette;

architecture arch of palette is
  constant PALETTE_RAM_ADDR_WIDTH_B : natural := 10;
  constant PALETTE_RAM_DATA_WIDTH_B : natural := 16;

  -- palette RAM (port B)
  signal palette_ram_addr_b : std_logic_vector(PALETTE_RAM_ADDR_WIDTH_B-1 downto 0);
  signal palette_ram_dout_b : std_logic_vector(PALETTE_RAM_DATA_WIDTH_B-1 downto 0);

  -- current layer
  signal layer : layer_t;
begin
  -- The palette RAM contains 1024 16-bit RGB colour values, stored in
  -- RRRRGGGGXXXXBBBB format.
  --
  -- It has been implemented as a dual-port RAM because both the CPU and the
  -- graphics pipeline need to access the RAM concurrently. Port A is 8-bits
  -- wide and is connected to the CPU data bus. Port B is 16-bits wide and is
  -- connected to the graphics pipeine.
  --
  -- This differs from the original arcade hardware, which only contains
  -- a single-port palette RAM. Using a dual-port RAM instead simplifies
  -- things, because we don't need all the additional logic required to
  -- coordinate RAM access.
  palette_ram : entity work.true_dual_port_ram
  generic map (
    ADDR_WIDTH_A => PALETTE_RAM_ADDR_WIDTH,
    ADDR_WIDTH_B => PALETTE_RAM_ADDR_WIDTH_B,
    DATA_WIDTH_B => PALETTE_RAM_DATA_WIDTH_B
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
    addr_b => palette_ram_addr_b,
    dout_b => palette_ram_dout_b
  );

  -- latch RGB data from the palette RAM
  latch_rgb_data : process (clk)
  begin
    if rising_edge(clk) and cen_6 = '1' then
      if video.enable = '1' then
        rgb.r <= palette_ram_dout_b(15 downto 12);
        rgb.g <= palette_ram_dout_b(11 downto 8);
        rgb.b <= palette_ram_dout_b(3 downto 0);
      else
        rgb.r <= (others => '0');
        rgb.g <= (others => '0');
        rgb.b <= (others => '0');
      end if;
    end if;
  end process;

  -- set current layer
  layer <= mux_layers(sprite_priority, sprite_data, char_data, fg_data, bg_data);

  -- set palette RAM address
  with layer select
    palette_ram_addr_b <= "00" & sprite_data when SPRITE_LAYER,
                          "01" & char_data   when CHAR_LAYER,
                          "10" & fg_data     when FG_LAYER,
                          "11" & bg_data     when BG_LAYER,
                          "0100000000"       when FILL_LAYER;
end arch;
