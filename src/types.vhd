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

package types is
  subtype byte_t is std_logic_vector(7 downto 0);
  subtype nibble_t is std_logic_vector(3 downto 0);

  -- memory sizes
  constant PROG_ROM_1_ADDR_WIDTH   : natural := 15; -- 32kB
  constant PROG_ROM_2_ADDR_WIDTH   : natural := 14; -- 16kB
  constant PROG_ROM_3_ADDR_WIDTH   : natural := 15; -- 32kB
  constant WORK_RAM_ADDR_WIDTH     : natural := 12; -- 4kB
  constant CHAR_RAM_ADDR_WIDTH     : natural := 11; -- 2kB
  constant CHAR_ROM_ADDR_WIDTH     : natural := 15; -- 32kB
  constant FG_RAM_ADDR_WIDTH       : natural := 10; -- 1kB
  constant FG_ROM_ADDR_WIDTH       : natural := 17; -- 128kB
  constant BG_RAM_ADDR_WIDTH       : natural := 10; -- 1kB
  constant BG_ROM_ADDR_WIDTH       : natural := 17; -- 128kB
  constant SPRITE_RAM_ADDR_WIDTH   : natural := 11; -- 2kB
  constant SPRITE_ROM_ADDR_WIDTH   : natural := 17; -- 128kB
  constant PALETTE_RAM_ADDR_WIDTH  : natural := 11; -- 2kB

  constant SPRITE_RAM_ADDR_WIDTH_B    : natural := 8;
  constant SPRITE_RAM_DATA_WIDTH_B    : natural := 64;
  constant SPRITE_TILE_ROM_ADDR_WIDTH : natural := 17;
  constant SPRITE_PRIORITY_WIDTH      : natural := 2;
  constant FRAME_BUFFER_ADDR_WIDTH    : natural := 16;
  constant FRAME_BUFFER_DATA_WIDTH    : natural := 10;

  -- sprite byte 0
  constant SPRITE_HI_CODE_MSB : natural := 7;
  constant SPRITE_HI_CODE_LSB : natural := 4;
  constant SPRITE_ENABLE_BIT  : natural := 2;
  constant SPRITE_FLIP_Y_BIT  : natural := 1;
  constant SPRITE_FLIP_X_BIT  : natural := 0;

  -- sprite byte 1
  constant SPRITE_LO_CODE_MSB : natural := 15;
  constant SPRITE_LO_CODE_LSB : natural := 8;

  -- sprite byte 2
  constant SPRITE_SIZE_MSB : natural := 17;
  constant SPRITE_SIZE_LSB : natural := 16;

  -- sprite byte 3
  constant SPRITE_PRIORITY_MSB : natural := 31;
  constant SPRITE_PRIORITY_LSB : natural := 30;
  constant SPRITE_HI_POS_Y_BIT : natural := 29;
  constant SPRITE_HI_POS_X_BIT : natural := 28;
  constant SPRITE_COLOR_MSB    : natural := 27;
  constant SPRITE_COLOR_LSB    : natural := 24;

  -- sprite byte 4
  constant SPRITE_LO_POS_Y_MSB : natural := 39;
  constant SPRITE_LO_POS_Y_LSB : natural := 32;

  -- sprite byte 5
  constant SPRITE_LO_POS_X_MSB : natural := 47;
  constant SPRITE_LO_POS_X_LSB : natural := 40;

  -- colour depth
  constant COLOR_DEPTH_R : natural := 4;
  constant COLOR_DEPTH_G : natural := 4;
  constant COLOR_DEPTH_B : natural := 4;

  -- represents a position
  type pos_t is record
    x : unsigned(8 downto 0);
    y : unsigned(8 downto 0);
  end record pos_t;

  -- represents the position of a pixel in a sprite
  type sprite_pos_t is record
    x : unsigned(4 downto 0);
    y : unsigned(4 downto 0);
  end record sprite_pos_t;

  -- represents a RGB colour value
  type rgb_t is record
    r : std_logic_vector(COLOR_DEPTH_R-1 downto 0);
    g : std_logic_vector(COLOR_DEPTH_G-1 downto 0);
    b : std_logic_vector(COLOR_DEPTH_B-1 downto 0);
  end record rgb_t;

  -- represents a sprite
  type sprite_t is record
    code     : unsigned(11 downto 0);
    color    : unsigned(3 downto 0);
    enable   : std_logic;
    flip_x   : std_logic;
    flip_y   : std_logic;
    pos      : pos_t;
    priority : unsigned(1 downto 0);
    size     : unsigned(5 downto 0);
  end record sprite_t;

  -- represents the video signals
  type video_t is record
    -- position
    pos : pos_t;

    -- sync signals
    hsync : std_logic;
    vsync : std_logic;
    csync : std_logic;

    -- blank signals
    hblank : std_logic;
    vblank : std_logic;

    -- enable video output
    enable : std_logic;
  end record video_t;

  -- represents a graphics layer
  type layer_t is (SPRITE_LAYER, CHAR_LAYER, FG_LAYER, BG_LAYER, FILL_LAYER);

  -- calculate sprite size (8x8, 16x16, 32x32, 64x64)
  function sprite_size_in_pixels(size : std_logic_vector(1 downto 0)) return natural;

  -- initialise sprite from a raw 64-bit value
  function init_sprite(data : std_logic_vector(SPRITE_RAM_DATA_WIDTH_B-1 downto 0)) return sprite_t;

  -- determine which graphics layer should be rendered
  function mux_layers(
    sprite_priority : std_logic_vector(SPRITE_PRIORITY_WIDTH-1 downto 0);
    sprite_data     : byte_t;
    char_data       : byte_t;
    fg_data         : byte_t;
    bg_data         : byte_t
  ) return layer_t;
end package types;

package body types is
  function sprite_size_in_pixels(size : std_logic_vector(1 downto 0)) return natural is
  begin
    case size is
      when "00" => return 8;
      when "01" => return 16;
      when "10" => return 32;
      when "11" => return 64;
    end case;
  end sprite_size_in_pixels;

  --  byte     bit        description
  -- --------+-76543210-+----------------
  --       0 | xxxx---- | hi code
  --         | -----x-- | enable
  --         | ------x- | flip y
  --         | -------x | flip x
  --       1 | xxxxxxxx | lo code
  --       2 | ------xx | size
  --       3 | xx-------| priority
  --         | --x----- | hi pos y
  --         | ---x---- | hi pos x
  --         | ----xxxx | colour
  --       4 | xxxxxxxx | lo pos y
  --       5 | xxxxxxxx | lo pos x
  --       6 | -------- |
  --       7 | -------- |
  function init_sprite(data : std_logic_vector(SPRITE_RAM_DATA_WIDTH_B-1 downto 0)) return sprite_t is
    variable sprite : sprite_t;
  begin
    sprite.code     := unsigned(data(SPRITE_HI_CODE_MSB downto SPRITE_HI_CODE_LSB)) & unsigned(data(SPRITE_LO_CODE_MSB downto SPRITE_LO_CODE_LSB));
    sprite.color    := unsigned(data(SPRITE_COLOR_MSB downto SPRITE_COLOR_LSB));
    sprite.enable   := data(SPRITE_ENABLE_BIT);
    sprite.flip_x   := data(SPRITE_FLIP_X_BIT);
    sprite.flip_y   := data(SPRITE_FLIP_Y_BIT);
    sprite.pos.x    := data(SPRITE_HI_POS_X_BIT) & unsigned(data(SPRITE_LO_POS_X_MSB downto SPRITE_LO_POS_X_LSB));
    sprite.pos.y    := data(SPRITE_HI_POS_Y_BIT) & unsigned(data(SPRITE_LO_POS_Y_MSB downto SPRITE_LO_POS_Y_LSB));
    sprite.priority := unsigned(data(SPRITE_PRIORITY_MSB downto SPRITE_PRIORITY_LSB));
    sprite.size     := to_unsigned(sprite_size_in_pixels(data(SPRITE_SIZE_MSB downto SPRITE_SIZE_LSB)), sprite.size'length);
    return sprite;
  end init_sprite;

  function mux_layers(
    sprite_priority : std_logic_vector(SPRITE_PRIORITY_WIDTH-1 downto 0);
    sprite_data     : byte_t;
    char_data       : byte_t;
    fg_data         : byte_t;
    bg_data         : byte_t
  ) return layer_t is
  begin
    case sprite_priority is
      when "00" =>
        if sprite_data(3 downto 0) /= "0000" then
          return SPRITE_LAYER;
        elsif char_data(3 downto 0) /= "0000" then
          return CHAR_LAYER;
        elsif fg_data(3 downto 0) /= "0000" then
          return FG_LAYER;
        elsif bg_data(3 downto 0) /= "0000" then
          return BG_LAYER;
        else
          return FILL_LAYER;
        end if;

      when "01" =>
        if char_data(3 downto 0) /= "0000" then
          return CHAR_LAYER;
        elsif sprite_data(3 downto 0) /= "0000" then
          return SPRITE_LAYER;
        elsif fg_data(3 downto 0) /= "0000" then
          return FG_LAYER;
        elsif bg_data(3 downto 0) /= "0000" then
          return BG_LAYER;
        else
          return FILL_LAYER;
        end if;

      when "10" =>
        if char_data(3 downto 0) /= "0000" then
          return CHAR_LAYER;
        elsif fg_data(3 downto 0) /= "0000" then
          return FG_LAYER;
        elsif sprite_data(3 downto 0) /= "0000" then
          return SPRITE_LAYER;
        elsif bg_data(3 downto 0) /= "0000" then
          return BG_LAYER;
        else
          return FILL_LAYER;
        end if;

      when "11" =>
        if char_data(3 downto 0) /= "0000" then
          return CHAR_LAYER;
        elsif fg_data(3 downto 0) /= "0000" then
          return FG_LAYER;
        elsif bg_data(3 downto 0) /= "0000" then
          return BG_LAYER;
        elsif sprite_data(3 downto 0) /= "0000" then
          return SPRITE_LAYER;
        else
          return FILL_LAYER;
        end if;
    end case;
  end mux_layers;
end package body types;
