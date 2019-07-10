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

package rygar is
  constant SCREEN_WIDTH  : natural := 256;
  constant SCREEN_HEIGHT : natural := 224;

  constant COLOR_DEPTH_R : natural := 4;
  constant COLOR_DEPTH_G : natural := 4;
  constant COLOR_DEPTH_B : natural := 4;

  constant PROG_ROM_1_ADDR_WIDTH  : natural := 15; -- 32kB
  constant PROG_ROM_2_ADDR_WIDTH  : natural := 14; -- 16kB
  constant PROG_ROM_3_ADDR_WIDTH  : natural := 15; -- 32kB
  constant WORK_RAM_ADDR_WIDTH    : natural := 12; -- 4kB
  constant CHAR_RAM_ADDR_WIDTH    : natural := 11; -- 2kB
  constant CHAR_ROM_ADDR_WIDTH    : natural := 15; -- 32kB
  constant FG_RAM_ADDR_WIDTH      : natural := 10; -- 1kB
  constant FG_ROM_ADDR_WIDTH      : natural := 17; -- 128kB
  constant BG_RAM_ADDR_WIDTH      : natural := 10; -- 1kB
  constant BG_ROM_ADDR_WIDTH      : natural := 17; -- 128kB
  constant SPRITE_RAM_ADDR_WIDTH  : natural := 11; -- 2kB
  constant SPRITE_ROM_ADDR_WIDTH  : natural := 17; -- 128kB
  constant PALETTE_RAM_ADDR_WIDTH : natural := 11; -- 2kB
end package rygar;

package body rygar is
end package body rygar;
