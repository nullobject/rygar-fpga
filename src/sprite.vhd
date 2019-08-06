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

-- This module handles the sprite layer in the graphics pipeline.
--
-- All sprites are composed from multiple 8x8 tiles. There are three possible
-- sprite sizes: 8x8, 16x16, and 32x32.
--
-- Each sprite is represented by eight bytes in the sprite RAM:
--
--  byte     bit        description
-- --------+-76543210-+----------------
--       0 | xxxx---- | bank
--         | -----x-- | enable
--         | ------x- | flip y
--         | -------x | flip x
--       1 | xxxxxxxx | code
--       2 | ------xx | size
--       3 | xx-------| priority
--         | --x----- | hi position y
--         | ---x---- | hi position x
--         | ----xxxx | colour
--       4 | xxxxxxxx | lo position x
--       5 | xxxxxxxx | lo position y
--       6 | -------- |
--       7 | -------- |
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
    ram_we   : in std_logic;

    -- video signals
    video_pos   : in pos_t;
    video_blank : in blank_t;

    -- palette index output
    data : out byte_t
  );
end sprite;

architecture arch of sprite is
  constant SPRITE_RAM_ADDR_WIDTH_B : natural := 8;
  constant SPRITE_RAM_DATA_WIDTH_B : natural := 64;

  -- byte 0
  constant SPRITE_BANK_HI_BIT : natural := 7;
  constant SPRITE_BANK_LO_BIT : natural := 4;
  constant SPRITE_ENABLE_BIT  : natural := 2;
  constant SPRITE_FLIP_Y_BIT  : natural := 1;
  constant SPRITE_FLIP_X_BIT  : natural := 0;

  -- byte 1
  constant SPRITE_CODE_HI_BIT : natural := 15;
  constant SPRITE_CODE_LO_BIT : natural := 8;

  -- byte 2
  constant SPRITE_SIZE_HI_BIT : natural := 17;
  constant SPRITE_SIZE_LO_BIT : natural := 16;

  -- byte 3
  constant SPRITE_PRIORITY_HI_BIT : natural := 31;
  constant SPRITE_PRIORITY_LO_BIT : natural := 30;
  constant SPRITE_HI_POS_Y_BIT    : natural := 29;
  constant SPRITE_HI_POS_X_BIT    : natural := 28;
  constant SPRITE_COLOR_HI_BIT    : natural := 27;
  constant SPRITE_COLOR_LO_BIT    : natural := 24;

  -- byte 4
  constant SPRITE_LO_POS_X_HI_BIT : natural := 39;
  constant SPRITE_LO_POS_X_LO_BIT : natural := 32;

  -- byte 5
  constant SPRITE_LO_POS_Y_HI_BIT : natural := 47;
  constant SPRITE_LO_POS_Y_LO_BIT : natural := 40;

  -- initialise sprite from a raw 64-bit value
  function init_sprite(data : std_logic_vector(SPRITE_RAM_DATA_WIDTH_B-1 downto 0)) return sprite_t is
    variable sprite : sprite_t;
  begin
    sprite.bank     := unsigned(data(SPRITE_BANK_HI_BIT downto SPRITE_BANK_LO_BIT));
    sprite.code     := unsigned(data(SPRITE_CODE_HI_BIT downto SPRITE_CODE_LO_BIT));
    sprite.color    := unsigned(data(SPRITE_COLOR_HI_BIT downto SPRITE_COLOR_LO_BIT));
    sprite.enable   := data(SPRITE_ENABLE_BIT);
    sprite.flip_x   := data(SPRITE_FLIP_X_BIT);
    sprite.flip_y   := data(SPRITE_FLIP_Y_BIT);
    sprite.pos_x    := data(SPRITE_HI_POS_X_BIT) & unsigned(data(SPRITE_LO_POS_X_HI_BIT downto SPRITE_LO_POS_X_LO_BIT));
    sprite.pos_y    := data(SPRITE_HI_POS_Y_BIT) & unsigned(data(SPRITE_LO_POS_Y_HI_BIT downto SPRITE_LO_POS_Y_LO_BIT));
    sprite.priority := unsigned(data(SPRITE_PRIORITY_HI_BIT downto SPRITE_PRIORITY_LO_BIT));
    sprite.size     := unsigned(data(SPRITE_SIZE_HI_BIT downto SPRITE_SIZE_LO_BIT));

    return sprite;
  end init_sprite;

  -- sprite RAM (port B)
  signal sprite_ram_addr_b : std_logic_vector(SPRITE_RAM_ADDR_WIDTH_B-1 downto 0);
  signal sprite_ram_dout_b : std_logic_vector(SPRITE_RAM_DATA_WIDTH_B-1 downto 0);

  -- frame buffer
  signal frame_buffer_addr_rd : std_logic_vector(15 downto 0);
  signal frame_buffer_addr_wr : std_logic_vector(15 downto 0);
  signal frame_buffer_din     : std_logic_vector(7 downto 0);
  signal frame_buffer_dout    : std_logic_vector(7 downto 0);
  signal frame_buffer_flip    : std_logic;
  signal frame_buffer_we      : std_logic;

  signal vblank_falling : std_logic;

  signal x : unsigned(7 downto 0);
  signal y : unsigned(7 downto 0);
begin
  -- The sprite RAM (2kB) contains the sprite data.
  --
  -- It has been implemented as a dual-port RAM because both the CPU and the
  -- graphics pipeline need to access the RAM concurrently. Port A is 8-bits
  -- wide and is connected to the CPU data bus. Port B is 64-bits wide and is
  -- connected to the graphics pipeine.
  --
  -- This differs from the original arcade hardware, which only contains
  -- a single-port palette RAM. Using a dual-port RAM instead simplifies
  -- things, because we don't need all additional logic required to coordinate
  -- RAM access.
  sprite_ram : entity work.true_dual_port_ram
  generic map (
    ADDR_WIDTH_A => SPRITE_RAM_ADDR_WIDTH,
    ADDR_WIDTH_B => SPRITE_RAM_ADDR_WIDTH_B,
    DATA_WIDTH_B => SPRITE_RAM_DATA_WIDTH_B
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

  -- The sprite frame buffer contains two (256x256) pages of pixel data, which
  -- can be swapped. While the sprites are being rendered to one page, the
  -- other page is copied to the screen.
  --
  -- This is necessary because if we rendered the sprites to the same page that
  -- was being copied to the screen, then any changes to the sprites could
  -- cause graphical glitches.
  --
  -- TODO: When a location is read, it should be cleared to zero. That way the
  -- page will already be empty when it is flipped.
  sprite_frame_buffer : entity work.frame_buffer
  generic map (ADDR_WIDTH => 16, DATA_WIDTH => 8)
  port map (
    clk  => clk,
    flip => frame_buffer_flip,

    -- write-only port
    addr_wr => frame_buffer_addr_wr,
    din     => frame_buffer_din,
    we      => frame_buffer_we,

    -- read-only port
    addr_rd => frame_buffer_addr_rd,
    dout    => frame_buffer_dout
  );

  vblank_edge_detector : entity work.edge_detector
  generic map (FALLING => true)
  port map (
    clk  => clk,
    data => video_blank.vblank,
    edge => vblank_falling
  );

  page_flipper : process (clk)
  begin
    if rising_edge(clk) then
      if vblank_falling = '1' then
        frame_buffer_flip <= not frame_buffer_flip;
      end if;
    end if;
  end process;

  x <= video_pos.x(7 downto 0);
  y <= video_pos.y(7 downto 0);

  frame_buffer_addr_rd <= std_logic_vector(y & x);
  frame_buffer_addr_wr <= std_logic_vector(y & x);
  frame_buffer_din <= (others => '1');
  frame_buffer_we <= '1' when x >= 32 and x < 64 and y >= 32 and y < 64 else '0';

  -- output
  data <= frame_buffer_dout;
end architecture;
