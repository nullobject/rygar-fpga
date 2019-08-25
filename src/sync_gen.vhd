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

-- This module generates the video timing signals for a 256x224 screen
-- resolution. This is a very common resolution for older arcade games.
--
-- The sync signals tell the CRT when to start and stop scanning. The
-- horizontal sync tells the CRT when to start a new scanline, and the vertical
-- sync tells it when to start a new field.
--
-- The blanking signals indicate whether the beam is in the horizontal or
-- vertical blanking (non-visible) regions. Video output should be disabled
-- while the beam is in these regions, they are also used to do things like
-- fetch graphics data.
--
-- horizontal frequency: 6Mhz / 384 = 15.625kHz
-- vertical frequency: 15.625kHz / 264 = 59.185 Hz
entity sync_gen is
  port (
    -- clock signals
    clk   : in std_logic;
    cen_6 : in std_logic;

    -- video signals
    video : out video_t
  );
end sync_gen;

architecture arch of sync_gen is
  -- horizontal regions
  constant H_DISPLAY     : natural := 256;
  constant H_FRONT_PORCH : natural := 48;
  constant H_RETRACE     : natural := 32;
  constant H_BACK_PORCH  : natural := 48;
  constant H_SCAN        : natural := H_DISPLAY+H_FRONT_PORCH+H_RETRACE+H_BACK_PORCH; -- 384

  -- vertical regions
  constant V_DISPLAY     : natural := 224;
  constant V_FRONT_PORCH : natural := 16;
  constant V_RETRACE     : natural := 8;
  constant V_BACK_PORCH  : natural := 16;
  constant V_SCAN        : natural := V_DISPLAY+V_FRONT_PORCH+V_RETRACE+V_BACK_PORCH; -- 264

  -- initial counter values
  constant H_START : natural := 128;
  constant V_START : natural := 248;

  -- position counters
  signal x : natural range 0 to 511 := H_START;
  signal y : natural range 0 to 511 := V_START;

  -- sync signals
  signal hsync, vsync : std_logic;

  -- blank signals
  signal hblank, vblank : std_logic;
begin
  -- generate horizontal timing signals
  horizontal_timing : process (clk)
  begin
    if rising_edge(clk) then
      if cen_6 = '1' then
        if x = 511 then
          x <= H_START;
        else
          x <= x + 1;
        end if;

        if x = H_START+H_FRONT_PORCH+H_RETRACE-1 then
          hsync <= '0';
        elsif x = H_START+H_FRONT_PORCH-1 then
          hsync <= '1';
        end if;

        if x = H_START+H_FRONT_PORCH+H_RETRACE+H_BACK_PORCH-1 then
          hblank <= '0';
        elsif x = H_START+H_SCAN-1 then
          hblank <= '1';
        end if;
      end if;
    end if;
  end process;

  -- generate vertical timing signals
  vertical_timing : process (clk)
  begin
    if rising_edge(clk) then
      if cen_6 = '1' then
        if x = H_START+H_FRONT_PORCH-1 then
          if y = 511 then
            y <= V_START;
          else
            y <= y + 1;
          end if;

          if y = V_START+V_RETRACE-1 then
            vsync <= '0';
          elsif y = V_START+V_SCAN-1 then
            vsync <= '1';
          end if;

          if y = V_START+V_RETRACE+V_BACK_PORCH-1 then
            vblank <= '0';
          elsif y = V_START+V_RETRACE+V_BACK_PORCH+V_DISPLAY-1 then
            vblank <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- set video position
  video.pos.x <= to_unsigned(x, video.pos.x'length);
  video.pos.y <= to_unsigned(y, video.pos.y'length);

  -- set sync signals
  video.hsync <= hsync;
  video.vsync <= vsync;

  -- set blank signals
  video.hblank <= hblank;
  video.vblank <= vblank;

  -- set output enable
  video.enable <= not (hblank or vblank);
end architecture arch;
