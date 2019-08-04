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

use work.types.all;

entity rygar_top is
  port (
    -- 50MHz input clock
    clk : in std_logic;

    -- VGA signals
    vga_r     : out std_logic_vector(5 downto 0);
    vga_g     : out std_logic_vector(5 downto 0);
    vga_b     : out std_logic_vector(5 downto 0);
    vga_csync : out std_logic;

    -- buttons
    key : in std_logic_vector(1 downto 0);

    -- LEDs
    led : out byte_t
  );
end rygar_top;

architecture arch of rygar_top is
  -- clock signals
  signal clk_12 : std_logic;
  signal cen_6  : std_logic;
  signal cen_4  : std_logic;

  -- reset
  signal reset : std_logic;

  -- CPU signals
  signal cpu_cen     : std_logic;
  signal cpu_addr    : std_logic_vector(15 downto 0);
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
  signal fg_scroll_cs   : std_logic;
  signal bg_scroll_cs   : std_logic;

  -- chip data output signals
  signal prog_rom_1_dout  : byte_t;
  signal prog_rom_2_dout  : byte_t;
  signal prog_rom_3_dout  : byte_t;
  signal work_ram_dout    : byte_t;
  signal char_ram_dout    : byte_t;
  signal fg_ram_dout      : byte_t;
  signal bg_ram_dout      : byte_t;
  signal sprite_ram_dout  : byte_t;
  signal palette_ram_dout : byte_t;

  -- currently selected bank for program ROM 3
  signal current_bank : unsigned(3 downto 0);

  -- scroll position registers
  signal fg_scroll_hpos : unsigned(8 downto 0);
  signal fg_scroll_vpos : unsigned(7 downto 0);
  signal bg_scroll_hpos : unsigned(8 downto 0);
  signal bg_scroll_vpos : unsigned(7 downto 0);

  -- video signals
  signal video_pos   : pos_t;
  signal video_sync  : sync_t;
  signal video_blank : blank_t;

  -- pixel data
  signal pixel : rgb_t;

  signal vblank_falling : std_logic;

  -- graphics layer data
  signal char_data : byte_t;
  signal fg_data : byte_t;
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

  -- Generate reset pulse after powering on, or when KEY0 is pressed.
  --
  -- The Z80 needs to be reset after powering on, otherwise it may load garbage
  -- data from the address and data buses.
  reset_gen : entity work.reset_gen
  port map (
    clk  => clk_12,
    rin  => not key(0),
    rout => reset
  );

  -- video timing generator
  sync_gen : entity work.sync_gen
  port map (
    clk   => clk_12,
    cen   => cen_6,
    pos   => video_pos,
    sync  => video_sync,
    blank => video_blank
  );

  -- program ROM 1
  prog_rom_1 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_1_ADDR_WIDTH, INIT_FILE => "rom/cpu_5p.mif")
  port map (
    clk  => clk_12,
    cs   => prog_rom_1_cs,
    addr => cpu_addr(PROG_ROM_1_ADDR_WIDTH-1 downto 0),
    dout => prog_rom_1_dout
  );

  -- program ROM 2
  prog_rom_2 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_2_ADDR_WIDTH, INIT_FILE => "rom/cpu_5m.mif")
  port map (
    clk  => clk_12,
    cs   => prog_rom_2_cs,
    addr => cpu_addr(PROG_ROM_2_ADDR_WIDTH-1 downto 0),
    dout => prog_rom_2_dout
  );

  -- program ROM 3
  prog_rom_3 : entity work.single_port_rom
  generic map (ADDR_WIDTH => PROG_ROM_3_ADDR_WIDTH, INIT_FILE => "rom/cpu_5j.mif")
  port map (
    clk  => clk_12,
    cs   => prog_rom_3_cs,
    addr => std_logic_vector(current_bank) & cpu_addr(10 downto 0),
    dout => prog_rom_3_dout
  );

  -- work RAM
  work_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => WORK_RAM_ADDR_WIDTH)
  port map (
    clk  => clk_12,
    cs   => work_ram_cs,
    addr => cpu_addr(WORK_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => work_ram_dout,
    we   => not cpu_wr_n
  );

  -- background RAM
  bg_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => BG_RAM_ADDR_WIDTH)
  port map (
    clk  => clk_12,
    cs   => bg_ram_cs,
    addr => cpu_addr(BG_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => bg_ram_dout,
    we   => not cpu_wr_n
  );

  -- sprite RAM
  sprite_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => SPRITE_RAM_ADDR_WIDTH)
  port map (
    clk  => clk_12,
    cs   => sprite_ram_cs,
    addr => cpu_addr(SPRITE_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => sprite_ram_dout,
    we   => not cpu_wr_n
  );

  -- main CPU
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
  generic map (FALLING => true)
  port map (
    clk  => clk_12,
    data => video_blank.vblank,
    edge => vblank_falling
  );

  -- Trigger an interrupt on the falling edge of the VBLANK signal.
  --
  -- Once the interrupt request has been accepted by the CPU, it is
  -- acknowledged by activating the IORQ signal during the M1 cycle. This
  -- disables the interrupt signal, and the cycle starts over.
  irq : process (clk_12)
  begin
    if rising_edge(clk_12) then
      if cpu_m1_n = '0' and cpu_ioreq_n = '0' then
        cpu_int_n <= '1';
      elsif vblank_falling = '1' then
        cpu_int_n <= '0';
      end if;
    end if;
  end process;

  -- set current bank register
  set_current_bank : process (clk_12)
  begin
    if rising_edge(clk_12) then
      if bank_cs = '1' and cpu_wr_n = '0' then
        -- flip-flop 6J uses data lines 3 to 6
        current_bank <= unsigned(cpu_dout(6 downto 3));
      end if;
    end if;
  end process;

  -- set foreground horizontal and vertical scroll position registers
  set_fg_scroll_pos : process (clk_12)
  begin
    if rising_edge(clk_12) then
      if fg_scroll_cs = '1' and cpu_wr_n = '0' then
        case cpu_addr(1 downto 0) is
          when "00" => fg_scroll_hpos(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when "01" => fg_scroll_hpos(8 downto 8) <= unsigned(cpu_dout(0 downto 0));
          when "10" => fg_scroll_vpos(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- set background horizontal and vertical scroll position registers
  set_bg_scroll_pos : process (clk_12)
  begin
    if rising_edge(clk_12) then
      if bg_scroll_cs = '1' and cpu_wr_n = '0' then
        case cpu_addr(1 downto 0) is
          when "00" => bg_scroll_hpos(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when "01" => bg_scroll_hpos(8 downto 8) <= unsigned(cpu_dout(0 downto 0));
          when "10" => bg_scroll_vpos(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- character layer
  char : entity work.char
  port map (
    clk       => clk_12,
    cen       => cen_6,
    ram_cs    => char_ram_cs,
    ram_addr  => cpu_addr(CHAR_RAM_ADDR_WIDTH-1 downto 0),
    ram_din   => cpu_dout,
    ram_dout  => char_ram_dout,
    ram_we    => not cpu_wr_n,
    video_pos => video_pos,
    data      => char_data
  );

  -- foreground layer
  fg : entity work.scroll
  generic map (
    RAM_ADDR_WIDTH => FG_RAM_ADDR_WIDTH,
    ROM_ADDR_WIDTH => FG_ROM_ADDR_WIDTH,
    ROM_INIT_FILE  => "rom/fg.mif"
  )
  port map (
    clk         => clk_12,
    cen         => cen_6,
    ram_cs      => fg_ram_cs,
    ram_addr    => cpu_addr(FG_RAM_ADDR_WIDTH-1 downto 0),
    ram_din     => cpu_dout,
    ram_dout    => fg_ram_dout,
    ram_we      => not cpu_wr_n,
    video_pos   => video_pos,
    video_sync  => video_sync,
    scroll_hpos => fg_scroll_hpos,
    scroll_vpos => fg_scroll_vpos,
    data        => fg_data
  );

  -- colour palette
  palette : entity work.palette
  port map (
    clk         => clk_12,
    cen         => cen_6,
    ram_cs      => palette_ram_cs,
    ram_addr    => cpu_addr(PALETTE_RAM_ADDR_WIDTH-1 downto 0),
    ram_din     => cpu_dout,
    ram_dout    => palette_ram_dout,
    ram_we      => not cpu_wr_n,
    char_data   => char_data,
    fg_data     => fg_data,
    video_blank => video_blank,
    pixel       => pixel
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
  fg_scroll_cs   <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"f800" and unsigned(cpu_addr) <= x"f801" else '0';
  bg_scroll_cs   <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"f803" and unsigned(cpu_addr) <= x"f804" else '0';
  bank_cs        <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) = x"f808" else '0';

  -- CPU data input bus
  cpu_din <= prog_rom_1_dout or
             prog_rom_2_dout or
             prog_rom_3_dout or
             work_ram_dout or
             char_ram_dout or
             fg_ram_dout or
             bg_ram_dout or
             sprite_ram_dout or
             palette_ram_dout;

  led <= cpu_dout when work_ram_cs = '1' and cpu_wr_n = '0' else (others => '0');

  -- composite sync
  vga_csync <= not (video_sync.hsync xor video_sync.vsync);

  -- color output
  vga_r <= pixel.r & pixel.r(3 downto 2);
  vga_g <= pixel.g & pixel.g(3 downto 2);
  vga_b <= pixel.b & pixel.b(3 downto 2);
end arch;
