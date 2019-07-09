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

entity sync_gen is
  port (
    -- input clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- horizontal and vertical pixel position
    pixel_x, pixel_y : out unsigned(8 downto 0);

    -- horizontal and vertical sync
    hsync, vsync : out std_logic;

    -- horizontal and vertical blank
    hblank, vblank : out std_logic
  );
end sync_gen;

architecture struct of sync_gen is
  signal hcnt : natural range 0 to 511;
  signal vcnt : natural range 0 to 511;
begin
  hv_count : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        -- 6Mhz / 384 = 15.625 kHz
        if hcnt = 383 then
          hcnt <= 0;
        else
          hcnt <= hcnt + 1;
        end if;

        -- 15.625 kHz / 264 = 59.185 Hz
        if hcnt = 303 then
          if vcnt = 263 then
            vcnt <= 0;
          else
            vcnt <= vcnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  sync : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if hcnt = 0 then hblank <= '0';
        elsif hcnt = 256 then hblank <= '1';
        end if;

        if hcnt = 303 then hsync <= '1';
        elsif hcnt = 335 then hsync <= '0';
        end if;

        if vcnt = 0 then vblank <= '0';
        elsif vcnt = 224 then vblank <= '1';
        end if;

        if vcnt = 240 then vsync <= '1';
        elsif vcnt = 248 then vsync <= '0';
        end if;
      end if;
    end if;
  end process;

  pixel_x <= to_unsigned(hcnt, pixel_x'length);
  pixel_y <= to_unsigned(vcnt, pixel_y'length);
end architecture;
