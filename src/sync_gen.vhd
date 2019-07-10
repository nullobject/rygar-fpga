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

-- Generates the video timing signals.
entity sync_gen is
  port (
    -- input clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- horizontal and vertical counter
    hcnt, vcnt : out unsigned(8 downto 0);

    -- horizontal and vertical sync
    hsync, vsync : out std_logic;

    -- horizontal and vertical blank
    hblank, vblank : out std_logic
  );
end sync_gen;

architecture struct of sync_gen is
  signal x : natural range 0 to 511;
  signal y : natural range 0 to 511;
begin
  hv_count : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        -- 6Mhz / 384 = 15.625 kHz
        if x = 383 then
          x <= 0;
        else
          x <= x + 1;
        end if;

        -- 15.625 kHz / 264 = 59.185 Hz
        if x = 303 then
          if y = 263 then
            y <= 0;
          else
            y <= y + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  sync : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if x = 0 then hblank <= '0';
        elsif x = SCREEN_WIDTH then hblank <= '1';
        end if;

        if x = 303 then hsync <= '1';
        elsif x = 335 then hsync <= '0';
        end if;

        if y = 0 then vblank <= '0';
        elsif y = SCREEN_HEIGHT then vblank <= '1';
        end if;

        if y = 240 then vsync <= '1';
        elsif y = 248 then vsync <= '0';
        end if;
      end if;
    end if;
  end process;

  hcnt <= to_unsigned(x, hcnt'length);
  vcnt <= to_unsigned(y, vcnt'length);
end architecture;
