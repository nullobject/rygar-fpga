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

entity gpu is
  generic (
    SPRITE_LAYER_ENABLE : boolean := true;
    CHAR_LAYER_ENABLE   : boolean := true;
    FG_LAYER_ENABLE     : boolean := true;
    BG_LAYER_ENABLE     : boolean := true
  );
  port (
    -- clock signals
    clk   : in std_logic;
    cen_6 : in std_logic;

    -- RAM interface
    ram_addr : in unsigned(CPU_ADDR_WIDTH-1 downto 0);
    ram_din  : in byte_t;
    ram_dout : out byte_t;
    ram_we   : in std_logic;

    -- chip select signals
    sprite_ram_cs  : in std_logic;
    char_ram_cs    : in std_logic;
    fg_ram_cs      : in std_logic;
    bg_ram_cs      : in std_logic;
    palette_ram_cs : in std_logic;

    -- scroll layer positions
    fg_scroll_pos : in pos_t;
    bg_scroll_pos : in pos_t;

    -- video signals
    video : buffer video_t;
    rgb   : out rgb_t
  );
end gpu;

architecture arch of gpu is
  -- data output signals
  signal char_ram_dout    : byte_t;
  signal fg_ram_dout      : byte_t;
  signal bg_ram_dout      : byte_t;
  signal sprite_ram_dout  : byte_t;
  signal palette_ram_dout : byte_t;

  -- sprite ROM
  signal sprite_rom_addr : unsigned(SPRITE_ROM_ADDR_WIDTH-1 downto 0);
  signal sprite_rom_data : std_logic_vector(SPRITE_ROM_DATA_WIDTH-1 downto 0);

  -- character ROM
  signal char_rom_addr : unsigned(CHAR_ROM_ADDR_WIDTH-1 downto 0);
  signal char_rom_data : std_logic_vector(CHAR_ROM_DATA_WIDTH-1 downto 0);

  -- foreground ROM
  signal fg_rom_addr : unsigned(FG_ROM_ADDR_WIDTH-1 downto 0);
  signal fg_rom_data : std_logic_vector(FG_ROM_DATA_WIDTH-1 downto 0);

  -- background ROM
  signal bg_rom_addr : unsigned(BG_ROM_ADDR_WIDTH-1 downto 0);
  signal bg_rom_data : std_logic_vector(BG_ROM_DATA_WIDTH-1 downto 0);

  -- graphics layer data
  signal sprite_data : byte_t := (others => '0');
  signal char_data   : byte_t := (others => '0');
  signal fg_data     : byte_t := (others => '0');
  signal bg_data     : byte_t := (others => '0');

  -- sprite priority data
  signal sprite_priority : priority_t;
begin
  -- video timing generator
  sync_gen : entity work.sync_gen
  port map (
    clk   => clk,
    cen_6 => cen_6,
    video => video
  );

  sprite_layer_gen : if SPRITE_LAYER_ENABLE generate
    -- sprite ROM
    sprite_rom : entity work.single_port_rom
    generic map (
      ADDR_WIDTH => SPRITE_ROM_ADDR_WIDTH,
      DATA_WIDTH => SPRITE_ROM_DATA_WIDTH,
      INIT_FILE  => "rom/sprites.mif"
    )
    port map (
      clk  => clk,
      addr => sprite_rom_addr,
      dout => sprite_rom_data
    );

    -- sprite layer
    sprite_layer : entity work.sprite
    port map (
      -- clock signals
      clk   => clk,
      cen_6 => cen_6,

      -- RAM interface
      ram_cs   => sprite_ram_cs,
      ram_addr => ram_addr(SPRITE_RAM_ADDR_WIDTH-1 downto 0),
      ram_din  => ram_din,
      ram_dout => sprite_ram_dout,
      ram_we   => ram_we,

      -- ROM interface
      rom_addr => sprite_rom_addr,
      rom_data => sprite_rom_data,

      -- video signals
      video    => video,
      priority => sprite_priority,
      data     => sprite_data
    );
  end generate;

  sprite_debug_gen : if not SPRITE_LAYER_ENABLE generate
    -- dummy sprite RAM
    sprite_ram : entity work.single_port_ram
    generic map (ADDR_WIDTH => SPRITE_RAM_ADDR_WIDTH)
    port map (
      clk  => clk,
      cs   => sprite_ram_cs,
      addr => ram_addr(SPRITE_RAM_ADDR_WIDTH-1 downto 0),
      din  => ram_din,
      dout => sprite_ram_dout,
      we   => ram_we
    );
  end generate;

  char_layer_gen : if CHAR_LAYER_ENABLE generate
    -- character ROM
    char_rom : entity work.single_port_rom
    generic map (
      ADDR_WIDTH => CHAR_ROM_ADDR_WIDTH,
      DATA_WIDTH => CHAR_ROM_DATA_WIDTH,
      INIT_FILE  => "rom/cpu_8k.mif"
    )
    port map (
      clk  => clk,
      addr => char_rom_addr,
      dout => char_rom_data
    );

    -- character layer
    char_layer : entity work.char
    port map (
      -- clock signals
      clk   => clk,
      cen_6 => cen_6,

      -- RAM interface
      ram_cs   => char_ram_cs,
      ram_addr => ram_addr(CHAR_RAM_ADDR_WIDTH-1 downto 0),
      ram_din  => ram_din,
      ram_dout => char_ram_dout,
      ram_we   => ram_we,

      -- ROM interface
      rom_addr => char_rom_addr,
      rom_data => char_rom_data,

      -- video signals
      video => video,
      data  => char_data
    );
  end generate;

  char_debug_gen : if not CHAR_LAYER_ENABLE generate
    -- dummy character RAM
    char_ram : entity work.single_port_ram
    generic map (ADDR_WIDTH => CHAR_RAM_ADDR_WIDTH)
    port map (
      clk  => clk,
      cs   => char_ram_cs,
      addr => ram_addr(CHAR_RAM_ADDR_WIDTH-1 downto 0),
      din  => ram_din,
      dout => char_ram_dout,
      we   => ram_we
    );
  end generate;

  fg_layer_gen : if FG_LAYER_ENABLE generate
    -- foreground ROM
    fg_rom : entity work.single_port_rom
    generic map (
      ADDR_WIDTH => FG_ROM_ADDR_WIDTH,
      DATA_WIDTH => FG_ROM_DATA_WIDTH,
      INIT_FILE  => "rom/fg.mif"
    )
    port map (
      clk  => clk,
      addr => fg_rom_addr,
      dout => fg_rom_data
    );

    -- foreground layer
    fg_layer : entity work.scroll
    generic map (
      RAM_ADDR_WIDTH => FG_RAM_ADDR_WIDTH,
      ROM_ADDR_WIDTH => FG_ROM_ADDR_WIDTH,
      ROM_DATA_WIDTH => FG_ROM_DATA_WIDTH
    )
    port map (
      -- clock signals
      clk   => clk,
      cen_6 => cen_6,

      -- RAM interface
      ram_cs   => fg_ram_cs,
      ram_addr => ram_addr(FG_RAM_ADDR_WIDTH-1 downto 0),
      ram_din  => ram_din,
      ram_dout => fg_ram_dout,
      ram_we   => ram_we,

      -- ROM interface
      rom_addr => fg_rom_addr,
      rom_data => fg_rom_data,

      -- video signals
      video      => video,
      scroll_pos => fg_scroll_pos,
      data       => fg_data
    );
  end generate;

  fg_debug_gen : if not FG_LAYER_ENABLE generate
    -- dummy foreground RAM
    fg_ram : entity work.single_port_ram
    generic map (ADDR_WIDTH => FG_RAM_ADDR_WIDTH)
    port map (
      clk  => clk,
      cs   => fg_ram_cs,
      addr => ram_addr(FG_RAM_ADDR_WIDTH-1 downto 0),
      din  => ram_din,
      dout => fg_ram_dout,
      we   => ram_we
    );
  end generate;

  bg_layer_gen : if BG_LAYER_ENABLE generate
    -- background ROM
    bg_rom : entity work.single_port_rom
    generic map (
      ADDR_WIDTH => BG_ROM_ADDR_WIDTH,
      DATA_WIDTH => BG_ROM_DATA_WIDTH,
      INIT_FILE  => "rom/bg.mif"
    )
    port map (
      clk  => clk,
      addr => bg_rom_addr,
      dout => bg_rom_data
    );

    -- background layer
    bg_layer : entity work.scroll
    generic map (
      RAM_ADDR_WIDTH => BG_RAM_ADDR_WIDTH,
      ROM_ADDR_WIDTH => BG_ROM_ADDR_WIDTH,
      ROM_DATA_WIDTH => BG_ROM_DATA_WIDTH
    )
    port map (
      -- clock signals
      clk   => clk,
      cen_6 => cen_6,

      -- RAM interface
      ram_cs   => bg_ram_cs,
      ram_addr => ram_addr(BG_RAM_ADDR_WIDTH-1 downto 0),
      ram_din  => ram_din,
      ram_dout => bg_ram_dout,
      ram_we   => ram_we,

      -- ROM interface
      rom_addr => bg_rom_addr,
      rom_data => bg_rom_data,

      -- video signals
      video      => video,
      scroll_pos => bg_scroll_pos,
      data       => bg_data
    );
  end generate;

  bg_debug_gen : if not BG_LAYER_ENABLE generate
    -- dummy background RAM
    bg_ram : entity work.single_port_ram
    generic map (ADDR_WIDTH => BG_RAM_ADDR_WIDTH)
    port map (
      clk  => clk,
      cs   => bg_ram_cs,
      addr => ram_addr(BG_RAM_ADDR_WIDTH-1 downto 0),
      din  => ram_din,
      dout => bg_ram_dout,
      we   => ram_we
    );
  end generate;

  -- colour palette
  palette : entity work.palette
  port map (
    -- clock signals
    clk   => clk,
    cen_6 => cen_6,

    -- RAM interface
    ram_cs   => palette_ram_cs,
    ram_addr => ram_addr(PALETTE_RAM_ADDR_WIDTH-1 downto 0),
    ram_din  => ram_din,
    ram_dout => palette_ram_dout,
    ram_we   => ram_we,

    -- layer data
    sprite_data => sprite_data,
    char_data   => char_data,
    fg_data     => fg_data,
    bg_data     => bg_data,

    -- sprite priority
    sprite_priority => sprite_priority,

    -- video signals
    video => video,
    rgb   => rgb
  );

  -- mux GPU data output
  ram_dout <= char_ram_dout or
              fg_ram_dout or
              bg_ram_dout or
              sprite_ram_dout or
              palette_ram_dout;
end architecture arch;
