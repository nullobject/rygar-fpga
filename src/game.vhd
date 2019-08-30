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

entity game is
  port (
    -- clock signals
    clk   : in std_logic;
    cen_6 : in std_logic;
    cen_4 : in std_logic;

    -- reset
    reset : in std_logic;

    -- sync signals
    hsync : out std_logic;
    vsync : out std_logic;

    -- RGB data
    r : out std_logic_vector(5 downto 0);
    g : out std_logic_vector(5 downto 0);
    b : out std_logic_vector(5 downto 0)
  );
end game;

architecture arch of game is
  -- CPU signals
  signal cpu_cen     : std_logic;
  signal cpu_addr    : unsigned(CPU_ADDR_WIDTH-1 downto 0);
  signal cpu_din     : byte_t;
  signal cpu_dout    : byte_t;
  signal cpu_ioreq_n : std_logic;
  signal cpu_mreq_n  : std_logic;
  signal cpu_rd_n    : std_logic;
  signal cpu_wr_n    : std_logic;
  signal cpu_rfsh_n  : std_logic;
  signal cpu_int_n   : std_logic := '1';
  signal cpu_m1_n    : std_logic;
  signal cpu_halt_n  : std_logic;

  -- chip select signals
  signal prog_rom_1_cs  : std_logic;
  signal prog_rom_2_cs  : std_logic;
  signal prog_rom_3_cs  : std_logic;
  signal work_ram_cs    : std_logic;
  signal char_ram_cs    : std_logic;
  signal fg_ram_cs      : std_logic;
  signal bg_ram_cs      : std_logic;
  signal sprite_ram_cs  : std_logic;
  signal palette_ram_cs : std_logic;
  signal bank_cs        : std_logic;
  signal scroll_cs      : std_logic;

  -- ROM signals
  signal sprite_rom_addr : unsigned(SPRITE_ROM_ADDR_WIDTH-1 downto 0);
  signal sprite_rom_data : std_logic_vector(SPRITE_ROM_DATA_WIDTH-1 downto 0);
  signal char_rom_addr   : unsigned(CHAR_ROM_ADDR_WIDTH-1 downto 0);
  signal char_rom_data   : std_logic_vector(CHAR_ROM_DATA_WIDTH-1 downto 0);
  signal fg_rom_addr     : unsigned(FG_ROM_ADDR_WIDTH-1 downto 0);
  signal fg_rom_data     : std_logic_vector(FG_ROM_DATA_WIDTH-1 downto 0);
  signal bg_rom_addr     : unsigned(BG_ROM_ADDR_WIDTH-1 downto 0);
  signal bg_rom_data     : std_logic_vector(BG_ROM_DATA_WIDTH-1 downto 0);

  -- data output signals
  signal prog_rom_1_dout : byte_t;
  signal prog_rom_2_dout : byte_t;
  signal prog_rom_3_dout : byte_t;
  signal work_ram_dout   : byte_t;
  signal gpu_dout        : byte_t;

  -- currently bank register
  signal current_bank_reg : unsigned(3 downto 0);

  -- scroll position registers
  signal fg_scroll_pos_reg : pos_t;
  signal bg_scroll_pos_reg : pos_t;

  -- video signals
  signal video : video_t;

  -- control signals
  signal vblank_falling : std_logic;

  -- RGB data
  signal rgb : rgb_t;
begin
  -- detect falling edges of the VBLANK signal
  vblank_edge_detector : entity work.edge_detector
  generic map (FALLING => true)
  port map (
    clk  => clk,
    data => video.vblank,
    edge => vblank_falling
  );

  -- program ROM 1
  prog_rom_1 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_1_ADDR_WIDTH, INIT_FILE => "rom/cpu_5p.mif")
  port map (
    clk  => clk,
    cs   => prog_rom_1_cs,
    addr => cpu_addr(PROG_ROM_1_ADDR_WIDTH-1 downto 0),
    dout => prog_rom_1_dout
  );

  -- program ROM 2
  prog_rom_2 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_2_ADDR_WIDTH, INIT_FILE => "rom/cpu_5m.mif")
  port map (
    clk  => clk,
    cs   => prog_rom_2_cs,
    addr => cpu_addr(PROG_ROM_2_ADDR_WIDTH-1 downto 0),
    dout => prog_rom_2_dout
  );

  -- program ROM 3
  prog_rom_3 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_3_ADDR_WIDTH, INIT_FILE => "rom/cpu_5j.mif")
  port map (
    clk  => clk,
    cs   => prog_rom_3_cs,
    addr => current_bank_reg & cpu_addr(10 downto 0),
    dout => prog_rom_3_dout
  );

  -- work RAM
  work_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => WORK_RAM_ADDR_WIDTH)
  port map (
    clk  => clk,
    cs   => work_ram_cs,
    addr => cpu_addr(WORK_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => work_ram_dout,
    we   => not cpu_wr_n
  );

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

  -- main CPU
  cpu : entity work.T80s
  port map (
    RESET_n             => not reset,
    CLK                 => clk,
    CEN                 => cen_4,
    WAIT_n              => '1',
    INT_n               => cpu_int_n,
    M1_n                => cpu_m1_n,
    MREQ_n              => cpu_mreq_n,
    IORQ_n              => cpu_ioreq_n,
    RD_n                => cpu_rd_n,
    WR_n                => cpu_wr_n,
    RFSH_n              => cpu_rfsh_n,
    HALT_n              => cpu_halt_n,
    BUSAK_n             => open,
    std_logic_vector(A) => cpu_addr,
    DI                  => cpu_din,
    DO                  => cpu_dout
  );

  -- GPU
  gpu : entity work.gpu
  generic map (
    SPRITE_LAYER_ENABLE => true,
    CHAR_LAYER_ENABLE   => true,
    FG_LAYER_ENABLE     => true,
    BG_LAYER_ENABLE     => false
  )
  port map (
    -- clock signals
    clk   => clk,
    cen_6 => cen_6,

    -- RAM interface
    ram_addr => cpu_addr,
    ram_din  => cpu_dout,
    ram_dout => gpu_dout,
    ram_we   => not cpu_wr_n,

    -- ROM interface
    sprite_rom_addr => sprite_rom_addr,
    sprite_rom_data => sprite_rom_data,
    char_rom_addr   => char_rom_addr,
    char_rom_data   => char_rom_data,
    fg_rom_addr     => fg_rom_addr,
    fg_rom_data     => fg_rom_data,
    bg_rom_addr     => bg_rom_addr,
    bg_rom_data     => bg_rom_data,

    -- chip select signals
    sprite_ram_cs  => sprite_ram_cs,
    char_ram_cs    => char_ram_cs,
    fg_ram_cs      => fg_ram_cs,
    bg_ram_cs      => bg_ram_cs,
    palette_ram_cs => palette_ram_cs,

    -- scroll layer positions
    fg_scroll_pos => fg_scroll_pos_reg,
    bg_scroll_pos => bg_scroll_pos_reg,

    -- video signals
    video => video,
    rgb   => rgb
  );

  -- Trigger an interrupt on the falling edge of the VBLANK signal.
  --
  -- Once the interrupt request has been accepted by the CPU, it is
  -- acknowledged by activating the IORQ signal during the M1 cycle. This
  -- disables the interrupt signal, and the cycle starts over.
  irq : process (clk)
  begin
    if rising_edge(clk) then
      if cpu_m1_n = '0' and cpu_ioreq_n = '0' then
        cpu_int_n <= '1';
      elsif vblank_falling = '1' then
        cpu_int_n <= '0';
      end if;
    end if;
  end process;

  -- Set current bank register.
  --
  -- This register selects the current bank for program ROM 3.
  set_current_bank : process (clk)
  begin
    if rising_edge(clk) then
      if bank_cs = '1' and cpu_wr_n = '0' then
        -- flip-flop 6J uses data lines 3 to 6
        current_bank_reg <= unsigned(cpu_dout(6 downto 3));
      end if;
    end if;
  end process;

  -- set foreground and background scroll position registers
  set_scroll_pos : process (clk)
  begin
    if rising_edge(clk) then
      if scroll_cs = '1' and cpu_wr_n = '0' then
        case cpu_addr(2 downto 0) is
          when "000" => fg_scroll_pos_reg.x(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when "001" => fg_scroll_pos_reg.x(8 downto 8) <= unsigned(cpu_dout(0 downto 0));
          when "010" => fg_scroll_pos_reg.y(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when "011" => bg_scroll_pos_reg.x(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when "100" => bg_scroll_pos_reg.x(8 downto 8) <= unsigned(cpu_dout(0 downto 0));
          when "110" => bg_scroll_pos_reg.y(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- $0000-$7fff PROGRAM ROM 1
  -- $8000-$bfff PROGRAM ROM 2
  -- $c000-$cfff WORK RAM
  -- $d000-$d7ff CHARACTER RAM
  -- $d800-$dbff FOREGROUND RAM
  -- $dc00-$dfff BACKGROUND RAM
  -- $e000-$e7ff SPRITE RAM
  -- $e800-$efff PALETTE RAM
  -- $f000-$f7ff PROGRAM ROM 3 (BANK SWITCHED)
  -- $f800-$ffff
  prog_rom_1_cs  <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"0000" and unsigned(cpu_addr) <= x"7fff" else '0';
  prog_rom_2_cs  <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"8000" and unsigned(cpu_addr) <= x"bfff" else '0';
  work_ram_cs    <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"c000" and unsigned(cpu_addr) <= x"cfff" else '0';
  char_ram_cs    <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"d000" and unsigned(cpu_addr) <= x"d7ff" else '0';
  fg_ram_cs      <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"d800" and unsigned(cpu_addr) <= x"dbff" else '0';
  bg_ram_cs      <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"dc00" and unsigned(cpu_addr) <= x"dfff" else '0';
  sprite_ram_cs  <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"e000" and unsigned(cpu_addr) <= x"e7ff" else '0';
  palette_ram_cs <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"e800" and unsigned(cpu_addr) <= x"efff" else '0';
  prog_rom_3_cs  <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"f000" and unsigned(cpu_addr) <= x"f7ff" else '0';
  scroll_cs      <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"f800" and unsigned(cpu_addr) <= x"f805" else '0';
  bank_cs        <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) = x"f808" else '0';

  -- mux CPU data input
  cpu_din <= prog_rom_1_dout or
             prog_rom_2_dout or
             prog_rom_3_dout or
             work_ram_dout or
             gpu_dout;

  -- set sync signals
  hsync <= video.hsync;
  vsync <= video.vsync;

  -- set RGB data
  r <= rgb.r & rgb.r(3 downto 2);
  g <= rgb.g & rgb.g(3 downto 2);
  b <= rgb.b & rgb.b(3 downto 2);
end architecture arch;
