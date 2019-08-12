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

-- The sprite blitter copies sprite data from the tile ROM to the frame buffer.
--
-- A blit operation is triggered by setting the sprite descriptor and asserting
-- the start signal. Once all the pixels have been copied to the frame buffer,
-- the done signal is asserted by the sprite blitter.
--
-- The busy signal is asserted while the sprite blitter is writing pixel data
-- to the frame buffer. This signal should be used to enable write access to
-- the frame buffer.
entity sprite_blitter is
  port (
    -- clock
    clk : in std_logic;

    -- sprite descriptor
    sprite : in sprite_t;

    -- control signals
    start : in std_logic;
    busy  : out std_logic;
    done  : out std_logic;

    -- data in
    src_addr : out std_logic_vector(SPRITE_TILE_ROM_ADDR_WIDTH-1 downto 0);
    din      : in byte_t;

    -- data out
    dest_addr : out std_logic_vector(FRAME_BUFFER_ADDR_WIDTH-1 downto 0);
    dout      : out std_logic_vector(FRAME_BUFFER_DATA_WIDTH-1 downto 0)
  );
end sprite_blitter;

architecture arch of sprite_blitter is
  -- represents the position of a pixel in a sprite
  type sprite_pos_t is record
    x : unsigned(4 downto 0);
    y : unsigned(4 downto 0);
  end record sprite_pos_t;

  type state_t is (INIT, CHECK, PRELOAD, BLIT);

  -- state signals
  signal state, next_state : state_t;

  -- position signals
  signal src_pos  : sprite_pos_t;
  signal load_pos : sprite_pos_t;
  signal dest_pos : pos_t;

  -- graphics signals
  signal gfx_data : byte_t;
  signal pixel    : nibble_t;

  -- control signals
  signal preload_done : std_logic;
  signal blit_done    : std_logic;
  signal visible      : std_logic;
begin
  -- latch the next state
  latch_state : process (clk)
  begin
    if rising_edge(clk) then
      state <= next_state;
    end if;
  end process;

  -- state machine
  fsm : process (state, start, visible, preload_done, blit_done)
  begin
    next_state <= state;

    case state is
      -- this is the default state, we just wait for the start signal
      when INIT =>
        if start = '1' then
          next_state <= CHECK;
        end if;

      -- check whether the sprite is visible before we bother to render it
      when CHECK =>
        if visible = '1' then
          next_state <= PRELOAD;
        else
          next_state <= INIT;
        end if;

      -- preload the data for the first pixel
      when PRELOAD =>
        if preload_done = '1' then
          next_state <= BLIT;
        end if;

      -- copy pixels from the source to the destination
      when BLIT =>
        if blit_done = '1' then
          next_state <= INIT;
        end if;
    end case;
  end process;

  -- the source position represents the current pixel offset of the sprite to
  -- be copied to the frame buffer
  update_src_pos_counter : process (clk)
  begin
    if rising_edge(clk) then
      if state = INIT then
        -- set source position to first pixel
        src_pos.x <= (others => '0');
        src_pos.y <= (others => '0');
      elsif state = BLIT then
        if src_pos.x = sprite.size-1 then
          src_pos.x <= (others => '0');

          if src_pos.y = sprite.size-1 then
            src_pos.y <= (others => '0');
          else
            src_pos.y <= src_pos.y + 1;
          end if;
        else
          src_pos.x <= src_pos.x + 1;
        end if;
      end if;
    end if;
  end process;

  -- the load position represents the position of the next pixel to be loaded
  update_load_pos_counter : process (clk)
  begin
    if rising_edge(clk) then
      if state = INIT then
        -- set load position to first pixel
        load_pos.x <= (others => '0');
        load_pos.y <= (others => '0');
      elsif state = PRELOAD or state = BLIT then
        if load_pos.x = sprite.size-1 then
          load_pos.x <= (others => '0');

          if load_pos.y = sprite.size-1 then
            load_pos.y <= (others => '0');
          else
            load_pos.y <= load_pos.y + 1;
          end if;
        else
          load_pos.x <= load_pos.x + 1;
        end if;
      end if;
    end if;
  end process;

  -- latch fresh graphics data from the tile ROM while we are blitting the odd
  -- pixels to the frame buffer
  latch_gfx_data : process (clk)
  begin
    if rising_edge(clk) then
      if (state = PRELOAD or state = BLIT) and load_pos.x(0) = '1' then
        gfx_data <= din;
      end if;
    end if;
  end process;

  -- write to the frame buffer when we're blitting to the visible part of the frame
  busy <= '1' when state = BLIT and pixel /= "0000" and dest_pos.x(8) = '0' and dest_pos.y(8) = '0' else '0';

  -- set done output
  done <= '1' when state = INIT else '0';

  -- the sprite is visible if it is enabled
  visible <= '1' when sprite.enable = '1' else '0';

  -- the source address
  src_addr <= std_logic_vector(
    sprite.code(11 downto 4) &
    (sprite.code(3 downto 0) or (load_pos.y(4) & load_pos.x(4) & load_pos.y(3) & load_pos.x(3))) &
    load_pos.y(2 downto 0) &
    load_pos.x(2 downto 1)
  );

  -- set destination position and handle X/Y axis flipping
  dest_pos.x <= resize(sprite.pos.x+src_pos.x, dest_pos.x'length) when sprite.flip_x = '0' else
                resize(sprite.pos.x-src_pos.x+sprite.size-1, dest_pos.x'length);
  dest_pos.y <= resize(sprite.pos.y+src_pos.y, dest_pos.y'length) when sprite.flip_y = '0' else
                resize(sprite.pos.y-src_pos.y+sprite.size-1, dest_pos.y'length);

  -- the pre-blit is done when the first two pixels have been loaded
  preload_done <= '1' when load_pos.x = 1 else '0';

  -- the blit is done when all the pixels have been copied
  blit_done <= '1' when src_pos.x = sprite.size-1 and src_pos.y = sprite.size-1 else '0';

  -- set destination address
  dest_addr <= std_logic_vector(dest_pos.y(7 downto 0) & dest_pos.x(7 downto 0));

  -- set current pixel
  pixel <= gfx_data(7 downto 4) when src_pos.x(0) = '0' else gfx_data(3 downto 0);

  -- set data
  dout <= std_logic_vector(sprite.priority & sprite.color) & pixel;
end architecture arch;
