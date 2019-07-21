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

    -- current position
    pos : out position_t;

    -- horizontal and vertical sync
    sync : out sync_t;

    -- horizontal and vertical blank
    blank : out blank_t
  );
end sync_gen;

architecture struct of sync_gen is
  -- horizontal scan region widths
  constant H_DISPLAY     : natural := 256;
  constant H_FRONT_PORCH : natural := 48;
  constant H_RETRACE     : natural := 32;
  constant H_BACK_PORCH  : natural := 48;

  -- vertical scan region widths
  constant V_DISPLAY     : natural := 224;
  constant V_FRONT_PORCH : natural := 16;
  constant V_RETRACE     : natural := 8;
  constant V_BACK_PORCH  : natural := 16;

  -- horizontal and vertical scan widths
  constant H_SCAN : natural := H_DISPLAY+H_FRONT_PORCH+H_RETRACE+H_BACK_PORCH;
  constant V_SCAN : natural := V_DISPLAY+V_FRONT_PORCH+V_RETRACE+V_BACK_PORCH;

  -- The vertical offset is used to skip the first two rows of tiles (16
  -- lines). Rygar includes the first two rows of tiles in memory, but they
  -- aren't actually rendered on the screen.
  constant V_OFFSET : natural := 16;

  signal x : natural range 0 to 511 := H_SCAN-1;
  signal y : natural range 0 to 511 := V_SCAN-1;
begin
  -- Generate horizontal timings.
  --
  -- visible:     256
  -- front porch: 48
  -- hsync:       32
  -- back porch:  48
  -- total:       384
  --
  -- 6Mhz / 384 = 15.625kHz
  horizontal : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if x = H_SCAN-1 then
          x <= 0;
        else
          x <= x + 1;
        end if;

        if x = H_DISPLAY+H_FRONT_PORCH-1 then
          sync.hsync <= '1';
        elsif x = H_DISPLAY+H_FRONT_PORCH+H_RETRACE-1 then
          sync.hsync <= '0';
        end if;

        if x = H_SCAN-1 then
          blank.hblank <= '0';
        elsif x = H_DISPLAY-1 then
          blank.hblank <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Generate vertical timings.
  --
  -- visible:     224
  -- front porch: 16
  -- vsync:       8
  -- back porch:  16
  -- total:       264
  --
  -- 15.625kHz / 264 = 59.185 Hz
  vertical : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if x = H_DISPLAY+H_FRONT_PORCH-1 then
          if y = V_SCAN-1 then
            y <= 0;
          else
            y <= y + 1;
          end if;

          if y = V_DISPLAY+V_FRONT_PORCH-1 then
            sync.vsync <= '1';
          elsif y = V_DISPLAY+V_FRONT_PORCH+V_RETRACE-1 then
            sync.vsync <= '0';
          end if;

          if y = V_SCAN-1 then
            blank.vblank <= '0';
          elsif y = V_DISPLAY-1 then
            blank.vblank <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  pos.x <= to_unsigned(x, pos.x'length);
  pos.y <= to_unsigned(y+V_OFFSET, pos.y'length);
end architecture;
