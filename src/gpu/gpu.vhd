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

use work.common.all;

-- The graphical processing unit (GPU) implements the graphical layers of the
-- original arcade hardware.
--
-- The VRAM has been implemented using a dual-port RAM, because both the CPU
-- and the GPU need to access the VRAM concurrently. Port A is connected to the
-- CPU data bus, port B is connected to the GPU.
--
-- This differs from the original arcade hardware, which only contains
-- single-port RAM. Using a dual-port RAM instead simplifies things, because we
-- don't need all the additional logic required to coordinate RAM access.
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

    -- tile ROM interface
    sprite_rom_addr : out unsigned(SPRITE_ROM_ADDR_WIDTH-1 downto 0) := (others => '0');
    sprite_rom_data : in std_logic_vector(SPRITE_ROM_DATA_WIDTH-1 downto 0);
    char_rom_addr   : out unsigned(CHAR_ROM_ADDR_WIDTH-1 downto 0) := (others => '0');
    char_rom_data   : in std_logic_vector(CHAR_ROM_DATA_WIDTH-1 downto 0);
    fg_rom_addr     : out unsigned(FG_ROM_ADDR_WIDTH-1 downto 0) := (others => '0');
    fg_rom_data     : in std_logic_vector(FG_ROM_DATA_WIDTH-1 downto 0);
    bg_rom_addr     : out unsigned(BG_ROM_ADDR_WIDTH-1 downto 0) := (others => '0');
    bg_rom_data     : in std_logic_vector(BG_ROM_DATA_WIDTH-1 downto 0);

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
  -- sprite RAM
  signal sprite_ram_cpu_dout : byte_t;
  signal sprite_ram_gpu_addr : unsigned(SPRITE_RAM_GPU_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal sprite_ram_gpu_dout : std_logic_vector(SPRITE_RAM_GPU_DATA_WIDTH-1 downto 0);

  -- character RAM
  signal char_ram_cpu_dout : byte_t;
  signal char_ram_gpu_addr : unsigned(CHAR_RAM_GPU_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal char_ram_gpu_dout : std_logic_vector(CHAR_RAM_GPU_DATA_WIDTH-1 downto 0);

  -- foreground RAM
  signal fg_ram_cpu_dout : byte_t;
  signal fg_ram_gpu_addr : unsigned(FG_RAM_GPU_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal fg_ram_gpu_dout : std_logic_vector(FG_RAM_GPU_DATA_WIDTH-1 downto 0);

  -- background RAM
  signal bg_ram_cpu_dout : byte_t;
  signal bg_ram_gpu_addr : unsigned(BG_RAM_GPU_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal bg_ram_gpu_dout : std_logic_vector(BG_RAM_GPU_DATA_WIDTH-1 downto 0);

  -- palette RAM
  signal palette_ram_cpu_dout : byte_t;
  signal palette_ram_gpu_addr : unsigned(PALETTE_RAM_GPU_ADDR_WIDTH-1 downto 0);
  signal palette_ram_gpu_dout : std_logic_vector(PALETTE_RAM_GPU_DATA_WIDTH-1 downto 0);

  -- layer output signals
  signal sprite_data : byte_t := (others => '0');
  signal char_data   : byte_t := (others => '0');
  signal fg_data     : byte_t := (others => '0');
  signal bg_data     : byte_t := (others => '0');

  -- sprite priority data
  signal sprite_priority : priority_t;
begin
  -- video timing generator
  video_gen : entity work.video_gen
  port map (
    clk   => clk,
    cen   => cen_6,
    video => video
  );

  -- The sprite RAM (2kB) contains the sprite data.
  sprite_ram : entity work.true_dual_port_ram
  generic map (
    ADDR_WIDTH_A => SPRITE_RAM_CPU_ADDR_WIDTH,
    ADDR_WIDTH_B => SPRITE_RAM_GPU_ADDR_WIDTH,
    DATA_WIDTH_B => SPRITE_RAM_GPU_DATA_WIDTH
  )
  port map (
    -- CPU interface
    clk_a  => clk,
    cs_a   => sprite_ram_cs,
    addr_a => ram_addr(SPRITE_RAM_CPU_ADDR_WIDTH-1 downto 0),
    din_a  => ram_din,
    dout_a => sprite_ram_cpu_dout,
    we_a   => ram_we,

    -- GPU interface
    clk_b  => clk,
    addr_b => sprite_ram_gpu_addr,
    dout_b => sprite_ram_gpu_dout
  );

  -- The character RAM (2kB) contains the code and colour of each tile in the
  -- character tilemap.
  char_ram : entity work.true_dual_port_ram
  generic map (
    ADDR_WIDTH_A => CHAR_RAM_CPU_ADDR_WIDTH,
    ADDR_WIDTH_B => CHAR_RAM_GPU_ADDR_WIDTH,
    DATA_WIDTH_B => CHAR_RAM_GPU_DATA_WIDTH
  )
  port map (
    -- CPU interface
    clk_a  => clk,
    cs_a   => char_ram_cs,
    addr_a => ram_addr(CHAR_RAM_CPU_ADDR_WIDTH-1 downto 0),
    din_a  => ram_din,
    dout_a => char_ram_cpu_dout,
    we_a   => ram_we,

    -- GPU interface
    clk_b  => clk,
    addr_b => char_ram_gpu_addr,
    dout_b => char_ram_gpu_dout
  );

  -- The foreground RAM (1kB) contains the code and colour of each tile in the
  -- foreground tilemap.
  fg_ram : entity work.true_dual_port_ram
  generic map (
    ADDR_WIDTH_A => FG_RAM_CPU_ADDR_WIDTH,
    ADDR_WIDTH_B => FG_RAM_GPU_ADDR_WIDTH,
    DATA_WIDTH_B => FG_RAM_GPU_DATA_WIDTH
  )
  port map (
    -- CPU interface
    clk_a  => clk,
    cs_a   => fg_ram_cs,
    addr_a => ram_addr(FG_RAM_CPU_ADDR_WIDTH-1 downto 0),
    din_a  => ram_din,
    dout_a => fg_ram_cpu_dout,
    we_a   => ram_we,

    -- GPU interface
    clk_b  => clk,
    addr_b => fg_ram_gpu_addr,
    dout_b => fg_ram_gpu_dout
  );

  -- The background RAM (1kB) contains the code and colour of each tile in the
  -- background tilemap.
  bg_ram : entity work.true_dual_port_ram
  generic map (
    ADDR_WIDTH_A => BG_RAM_CPU_ADDR_WIDTH,
    ADDR_WIDTH_B => BG_RAM_GPU_ADDR_WIDTH,
    DATA_WIDTH_B => BG_RAM_GPU_DATA_WIDTH
  )
  port map (
    -- CPU interface
    clk_a  => clk,
    cs_a   => bg_ram_cs,
    addr_a => ram_addr(BG_RAM_CPU_ADDR_WIDTH-1 downto 0),
    din_a  => ram_din,
    dout_a => bg_ram_cpu_dout,
    we_a   => ram_we,

    -- GPU interface
    clk_b  => clk,
    addr_b => bg_ram_gpu_addr,
    dout_b => bg_ram_gpu_dout
  );

  -- The palette RAM contains 1024 16-bit RGB colour values, stored in
  -- RRRRGGGGXXXXBBBB format.
  palette_ram : entity work.true_dual_port_ram
  generic map (
    ADDR_WIDTH_A => PALETTE_RAM_CPU_ADDR_WIDTH,
    ADDR_WIDTH_B => PALETTE_RAM_GPU_ADDR_WIDTH,
    DATA_WIDTH_B => PALETTE_RAM_GPU_DATA_WIDTH
  )
  port map (
    -- CPU interface
    clk_a  => clk,
    cs_a   => palette_ram_cs,
    addr_a => ram_addr(PALETTE_RAM_CPU_ADDR_WIDTH-1 downto 0),
    din_a  => ram_din,
    dout_a => palette_ram_cpu_dout,
    we_a   => ram_we,

    -- GPU interface
    clk_b  => clk,
    addr_b => palette_ram_gpu_addr,
    dout_b => palette_ram_gpu_dout
  );

  sprite_layer_gen : if SPRITE_LAYER_ENABLE generate
    -- sprite layer
    sprite_layer : entity work.sprite_layer
    port map (
      -- clock signals
      clk   => clk,
      cen_6 => cen_6,

      -- RAM interface
      ram_addr => sprite_ram_gpu_addr,
      ram_data => sprite_ram_gpu_dout,

      -- ROM interface
      rom_addr => sprite_rom_addr,
      rom_data => sprite_rom_data,

      -- video signals
      video    => video,
      priority => sprite_priority,
      data     => sprite_data
    );
  end generate;

  char_layer_gen : if CHAR_LAYER_ENABLE generate
    -- character layer
    char_layer : entity work.char_layer
    port map (
      -- clock signals
      clk   => clk,
      cen_6 => cen_6,

      -- RAM interface
      ram_addr => char_ram_gpu_addr,
      ram_data => char_ram_gpu_dout,

      -- ROM interface
      rom_addr => char_rom_addr,
      rom_data => char_rom_data,

      -- video signals
      video => video,
      data  => char_data
    );
  end generate;

  fg_layer_gen : if FG_LAYER_ENABLE generate
    -- foreground layer
    fg_layer : entity work.scroll_layer
    generic map (
      RAM_ADDR_WIDTH => FG_RAM_GPU_ADDR_WIDTH,
      RAM_DATA_WIDTH => FG_RAM_GPU_DATA_WIDTH,
      ROM_ADDR_WIDTH => FG_ROM_ADDR_WIDTH,
      ROM_DATA_WIDTH => FG_ROM_DATA_WIDTH
    )
    port map (
      -- clock signals
      clk   => clk,
      cen_6 => cen_6,

      -- RAM interface
      ram_addr => fg_ram_gpu_addr,
      ram_data => fg_ram_gpu_dout,

      -- ROM interface
      rom_addr => fg_rom_addr,
      rom_data => fg_rom_data,

      -- video signals
      video      => video,
      scroll_pos => fg_scroll_pos,
      data       => fg_data
    );
  end generate;

  bg_layer_gen : if BG_LAYER_ENABLE generate
    -- background layer
    bg_layer : entity work.scroll_layer
    generic map (
      RAM_ADDR_WIDTH => BG_RAM_GPU_ADDR_WIDTH,
      RAM_DATA_WIDTH => BG_RAM_GPU_DATA_WIDTH,
      ROM_ADDR_WIDTH => BG_ROM_ADDR_WIDTH,
      ROM_DATA_WIDTH => BG_ROM_DATA_WIDTH
    )
    port map (
      -- clock signals
      clk   => clk,
      cen_6 => cen_6,

      -- RAM interface
      ram_addr => bg_ram_gpu_addr,
      ram_data => bg_ram_gpu_dout,

      -- ROM interface
      rom_addr => bg_rom_addr,
      rom_data => bg_rom_data,

      -- video signals
      video      => video,
      scroll_pos => bg_scroll_pos,
      data       => bg_data
    );
  end generate;

  -- colour palette
  palette : entity work.palette
  port map (
    -- clock signals
    clk   => clk,
    cen_6 => cen_6,

    -- RAM interface
    ram_addr => palette_ram_gpu_addr,
    ram_data => palette_ram_gpu_dout,

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
  ram_dout <= sprite_ram_cpu_dout or
              char_ram_cpu_dout or
              fg_ram_cpu_dout or
              bg_ram_cpu_dout or
              palette_ram_cpu_dout;
end architecture arch;
