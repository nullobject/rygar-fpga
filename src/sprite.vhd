-- Copyright (c) 2019 Josh Bassett
--
-- Permission is hereby granted, free of spritege, to any person obtaining a copy
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

entity sprite is
  port (
    -- input clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- sprite RAM
    ram_cs   : in std_logic;
    ram_addr : in std_logic_vector(SPRITE_RAM_ADDR_WIDTH-1 downto 0);
    ram_din  : in byte_t;
    ram_dout : out byte_t;
    ram_we   : in std_logic
  );
end sprite;

architecture arch of sprite is
  -- sprite RAM (port B)
  signal sprite_ram_addr_b : std_logic_vector(SPRITE_RAM_ADDR_WIDTH-1 downto 0);
  signal sprite_ram_dout_b : byte_t;
begin
  -- The sprite RAM (2kB) contains the sprite data.
  --
  -- Each sprite is represented by eight bytes in the sprite RAM:
  --
  --  byte     bit        description
  -- --------+-76543210-+----------------
  --       0 | xxxx---- | bank
  --         | -----x-- | visible
  --         | ------x- | flip y
  --         | -------x | flip x
  --       1 | xxxxxxxx | tile code
  --       2 | ------xx | size
  --       3 | xx-------| priority
  --         | --x----- | upper y co-ord
  --         | ---x---- | upper x co-ord
  --         | ----xxxx | colour
  --       4 | xxxxxxxx | ypos
  --       5 | xxxxxxxx | xpos
  --       6 | -------- |
  --       7 | -------- |
  --
  -- There are three possible sprite sizes: 8x8, 16x16, and 32x32. All sprites
  -- are composed from a number of 8x8 tiles.
  sprite_ram : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH_A => SPRITE_RAM_ADDR_WIDTH,
    ADDR_WIDTH_B => SPRITE_RAM_ADDR_WIDTH
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
    addr_b => sprite_ram_addr_b,
    dout_b => sprite_ram_dout_b
  );
end architecture;
