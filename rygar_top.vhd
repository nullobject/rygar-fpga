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

library pll;

use work.rygar.all;

entity rygar_top is
  port (
    -- 50MHz input clock
    clk : in std_logic;

    -- RGB colours
    vga_r, vga_g, vga_b : out std_logic_vector(5 downto 0);

    -- horizontal and vertical sync
    vga_hs, vga_vs : out std_logic := '1';

    -- buttons
    key : in std_logic_vector(1 downto 0);

    -- LEDs
    led : out std_logic_vector(7 downto 0);
    debug : out std_logic_vector(23 downto 0)
  );
end rygar_top;

architecture arch of rygar_top is
  -- clock signals
  signal clk_12 : std_logic;
  signal cen_6 : std_logic;
  signal cen_4 : std_logic;

  -- reset
  signal reset : std_logic;

  -- CPU clock enable
  signal cpu_cen : std_logic;

  -- CPU address bus
  signal cpu_addr : std_logic_vector(15 downto 0);

  -- CPU data bus
  signal cpu_din, cpu_dout : std_logic_vector(7 downto 0);

  -- CPU IO request: the address bus holds a valid address for an IO read or
  -- write operation
  signal cpu_ioreq_n : std_logic;

  -- CPU memory request: the address bus holds a valid address for a memory
  -- read or write operation
  signal cpu_mreq_n : std_logic;

  -- CPU read: ready to read data from the data bus
  signal cpu_rd_n : std_logic;

  -- CPU write: the data bus contains a byte to write somewhere
  signal cpu_wr_n : std_logic;

  -- CPU refresh: the lower seven bits of the address bus should be refreshed
  signal cpu_rfsh_n : std_logic;

  -- CPU interrupt: when this signal is asserted it triggers an interrupt
  signal cpu_int_n : std_logic := '1';

  -- CPU timing signal
  signal cpu_m1_n : std_logic;

  -- CPU halt signal
  signal cpu_halt_n : std_logic;

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

  -- chip data output signals
  signal prog_rom_1_dout  : std_logic_vector(7 downto 0);
  signal prog_rom_2_dout  : std_logic_vector(7 downto 0);
  signal prog_rom_3_dout  : std_logic_vector(7 downto 0);
  signal work_ram_dout    : std_logic_vector(7 downto 0);
  signal char_ram_dout    : std_logic_vector(7 downto 0);
  signal fg_ram_dout      : std_logic_vector(7 downto 0);
  signal bg_ram_dout      : std_logic_vector(7 downto 0);
  signal sprite_ram_dout  : std_logic_vector(7 downto 0);
  signal palette_ram_dout : std_logic_vector(7 downto 0);

  -- currently selected bank for program ROM 3
  signal prog_rom_3_bank : unsigned(3 downto 0);

  signal video_pixel_x, video_pixel_y : unsigned(8 downto 0);
  signal video_hsync, video_vsync : std_logic;
  signal video_hblank, video_vblank : std_logic;
  signal video_on : std_logic;
  signal vblank_falling : std_logic;

  -- char tilemap signals
  signal char_tilemap_data : std_logic_vector(7 downto 0);
  signal char_tilemap_debug : std_logic_vector(5 downto 0);
begin
  my_pll : entity pll.pll
  port map (
    refclk   => clk,
    rst      => '0',
    outclk_0 => clk_12,
    locked   => open
  );

  -- generate the 6MHz clock enable signal
  clock_divider_6 : entity work.clock_divider
  generic map (DIVISOR => 2)
  port map (clk => clk_12, cen => cen_6);

  -- generate the 4MHz clock enable signal
  clock_divider_4 : entity work.clock_divider
  generic map (DIVISOR => 3)
  port map (clk => clk_12, cen => cen_4);

  -- Generate CPU reset pulse after powering on, or when KEY0 is pressed.
  --
  -- The Z80 needs to be reset after powering on, otherwise it may load garbage
  -- data from the address and data buses.
  reset_gen : entity work.reset_gen
  port map (
    clk  => clk_12,
    rin  => not key(0),
    rout => reset
  );

  -- video sync generator
  sync_gen : entity work.sync_gen
  port map (
    clk     => clk_12,
    cen     => cen_6,
    pixel_x => video_pixel_x,
    pixel_y => video_pixel_y,
    hsync   => video_hsync,
    vsync   => video_vsync,
    hblank  => video_hblank,
    vblank  => video_vblank
  );

  -- program ROM 1 (32kB)
  prog_rom_1 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_1_ADDR_WIDTH, INIT_FILE => "cpu_5p.mif")
  port map (
    clk  => clk_12,
    addr => cpu_addr(PROG_ROM_1_ADDR_WIDTH-1 downto 0),
    dout => prog_rom_1_dout
  );

  -- program ROM 2 (16kB)
  prog_rom_2 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_2_ADDR_WIDTH, INIT_FILE => "cpu_5m.mif")
  port map (
    clk  => clk_12,
    addr => cpu_addr(PROG_ROM_2_ADDR_WIDTH-1 downto 0),
    dout => prog_rom_2_dout
  );

  -- program ROM 3 (32kB bank switched)
  prog_rom_3 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_3_ADDR_WIDTH, INIT_FILE => "cpu_5j.mif")
  port map (
    clk  => clk_12,
    addr => std_logic_vector(prog_rom_3_bank) & cpu_addr(10 downto 0),
    dout => prog_rom_3_dout
  );

  -- work ram (4kB)
  work_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => WORK_RAM_ADDR_WIDTH)
  port map (
    clk  => clk_12,
    cen  => work_ram_cs,
    addr => cpu_addr(WORK_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => work_ram_dout,
    we   => not cpu_wr_n
  );

  -- fg ram (1kB)
  fg_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => FG_RAM_ADDR_WIDTH)
  port map (
    clk  => clk_12,
    cen  => fg_ram_cs,
    addr => cpu_addr(FG_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => fg_ram_dout,
    we   => not cpu_wr_n
  );

  -- bg ram (1kB)
  bg_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => BG_RAM_ADDR_WIDTH)
  port map (
    clk  => clk_12,
    cen  => bg_ram_cs,
    addr => cpu_addr(BG_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => bg_ram_dout,
    we   => not cpu_wr_n
  );

  -- sprite ram (2kB)
  sprite_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => SPRITE_RAM_ADDR_WIDTH)
  port map (
    clk  => clk_12,
    cen  => sprite_ram_cs,
    addr => cpu_addr(SPRITE_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => sprite_ram_dout,
    we   => not cpu_wr_n
  );

  -- palette ram (2kB)
  palette_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => PALETTE_RAM_ADDR_WIDTH)
  port map (
    clk  => clk_12,
    cen  => palette_ram_cs,
    addr => cpu_addr(PALETTE_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => palette_ram_dout,
    we   => not cpu_wr_n
  );

  -- main cpu
  cpu : entity work.T80s
  port map (
    RESET_n => not reset,
    CLK     => clk_12,
    CEN     => cen_4,
    WAIT_n  => '1',
    INT_n   => cpu_int_n,
    M1_n    => cpu_m1_n,
    MREQ_n  => cpu_mreq_n,
    IORQ_n  => cpu_ioreq_n,
    RD_n    => cpu_rd_n,
    WR_n    => cpu_wr_n,
    RFSH_n  => cpu_rfsh_n,
    HALT_n  => cpu_halt_n,
    BUSAK_n => open,
    A       => cpu_addr,
    DI      => cpu_din,
    DO      => cpu_dout
  );

  -- detect falling edges of the VBLANK signal
  vblank_edge_detector : entity work.edge_detector
  generic map (RISING => false)
  port map (
    clk  => clk_12,
    data => video_vblank,
    edge => vblank_falling
  );

  -- An interrupt is triggered on the falling edge of the VBLANK signal.
  --
  -- Once the interrupt request has been accepted by the CPU, it is
  -- acknowledged by activating the IORQ signal during the M1 cycle. This
  -- disables the interrupt signal, and the cycle starts over.
  irq : process(clk_12)
  begin
    if rising_edge(clk_12) then
      if cpu_m1_n = '0' and cpu_ioreq_n = '0' then
        cpu_int_n <= '1';
      elsif vblank_falling = '1' then
        cpu_int_n <= '0';
      end if;
    end if;
  end process;

  -- Setting the bank register changes the currently selected bank of program
  -- ROM 3.
  bank_register : process(clk_12)
  begin
    if rising_edge(clk_12) then
      if bank_cs = '1' and cpu_wr_n = '0' then
        -- flip-flop 6J uses data lines 3 to 6
        prog_rom_3_bank <= unsigned(cpu_dout(6 downto 3));
      end if;
    end if;
  end process;

  -- character tilemap generator
  char_tilemap : entity work.char_tilemap
  port map (
    reset    => reset,
    clk      => clk_12,
    cen      => cen_6,
    ram_cs   => char_ram_cs,
    ram_addr => cpu_addr(CHAR_RAM_ADDR_WIDTH-1 downto 0),
    ram_din  => cpu_dout,
    ram_dout => char_ram_dout,
    ram_we   => not cpu_wr_n,
    pixel_x  => video_pixel_x(7 downto 0),
    pixel_y  => video_pixel_y(7 downto 0),
    data     => char_tilemap_data,
    debug    => char_tilemap_debug
  );

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
  bank_cs        <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) = x"f808" else '0';

  -- Connect the selected devices to the CPU data input bus.
  cpu_din <= prog_rom_1_dout when prog_rom_1_cs = '1' else
             prog_rom_2_dout when prog_rom_2_cs = '1' else
             prog_rom_3_dout when prog_rom_3_cs = '1' else
             work_ram_dout when work_ram_cs = '1' else
             char_ram_dout when char_ram_cs = '1' else
             fg_ram_dout when fg_ram_cs = '1' else
             bg_ram_dout when bg_ram_cs = '1' else
             sprite_ram_dout when sprite_ram_cs = '1' else
             palette_ram_dout when palette_ram_cs = '1' else
             (others => '0');

  led <= cpu_dout when work_ram_cs = '1' and cpu_wr_n = '0' else (others => '0');

  -- output flags and 8 lsb address lines
  debug(15 downto 0) <= (not cpu_m1_n) &
                        (not cpu_mreq_n) &
                        (not cpu_rd_n) &
                        (not cpu_wr_n) &
                        (not cpu_rfsh_n) &
                        (not cpu_halt_n) &
                        cpu_addr(9 downto 0);
  debug(16) <= clk_12;
  debug(17) <= cen_4;
  debug(18) <= cen_6;
  debug(19) <= video_vsync;
  debug(20) <= video_vblank;
  debug(21) <= cpu_int_n;
  debug(22) <= cpu_m1_n;
  debug(23) <= cpu_ioreq_n;

  video_on <= not (video_hblank or video_vblank);
  vga_hs <= not (video_hsync xor video_vsync);

  process(clk_12)
  begin
    if rising_edge(clk_12) then
      if video_on = '1' then
        vga_r <= char_tilemap_debug;
        vga_g <= char_tilemap_debug;
        vga_b <= char_tilemap_debug;
      else
        vga_r <= (others => '0');
        vga_g <= (others => '0');
        vga_b <= (others => '0');
      end if;
    end if;
  end process;
end arch;
