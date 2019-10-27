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

use work.common.all;

-- The palette combines data from the different graphics layers to produce an
-- actual RGB value that can be rendered on the screen.
entity palette is
  port (
    -- clock signals
    clk   : in std_logic;
    cen_6 : in std_logic;

    -- palette RAM
    ram_addr : out unsigned(PALETTE_RAM_GPU_ADDR_WIDTH-1 downto 0);
    ram_data : in std_logic_vector(PALETTE_RAM_GPU_DATA_WIDTH-1 downto 0);

    -- layer data
    sprite_data : in byte_t;
    char_data   : in byte_t;
    fg_data     : in byte_t;
    bg_data     : in byte_t;

    -- sprite priority
    sprite_priority : in priority_t;

    -- video signals
    video : in video_t;
    rgb   : out rgb_t
  );
end palette;

architecture arch of palette is
  -- current layer
  signal layer : layer_t;
begin
  -- latch RGB data from the palette RAM
  latch_rgb_data : process (clk)
  begin
    if rising_edge(clk) then
      if cen_6 = '1' then
        if video.enable = '1' then
          rgb.r <= ram_data(15 downto 12);
          rgb.g <= ram_data(11 downto 8);
          rgb.b <= ram_data(3 downto 0);
        else
          rgb.r <= (others => '0');
          rgb.g <= (others => '0');
          rgb.b <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  -- set current layer
  layer <= mux_layers(sprite_priority, sprite_data, char_data, fg_data, bg_data);

  -- set palette RAM address
  with layer select
    ram_addr <= "00" & unsigned(sprite_data) when SPRITE_LAYER,
                "01" & unsigned(char_data)   when CHAR_LAYER,
                "10" & unsigned(fg_data)     when FG_LAYER,
                "11" & unsigned(bg_data)     when BG_LAYER,
                "0100000000"                 when FILL_LAYER;
end arch;
