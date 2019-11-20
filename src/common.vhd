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
use ieee.math_real.all;

package common is
  constant CPU_ADDR_WIDTH : natural := 16;

  -- IOCTL
  constant IOCTL_ADDR_WIDTH : natural := 22;

  -- SDRAM
  constant SDRAM_ADDR_WIDTH      : natural := 13;
  constant SDRAM_DATA_WIDTH      : natural := 16;
  constant SDRAM_BANK_WIDTH      : natural := 2;
  constant SDRAM_COL_WIDTH       : natural := 9;
  constant SDRAM_ROW_WIDTH       : natural := 13;
  constant SDRAM_CTRL_ADDR_WIDTH : natural := 23; -- 8Mx32-bit
  constant SDRAM_CTRL_DATA_WIDTH : natural := 32;

  -- work RAM
  constant WORK_RAM_ADDR_WIDTH : natural := 12; -- 4kB

  -- program ROMs
  constant PROG_ROM_1_ADDR_WIDTH : natural := 15; -- 32kB
  constant PROG_ROM_1_DATA_WIDTH : natural := 8;
  constant PROG_ROM_2_ADDR_WIDTH : natural := 14; -- 16kB
  constant PROG_ROM_2_DATA_WIDTH : natural := 8;
  constant PROG_ROM_3_ADDR_WIDTH : natural := 15; -- 32kB
  constant PROG_ROM_3_DATA_WIDTH : natural := 8;

  -- tile ROMs
  constant SPRITE_ROM_ADDR_WIDTH : natural := 15; -- 128kB
  constant SPRITE_ROM_DATA_WIDTH : natural := 32;
  constant CHAR_ROM_ADDR_WIDTH   : natural := 13; -- 32kB
  constant CHAR_ROM_DATA_WIDTH   : natural := 32;
  constant FG_ROM_ADDR_WIDTH     : natural := 15; -- 128kB
  constant FG_ROM_DATA_WIDTH     : natural := 32;
  constant BG_ROM_ADDR_WIDTH     : natural := 15; -- 128kB
  constant BG_ROM_DATA_WIDTH     : natural := 32;

  -- sound ROMs
  constant SOUND_ROM_1_ADDR_WIDTH : natural := 14;
  constant SOUND_ROM_1_DATA_WIDTH : natural := 8;
  constant SOUND_ROM_2_ADDR_WIDTH : natural := 15;
  constant SOUND_ROM_2_DATA_WIDTH : natural := 8;

  -- ROM offsets
  constant PROG_ROM_1_OFFSET  : natural := 16#00000#;
  constant PROG_ROM_2_OFFSET  : natural := 16#08000#;
  constant PROG_ROM_3_OFFSET  : natural := 16#0C000#;
  constant CHAR_ROM_OFFSET    : natural := 16#14000#;
  constant FG_ROM_OFFSET      : natural := 16#1C000#;
  constant BG_ROM_OFFSET      : natural := 16#3C000#;
  constant SPRITE_ROM_OFFSET  : natural := 16#5C000#;
  constant SOUND_ROM_1_OFFSET : natural := 16#7C000#;
  constant SOUND_ROM_2_OFFSET : natural := 16#80000#;

  -- VRAM
  constant BG_RAM_CPU_ADDR_WIDTH      : natural := 10; -- 1kB
  constant BG_RAM_GPU_ADDR_WIDTH      : natural := 10;
  constant BG_RAM_GPU_DATA_WIDTH      : natural := 8;
  constant CHAR_RAM_CPU_ADDR_WIDTH    : natural := 11; -- 2kB
  constant CHAR_RAM_GPU_ADDR_WIDTH    : natural := 11;
  constant CHAR_RAM_GPU_DATA_WIDTH    : natural := 8;
  constant FG_RAM_CPU_ADDR_WIDTH      : natural := 10; -- 1kB
  constant FG_RAM_GPU_ADDR_WIDTH      : natural := 10;
  constant FG_RAM_GPU_DATA_WIDTH      : natural := 8;
  constant PALETTE_RAM_CPU_ADDR_WIDTH : natural := 11; -- 2kB
  constant PALETTE_RAM_GPU_ADDR_WIDTH : natural := 10;
  constant PALETTE_RAM_GPU_DATA_WIDTH : natural := 16;
  constant SPRITE_RAM_CPU_ADDR_WIDTH  : natural := 11; -- 2kB
  constant SPRITE_RAM_GPU_ADDR_WIDTH  : natural := 8;
  constant SPRITE_RAM_GPU_DATA_WIDTH  : natural := 64;

  -- sound RAM
  constant SOUND_RAM_ADDR_WIDTH : natural := 11;

  -- frame buffer
  constant FRAME_BUFFER_ADDR_WIDTH : natural := 16;
  constant FRAME_BUFFER_DATA_WIDTH : natural := 10;

  -- each 8x8 tile is composed of four layers of pixel data (bitplanes)
  constant TILE_BPP : natural := 4;

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

  subtype byte_t is std_logic_vector(7 downto 0);
  subtype nibble_t is std_logic_vector(3 downto 0);

  -- represents a RGB colour value
  type rgb_t is record
    r : std_logic_vector(COLOR_DEPTH_R-1 downto 0);
    g : std_logic_vector(COLOR_DEPTH_G-1 downto 0);
    b : std_logic_vector(COLOR_DEPTH_B-1 downto 0);
  end record rgb_t;

  -- represents a position
  type pos_t is record
    x : unsigned(8 downto 0);
    y : unsigned(8 downto 0);
  end record pos_t;

  -- represents a priority
  subtype priority_t is unsigned(1 downto 0);

  -- represents a row of pixels in a 8x8 tile
  subtype tile_row_t is std_logic_vector(TILE_BPP*8-1 downto 0);

  -- represents a pixel in a 8x8 tile
  subtype tile_pixel_t is std_logic_vector(TILE_BPP-1 downto 0);

  -- represents the colour of a tile
  subtype tile_color_t is std_logic_vector(3 downto 0);

  -- represents the index of a tile in a tilemap
  subtype tile_code_t is unsigned(9 downto 0);

  -- represents the video signals
  type video_t is record
    -- position
    pos : pos_t;

    -- sync signals
    hsync : std_logic;
    vsync : std_logic;

    -- blank signals
    hblank : std_logic;
    vblank : std_logic;

    -- enable video output
    enable : std_logic;
  end record video_t;

  -- represents a sprite
  type sprite_t is record
    code     : unsigned(11 downto 0);
    color    : unsigned(3 downto 0);
    enable   : std_logic;
    flip_x   : std_logic;
    flip_y   : std_logic;
    pos      : pos_t;
    priority : priority_t;
    size     : unsigned(5 downto 0);
  end record sprite_t;

  -- represents a graphics layer
  type layer_t is (SPRITE_LAYER, CHAR_LAYER, FG_LAYER, BG_LAYER, FILL_LAYER);

  -- represents an audio sample
  subtype audio_t is signed(15 downto 0);

  -- calculates the log2 of the given number
  function ilog2(n : natural) return natural;

  -- decodes a single pixel from a tile row at the given offset
  function decode_tile_row (tile_row : tile_row_t; offset : unsigned(2 downto 0)) return tile_pixel_t;

  -- calculate sprite size (8x8, 16x16, 32x32, 64x64)
  function sprite_size_in_pixels (size : std_logic_vector(1 downto 0)) return natural;

  -- initialise sprite from a raw 64-bit value
  function init_sprite (data : std_logic_vector(SPRITE_RAM_GPU_DATA_WIDTH-1 downto 0)) return sprite_t;

  -- determine which graphics layer should be rendered
  function mux_layers (
    sprite_priority : priority_t;
    sprite_data     : byte_t;
    char_data       : byte_t;
    fg_data         : byte_t;
    bg_data         : byte_t
  ) return layer_t;
end package common;

package body common is
  function ilog2(n : natural) return natural is
  begin
    return natural(ceil(log2(real(n))));
  end ilog2;

  function decode_tile_row (
    tile_row : tile_row_t;
    offset   : unsigned(2 downto 0)
  ) return tile_pixel_t is
  begin
    case offset is
      when "000" => return tile_row(31 downto 28);
      when "001" => return tile_row(27 downto 24);
      when "010" => return tile_row(23 downto 20);
      when "011" => return tile_row(19 downto 16);
      when "100" => return tile_row(15 downto 12);
      when "101" => return tile_row(11 downto 8);
      when "110" => return tile_row(7 downto 4);
      when "111" => return tile_row(3 downto 0);
    end case;
  end decode_tile_row;

  function sprite_size_in_pixels (size : std_logic_vector(1 downto 0)) return natural is
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
  function init_sprite (data : std_logic_vector(SPRITE_RAM_GPU_DATA_WIDTH-1 downto 0)) return sprite_t is
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

  -- This function determines which graphics layer should be rendered, based on
  -- the sprite priority and the graphics layer data.
  --
  -- This differs from the original arcade hardware, which uses a priority
  -- encoder and some other logic gates to choose the correct layer to render.
  -- A giant conditional is way more verbose, but it's easy to understand how
  -- it works.
  function mux_layers (
    sprite_priority : priority_t;
    sprite_data     : byte_t;
    char_data       : byte_t;
    fg_data         : byte_t;
    bg_data         : byte_t
  ) return layer_t is
  begin
    case sprite_priority is
      -- sprites have the highest priority
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

      -- sprites are obscured by the character layer
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

      -- sprites are obscured by the character and foreground layers
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

      -- sprites are obscured by the character, foreground, and background layers
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
end package body common;
